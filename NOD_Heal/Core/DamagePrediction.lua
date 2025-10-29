-- Module: DamagePrediction
-- Purpose: Forecast expected incoming damage (D_pred) per unit using an exponential moving average of recent combat log samples.
-- API: COMBAT_LOG_EVENT_UNFILTERED

local M = {}

function M.Initialize(dispatcher)
  -- TODO: Register COMBAT_LOG_EVENT_UNFILTERED and throttle updates to roughly 0.2s windows for raid performance.
end

function M.RecordCombatSample(timestamp, combatEvent, sourceGUID, destGUID, amount)
  -- TODO: Feed damage values into the EMA window per unit to maintain rolling DPS estimates.
end

function M.CalculateUntil(unit, tLand)
  -- TODO: Apply D_pred = EMA_DPS * (tLand - now) to project accumulated damage for the unit.
end

return M
