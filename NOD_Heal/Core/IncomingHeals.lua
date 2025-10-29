-- Module: IncomingHeals
-- Purpose: Aggregate all incoming heals from LibHealComm and Blizzard API sources until the computed landing time.
-- API: LibHealComm callbacks, UnitGetIncomingHeals

local M = {}

function M.Initialize(libHealComm, dispatcher)
  -- TODO: Hook HealComm_HealStarted, HealComm_HealUpdated, HealComm_HealStopped, and related events to maintain heal queues.
end

function M.CollectUntil(unit, tLand)
  -- TODO: Sum scheduled heals up to tLand, track sources, and flag confidence when only UnitGetIncomingHeals data is available.
end

function M.FetchFallback(unit, healer)
  -- TODO: Use UnitGetIncomingHeals to provide a safety net when LibHealComm lacks entries for the given unit.
end

return M
