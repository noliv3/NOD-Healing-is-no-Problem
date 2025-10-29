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

local M = {}

function M.Initialize(dispatcher)
  if dispatcher and dispatcher.RegisterHandler then
    dispatcher:RegisterHandler("UNIT_HEALTH", function(_, unit)
      if unit then
        cache[unit] = nil
      end
    end)
    dispatcher:RegisterHandler("UNIT_MAXHEALTH", function(_, unit)
      if unit then
        cache[unit] = nil
      end
    end)
    dispatcher:RegisterHandler("UNIT_ABSORB_AMOUNT_CHANGED", function(_, unit)
      if unit then
        cache[unit] = nil
      end
    end)
    dispatcher:RegisterHandler("GROUP_ROSTER_UPDATE", function()
      wipe(cache)
    end)
  end
end

local function compute(unit)
  local hpNow = UnitHealth and UnitHealth(unit) or 0
  local absorbs = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
  if absorbs < 0 then
    absorbs = 0
  end

  local effective = max(hpNow, 0) + absorbs
  local hpMax = UnitHealthMax and UnitHealthMax(unit)
  if hpMax and hpMax > 0 then
    effective = min(effective, hpMax + absorbs)
  end

  return effective, hpNow, absorbs
end

function M.Calculate(unit)
  if not unit then
    return 0, 0, 0
  end

  local now = GetTime()
  local cached = cache[unit]
  if cached and (now - cached.timestamp) <= CACHE_DURATION then
    return cached.ehp, cached.hp, cached.absorbs
  end

  local effective, hpNow, absorbs = compute(unit)

  cache[unit] = {
    timestamp = now,
    ehp = effective,
    hp = hpNow,
    absorbs = absorbs,
  }

  return effective, hpNow, absorbs
end

return M
