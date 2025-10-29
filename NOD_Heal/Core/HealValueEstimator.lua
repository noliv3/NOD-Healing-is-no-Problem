-- Module: HealValueEstimator
-- Purpose: Derive expected heal values per spell using rolling averages, stat-based estimation, and fallback spell data.
-- API: LibHealComm databases (optional)

local rolling = {}
local fallbackDB

local math_max = math.max

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
  fallbackDB = fallbackDatabase or fallbackDB
  for spellID, data in pairs(rolling) do
    rolling[spellID] = {
      mean = data.mean or 0,
      m2 = data.m2 or 0,
      count = data.count or 0,
      variance = data.variance or 0,
    }
  end
end

function M.Learn(spellID, newHealValue)
  if not spellID or not newHealValue then
    return
  end

  local state = getState(spellID)
  state.count = state.count + 1

  local delta = newHealValue - state.mean
  state.mean = state.mean + (delta / state.count)
  state.m2 = state.m2 + delta * (newHealValue - state.mean)
  if state.count > 1 then
    state.variance = state.m2 / (state.count - 1)
  else
    state.variance = 0
  end
end

function M.Estimate(spellID, statsSnapshot)
  if not spellID then
    return { amount = 0, variance = 0, confidence = "low" }
  end

  local state = rolling[spellID]
  local base = statsSnapshot and statsSnapshot.baseHeal or nil
  if not base and state then
    base = state.mean
  end
  if not base then
    base = M.FetchFallback(spellID)
  end

  if type(base) == "table" then
    base = base.amount
  end

  base = base or 0

  local throughput = 0
  if statsSnapshot then
    throughput = (statsSnapshot.spellPowerCoeff or 0) * (statsSnapshot.spellPower or 0)
    throughput = throughput + (statsSnapshot.throughputBonus or 0)
  end

  local mastery = statsSnapshot and statsSnapshot.masteryBonus or 0
  local critChance = statsSnapshot and statsSnapshot.critChance or 0
  local critMultiplier = statsSnapshot and statsSnapshot.critMultiplier or 2

  local expected = base + throughput
  expected = expected * (1 + mastery)
  expected = expected * (1 + critChance * math_max(critMultiplier - 1, 0))

  local variance = state and state.variance or 0
  local confidence
  if state and state.count >= 5 then
    confidence = "high"
  elseif state and state.count > 0 then
    confidence = "medium"
  elseif fallbackDB then
    confidence = "medium"
  else
    confidence = "low"
  end

  return {
    amount = expected,
    variance = variance,
    confidence = confidence,
  }
end

function M.FetchFallback(spellID)
  if not fallbackDB then
    return { amount = 0, variance = 0, confidence = "low" }
  end

  local data = fallbackDB[spellID]
  if not data then
    return { amount = 0, variance = 0, confidence = "low" }
  end

  if type(data) == "number" then
    return { amount = data, variance = 0, confidence = "medium" }
  end

  return {
    amount = data.amount or 0,
    variance = data.variance or 0,
    confidence = data.confidence or "medium",
  }
end

return M
