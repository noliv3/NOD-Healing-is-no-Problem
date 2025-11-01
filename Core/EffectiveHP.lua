-- Module: EffectiveHP
-- Purpose: Return the current effective health of a unit (HP + absorbs) for solver consumption.
-- API: UnitHealth, UnitHealthMax, UnitGetTotalAbsorbs

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local GetTime = GetTime
local pairs = pairs
local wipe = wipe
local min = math.min
local max = math.max

local cache = {}
local CACHE_DURATION = 0.2
local dispatcherRef

if not wipe then
  wipe = function(tbl)
    if not tbl then
      return
    end
    for k in pairs(tbl) do
      tbl[k] = nil
    end
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
    if unit then
      cache[unit] = nil
    end
  end)
  hub:RegisterHandler("UNIT_MAXHEALTH", function(_, unit)
    if unit then
      cache[unit] = nil
    end
  end)
  hub:RegisterHandler("UNIT_ABSORB_AMOUNT_CHANGED", function(_, unit)
    if unit then
      cache[unit] = nil
    end
  end)
  hub:RegisterHandler("GROUP_ROSTER_UPDATE", function()
    wipe(cache)
  end)
end

local function compute(unit)
  local hpNow = UnitHealth and UnitHealth(unit) or 0
  local absorbs = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
  if absorbs < 0 then
    absorbs = 0
  end

  local effective = max(hpNow or 0, 0) + absorbs
  local hpMax = UnitHealthMax and UnitHealthMax(unit)
  if hpMax and hpMax > 0 then
    effective = min(effective, hpMax + absorbs)
  end

  if effective < 0 then
    effective = 0
  end

  return effective, hpNow or 0, absorbs
end

function M.Calculate(unit)
  if not unit then
    return 0
  end

  local now = GetTime()
  local cached = cache[unit]
  if cached and (now - cached.timestamp) <= CACHE_DURATION then
    return cached.ehp
  end

  local effective, hpNow, absorbs = compute(unit)

  cache[unit] = {
    timestamp = now,
    ehp = effective,
    hp = hpNow,
    absorbs = absorbs,
  }

  return effective
end

function M.UpdateFromUnit(unit)
  if not unit then
    return 0
  end

  cache[unit] = nil
  return M.Calculate(unit)
end

return _G.NODHeal:RegisterModule("EffectiveHP", M)
