-- Module: DeathAuthority
-- Purpose: Maintain authoritative death/ghost/feign states per unit using layered event sources.

local GetTime = GetTime
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitIsConnected = UnitIsConnected
local UnitIsFeignDeath = UnitIsFeignDeath
local UnitHealth = UnitHealth
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local wipe = wipe
local pairs = pairs
local ipairs = ipairs
local math_max = math.max

local HEARTBEAT_INTERVAL = 0.7

local STATES = {
  ALIVE = "ALIVE",
  DYING = "DYING",
  DEAD = "DEAD",
  GHOST = "GHOST",
  FEIGN = "FEIGN",
  UNKNOWN = "UNKNOWN",
}

local dispatcherRef
local rosterUnits = {}
local stateByUnit = {}
local guidToUnit = {}
local pendingDeaths = {}
local listeners = {}

local function namespace()
  return _G.NODHeal
end

local function ensureDispatcher()
  if dispatcherRef then
    return dispatcherRef
  end
  local ns = namespace()
  if ns and ns.GetModule then
    dispatcherRef = ns:GetModule("CoreDispatcher")
  end
  return dispatcherRef
end

local function ensureRecord(unit)
  local record = stateByUnit[unit]
  if not record then
    record = {
      state = STATES.UNKNOWN,
      flags = {},
      guid = nil,
      updated = 0,
      dyingUntil = nil,
    }
    stateByUnit[unit] = record
  end
  return record
end

local function notify(unit, newState, previousState, context)
  if newState == previousState then
    return
  end
  for index = 1, #listeners do
    local cb = listeners[index]
    if type(cb) == "function" then
      local ok, err = pcall(cb, unit, newState, previousState, context)
      if not ok and _G.NODHeal and _G.NODHeal.Core and _G.NODHeal.Core.pushErr then
        _G.NODHeal.Core.pushErr(err)
      end
    end
  end
end

local function determineState(record)
  if not record then
    return STATES.UNKNOWN
  end

  local flags = record.flags or {}
  local now = GetTime()

  if flags.feign then
    return STATES.FEIGN
  end
  if flags.cleuDead then
    return STATES.DEAD
  end
  if flags.apiGhost then
    return STATES.GHOST
  end
  if flags.apiDead then
    return STATES.DEAD
  end
  if flags.hpZero then
    return STATES.DEAD
  end
  if record.dyingUntil and record.dyingUntil > now then
    return STATES.DYING
  end
  if flags.offline or flags.missing then
    return STATES.UNKNOWN
  end
  return STATES.ALIVE
end

local function setFlag(record, key, value)
  if not record then
    return
  end
  local flags = record.flags
  if value then
    flags[key] = true
  else
    flags[key] = nil
  end
end

local function associateGuid(unit, guid)
  if not unit or not guid then
    return
  end
  guidToUnit[guid] = unit
  local record = ensureRecord(unit)
  record.guid = guid
  if pendingDeaths[guid] then
    setFlag(record, "cleuDead", true)
    record.dyingUntil = nil
    pendingDeaths[guid] = nil
  end
end

local function clearGuid(guid)
  if not guid then
    return
  end
  guidToUnit[guid] = nil
  pendingDeaths[guid] = nil
end

local function applyState(unit, modifier, source)
  if not unit then
    return
  end
  local record = ensureRecord(unit)
  local previous = record.state

  if type(modifier) == "function" then
    modifier(record)
  end

  if record.dyingUntil and record.dyingUntil <= GetTime() then
    record.dyingUntil = nil
  end

  local newState = determineState(record)
  record.state = newState
  record.updated = GetTime()
  record.lastSource = source or record.lastSource

  if newState ~= previous then
    notify(unit, newState, previous, record)
  end
end

