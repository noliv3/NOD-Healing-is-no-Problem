-- Module: LatencyTools
-- Purpose: Provide latency and spell queue window metrics for conservative landing time projections.
-- API: GetNetStats, C_CVar.GetCVar

local latencyMs = 0
local spellQueueMs = 400

local GetNetStats = GetNetStats
local GetTime = GetTime
local C_CVar = C_CVar
local math_max = math.max
local math_min = math.min

local lastUpdate = 0
local UPDATE_INTERVAL = 0.2

local M = {}

function M.Initialize()
  latencyMs = 0
  spellQueueMs = 400
  lastUpdate = 0
  M.Refresh()
end

function M.Refresh()
  local now = GetTime and GetTime() or 0
  if (now - lastUpdate) < UPDATE_INTERVAL then
    return
  end

  lastUpdate = now

  if GetNetStats then
    local _, _, home, world = GetNetStats()
    local highest = math_max(home or 0, world or 0)
    if highest < 0 then
      highest = 0
    end
    latencyMs = highest
  end

  if C_CVar and C_CVar.GetCVar then
    local queueWindow = tonumber(C_CVar.GetCVar("SpellQueueWindow"))
    if queueWindow then
      queueWindow = math_max(queueWindow, 0)
      queueWindow = math_min(queueWindow, 4000)
      spellQueueMs = queueWindow
    end
  end

  if spellQueueMs < 0 then
    spellQueueMs = 0
  elseif spellQueueMs > 4000 then
    spellQueueMs = 4000
  end

  if latencyMs < 0 then
    latencyMs = 0
  elseif latencyMs > 4000 then
    latencyMs = 4000
  end
end

function M.GetLatency()
  M.Refresh()
  return latencyMs
end

function M.GetSpellQueueWindow()
  M.Refresh()
  return spellQueueMs
end

local namespace = _G.NODHeal
if namespace and namespace.RegisterModule then
  return namespace:RegisterModule("LatencyTools", M)
end

return M
