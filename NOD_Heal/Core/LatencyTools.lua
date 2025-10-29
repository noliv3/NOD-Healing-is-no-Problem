-- Module: LatencyTools
-- Purpose: Provide latency and spell queue window metrics for conservative landing time projections.
-- API: GetNetStats, C_CVar.GetCVar

local latencySeconds = 0
local spellQueueSeconds = 0.4

local GetNetStats = GetNetStats
local GetTime = GetTime
local C_CVar = C_CVar
local math_max = math.max

local lastUpdate = 0

local M = {}

function M.Initialize()
  latencySeconds = 0
  spellQueueSeconds = 0.4
  lastUpdate = 0
  M.Refresh()
end

function M.Refresh()
  local now = GetTime and GetTime() or 0
  if now - lastUpdate < 0.2 then
    return
  end

  lastUpdate = now

  if GetNetStats then
    local _, _, home, world = GetNetStats()
    local highest = math_max(home or 0, world or 0)
    if highest > 0 then
      latencySeconds = highest / 1000
    end
  end

  if C_CVar and C_CVar.GetCVar then
    local queueWindow = tonumber(C_CVar.GetCVar("SpellQueueWindow"))
    if queueWindow then
      spellQueueSeconds = queueWindow / 1000
    end
  end
end

function M.GetLatency()
  return latencySeconds
end

function M.GetSpellQueueWindow()
  return spellQueueSeconds
end

return M