local function flagAlive(unit, reason)
  applyState(unit, function(record)
    setFlag(record, "cleuDead", false)
    setFlag(record, "apiDead", false)
    setFlag(record, "apiGhost", false)
    setFlag(record, "hpZero", false)
    setFlag(record, "feign", false)
    record.dyingUntil = nil
    if record.guid then
      pendingDeaths[record.guid] = nil
    end
  end, reason or "alive-check")
end

local function collectRoster(into)
  wipe(into)
  if IsInRaid and IsInRaid() then
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    for index = 1, members do
      into[#into + 1] = "raid" .. index
    end
  elseif IsInGroup and IsInGroup() then
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    for index = 1, members - 1 do
      into[#into + 1] = "party" .. index
    end
    into[#into + 1] = "player"
  else
    into[#into + 1] = "player"
  end
  return into
end

local function refreshUnit(unit, reason)
  if not unit then
    return
  end

  local exists = not UnitExists or UnitExists(unit)
  local guid = UnitGUID and UnitGUID(unit) or nil
  if guid then
    associateGuid(unit, guid)
  end

  if not exists then
    applyState(unit, function(record)
      setFlag(record, "missing", true)
      setFlag(record, "offline", false)
    end, reason or "no-exists")
    return
  end

  local isFeign = UnitIsFeignDeath and UnitIsFeignDeath(unit) or false
  local isDeadOrGhost = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) or false
  local isGhost = UnitIsGhost and UnitIsGhost(unit) or false
  local hp = UnitHealth and UnitHealth(unit) or 0
  local connected = UnitIsConnected and UnitIsConnected(unit)

  applyState(unit, function(record)
    setFlag(record, "missing", false)
    setFlag(record, "offline", connected == false)
    setFlag(record, "feign", isFeign)
    if isDeadOrGhost then
      setFlag(record, "apiDead", not isGhost)
      setFlag(record, "apiGhost", isGhost)
      setFlag(record, "hpZero", true)
    else
      setFlag(record, "apiDead", false)
      setFlag(record, "apiGhost", false)
      if hp and hp > 0 then
        setFlag(record, "hpZero", false)
      elseif hp == 0 and not isFeign then
        setFlag(record, "hpZero", true)
      end
      record.dyingUntil = nil
    end
  end, reason or "refresh")

  if not isDeadOrGhost and not isFeign and hp and hp > 0 then
    flagAlive(unit, reason)
  end
end

local function rebuildRoster(reason)
  local units = collectRoster(rosterUnits)
  local seen = {}
  for _, unit in ipairs(units) do
    seen[unit] = true
    refreshUnit(unit, reason or "roster")
  end

  for unit, record in pairs(stateByUnit) do
    if not seen[unit] then
      local guid = record.guid
      if guid then
        clearGuid(guid)
      end
      stateByUnit[unit] = nil
    end
  end
end

local function heartbeat()
  local now = GetTime()
  if not heartbeat._lastTick or now - heartbeat._lastTick >= HEARTBEAT_INTERVAL then
    heartbeat._lastTick = now
    for _, unit in ipairs(collectRoster(rosterUnits)) do
      refreshUnit(unit, "heartbeat")
    end
  end
end

local function markGuidDead(guid, source)
  if not guid then
    return
  end
  pendingDeaths[guid] = GetTime()
  local unit = guidToUnit[guid]
  if unit then
    applyState(unit, function(record)
      setFlag(record, "cleuDead", true)
      record.dyingUntil = nil
    end, source or "cleu")
  end
end

local function markGuidRevived(guid, source)
  if not guid then
    return
  end
  pendingDeaths[guid] = nil
  local unit = guidToUnit[guid]
  if unit then
    flagAlive(unit, source or "cleu-revive")
    refreshUnit(unit, "cleu-revive")
  end
end

local function handleCombatLog()
  if not CombatLogGetCurrentEventInfo then
    return
  end
  local _, subEvent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
  if not subEvent or not destGUID then
    return
  end
  if subEvent == "UNIT_DIED" or subEvent == "UNIT_DESTROYED" or subEvent == "UNIT_DISSIPATES" or subEvent == "SPELL_INSTAKILL" then
    markGuidDead(destGUID, "cleu")
  elseif subEvent == "SPELL_RESURRECT" or subEvent == "SPELL_RESURRECTED" then
    markGuidRevived(destGUID, "cleu-res")
  end
end

local function handleUnitEvent(_, unit)
  if unit then
    refreshUnit(unit, "unit-event")
  else
    rebuildRoster("unit-event")
  end
end

local function handleFlags(_, unit)
  if unit then
    refreshUnit(unit, "flags")
  end
end

local M = {}

function M.Initialize(dispatcher)
  dispatcherRef = dispatcher or ensureDispatcher()
  if not dispatcherRef or not dispatcherRef.RegisterHandler then
    return
  end

  if M._initialized then
    return
  end

  dispatcherRef.RegisterHandler("PLAYER_ENTERING_WORLD", function()
    rebuildRoster("entering")
  end)
  dispatcherRef.RegisterHandler("GROUP_ROSTER_UPDATE", function()
    rebuildRoster("roster-update")
  end)
  dispatcherRef.RegisterHandler("UNIT_HEALTH", handleUnitEvent)
  dispatcherRef.RegisterHandler("UNIT_MAXHEALTH", handleUnitEvent)
  dispatcherRef.RegisterHandler("UNIT_FLAGS", handleFlags)
  dispatcherRef.RegisterHandler("UNIT_CONNECTION", handleFlags)
  dispatcherRef.RegisterHandler("PLAYER_ALIVE", function()
    refreshUnit("player", "player-alive")
  end)
  dispatcherRef.RegisterHandler("PLAYER_DEAD", function()
    refreshUnit("player", "player-dead")
  end)
  dispatcherRef.RegisterHandler("PLAYER_UNGHOST", function()
    refreshUnit("player", "player-ghost")
  end)
  dispatcherRef.RegisterHandler("COMBAT_LOG_EVENT_UNFILTERED", handleCombatLog)

  if dispatcherRef.RegisterTick then
    dispatcherRef.RegisterTick(heartbeat)
  end

  rebuildRoster("init")
  M._initialized = true
end

function M.RefreshUnit(unit, reason)
  refreshUnit(unit, reason or "api")
end

function M.FlagDying(unit, duration, source)
  if not unit then
    return
  end
  local record = ensureRecord(unit)
  local now = GetTime()
  local span = duration or 0.9
  if span < 0 then
    span = 0
  elseif span > 1.5 then
    span = 1.5
  end
  record.dyingUntil = math_max(record.dyingUntil or 0, now + span)
  applyState(unit, nil, source or "solver")
end

function M.GetState(unit)
  if not unit then
    return STATES.UNKNOWN
  end
  local record = stateByUnit[unit]
  if not record then
    return STATES.UNKNOWN
  end
  if record.dyingUntil and record.dyingUntil <= GetTime() then
    record.dyingUntil = nil
    record.state = determineState(record)
  end
  return record.state or STATES.UNKNOWN
end

function M.IsDead(unit)
  local state = M.GetState(unit)
  return state == STATES.DEAD or state == STATES.GHOST
end

function M.IsHealImmune(unit)
  local state = M.GetState(unit)
  return state == STATES.DEAD or state == STATES.GHOST or state == STATES.FEIGN
end

function M.RegisterListener(callback)
  if type(callback) ~= "function" then
    return false
  end
  for index = 1, #listeners do
    if listeners[index] == callback then
      return true
    end
  end
  listeners[#listeners + 1] = callback
  return true
end

function M.DebugDump()
  local dump = {}
  for unit, record in pairs(stateByUnit) do
    dump[#dump + 1] = { unit = unit, state = record.state, guid = record.guid, flags = record.flags, untilTime = record.dyingUntil }
  end
  return dump
end

return _G.NODHeal:RegisterModule("DeathAuthority", M)
