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
local math_huge = math.huge

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
      samples = 1,
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
  entry.samples = (entry.samples or 0) + 1
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

function M.RecordCombatSample(targetGUID, amount, timestamp)
  pushSample(targetGUID, amount, timestamp)
end

local function evaluateBucket(guid, tLand)
  local bucket = damageBuckets[guid]
  if not bucket then
    return nil
  end

  local now = GetTime()
  local age = now - (bucket.lastTimestamp or 0)
  if age > STALE_WINDOW then
    damageBuckets[guid] = nil
    return nil
  end

  local horizon = (tLand or now) - now
  if horizon <= 0 then
    horizon = 0
  end

  local predicted = clampPositive(bucket.ema * horizon)
  local samples = bucket.samples or 0
  local confidence
  if samples >= 10 and age <= 1.5 then
    confidence = "high"
  elseif samples >= 3 and age <= 3 then
    confidence = "medium"
  else
    confidence = "low"
  end

  return {
    amount = predicted,
    rate = bucket.ema or 0,
    horizon = horizon,
    samples = samples,
    confidence = confidence,
    lastEventAge = age,
  }
end

function M.Estimate(unit, T_land)
  if not unit then
    return { amount = 0, rate = 0, horizon = 0, samples = 0, confidence = "low", lastEventAge = math_huge }
  end

  local guid = UnitGUID(unit)
  if not guid then
    return { amount = 0, rate = 0, horizon = 0, samples = 0, confidence = "low", lastEventAge = math_huge }
  end

  local result = evaluateBucket(guid, T_land)
  if not result then
    return { amount = 0, rate = 0, horizon = (T_land and math.max(T_land - GetTime(), 0)) or 0, samples = 0, confidence = "low", lastEventAge = math_huge }
  end

  return result
end

function M.PredictDamage(unit, T_land)
  local estimate = M.Estimate(unit, T_land)
  return estimate.amount or 0
end

function M.DebugDump()
  return damageBuckets
end

return _G.NODHeal:RegisterModule("DamagePrediction", M)
