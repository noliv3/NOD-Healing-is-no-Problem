-- Module: DamagePrediction
-- Purpose: Maintain an EMA-based damage forecast per unit derived from combat log events.
-- API: COMBAT_LOG_EVENT_UNFILTERED, CombatLogGetCurrentEventInfo, UnitGUID, GetTime

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitGUID = UnitGUID
local GetTime = GetTime
local pairs = pairs
local wipe = wipe

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

local EMA_WINDOW = 3 -- seconds used to smooth DPS samples
local STALE_WINDOW = 5 -- seconds before clearing stale EMA data
local MIN_DELTA = 0.2

local damageBuckets = {}

local function clampPositive(value)
  if value and value > 0 then
    return value
  end
  return 0
end

local function pushSample(destGUID, amount, timestamp)
  if not destGUID or not amount or amount <= 0 then
    return
  end

  local now = timestamp or GetTime()
  local entry = damageBuckets[destGUID]
  if not entry then
    entry = {
      ema = clampPositive(amount),
      lastTimestamp = now,
    }
    damageBuckets[destGUID] = entry
    return
  end

  local elapsed = now - (entry.lastTimestamp or now)
  if elapsed < MIN_DELTA then
    elapsed = MIN_DELTA
  end

  local sampleDPS = clampPositive(amount) / elapsed
  local weight = elapsed / EMA_WINDOW
  if weight > 1 then
    weight = 1
  elseif weight < 0.1 then
    weight = 0.1
  end

  entry.ema = entry.ema + (sampleDPS - entry.ema) * weight
  entry.lastTimestamp = now
end

local function handleCombatLog()
  local timestamp, eventType, _, _, _, _, _, destGUID, _, _, _, arg12, arg13, arg14, arg15 = CombatLogGetCurrentEventInfo()
  if not destGUID then
    return
  end

  local amount
  if eventType == "SWING_DAMAGE" then
    amount = arg12
  elseif eventType == "ENVIRONMENTAL_DAMAGE" then
    amount = arg13
  elseif eventType == "RANGE_DAMAGE" or eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "SPELL_BUILDING_DAMAGE" or eventType == "DAMAGE_SPLIT" then
    amount = arg15
  else
    return
  end

  pushSample(destGUID, amount, timestamp)
end

local M = {}

function M.Initialize(dispatcher)
  if dispatcher and dispatcher.RegisterHandler then
    dispatcher:RegisterHandler("COMBAT_LOG_EVENT_UNFILTERED", handleCombatLog)
    dispatcher:RegisterHandler("GROUP_ROSTER_UPDATE", function()
      wipe(damageBuckets)
    end)
  end
end

function M.PredictDamage(unit, T_land)
  if not unit then
    return 0
  end

  local guid = UnitGUID(unit)
  if not guid then
    return 0
  end

  local bucket = damageBuckets[guid]
  if not bucket then
    return 0
  end

  local now = GetTime()
  if (now - (bucket.lastTimestamp or 0)) > STALE_WINDOW then
    damageBuckets[guid] = nil
    return 0
  end

  local horizon = (T_land or now) - now
  if horizon <= 0 then
    return 0
  end

  local predicted = bucket.ema * horizon
  return clampPositive(predicted)
end

function M.DebugDump()
  return damageBuckets
end

return M
