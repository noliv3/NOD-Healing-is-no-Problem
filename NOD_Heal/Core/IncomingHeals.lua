-- Module: IncomingHeals (read-side)
-- Purpose: Read-only interface to collect incoming heals until tLand using LHC/API fallback.
-- Role: Provides aggregated view for solver consumption; no dispatch or persistent queues here.
-- See also: IncomingHealAggregator (write-side feed & dispatcher)

local healQueue = {}
local libHandle
local dispatcherRef

local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitGetIncomingHeals = UnitGetIncomingHeals
local pairs = pairs
local ipairs = ipairs
local type = type

local LANDING_EPSILON = 0.05

local function getGuid(unit)
  if not unit then
    return nil
  end
  return UnitGUID and UnitGUID(unit) or unit
end

local function pushHeal(targetGUID, payload)
  if not targetGUID then
    return
  end

  local queue = healQueue[targetGUID]
  if not queue then
    queue = {}
    healQueue[targetGUID] = queue
  end

  queue[#queue + 1] = payload
end

local function purgeExpired(targetGUID, now)
  local queue = healQueue[targetGUID]
  if not queue then
    return
  end

  now = now or GetTime()

  local write = 1
  local size = #queue
  for index = 1, size do
    local entry = queue[index]
    local landTime = entry and entry.t_land
    if landTime and landTime + LANDING_EPSILON >= now then
      queue[write] = entry
      write = write + 1
    end
  end

  for index = write, size do
    queue[index] = nil
  end

  if write == 1 then
    healQueue[targetGUID] = nil
  end
end

local function scheduleFromTargetsInternal(casterGUID, spellID, endTime, targets)
  if type(targets) ~= "table" then
    return
  end

  local landing = endTime
  if landing then
    if landing > 1000000 then
      landing = landing / 1000
    end
  else
    landing = GetTime()
  end

  for targetGUID, amount in pairs(targets) do
    local payload = {
      amount = amount or 0,
      source = casterGUID,
      spellID = spellID,
      t_land = landing,
    }
    pushHeal(targetGUID, payload)
  end
end

local function removeEntries(casterGUID, spellID, targets)
  if type(targets) ~= "table" then
    return
  end

  for targetGUID in pairs(targets) do
    local queue = healQueue[targetGUID]
    if queue then
      local write = 1
      for i = 1, #queue do
        local entry = queue[i]
        if entry and (entry.source ~= casterGUID or (spellID and entry.spellID ~= spellID)) then
          queue[write] = entry
          write = write + 1
        end
      end
      for i = write, #queue do
        queue[i] = nil
      end
    end
  end
end

local M = {}

-- REGION: LHC Callbacks
-- [D1-LHCAPI] Registrierung von HealComm-Events
function M.RegisterHealComm()
  print("[NOD] RegisterHealComm() – Placeholder aktiviert")
end

-- [D1-LHCAPI] Deregistrierung von HealComm-Events
function M.UnregisterHealComm()
  print("[NOD] UnregisterHealComm() – Placeholder deaktiviert")
end

-- [D1-LHCAPI] Queue-Aufbau aus HealComm-Payload
function M.scheduleFromTargets(casterGUID, spellID, targets, amount, t_land)
  print("[NOD] scheduleFromTargets()", casterGUID, spellID, amount, t_land)
  if scheduleFromTargetsInternal then
    local effectiveEndTime = t_land
    local effectiveTargets = targets
    if type(targets) ~= "table" and type(amount) == "table" then
      effectiveEndTime = targets
      effectiveTargets = amount
    end
    scheduleFromTargetsInternal(casterGUID, spellID, effectiveEndTime, effectiveTargets)
  end
end
-- ENDREGION

function M.Initialize(libHealComm, dispatcher)
  libHandle = libHealComm
  dispatcherRef = dispatcher or dispatcherRef
  if not dispatcherRef then
    local namespace = _G.NODHeal
    if namespace and namespace.GetModule then
      dispatcherRef = namespace:GetModule("CoreDispatcher")
    end
  end

  if libHealComm and libHealComm.RegisterCallback then
    libHealComm:RegisterCallback(M, "HealComm_HealStarted", function(_, casterGUID, spellID, _, endTime, targets)
      scheduleFromTargetsInternal(casterGUID, spellID, endTime, targets)
    end)

    libHealComm:RegisterCallback(M, "HealComm_HealUpdated", function(_, casterGUID, spellID, _, endTime, targets)
      scheduleFromTargetsInternal(casterGUID, spellID, endTime, targets)
    end)

    libHealComm:RegisterCallback(M, "HealComm_HealDelayed", function(_, casterGUID, spellID, _, endTime, targets)
      scheduleFromTargetsInternal(casterGUID, spellID, endTime, targets)
    end)

    libHealComm:RegisterCallback(M, "HealComm_HealStopped", function(_, casterGUID, spellID, _, targets)
      removeEntries(casterGUID, spellID, targets)
    end)
  end

  if dispatcherRef and dispatcherRef.RegisterHandler then
    dispatcherRef:RegisterHandler("UNIT_SPELLCAST_STOP", function()
      M.CleanExpired()
    end)
  end
end

function M.CollectUntil(unit, tLand)
  local guid = getGuid(unit)
  if not guid then
    return { amount = 0, confidence = "low", sources = {} }
  end

  local queue = healQueue[guid]
  if not queue or not tLand then
    local fallbackAmount = M.FetchFallback(unit, tLand)
    return {
      amount = fallbackAmount,
      confidence = fallbackAmount > 0 and (libHandle and "medium" or "low") or "low",
      sources = {},
    }
  end

  local now = GetTime()
  purgeExpired(guid, now)

  local total = 0
  local contributions = {}
  for _, entry in ipairs(queue) do
    if not entry.t_land or entry.t_land <= (tLand + LANDING_EPSILON) then
      total = total + (entry.amount or 0)
      local source = entry.source or "unknown"
      contributions[source] = (contributions[source] or 0) + (entry.amount or 0)
    end
  end

  if total <= 0 then
    local fallbackAmount = M.FetchFallback(unit, tLand)
    return {
      amount = fallbackAmount,
      confidence = fallbackAmount > 0 and (libHandle and "medium" or "low") or "low",
      sources = contributions,
    }
  end

  return {
    amount = total,
    confidence = "high",
    sources = contributions,
  }
end

-- REGION: API Fallback
-- [D1-LHCAPI] Blizzard-API-Fallback (UnitGetIncomingHeals)
function M.FetchFallback(unit, tLand)
  print("[NOD] FetchFallback()", unit, tLand)
  if not UnitGetIncomingHeals or not unit then
    return 0, "fallback"
  end

  local amount = UnitGetIncomingHeals(unit) or 0
  if amount < 0 then
    amount = 0
  end

  return amount, "fallback"
end
-- ENDREGION

-- REGION: Cleanup
-- [D1-LHCAPI] Queue-Bereinigung
function M.CleanExpired(now, unit)
  print("[NOD] CleanExpired() – Queue gereinigt (Stub)")
  local timestamp = now
  local unitRef = unit

  if type(now) == "string" or type(now) == "table" then
    unitRef = now
    timestamp = nil
  end

  local current = timestamp or GetTime()
  if unitRef then
    local guid = getGuid(unitRef)
    if guid then
      purgeExpired(guid, current)
    end
    return
  end

  for guid in pairs(healQueue) do
    purgeExpired(guid, current)
  end
end

-- ENDREGION

-- [D1-LHCAPI] Placeholder verification
if DEBUG then
  print("[NOD] LHC/API stub loaded")
end

return _G.NODHeal:RegisterModule("IncomingHeals", M)
