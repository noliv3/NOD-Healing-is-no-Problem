-- Module: AuraTickPredictor
-- Purpose: Predict upcoming HoT and DoT ticks until the landing time to feed scheduled healing into projections.
-- API: AuraUtil.FindAuraBy..., UnitAura

local M = {}

function M.Initialize(dispatcher)
  -- TODO: Monitor UNIT_AURA and self-cast HoT events to refresh tick schedules only for relevant raid members.
end

function M.RefreshUnit(unit)
  -- TODO: Scan active auras, determine tick intervals, and enqueue tick timestamps leading up to t_land.
end

function M.GetTicksUntil(unit, tLand)
  -- TODO: Return pending tick events and their summed values up to the provided landing time.
end

return M
