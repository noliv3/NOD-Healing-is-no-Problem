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
local format = string.format
local math_floor = math.floor
local tonumber = tonumber

local dispatcherRef
local aggregator = {}

local HEAL_STORAGE = {} -- [targetGUID] = { { amount, landTime, sourceGUID, spellID } }
local lastPrune = 0

local STALE_PADDING = 0.25
local EXPIRY_GRACE = 0.05
local PRUNE_INTERVAL = 1.0

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

local function log(message)
  if message then
    print("[NOD] " .. message)
  end
end

local function namespace()
  return _G.NODHeal
end

local function toGUID(unitOrGUID)
  if not unitOrGUID then
    return nil
  end

  if UnitGUID and type(unitOrGUID) == "string" and (#unitOrGUID <= 18 or unitOrGUID:match("^[%a]+$")) then
    local guid = UnitGUID(unitOrGUID)
    if guid then
      return guid
    end
  end

  return unitOrGUID
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

local function ensureQueue(targetGUID)
  local queue = HEAL_STORAGE[targetGUID]
  if not queue then
    queue = {}
    HEAL_STORAGE[targetGUID] = queue
  end
  return queue
end

local function dispatch(eventName, ...)
  if dispatcherRef and dispatcherRef.Dispatch then
    dispatcherRef.Dispatch(eventName, ...)
  end
end

local function pruneQueue(queue, now)
  if not queue then
    return 0, 0
  end

  local write = 1
  local removed = 0
  local size = #queue
  for index = 1, size do
    local entry = queue[index]
    local landTime = entry and entry.landTime
    if landTime and (landTime + STALE_PADDING + EXPIRY_GRACE) >= now then
      queue[write] = entry
      write = write + 1
    else
      removed = removed + 1
    end
  end

  for index = write, size do
    queue[index] = nil
  end

  return write - 1, removed
end

local function purgeExpired(now, targetGUID)
  now = now or GetTime()

  if targetGUID then
    local queue = HEAL_STORAGE[targetGUID]
    if not queue then
      return 0
    end
    local remaining, removed = pruneQueue(queue, now)
    if remaining == 0 then
      HEAL_STORAGE[targetGUID] = nil
    end
    return removed
  end

  local totalRemoved = 0
  for guid, queue in pairs(HEAL_STORAGE) do
    local remaining, removed = pruneQueue(queue, now)
    if remaining == 0 then
      HEAL_STORAGE[guid] = nil
    end
    totalRemoved = totalRemoved + removed
  end
  lastPrune = now
  return totalRemoved
end

local function summarize(targetGUID, cutoff)
  local queue = HEAL_STORAGE[targetGUID]
  if not queue then
    return 0, 0
  end

  local total = 0
  local count = 0
  for index = 1, #queue do
    local entry = queue[index]
    if entry and entry.landTime and entry.landTime <= cutoff then
      total = total + (entry.amount or 0)
      count = count + 1
    end
  end
  return total, count
end

local function tickDispatcher()
  local now = GetTime()
  if (now - lastPrune) >= PRUNE_INTERVAL then
    local removed = purgeExpired(now)
    if removed > 0 then
      log(format("Agg: CleanExpired removed=%d", removed))
    end
  end
end

local function obtainDispatcher()
  if dispatcherRef then
    return dispatcherRef
  end

  local ns = namespace()
  if ns and ns.GetModule then
    dispatcherRef = ns:GetModule("CoreDispatcher")
  end
  return dispatcherRef
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
    aggregator.AddHeal({
      targetGUID = destGUID,
      amount = amount or 0,
      landTime = now,
      sourceGUID = sourceGUID,
      spellID = spellID,
      overheal = overheal or 0,
      source = eventType,
    })
  elseif eventType == "SPELL_CAST_SUCCESS" then
    dispatch("NOD_INCOMING_CAST_SUCCESS", {
      sourceGUID = sourceGUID,
      targetGUID = destGUID,
      spellID = spellID,
      timestamp = timestamp or GetTime(),
    })
  end

  tickDispatcher()
end

local function clampAmount(value)
  if not value then
    return 0
  end
  local amount = math_floor(value + 0.5)
  if amount < 0 then
    amount = 0
  end
  return amount
end

function aggregator.AddHeal(payload)
  if type(payload) ~= "table" then
    return
  end

  local targetGUID = toGUID(payload.targetGUID)
  if not targetGUID then
    return
  end

  local amount = clampAmount(payload.amount)
  local landing = normalizeLandingTime(payload.landTime)

  local entry = {
    amount = amount,
    landTime = landing,
    sourceGUID = payload.sourceGUID,
    spellID = payload.spellID,
    source = payload.source,
  }

  ensureQueue(targetGUID)
  local queue = HEAL_STORAGE[targetGUID]
  queue[#queue + 1] = entry

  log(format("LHC: queue target=%s +%d@%.2f from caster=%s spell=%s", tostring(targetGUID), amount, landing, tostring(payload.sourceGUID), tostring(payload.spellID)))

  dispatch("NOD_INCOMING_HEAL_RECORDED", targetGUID, entry)
  purgeExpired(landing + STALE_PADDING, targetGUID)
end

function aggregator.RemoveHeal(descriptor)
  if type(descriptor) ~= "table" then
    return
  end

  local casterGUID = descriptor.casterGUID
  local spellID = descriptor.spellID
  local targets = descriptor.targets
  if type(targets) ~= "table" then
    return
  end

  for targetGUID in pairs(targets) do
    local guid = toGUID(targetGUID)
    local queue = HEAL_STORAGE[guid]
    if queue then
      local write = 1
      local removed = 0
      for index = 1, #queue do
        local entry = queue[index]
        local match = entry and entry.sourceGUID == casterGUID
        if match and spellID and entry.spellID ~= spellID then
          match = false
        end
        if match then
          removed = removed + 1
        else
          queue[write] = entry
          write = write + 1
        end
      end
      for index = write, #queue do
        queue[index] = nil
      end
      if write == 1 then
        HEAL_STORAGE[guid] = nil
      end
      if removed > 0 then
        log(format("LHC: removed target=%s entries=%d caster=%s spell=%s", tostring(guid), removed, tostring(casterGUID), tostring(spellID)))
      end
    end
  end
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

  local total, count = summarize(guid, cutoff)
  log(format("Agg: sum target=%s = %d@≤%.2f (%d entries)", tostring(guid), total, cutoff, count))
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

function aggregator.CleanExpired(now, unit)
  local timestamp = now
  local unitRef = unit

  if type(now) == "string" or type(now) == "table" then
    unitRef = now
    timestamp = nil
  end

  local current = timestamp or GetTime()
  local removed

  if unitRef then
    local guid = toGUID(unitRef)
    if guid then
      removed = purgeExpired(current, guid)
    end
  else
    removed = purgeExpired(current)
  end

  if removed and removed > 0 then
    log(format("Agg: CleanExpired removed=%d", removed))
  end
end

function aggregator.FetchFallback(unit)
  local incoming = namespace() and namespace():GetModule("IncomingHeals")
  if incoming and incoming.FetchFallback then
    return incoming.FetchFallback(unit)
  end
  return { amount = 0, confidence = "low" }
end

function aggregator.RegisterHealComm()
  local incoming = namespace() and namespace():GetModule("IncomingHeals")
  if incoming and incoming.RegisterHealComm then
    return incoming.RegisterHealComm()
  end
  return false
end

function aggregator.UnregisterHealComm()
  local incoming = namespace() and namespace():GetModule("IncomingHeals")
  if incoming and incoming.UnregisterHealComm then
    incoming.UnregisterHealComm()
  end
end

function aggregator.ToggleHealComm(stateFlag)
  if stateFlag then
    aggregator.RegisterHealComm()
  else
    aggregator.UnregisterHealComm()
  end
end

function aggregator.Initialize(dispatcher)
  dispatcherRef = dispatcher or obtainDispatcher()

  local hub = dispatcherRef
  if hub and hub.RegisterHandler then
    hub.RegisterHandler("COMBAT_LOG_EVENT_UNFILTERED", handleCombatLog)
    hub.RegisterHandler("GROUP_ROSTER_UPDATE", function()
      wipe(HEAL_STORAGE)
      log("Agg: reset on GROUP_ROSTER_UPDATE")
    end)
    hub.RegisterHandler("PLAYER_REGEN_ENABLED", function()
      wipe(HEAL_STORAGE)
      log("Agg: reset on PLAYER_REGEN_ENABLED")
    end)
  end
end

function aggregator.DebugDump()
  return HEAL_STORAGE
end

return _G.NODHeal:RegisterModule("IncomingHealAggregator", aggregator)
