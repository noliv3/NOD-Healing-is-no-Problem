-- Module: CastLandingTime
-- Purpose: Compute the expected spell landing timestamp (T_land) including cast time, GCD, spell queue window, and latency adjustments.
-- API: GetSpellCooldown, GetNetStats, C_CVar.GetCVar

local activeCasts = {}

local GetTime = GetTime
local GetSpellCooldown = GetSpellCooldown
local GetNetStats = GetNetStats
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local math_max = math.max

local latencyModule

local function getLatencyModule()
  if not latencyModule then
    local namespace = _G.NODHeal
    if namespace and namespace.GetModule then
      latencyModule = namespace:GetModule("LatencyTools")
    end
  end
  return latencyModule
end

local function computeLatency()
  local module = getLatencyModule()
  if module and module.GetLatency then
    return module:GetLatency()
  end

  if not GetNetStats then
    return 0
  end

  local _, _, home, world = GetNetStats()
  local highest = math_max(home or 0, world or 0)
  return highest > 0 and (highest / 1000) or 0
end

local function computeQueueWindow()
  local module = getLatencyModule()
  if module and module.GetSpellQueueWindow then
    return module:GetSpellQueueWindow()
  end

  if C_CVar and C_CVar.GetCVar then
    local value = tonumber(C_CVar.GetCVar("SpellQueueWindow"))
    if value then
      return value / 1000
    end
  end

  return 0.4 -- Blizzard default in milliseconds converted to seconds
end

local function resolveCastTime(castInfo)
  if castInfo.castTime then
    return castInfo.castTime
  end

  if castInfo.startTime and castInfo.endTime then
    local duration = (castInfo.endTime - castInfo.startTime)
    if duration > 0 then
      if duration > 1000 then
        return duration / 1000
      end
      return duration
    end
  end

  return 0
end

local function resolveGCD(castInfo)
  if castInfo.gcd then
    return castInfo.gcd
  end

  if not GetSpellCooldown then
    return 0
  end

  local _, duration = GetSpellCooldown(61304)
  if duration and duration > 0 then
    return duration
  end

  return 0
end

local M = {}

function M.Initialize(dispatcher)
  if dispatcher and dispatcher.RegisterHandler then
    dispatcher:RegisterHandler("UNIT_SPELLCAST_START", function(_, unit)
      M.TrackUnitCast(unit)
    end)
    dispatcher:RegisterHandler("UNIT_SPELLCAST_CHANNEL_START", function(_, unit)
      M.TrackUnitCast(unit)
    end)
    dispatcher:RegisterHandler("UNIT_SPELLCAST_DELAYED", function(_, unit)
      M.TrackUnitCast(unit)
    end)
    dispatcher:RegisterHandler("UNIT_SPELLCAST_STOP", function(_, unit)
      if unit then
        activeCasts[unit] = nil
      end
    end)
    dispatcher:RegisterHandler("UNIT_SPELLCAST_INTERRUPTED", function(_, unit)
      if unit then
        activeCasts[unit] = nil
      end
    end)
  end
end

function M.ComputeLandingTime(castInfo)
  if not castInfo then
    return nil
  end

  local castTime = resolveCastTime(castInfo)
  local gcd = resolveGCD(castInfo)
  local queue = castInfo.spellQueueWindow or computeQueueWindow()
  local latency = castInfo.latency or computeLatency()

  local total = castTime + gcd + queue + latency

  local startTime = castInfo.startTime
  if not startTime then
    startTime = GetTime()
  elseif startTime > 1000000 then
    startTime = startTime / 1000
  end

  return startTime + total
end

function M.TrackUnitCast(unit, spellID)
  if not unit then
    return nil
  end

  local castName, _, _, startMS, endMS, _, castID = UnitCastingInfo and UnitCastingInfo(unit)
  local channelName
  if not castName then
    channelName, _, _, startMS, endMS, _, castID = UnitChannelInfo and UnitChannelInfo(unit)
  end

  if not (castName or channelName) or not startMS or not endMS then
    activeCasts[unit] = nil
    return nil
  end

  local castInfo = {
    spellID = spellID or castID,
    startTime = startMS / 1000,
    endTime = endMS / 1000,
  }
  castInfo.castTime = castInfo.endTime - castInfo.startTime

  local tLand = M.ComputeLandingTime(castInfo)

  local payload = {
    spellID = castInfo.spellID,
    t_start = castInfo.startTime,
    t_end = castInfo.endTime,
    t_land = tLand,
  }

  activeCasts[unit] = payload
  return payload
end

return M
