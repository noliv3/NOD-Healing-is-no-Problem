-- Module: IncomingHeals
-- Purpose: Aggregate all incoming heals from LibHealComm and Blizzard API sources until the computed landing time.
-- API: LibHealComm callbacks, UnitGetIncomingHeals

local healQueue = {}
local libHandle

local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitGetIncomingHeals = UnitGetIncomingHeals
local pairs = pairs
local ipairs = ipairs

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

local function scheduleFromTargets(casterGUID, spellID, endTime, targets)
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

function M.Initialize(libHealComm, dispatcher)
  libHandle = libHealComm

  if libHealComm and libHealComm.RegisterCallback then
    libHealComm:RegisterCallback(M, "HealComm_HealStarted", function(_, casterGUID, spellID, _, endTime, targets)
      scheduleFromTargets(casterGUID, spellID, endTime, targets)
    end)

    libHealComm:RegisterCallback(M, "HealComm_HealUpdated", function(_, casterGUID, spellID, _, endTime, targets)
      scheduleFromTargets(casterGUID, spellID, endTime, targets)
    end)

    libHealComm:RegisterCallback(M, "HealComm_HealDelayed", function(_, casterGUID, spellID, _, endTime, targets)
      scheduleFromTargets(casterGUID, spellID, endTime, targets)
    end)

    libHealComm:RegisterCallback(M, "HealComm_HealStopped", function(_, casterGUID, spellID, _, targets)
      removeEntries(casterGUID, spellID, targets)
    end)
  end

  if dispatcher and dispatcher.RegisterHandler then
    dispatcher:RegisterHandler("UNIT_SPELLCAST_STOP", function()
      -- Clear completed heals on every stop to avoid stale entries.
      local now = GetTime()
      for guid in pairs(healQueue) do
        purgeExpired(guid, now)
      end
    end)
  end
end

function M.CollectUntil(unit, tLand)
  local guid = getGuid(unit)
  if not guid then
    return { total = 0, contributions = {}, confidence = "low" }
  end

  local queue = healQueue[guid]
  if not queue or not tLand then
    local fallback = M.FetchFallback(unit)
    return {
      total = fallback.amount,
      contributions = fallback.contributions,
      confidence = fallback.confidence,
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
    local fallback = M.FetchFallback(unit)
    return {
      total = fallback.amount,
      contributions = fallback.contributions,
      confidence = fallback.confidence,
    }
  end

  return {
    total = total,
    contributions = contributions,
    confidence = "high",
  }
end

function M.FetchFallback(unit, healer)
  local amount = 0
  if UnitGetIncomingHeals then
    amount = UnitGetIncomingHeals(unit, healer) or UnitGetIncomingHeals(unit) or 0
  end

  local contributions = {}
  if healer and amount > 0 then
    contributions[healer] = amount
  end

  local confidence = libHandle and "medium" or "low"

  return {
    amount = amount,
    contributions = contributions,
    confidence = confidence,
  }
end

function M.CleanExpired(unit)
  local now = GetTime()
  if unit then
    local guid = getGuid(unit)
    if guid then
      purgeExpired(guid, now)
    end
  else
    for guid in pairs(healQueue) do
      purgeExpired(guid, now)
    end
  end
end

return M
