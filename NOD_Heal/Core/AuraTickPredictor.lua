-- Module: AuraTickPredictor
-- Purpose: Derive upcoming HoT ticks until the specified landing window for predictive healing merges.
-- API: AuraUtil.ForEachAura, UnitAura, GetTime

local AuraUtil = AuraUtil
local UnitAura = UnitAura
local GetTime = GetTime
local pairs = pairs
local wipe = wipe
local floor = math.floor
local max = math.max
local min = math.min
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

local function buildTickSchedule(aura, now, horizon)
  local expires = aura and aura.expirationTime
  if not expires or expires <= now then
    return {
      count = 0,
      times = {},
      expires = expires or 0,
      tickInterval = 0,
    }
  end

  local tickInterval = resolveTickInterval(aura)
  if not tickInterval or tickInterval <= 0 then
    return {
      count = 0,
      times = {},
      expires = expires,
      tickInterval = 0,
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
      times = {},
      expires = expires,
      tickInterval = tickInterval,
    }
  end

  local elapsed = max(0, now - auraStart)
  local ticksPassed = floor(elapsed / tickInterval)
  local nextTick = auraStart + (ticksPassed + 1) * tickInterval

  local times = {}
  while nextTick <= effectiveEnd + 0.01 do
    if nextTick >= now then
      tinsert(times, nextTick)
    end
    nextTick = nextTick + tickInterval
  end

  return {
    count = #times,
    times = times,
    expires = expires,
    tickInterval = tickInterval,
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

function M.GetHoTTicks(unit, spellID, T_land)
  if not unit or not spellID then
    return { count = 0, times = {}, expires = 0, tickInterval = 0 }
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
    unitCache[key] = { count = 0, times = {}, expires = 0, tickInterval = 0 }
    return unitCache[key]
  end

  local schedule = buildTickSchedule(aura, now, horizon)
  schedule.horizon = horizon
  unitCache[key] = schedule
  return schedule
end

return M
