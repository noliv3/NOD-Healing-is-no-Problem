-- Module: IncomingHealAggregator (write-side)
-- Purpose: Central feed of incoming heal events; maintains queues, cleans expired items, dispatches notifications.
-- Role: Producer/bridge from combat/log callbacks to consumers; not responsible for read-time aggregation.
-- Provides: CleanExpired, AddHeal, Dispatch hooks
-- See also: IncomingHeals (read-side aggregator for solver)
-- Referenz: /DOCU/NOD_Datenpfad_LHC_API.md §Ereignisfluss

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitGUID = UnitGUID
local GetTime = GetTime
local pairs = pairs
local ipairs = ipairs
local wipe = wipe
local math_huge = math.huge
local type = type

local dispatcherRef
local aggregator = {}

-- REGION: LHC Callbacks
-- [D1-LHCAPI] Registrierung von HealComm-Events
function aggregator.RegisterHealComm()
  print("[NOD] RegisterHealComm() – Placeholder aktiviert")
end

-- [D1-LHCAPI] Deregistrierung von HealComm-Events
function aggregator.UnregisterHealComm()
  print("[NOD] UnregisterHealComm() – Placeholder deaktiviert")
end

-- [D1-LHCAPI] Queue-Aufbau aus HealComm-Payload
function aggregator.scheduleFromTargets(casterGUID, spellID, targets, amount, t_land)
  print(string.format("[NOD] scheduleFromTargets() %s %s %s %s", tostring(casterGUID), tostring(spellID), tostring(amount), tostring(t_land)))
end
-- ENDREGION

-- REGION: HealComm Toggle
-- [D1-LHCAPI] Toggle-Kommandos für HealComm-Platzhalter
function aggregator.ToggleHealComm(state)
  print(string.format("[NOD] ToggleHealComm() %s", tostring(state)))
end
-- ENDREGION

-- REGION: API Fallback
-- [D1-LHCAPI] Fallback-Router (Aggregator-Sicht)
function aggregator.FetchFallback(unit)
  print(string.format("[NOD] FetchFallback() %s", tostring(unit)))
  return 0, "fallback"
end
-- ENDREGION

local lastPrune = 0

local HEAL_STORAGE = {} -- [targetGUID] = { { sourceGUID, amount, landTime, spellID, overheal } }
local PRUNE_INTERVAL = 1.0
local STALE_PADDING = 0.25
local EXPIRY_GRACE = 0.05

if not wipe then
  wipe = function(tbl)
    if not tbl then
      return
    end
    for key in pairs(tbl) do
      tbl[key] = nil
    end
  end
end

local function dispatch(eventName, ...)
  if dispatcherRef and dispatcherRef.Dispatch then
    dispatcherRef.Dispatch(eventName, ...)
  end
end

local function pruneQueue(queue, now)
  if not queue then
    return 0
  end

  local write = 1
  local size = #queue
  for index = 1, size do
    local entry = queue[index]
    local landTime = entry and entry.landTime
    if landTime and (landTime + STALE_PADDING + EXPIRY_GRACE) >= now then
      queue[write] = entry
      write = write + 1
    end
  end

  for index = write, size do
    queue[index] = nil
  end

  return write - 1
end

local function purgeExpired(now, targetGUID)
  now = now or GetTime()

  if targetGUID then
    local queue = HEAL_STORAGE[targetGUID]
    if pruneQueue(queue, now) == 0 then
      HEAL_STORAGE[targetGUID] = nil
    end
    lastPrune = now
    return
  end

  for guid, queue in pairs(HEAL_STORAGE) do
    if pruneQueue(queue, now) == 0 then
      HEAL_STORAGE[guid] = nil
    end
  end

  lastPrune = now
end

local function resetStorage()
  wipe(HEAL_STORAGE)
  lastPrune = GetTime()
end

