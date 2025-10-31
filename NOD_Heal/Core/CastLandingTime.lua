-- Module: CastLandingTime
-- Purpose: Compute the expected spell landing timestamp (T_land) including cast time, GCD, spell queue window, and latency adjustments.
-- API: GetSpellCooldown, UnitCastingInfo, LatencyTools

local activeCasts = {}

local GetTime = GetTime
local GetSpellCooldown = GetSpellCooldown
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local math_max = math.max
local math_min = math.min

local dispatcherRef
local latencyModule

local function obtainLatencyModule()
  if latencyModule then
    return latencyModule
  end

  local namespace = _G.NODHeal
  if namespace and namespace.GetModule then
    latencyModule = namespace:GetModule("LatencyTools")
  end

  return latencyModule
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

local function resolveLatency()
  local module = obtainLatencyModule()
  if module and module.GetLatency then
    local value = module:GetLatency()
    if value and value > 0 then
      if value > 4000 then
        value = 4000
      end
      return value / 1000
    end
  end

  return 0
end

local function resolveQueueWindow()
  local module = obtainLatencyModule()
  if module and module.GetSpellQueueWindow then
    local value = module:GetSpellQueueWindow() or 0
    if value < 0 then
      value = 0
    elseif value > 4000 then
      value = 4000
    end
    return value / 1000
  end

  return 0.4
end

local function resolveGCDSeconds()
  if not GetSpellCooldown then
    return 0
  end

  local _, duration = GetSpellCooldown(61304)
  if duration and duration > 0 then
    return duration
  end

  return 0
end

local function normaliseTimestamp(value)
  if not value then
    return nil
  end

  if value > 1000000 then
    return value / 1000
  end

  if value > 10000 then
    return value / 1000
  end

  return value
end

local M = {}

function M.Initialize(dispatcher)
  dispatcherRef = dispatcher or obtainDispatcher()

  local hub = dispatcherRef
  if not hub or type(hub.RegisterHandler) ~= "function" then
    return
  end

  hub:RegisterHandler("UNIT_SPELLCAST_START", function(_, unit)
    M.TrackUnitCast(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_CHANNEL_START", function(_, unit)
    M.TrackUnitCast(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_DELAYED", function(_, unit)
    M.TrackUnitCast(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_STOP", function(_, unit)
    if unit then
      activeCasts[unit] = nil
    end
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_INTERRUPTED", function(_, unit)
    if unit then
      activeCasts[unit] = nil
    end
  end)
end

function M.ComputeLandingTime(spellID, castMs, nowMs)
  local castSeconds = 0
  if type(castMs) == "number" then
    if castMs < 0 then
      castMs = 0
    end
    if castMs > 0 then
      if castMs > 10000 then
        castSeconds = castMs / 1000
      else
        castSeconds = castMs
      end
    end
  end

  local startTime
  if type(nowMs) == "number" then
    if nowMs > 0 then
      if nowMs > 10000 then
        startTime = nowMs / 1000
      else
        startTime = nowMs
      end
    end
  end

  if not startTime then
    startTime = GetTime()
  end

  local gcd = resolveGCDSeconds()
  if gcd < 0 then
    gcd = 0
  elseif gcd > 1.5 then
    gcd = 1.5
  end

  local queueSeconds = resolveQueueWindow()
  queueSeconds = math_min(math_max(queueSeconds, 0), 1.5)

  local latencySeconds = resolveLatency()
  latencySeconds = math_min(math_max(latencySeconds, 0), 1.5)

  local total = castSeconds + gcd + queueSeconds + latencySeconds
  if total < 0 then
    total = 0
  end

  return startTime + total
end

function M.TrackUnitCast(unit, spellID, startMs, endMs)
  if not unit then
    return nil
  end

  local start = startMs
  local finish = endMs
  local resolvedSpell = spellID

  if not start or not finish then
    local name, _, _, s, e, _, castID = UnitCastingInfo and UnitCastingInfo(unit)
    if not name then
      name, _, _, s, e, _, castID = UnitChannelInfo and UnitChannelInfo(unit)
    end

    if s and e then
      start = s
      finish = e
    end
    if not resolvedSpell and castID then
      resolvedSpell = castID
    end
  end

  if not start or not finish or start <= 0 or finish <= start then
    activeCasts[unit] = nil
    return nil
  end

  local castMs = finish - start
  local startSeconds = normaliseTimestamp(start)
  local landing = M.ComputeLandingTime(resolvedSpell, castMs, start)

  local record = {
    unit = unit,
    spellID = resolvedSpell,
    startTime = startSeconds,
    endTime = normaliseTimestamp(finish),
    castMs = castMs,
    t_land = landing,
  }

  activeCasts[unit] = record
  return record
end

return _G.NODHeal:RegisterModule("CastLandingTime", M)
