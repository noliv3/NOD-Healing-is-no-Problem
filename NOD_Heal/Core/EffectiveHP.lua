-- Module: EffectiveHP
-- Purpose: Estimate effective health by combining current HP with active absorbs before solver evaluation.
-- API: UnitGetTotalAbsorbs

local M = {}

function M.Initialize()
  -- TODO: Prepare caches for absorb values so they can be merged with health snapshots efficiently.
end

function M.Calculate(snapshot)
  -- TODO: Apply EHP_now = HP_now + Absorbs_now using the snapshot data collected from HealthSnapshot.
end

function M.UpdateFromUnit(unit)
  -- TODO: Refresh absorb totals for the unit via UnitGetTotalAbsorbs and synchronize with stored snapshots.
end

return M
