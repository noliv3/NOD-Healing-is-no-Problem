-- Module: IncomingHeals (read-side)
-- Purpose: Aggregate predicted incoming heals using Blizzard's API and local aggregator data.

local pairs = pairs
local tonumber = tonumber
local type = type
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitGetIncomingHeals = UnitGetIncomingHeals

local aggregatorRef
local dispatcherRef
local deathModule

local M = {}

local landingEpsilon = 0.05

local function namespace()
  return _G.NODHeal
end

local function ensureAggregator()
  if aggregatorRef then
    return aggregatorRef
  end

  local ns = namespace()
  if ns and ns.GetModule then
    aggregatorRef = ns:GetModule("IncomingHealAggregator")
  end

  return aggregatorRef
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

local function ensureDeathModule()
  if deathModule then
    return deathModule
  end
  local ns = namespace()
  if ns and ns.GetModule then
    deathModule = ns:GetModule("DeathAuthority")
  end
  return deathModule
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

local function resolveGuid(unit)
  if not unit then
    return nil
  end

  if UnitGUID then
    local guid = UnitGUID(unit)
    if guid then
      return guid
    end
  end

  return unit
end

local function computeFallback(unit)
  local amount = 0
  if UnitGetIncomingHeals and unit then
    amount = UnitGetIncomingHeals(unit) or 0
  end

  if amount < 0 then
    amount = 0
  end

  return {
    amount = amount,
    confidence = amount > 0 and "medium" or "low",
    sources = {},
  }
end

local function collectFromAggregator(unit, horizon)
  local aggregator = ensureAggregator()
  if not aggregator or not aggregator.Iterate then
    return 0, {}
  end

  local total = 0
  local contributions = {}

  aggregator.Iterate(unit, horizon, function(entry)
    local amount = entry.amount or 0
    if amount > 0 then
      total = total + amount
      local key = entry.sourceGUID or entry.source or "unknown"
      contributions[key] = (contributions[key] or 0) + amount
    end
  end)

  return total, contributions
end

function M.Initialize(dispatcher)
  dispatcherRef = dispatcher or ensureDispatcher()
  ensureAggregator()

  if dispatcherRef and dispatcherRef.RegisterHandler then
    dispatcherRef.RegisterHandler("UNIT_SPELLCAST_STOP", function()
      M.CleanExpired()
    end)
  end
end

function M.CollectUntil(unit, tLand)
  local death = ensureDeathModule()
  if death and death.IsHealImmune and death.IsHealImmune(unit) then
    return {
      amount = 0,
      confidence = "low",
      sources = {},
    }
  end

  local guid = resolveGuid(unit)
  if not guid then
    return {
      amount = 0,
      confidence = "low",
      sources = {},
    }
  end

  local landing = normalizeLandingTime(tLand)
  local now = GetTime()
  local horizon
  if landing then
    horizon = (landing - now) + landingEpsilon
    if horizon < 0 then
      horizon = 0
    end
  end

  local total, contributions = collectFromAggregator(guid, horizon)

  if total > 0 then
    return {
      amount = total,
      confidence = "high",
      sources = contributions,
    }
  end

  local fallback = computeFallback(unit)
  fallback.sources = contributions
  if fallback.amount <= 0 then
    fallback.confidence = "low"
  end
  return fallback
end

function M.FetchFallback(unit)
  local death = ensureDeathModule()
  if death and death.IsHealImmune and death.IsHealImmune(unit) then
    return {
      amount = 0,
      confidence = "low",
      sources = {},
    }
  end
  return computeFallback(unit)
end

function M.CleanExpired(now, unit)
  local aggregator = ensureAggregator()
  if not aggregator or not aggregator.CleanExpired then
    return
  end

  if unit then
    aggregator.CleanExpired(now, unit)
  else
    aggregator.CleanExpired(now)
  end
end

return _G.NODHeal:RegisterModule("IncomingHeals", M)

