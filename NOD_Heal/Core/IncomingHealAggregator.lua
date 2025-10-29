-- Module: IncomingHealAggregator
-- Purpose: Collect raw heals observed in the combat log and expose a cleaned queue per target for downstream consumers.
-- API: COMBAT_LOG_EVENT_UNFILTERED, CombatLogGetCurrentEventInfo, UnitGUID, GetTime

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
local lastPrune = 0

local HEAL_STORAGE = {} -- [targetGUID] = { { sourceGUID, amount, landTime, spellID, overheal } }
local PRUNE_INTERVAL = 1.0
local STALE_PADDING = 0.25

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

local function purgeExpired(now)
  now = now or GetTime()
  for targetGUID, queue in pairs(HEAL_STORAGE) do
    local write = 1
    for i = 1, #queue do
      local entry = queue[i]
      if entry and entry.landTime and entry.landTime + STALE_PADDING >= now then
        queue[write] = entry
        write = write + 1
      end
    end
    for i = write, #queue do
      queue[i] = nil
    end
    if #queue == 0 then
      HEAL_STORAGE[targetGUID] = nil
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

function aggregator.Initialize(dispatcher)
  dispatcherRef = dispatcher

  if dispatcher and dispatcher.RegisterHandler then
    dispatcher:RegisterHandler("COMBAT_LOG_EVENT_UNFILTERED", handleCombatLog)
    dispatcher:RegisterHandler("GROUP_ROSTER_UPDATE", function()
      resetStorage()
    end)
    dispatcher:RegisterHandler("PLAYER_REGEN_ENABLED", function()
      resetStorage()
    end)
  end
end

function aggregator.AddHeal(sourceGUID, targetGUID, landTime, amount, spellID, metadata)
  local guid = toGUID(targetGUID)
  if not guid then
    return
  end

  local payload = {
    sourceGUID = sourceGUID,
    targetGUID = guid,
    spellID = spellID,
    amount = amount or 0,
    landTime = landTime or GetTime(),
    metadata = metadata,
  }

  pushHeal(payload)
  purgeExpired()
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

return _G.NODHeal:RegisterModule("IncomingHealAggregator", aggregator)
