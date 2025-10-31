-- Module: HealValueEstimator
-- Purpose: Derive expected heal values per spell using rolling averages, stat-based estimation, and fallback spell data.
-- API: LibHealComm databases (optional)

local rolling = {}
local fallbackDB

local math_max = math.max
local math_sqrt = math.sqrt
local pairs = pairs

local function getState(spellID)
  if not spellID then
    return nil
  end

  local state = rolling[spellID]
  if not state then
    state = { mean = 0, m2 = 0, count = 0, variance = 0 }
    rolling[spellID] = state
  end
  return state
end

local M = {}

function M.Initialize(fallbackDatabase)
  fallbackDB = fallbackDatabase or fallbackDB or {}
  for spellID, data in pairs(rolling) do
    rolling[spellID] = {
      mean = data.mean or 0,
      m2 = data.m2 or 0,
      count = data.count or 0,
      variance = data.variance or 0,
    }
  end
end

function M.Learn(spellID, amount)
  if not spellID or type(amount) ~= "number" then
    return
  end

  if amount < 0 then
    amount = 0
  end

  local state = getState(spellID)
  state.count = state.count + 1

  local delta = amount - state.mean
  state.mean = state.mean + (delta / state.count)
  state.m2 = state.m2 + delta * (amount - state.mean)
  if state.count > 1 then
    state.variance = state.m2 / (state.count - 1)
  else
    state.variance = 0
  end
end

local function evaluateStats(spellID, statsSnapshot)
  local base = statsSnapshot and statsSnapshot.baseHeal or nil
  local state = rolling[spellID]

  if base == nil then
    if state and state.count > 0 then
      base = state.mean
    else
      base = M.FetchFallback(spellID)
    end
  end

  if type(base) ~= "number" then
    base = tonumber(base) or 0
  end

  local throughput = 0
  if statsSnapshot then
    throughput = throughput + (statsSnapshot.spellPowerCoeff or 0) * (statsSnapshot.spellPower or 0)
    throughput = throughput + (statsSnapshot.throughputBonus or 0)
  end

  local mastery = statsSnapshot and statsSnapshot.masteryBonus or 0
  local critChance = statsSnapshot and statsSnapshot.critChance or 0
  local critMultiplier = statsSnapshot and statsSnapshot.critMultiplier or 2

  local expected = base + throughput
  expected = expected * (1 + mastery)
  if critChance > 0 then
    local bonus = math_max(critMultiplier - 1, 0)
    expected = expected * (1 + critChance * bonus)
  end

  return expected, state
end

function M.Estimate(spellID, statsSnapshot)
  if not spellID then
    return { mean = 0, low = 0, high = 0 }
  end

  local mean, state = evaluateStats(spellID, statsSnapshot)
  if mean < 0 then
    mean = 0
  end

  local variance = state and state.variance or 0
  if variance < 0 then
    variance = 0
  end

  local deviation = variance > 0 and math_sqrt(variance) or 0
  local low = mean - deviation
  if low < 0 then
    low = 0
  end
  local high = mean + deviation

  return {
    mean = mean,
    low = low,
    high = high,
  }
end

function M.FetchFallback(spellID)
  if not fallbackDB or not spellID then
    return 0
  end

  local data = fallbackDB[spellID]
  if data == nil then
    return 0
  end

  if type(data) == "number" then
    if data < 0 then
      return 0
    end
    return data
  end

  if type(data) == "table" then
    local value = data.amount or data.mean or data.value
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  return 0
end

return _G.NODHeal:RegisterModule("HealValueEstimator", M)
