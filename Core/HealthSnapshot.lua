-- Module: HealthSnapshot
-- Purpose: Collect current HP state, death/offline flags, and absorbs per unit as baseline for solver calculations.
-- API: UnitHealth, UnitHealthMax, UnitIsDeadOrGhost, UnitGetTotalAbsorbs

local snapshotCache = {}
local dispatcherRef
local deathModule

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitExists = UnitExists

local pairs = pairs

local function ensureDeathModule()
  if deathModule then
    return deathModule
  end
  local namespace = _G.NODHeal
  if namespace and namespace.GetModule then
    deathModule = namespace:GetModule("DeathAuthority")
  end
  return deathModule
end

local function safeUnitHealth(u)
  if type(u) ~= "string" or (UnitExists and not UnitExists(u)) then
    return nil
  end
  if not UnitHealth or not UnitHealthMax then
    return nil
  end
  local ok, hp = pcall(UnitHealth, u)
  local ok2, max = pcall(UnitHealthMax, u)
  if not ok or not ok2 then
    return nil
  end
  return hp, max
end

local function resetUnit(unit)
  if unit then
    snapshotCache[unit] = nil
  end
end

local function wipeCache()
  for key in pairs(snapshotCache) do
    snapshotCache[key] = nil
  end
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

local M = {}

function M.Initialize(dispatcher)
  dispatcherRef = dispatcher or obtainDispatcher()
  local hub = dispatcherRef
  if not hub or type(hub.RegisterHandler) ~= "function" then
    return
  end

  hub:RegisterHandler("UNIT_HEALTH", function(_, unit)
    resetUnit(unit)
  end)
  hub:RegisterHandler("UNIT_MAXHEALTH", function(_, unit)
    resetUnit(unit)
  end)
  hub:RegisterHandler("UNIT_ABSORB_AMOUNT_CHANGED", function(_, unit)
    resetUnit(unit)
  end)
  hub:RegisterHandler("GROUP_ROSTER_UPDATE", function()
    wipeCache()
  end)
end

function M.Capture(unit)
  if not unit then
    return nil
  end

  local cached = snapshotCache[unit]
  if cached then
    return cached
  end

  local hpNow, hpMax = safeUnitHealth(unit)
  if not hpNow or not hpMax then
    return
  end
  if hpMax <= 0 then
    hpMax = 1
  end
  if hpNow < 0 then
    hpNow = 0
  elseif hpNow > hpMax then
    hpNow = hpMax
  end

  local absorbs = 0
  if UnitGetTotalAbsorbs then
    absorbs = UnitGetTotalAbsorbs(unit) or 0
    if absorbs < 0 then
      absorbs = 0
    end
  end

  local death = ensureDeathModule()
  local state
  local isDead = false
  local isGhost = false
  local isFeign = false
  if death and death.GetState then
    state = death.GetState(unit)
    if state == "DEAD" then
      isDead = true
    elseif state == "GHOST" then
      isDead = true
      isGhost = true
    elseif state == "FEIGN" then
      isDead = true
      isFeign = true
    elseif state == "DYING" then
      state = "DYING"
    end
  end

  if not state then
    isDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) or false
    if isDead and UnitIsGhost then
      isGhost = UnitIsGhost(unit) and true or false
    end
    if isDead then
      state = isGhost and "GHOST" or "DEAD"
    else
      state = "ALIVE"
    end
  end

  if isDead or isFeign then
    hpNow = 0
  end
  local isConnected = UnitIsConnected and UnitIsConnected(unit)
  local isOffline = isConnected == false

  local snapshot = {
    hp_now = hpNow,
    hp_max = hpMax > 0 and hpMax or 1,
    absorbs = absorbs,
    isDead = isDead,
    isOffline = isOffline,
    state = state,
    isGhost = isGhost,
    isFeign = isFeign,
  }

  snapshotCache[unit] = snapshot
  return snapshot
end

function M.FlagOfflineState(unit)
  if not unit then
    return
  end

  local snapshot = snapshotCache[unit]
  if not snapshot then
    snapshot = M.Capture(unit)
  end

  if not snapshot then
    return
  end

  local death = ensureDeathModule()
  if death and death.GetState then
    snapshot.state = death.GetState(unit)
    snapshot.isDead = death.IsDead and death.IsDead(unit) or snapshot.isDead
    snapshot.isGhost = snapshot.state == "GHOST"
    snapshot.isFeign = snapshot.state == "FEIGN"
  else
    snapshot.isDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) or false
    snapshot.isGhost = UnitIsGhost and UnitIsGhost(unit) or false
    snapshot.state = snapshot.isDead and (snapshot.isGhost and "GHOST" or "DEAD") or "ALIVE"
  end
  local isConnected = UnitIsConnected and UnitIsConnected(unit)
  snapshot.isOffline = isConnected == false
end

return _G.NODHeal:RegisterModule("HealthSnapshot", M)
