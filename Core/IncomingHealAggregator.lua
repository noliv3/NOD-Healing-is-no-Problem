-- Module: IncomingHealAggregator (write-side)
-- Purpose: Central feed of incoming heal events; maintains queues, cleans expired items, dispatches notifications.
-- Role: Producer/bridge from combat/log callbacks to consumers; not responsible for read-time aggregation.
-- Provides: CleanExpired, AddHeal, Dispatch hooks
-- See also: IncomingHeals (read-side aggregator for solver)
-- Referenz: /DOCU/NOD_Datenpfad_LHC_API.md §Ereignisfluss

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local GetTime = GetTime
local pairs = pairs
local ipairs = ipairs
local wipe = wipe
local math_huge = math.huge
local type = type
local format = string.format
local math_floor = math.floor
local tonumber = tonumber
local tostring = tostring
local select = select
local strmatch = string.match

local dispatcherRef
local aggregator = {}
local castLandingModule
local estimatorModule
local healCommLib

local HEAL_STORAGE = {} -- [targetGUID] = { { amount, landTime, sourceGUID, spellID } }
local SCHEDULED_STORAGE = {} -- [targetGUID] = { list = {}, index = {} }
local SCHEDULED_BY_KEY = {} -- [key] = entry
local PENDING_CASTS = {} -- [castGUID] = { key = castKey }
local CAST_LOOKUP = {} -- [castKey] = { success = boolean }
local lastPrune = 0

local STALE_PADDING = 0.25
local EXPIRY_GRACE = 0.05
local FUTURE_PADDING = 0.5
local PRUNE_INTERVAL = 1.0

local NODHeal = _G.NODHeal or {}
local core = NODHeal.Core or {}
local debugLog = core.Log or function() end

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
    debugLog(message)
  end
end

local function namespace()
  return _G.NODHeal
end

local function getConfig()
  local ns = namespace()
  if ns and ns.Config then
    return ns.Config
  end
  return {}
end

local function getHealsConfig()
  local cfg = getConfig()
  if type(cfg) ~= "table" then
    return {}
  end
  local heals = cfg.heals
  if type(heals) ~= "table" then
    return {}
  end
  return heals
end

local function isFutureWindowEnabled()
  local healsCfg = getHealsConfig()
  if healsCfg.futureWindow == false then
    return false
  end
  return true
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

local function ensureScheduledBucket(targetGUID)
  local bucket = SCHEDULED_STORAGE[targetGUID]
  if not bucket then
    bucket = { list = {}, index = {} }
    SCHEDULED_STORAGE[targetGUID] = bucket
  end
  return bucket
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

local function removeScheduledEntry(entry)
  if not entry or not entry.targetGUID then
    return false
  end

  local bucket = SCHEDULED_STORAGE[entry.targetGUID]
  if not bucket then
    return false
  end

  local list = bucket.list
  local write = 1
  local size = #list
  for index = 1, size do
    local candidate = list[index]
    if candidate ~= entry then
      list[write] = candidate
      write = write + 1
    end
  end

  for index = write, size do
    list[index] = nil
  end

  if entry.key then
    if bucket.index[entry.key] == entry then
      bucket.index[entry.key] = nil
    end
    if SCHEDULED_BY_KEY[entry.key] == entry then
      SCHEDULED_BY_KEY[entry.key] = nil
    end
  end

  if #list == 0 then
    SCHEDULED_STORAGE[entry.targetGUID] = nil
  end

  return true
end

local function pruneScheduled(bucket, now)
  if not bucket then
    return 0
  end

  local list = bucket.list
  local removed = 0
  local write = 1
  local size = #list
  for index = 1, size do
    local entry = list[index]
    local keep = false
    if entry and entry.landTime then
      if (entry.landTime + FUTURE_PADDING) >= now then
        keep = true
      end
    end
    if keep then
      list[write] = entry
      write = write + 1
    else
      removed = removed + 1
      if entry and entry.key then
        if bucket.index[entry.key] == entry then
          bucket.index[entry.key] = nil
        end
        if SCHEDULED_BY_KEY[entry.key] == entry then
          SCHEDULED_BY_KEY[entry.key] = nil
        end
      end
    end
  end

  for index = write, size do
    list[index] = nil
  end

  if #list == 0 then
    return removed
  end

  return removed