local function pushHeal(payload)
  if not payload or not payload.targetGUID then
    return
  end

  local targetGUID = payload.targetGUID
  local queue = HEAL_STORAGE[targetGUID]
  if not queue then
    queue = {}
    HEAL_STORAGE[targetGUID] = queue
  end

  queue[#queue + 1] = payload
  dispatch("NOD_INCOMING_HEAL_RECORDED", targetGUID, payload)
end

local function handleCombatLog()
  if not CombatLogGetCurrentEventInfo then
    return
  end

  local timestamp, eventType, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, _, _, amount, overheal = CombatLogGetCurrentEventInfo()
  if not destGUID then
    return
  end

  if eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" then
    local now = timestamp or GetTime()
    pushHeal({
      sourceGUID = sourceGUID,
      targetGUID = destGUID,
      spellID = spellID,
      amount = amount or 0,
      overheal = overheal or 0,
      landTime = now,
      event = eventType,
    })
  elseif eventType == "SPELL_CAST_SUCCESS" then
    dispatch("NOD_INCOMING_CAST_SUCCESS", {
      sourceGUID = sourceGUID,
      targetGUID = destGUID,
      spellID = spellID,
      timestamp = timestamp or GetTime(),
    })
  end

  local now = GetTime()
  if (now - lastPrune) >= PRUNE_INTERVAL then
    purgeExpired(now)
  end
end

local function toGUID(unitOrGUID)
  if not unitOrGUID then
    return nil
  end

  if UnitGUID and type(unitOrGUID) == "string" and #unitOrGUID <= 18 then
    local guid = UnitGUID(unitOrGUID)
    if guid then
      return guid
    end
  end

  return unitOrGUID
end

local function obtainDispatcher()
  if dispatcherRef then
    return dispatcherRef
  end

  local namespace = _G.NODHeal
  if namespace and namespace.GetModule then
    dispatcherRef = namespace:GetModule("CoreDispatcher")
  end

  return dispatcherRef
end

function aggregator.Initialize(dispatcher)
  dispatcherRef = dispatcher or obtainDispatcher()

  local hub = dispatcherRef
  if hub and hub.RegisterHandler then
    hub:RegisterHandler("COMBAT_LOG_EVENT_UNFILTERED", handleCombatLog)
    hub:RegisterHandler("GROUP_ROSTER_UPDATE", function()
      resetStorage()
    end)
    hub:RegisterHandler("PLAYER_REGEN_ENABLED", function()
      resetStorage()
    end)
  end
end

local function normalizeLandingTime(value)
  if value == nil then
    return GetTime()
  end

  if type(value) ~= "number" then
    value = tonumber(value)
  end

  if not value then
    return GetTime()
  end

  if value > 1000000 then
    return value / 1000
  end

  return value
end

function aggregator.AddHeal(payload)
  if type(payload) ~= "table" then
    return
  end

  local guid = toGUID(payload.targetGUID)
  if not guid then
    return
  end

  local amount = payload.amount or 0
  if amount < 0 then
    amount = 0
  end

  local entry = {
    sourceGUID = payload.sourceGUID,
    targetGUID = guid,
    spellID = payload.spellID,
    amount = amount,
    landTime = normalizeLandingTime(payload.landTime),
    metadata = payload.metadata,
  }

  pushHeal(entry)
  purgeExpired(entry.landTime or GetTime(), guid)
end

function aggregator.GetIncoming(unit, horizon)
  local guid = toGUID(unit)
  if not guid then
    return 0
  end

  purgeExpired()

  local queue = HEAL_STORAGE[guid]
  if not queue or #queue == 0 then
    return 0
  end

  local now = GetTime()
  local cutoff
  if horizon then
    if horizon > 1000000 then
      cutoff = horizon
    else
      cutoff = now + horizon
    end
  else
    cutoff = math_huge
  end

  local total = 0
  for index = 1, #queue do
    local entry = queue[index]
    if entry and entry.landTime and entry.landTime <= cutoff then
      total = total + (entry.amount or 0)
    end
  end

  return total
end

-- REGION: Cleanup
-- [D1-LHCAPI] Queue-Bereinigung
function aggregator.CleanExpired(now, unit)
  print("[NOD] CleanExpired() – Queue gereinigt (Stub)")
  local timestamp = now
  local unitRef = unit

  if type(now) == "string" or type(now) == "table" then
    unitRef = now
    timestamp = nil
  end

  local current = timestamp or GetTime()
  if unitRef then
    local guid = toGUID(unitRef)
    if guid then
      purgeExpired(current, guid)
    end
    return
  end

  purgeExpired(current)
end
-- ENDREGION

function aggregator.Iterate(unit, horizon, collector)
  local guid = toGUID(unit)
  if not guid or type(collector) ~= "function" then
    return
  end

  purgeExpired()

  local queue = HEAL_STORAGE[guid]
  if not queue then
    return
  end

  local now = GetTime()
  local cutoff
  if horizon then
    if horizon > 1000000 then
      cutoff = horizon
    else
      cutoff = now + horizon
    end
  else
    cutoff = math_huge
  end

  for _, entry in ipairs(queue) do
    if entry and entry.landTime and entry.landTime <= cutoff then
      collector(entry)
    end
  end
end

function aggregator.DebugDump()
  return HEAL_STORAGE
end

-- [D1-LHCAPI] Placeholder verification
if DEBUG then
  print("[NOD] LHC/API stub loaded")
end

return _G.NODHeal:RegisterModule("IncomingHealAggregator", aggregator)
