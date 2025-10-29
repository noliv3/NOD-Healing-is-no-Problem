-- Module: LatencyTools
-- Purpose: Provide latency and spell queue window metrics for conservative landing time projections.
-- API: GetNetStats, C_CVar.GetCVar

local M = {}

function M.Initialize()
  -- TODO: Create caches for world/realm latency values and load the SpellQueueWindow CVAR once at startup.
end

function M.Refresh()
  -- TODO: Pull current latency via GetNetStats and update the cached spell queue window for timing calculations.
end

function M.GetLatency()
  -- TODO: Return the most recent combined latency to be consumed by CastLandingTime.
end

function M.GetSpellQueueWindow()
  -- TODO: Expose the cached SpellQueueWindow value so timing modules can include it in T_land computations.
end

return M
