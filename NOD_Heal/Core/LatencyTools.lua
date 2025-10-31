-- Module: LatencyTools
-- Purpose: Provide latency and spell queue window metrics for conservative landing time projections.
-- API: GetNetStats, C_CVar.GetCVar

local latencySeconds = 0
local spellQueueSeconds = 0.4

local GetNetStats = GetNetStats
local GetTime = GetTime
local C_CVar = C_CVar
local math_max = math.max
local math_min = math.min

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
    if highest < 0 then
      highest = 0
    end
    latencySeconds = highest / 1000
  end

  if C_CVar and C_CVar.GetCVar then
    local queueWindow = tonumber(C_CVar.GetCVar("SpellQueueWindow"))
    if queueWindow then
      queueWindow = math_max(queueWindow, 0)
      queueWindow = math_min(queueWindow, 1500)
      spellQueueSeconds = queueWindow / 1000
    end
  end

  if spellQueueSeconds < 0 then
    spellQueueSeconds = 0
  elseif spellQueueSeconds > 1.5 then
    spellQueueSeconds = 1.5
  end
end

function M.GetLatency()
  M.Refresh()
  return latencySeconds
end

function M.GetSpellQueueWindow()
  M.Refresh()
  return spellQueueSeconds
end

return M