end

local function purgeScheduled(now, targetGUID)
  local timestamp = now or GetTime()
  if targetGUID then
    local bucket = SCHEDULED_STORAGE[targetGUID]
    if not bucket then
      return 0
    end
    local removed = pruneScheduled(bucket, timestamp)
    if #bucket.list == 0 then
      SCHEDULED_STORAGE[targetGUID] = nil
    end
    return removed
  end

  local total = 0
  for guid, bucket in pairs(SCHEDULED_STORAGE) do
    local removed = pruneScheduled(bucket, timestamp)
    if #bucket.list == 0 then
      SCHEDULED_STORAGE[guid] = nil
    end
    total = total + removed
  end
  return total
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
    local futureRemoved = purgeScheduled(now)
    if removed > 0 or futureRemoved > 0 then
      log(format("Agg: CleanExpired removed=%d future=%d", removed, futureRemoved))
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

local function addScheduled(payload)
  if type(payload) ~= "table" then
    return nil
  end

  local targetGUID = toGUID(payload.targetGUID)
  if not targetGUID then
    return nil
  end

  local amount = clampAmount(payload.amount)
  if amount <= 0 then
    return nil
  end

  local landing = normalizeLandingTime(payload.landTime)
  if not landing then
    return nil
  end

  local key = payload.key
  if key then
    local existing = SCHEDULED_BY_KEY[key]
    if existing then
      existing.amount = amount
      existing.landTime = landing
      existing.sourceGUID = payload.sourceGUID
      existing.spellID = payload.spellID
      existing.source = payload.source or existing.source
      existing.confidence = payload.confidence or existing.confidence
      existing.casterUnit = payload.casterUnit or existing.casterUnit
      existing.castGUID = payload.castGUID or existing.castGUID
      existing.targetGUID = targetGUID
      return existing
    end
  end

  local bucket = ensureScheduledBucket(targetGUID)
  local entry = {
    amount = amount,
    landTime = landing,
    sourceGUID = payload.sourceGUID,
    spellID = payload.spellID,
    source = payload.source,
    confidence = payload.confidence or "medium",
    casterUnit = payload.casterUnit,
    castGUID = payload.castGUID,
    key = key,
    targetGUID = targetGUID,
  }

  local list = bucket.list
  list[#list + 1] = entry

  if key then
    bucket.index[key] = entry
    SCHEDULED_BY_KEY[key] = entry
  end

  log(format(
    "Agg: schedule target=%s +%d@%.2f source=%s spell=%s key=%s",
    tostring(targetGUID),
    amount,
    landing,
    tostring(payload.sourceGUID or payload.source),
    tostring(payload.spellID),
    tostring(key)
  ))

  return entry
end

local function removeScheduledByKey(key)
  if not key then
    return
  end
  local entry = SCHEDULED_BY_KEY[key]
  if entry then
    removeScheduledEntry(entry)
    SCHEDULED_BY_KEY[key] = nil
    log(format("Agg: schedule removed key=%s", tostring(key)))
  end
end

local function buildCastKey(castGUID, sourceGUID, spellID, targetGUID, tag)
  if castGUID and castGUID ~= "" then
    return castGUID
  end
  local source = sourceGUID or tag or "?"
  local spell = spellID or 0
  local target = targetGUID or "?"
  return format("cast:%s:%s:%s", tostring(source), tostring(spell), tostring(target))
end

local function ensureCastLandingModule()
  if castLandingModule ~= nil then
    return castLandingModule
  end
  local ns = namespace()
  if ns and ns.GetModule then
    castLandingModule = ns:GetModule("CastLandingTime")
  end
  return castLandingModule
end

local function ensureEstimatorModule()
  if estimatorModule ~= nil then
    return estimatorModule
  end
  local ns = namespace()
  if ns and ns.GetModule then
    estimatorModule = ns:GetModule("HealValueEstimator")
  end
  return estimatorModule
end

local function ensureHealComm()
  if healCommLib ~= nil then
    return healCommLib or nil
  end
  local healsCfg = getHealsConfig()
  if healsCfg.useLHC ~= true then
    healCommLib = false
    return nil
  end
  local LibStub = _G.LibStub
  if type(LibStub) ~= "function" then
    healCommLib = false
    return nil
  end
  local lib = LibStub("LibHealComm-4.0", true)
  if not lib then
    healCommLib = false
    return nil
  end
  healCommLib = lib
  return healCommLib
end

local function shouldTrackUnit(unit)
  if not unit then
    return false
  end
  if unit == "player" or unit == "pet" or unit == "focus" then
    return true
  end
  if strmatch(unit, "^party%d+$") or strmatch(unit, "^raid%d+$") or strmatch(unit, "^raid%d+pet$") then
    return true
  end
  return false
end

local function resolveFriendlyTarget(unit)
  if not unit then
    return nil
  end

  local guid
  if UnitIsUnit and UnitIsUnit(unit, "player") then
    if UnitExists and UnitExists("mouseover") and UnitIsFriend and UnitIsFriend("player", "mouseover") then
      guid = UnitGUID("mouseover")
    end
    if not guid and UnitExists and UnitExists("target") and UnitIsFriend and UnitIsFriend("player", "target") then
      guid = UnitGUID("target")
    end
  end

  if not guid then
    local ref = unit .. "target"
    if UnitExists and UnitExists(ref) and UnitIsFriend and UnitIsFriend(unit, ref) then
      guid = UnitGUID(ref)
    end
  end

  return guid
end

local function scheduleCast(unit, castGUID, spellID)
  if not isFutureWindowEnabled() then
    return
  end
  if not shouldTrackUnit(unit) then
    return
  end
  local landing = ensureCastLandingModule()
  if not landing or not landing.TrackUnitCast then
    return
  end
  local record = landing.TrackUnitCast(unit, spellID)
  if not record or not record.t_land then
    return
  end
  local targetGUID = resolveFriendlyTarget(unit)
  if not targetGUID then
    return
  end
  local estimator = ensureEstimatorModule()
  local estimate
  if estimator and estimator.Estimate then
    local info = estimator.Estimate(spellID)
    estimate = info and info.mean
  end
  if not estimate or estimate <= 0 then
    return
  end
  local sourceGUID = toGUID(unit)
  local key = buildCastKey(castGUID, sourceGUID, spellID, targetGUID, "cast")
  addScheduled({
    targetGUID = targetGUID,
    amount = estimate,
    landTime = record.t_land,
    sourceGUID = sourceGUID,
    spellID = spellID,
    source = "cast",
    casterUnit = unit,
    castGUID = castGUID,
    key = key,
    confidence = "medium",
  })
  if castGUID then
    PENDING_CASTS[castGUID] = { key = key }
  end
  if key then
    CAST_LOOKUP[key] = CAST_LOOKUP[key] or { success = false }
  end
end

local function markCastSuccess(castGUID)
  if not castGUID then
    return
  end
  local pending = PENDING_CASTS[castGUID]
  if pending and pending.key then
    local entry = CAST_LOOKUP[pending.key]
    if entry then
      entry.success = true
    end
  end
end

local function abortCast(castGUID)
  if not castGUID then
    return
  end
  local pending = PENDING_CASTS[castGUID]
  if not pending or not pending.key then
    return
  end
  local key = pending.key
  local entry = CAST_LOOKUP[key]
  if entry and entry.success then
    return
  end
  removeScheduledByKey(key)
  CAST_LOOKUP[key] = nil
  PENDING_CASTS[castGUID] = nil
end

local function cleanupCast(castGUID)
  if not castGUID then
    return
  end
  local pending = PENDING_CASTS[castGUID]
  if pending and pending.key then
    CAST_LOOKUP[pending.key] = nil
  end
  PENDING_CASTS[castGUID] = nil
end

local function handleSpellcastEvent(event, unit, castGUID, spellID)
  if not isFutureWindowEnabled() then
    return
  end

  if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
    scheduleCast(unit, castGUID, spellID)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    markCastSuccess(castGUID)
  elseif event == "UNIT_SPELLCAST_STOP" then
    cleanupCast(castGUID)
  elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    abortCast(castGUID)
  end
end

local function lhcBuildKey(casterGUID, spellID, healType, targetGUID)
  return format("lhc:%s:%s:%s:%s", tostring(casterGUID or "?"), tostring(spellID or 0), tostring(healType or 0), tostring(targetGUID or "?"))
end

local function lhcScheduleTargets(event, casterGUID, spellID, healType, endTime, ...)
  local lib = ensureHealComm()
  if not lib then
    return
  end
  local landing = normalizeLandingTime(endTime)
  if not landing then
    return
  end
  for index = 1, select("#", ...) do
    local targetGUID = select(index, ...)
    if targetGUID then
      local amount = 0
      if lib.GetHealAmount then
        local ok, value = pcall(lib.GetHealAmount, lib, targetGUID, healType, endTime)
        if ok and type(value) == "number" then
          amount = value
        end
      end
      if amount and amount > 0 then
        local key = lhcBuildKey(casterGUID, spellID, healType, targetGUID)
        addScheduled({
          targetGUID = targetGUID,
          amount = amount,
          landTime = landing,
          sourceGUID = casterGUID,
          spellID = spellID,
          source = event,
          key = key,
          confidence = "high",
        })
      end
    end
  end
end

local function lhcRemoveTargets(casterGUID, spellID, healType, ...)
  for index = 1, select("#", ...) do
    local targetGUID = select(index, ...)
    if targetGUID then
      local key = lhcBuildKey(casterGUID, spellID, healType, targetGUID)
      removeScheduledByKey(key)
    end
  end
end

local function onHealCommStarted(_, casterGUID, spellID, healType, endTime, ...)
  lhcScheduleTargets("HealComm_HealStarted", casterGUID, spellID, healType, endTime, ...)
end

local function onHealCommUpdated(_, casterGUID, spellID, healType, endTime, ...)
  lhcScheduleTargets("HealComm_HealUpdated", casterGUID, spellID, healType, endTime, ...)
end

local function onHealCommDelayed(_, casterGUID, spellID, healType, endTime, ...)
  lhcScheduleTargets("HealComm_HealDelayed", casterGUID, spellID, healType, endTime, ...)
end

local function onHealCommStopped(_, casterGUID, spellID, healType, ...)
  lhcRemoveTargets(casterGUID, spellID, healType, ...)
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

function aggregator.IterateScheduled(unit, horizon, collector)
  local guid = toGUID(unit)
  if not guid or type(collector) ~= "function" then
    return
  end

  purgeScheduled()

  local bucket = SCHEDULED_STORAGE[guid]
  if not bucket or not bucket.list then
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

  for _, entry in ipairs(bucket.list) do
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
  local futureRemoved

  if unitRef then
    local guid = toGUID(unitRef)
    if guid then
      removed = purgeExpired(current, guid)
      futureRemoved = purgeScheduled(current, guid)
    end
  else
    removed = purgeExpired(current)
    futureRemoved = purgeScheduled(current)
  end

  local totalRemoved = (removed or 0) + (futureRemoved or 0)
  if totalRemoved > 0 then
    log(format("Agg: CleanExpired removed=%d future=%d", removed or 0, futureRemoved or 0))
  end
end

local function resolveCutoff(horizon)
  local now = GetTime()
  if type(horizon) ~= "number" then
    return math_huge
  end

  if horizon >= now then
    return horizon
  end

  return now + horizon
end

function aggregator:GetIncomingForGUID(guid, horizon)
  if not guid then
    return 0
  end

  purgeExpired()

  local queue = HEAL_STORAGE[guid]
  if not queue or #queue == 0 then
    return 0
  end

  local cutoff = resolveCutoff(horizon)
  local total = 0
  for index = 1, #queue do
    local entry = queue[index]
    if entry and entry.landTime and entry.landTime <= cutoff then
      total = total + (entry.amount or 0)
    end
  end

  return total
end

function aggregator.FetchFallback(unit)
  local incoming = namespace() and namespace():GetModule("IncomingHeals")
  if incoming and incoming.FetchFallback then
    return incoming.FetchFallback(unit)
  end
  return { amount = 0, confidence = "low" }
end

function aggregator.Initialize(dispatcher)
  dispatcherRef = dispatcher or obtainDispatcher()

  local hub = dispatcherRef
  if hub and hub.RegisterHandler then
    hub.RegisterHandler("COMBAT_LOG_EVENT_UNFILTERED", handleCombatLog)
    hub.RegisterHandler("UNIT_SPELLCAST_START", handleSpellcastEvent)
    hub.RegisterHandler("UNIT_SPELLCAST_CHANNEL_START", handleSpellcastEvent)
    hub.RegisterHandler("UNIT_SPELLCAST_SUCCEEDED", handleSpellcastEvent)
    hub.RegisterHandler("UNIT_SPELLCAST_STOP", handleSpellcastEvent)
    hub.RegisterHandler("UNIT_SPELLCAST_INTERRUPTED", handleSpellcastEvent)
    hub.RegisterHandler("UNIT_SPELLCAST_FAILED", handleSpellcastEvent)
    hub.RegisterHandler("UNIT_SPELLCAST_CHANNEL_STOP", handleSpellcastEvent)
    hub.RegisterHandler("GROUP_ROSTER_UPDATE", function()
      wipe(HEAL_STORAGE)
      wipe(SCHEDULED_STORAGE)
      wipe(SCHEDULED_BY_KEY)
      wipe(PENDING_CASTS)
      wipe(CAST_LOOKUP)
      log("Agg: reset on GROUP_ROSTER_UPDATE")
    end)
    hub.RegisterHandler("PLAYER_REGEN_ENABLED", function()
      wipe(HEAL_STORAGE)
      wipe(SCHEDULED_STORAGE)
      wipe(SCHEDULED_BY_KEY)
      wipe(PENDING_CASTS)
      wipe(CAST_LOOKUP)
      log("Agg: reset on PLAYER_REGEN_ENABLED")
    end)
  end

  local lib = ensureHealComm()
  if lib and type(lib.RegisterCallback) == "function" and not aggregator._lhcBound then
    local ok1 = pcall(lib.RegisterCallback, lib, aggregator, "HealComm_HealStarted", onHealCommStarted)
    local ok2 = pcall(lib.RegisterCallback, lib, aggregator, "HealComm_HealUpdated", onHealCommUpdated)
    local ok3 = pcall(lib.RegisterCallback, lib, aggregator, "HealComm_HealDelayed", onHealCommDelayed)
    local ok4 = pcall(lib.RegisterCallback, lib, aggregator, "HealComm_HealStopped", onHealCommStopped)
    if ok1 and ok2 and ok3 and ok4 then
      aggregator._lhcBound = true
      log("Agg: LibHealComm callbacks registered")
    end
  end
end

function aggregator.DebugDump()
  return HEAL_STORAGE
end

local module = _G.NODHeal:RegisterModule("IncomingHealAggregator", aggregator)

if NODHeal.Core then
  NODHeal.Core.Incoming = aggregator
end

return module
