-- Module: AuraTickPredictor
-- Purpose: Derive upcoming HoT ticks until the specified landing window for predictive healing merges.
-- API: AuraUtil.ForEachAura, UnitAura, GetTime

local AuraUtil = AuraUtil
local UnitAura = UnitAura
local GetTime = GetTime
local pairs = pairs
local ipairs = ipairs
local wipe = wipe
local floor = math.floor
local max = math.max
local min = math.min
local sort = table.sort
local tinsert = table.insert

local auraCache = {}

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

local function fetchAura(unit, spellID)
  if not unit or not spellID then
    return nil
  end

  local auraData
  if AuraUtil and AuraUtil.ForEachAura then
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
      if aura and aura.spellId == spellID then
        auraData = aura
        return true
      end
    end)
  elseif AuraUtil and AuraUtil.FindAuraBySpellID then
    local name, _, _, _, duration, expirationTime, source, _, _, spellId = AuraUtil.FindAuraBySpellID(spellID, unit, "HELPFUL")
    if name then
      auraData = {
        spellId = spellId,
        duration = duration,
        expirationTime = expirationTime,
        sourceUnit = source,
      }
    end
  end

  if not auraData and UnitAura then
    for index = 1, 40 do
      local name, _, count, _, duration, expirationTime, source, _, _, auraSpellID = UnitAura(unit, index, "HELPFUL")
      if not name then
        break
      end

      if auraSpellID == spellID then
        auraData = {
          spellId = auraSpellID,
          duration = duration,
          expirationTime = expirationTime,
          applications = count,
          sourceUnit = source,
        }
        break
      end
    end
  end

  return auraData
end

local function resolveTickInterval(aura)
  if not aura then
    return nil
  end

  if aura.tickRate and aura.tickRate > 0 then
    return aura.tickRate
  end

  if aura.tickInterval and aura.tickInterval > 0 then
    return aura.tickInterval
  end

  if aura.timeMod and aura.timeMod > 0 then
    return aura.timeMod
  end

  if aura.duration and aura.applications and aura.applications > 0 then
    return aura.duration / aura.applications
  end

  if aura.duration and aura.duration > 0 and aura.expectedTicks and aura.expectedTicks > 0 then
    return aura.duration / aura.expectedTicks
  end

  return nil
end

local function resolveTickAmount(aura)
  if not aura then
    return 0
  end

  if aura.tickValue and aura.tickValue > 0 then
    return aura.tickValue
  end

  if aura.value1 and aura.value1 > 0 then
    return aura.value1
  end

  if aura.points and aura.points[1] and aura.points[1] > 0 then
    return aura.points[1]
  end

  if aura.expectedTickValue and aura.expectedTickValue > 0 then
    return aura.expectedTickValue
  end

  if aura.totalAbsorb and aura.expectedTicks and aura.expectedTicks > 0 then
    return aura.totalAbsorb / aura.expectedTicks
  end

  return 0
end

local function buildTickSchedule(aura, now, horizon)
  local expires = aura and aura.expirationTime
  if not expires or expires <= now then
    return {
      count = 0,
      ticks = {},
      expires = expires or 0,
      tickInterval = 0,
      tickAmount = 0,
      total = 0,
    }
  end

  local tickInterval = resolveTickInterval(aura)
  if not tickInterval or tickInterval <= 0 then
    return {
      count = 0,
      ticks = {},
      expires = expires,
      tickInterval = 0,
      tickAmount = 0,
      total = 0,
    }
  end

  local duration = aura.duration or 0
  local auraStart = aura.startTime or (expires - duration)
  if not auraStart or auraStart <= 0 then
    auraStart = now
  end

  local effectiveEnd = min(expires, horizon)
  if effectiveEnd <= now then
    return {
      count = 0,
      ticks = {},
      expires = expires,
      tickInterval = tickInterval,
      tickAmount = resolveTickAmount(aura),
      total = 0,
    }
  end

  local elapsed = max(0, now - auraStart)
  local ticksPassed = floor(elapsed / tickInterval)
  local nextTick = auraStart + (ticksPassed + 1) * tickInterval

  local tickAmount = resolveTickAmount(aura)
  local ticks = {}
  while nextTick <= effectiveEnd + 0.01 do
    if nextTick >= now then
      tinsert(ticks, { time = nextTick, amount = tickAmount })
    end
    nextTick = nextTick + tickInterval
  end

  return {
    count = #ticks,
    ticks = ticks,
    expires = expires,
    tickInterval = tickInterval,
    tickAmount = tickAmount,
    total = tickAmount * #ticks,
  }
end

local M = {}

function M.Initialize(dispatcher)
  if dispatcher and dispatcher.RegisterHandler then
    dispatcher:RegisterHandler("UNIT_AURA", function(_, unit)
      if unit then
        auraCache[unit] = nil
      end
    end)
    dispatcher:RegisterHandler("GROUP_ROSTER_UPDATE", function()
      wipe(auraCache)
    end)
  end
end

function M.RefreshUnit(unit)
  if not unit then
    return
  end

  auraCache[unit] = nil
end

function M.GetHoTTicks(unit, spellID, T_land)
  if not unit or not spellID then
    return { ticks = {}, total = 0, count = 0, expires = 0, tickInterval = 0, tickAmount = 0 }
  end

  local now = GetTime()
  local horizon = T_land or now
  if horizon < now then
    horizon = now
  end

  local unitCache = auraCache[unit]
  if not unitCache then
    unitCache = {}
    auraCache[unit] = unitCache
  end

  local key = spellID
  local cached = unitCache[key]
  if cached and cached.expires and cached.expires > now and cached.horizon == horizon then
    return cached
  end

  local aura = fetchAura(unit, spellID)
  if not aura then
    unitCache[key] = { ticks = {}, total = 0, count = 0, expires = 0, tickInterval = 0, tickAmount = 0 }
    return unitCache[key]
  end

  local schedule = buildTickSchedule(aura, now, horizon)
  schedule.horizon = horizon
  schedule.spellID = spellID
  unitCache[key] = schedule
  return schedule
end

local function normalizeFilter(filter)
  if type(filter) ~= "table" then
    return nil
  end

  local normalized = {}
  local count = 0
  for key, value in pairs(filter) do
    if type(key) == "number" and value then
      normalized[key] = true
      count = count + 1
    elseif type(value) == "number" then
      normalized[value] = true
      count = count + 1
    end
  end

  if count == 0 then
    return nil
  end

  return normalized
end

function M.CollectHoTs(unit, spellFilter, T_land)
  if not unit then
    return { total = 0, ticks = {}, spells = {} }
  end

  local filterSet = normalizeFilter(spellFilter)
  if not filterSet then
    return { total = 0, ticks = {}, spells = {} }
  end

  local ticks = {}
  local spells = {}
  local total = 0
  for spellID in pairs(filterSet) do
    local schedule = M.GetHoTTicks(unit, spellID, T_land)
    spells[spellID] = schedule
    if schedule and schedule.count > 0 then
      total = total + (schedule.total or 0)
      for index, tick in ipairs(schedule.ticks or {}) do
        ticks[#ticks + 1] = {
          spellID = spellID,
          time = tick.time,
          amount = tick.amount,
          index = index,
        }
      end
    end
  end

  sort(ticks, function(left, right)
    if left.time == right.time then
      return (left.spellID or 0) < (right.spellID or 0)
    end
    return left.time < right.time
  end)

  for i = 1, #ticks do
    ticks[i].index = nil
  end

  return {
    total = total,
    ticks = ticks,
    spells = spells,
  }
end

return _G.NODHeal:RegisterModule("AuraTickPredictor", M)
