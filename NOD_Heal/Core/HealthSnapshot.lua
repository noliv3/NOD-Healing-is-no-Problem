-- Module: HealthSnapshot
-- Purpose: Collect current HP state, death/offline flags, and absorbs per unit as baseline for solver calculations.
-- API: UnitHealth, UnitHealthMax, UnitIsDeadOrGhost, UnitGetTotalAbsorbs

local M = {}

function M.Initialize(dispatcher)
  -- TODO: Subscribe to UNIT_HEALTH, UNIT_MAXHEALTH, UNIT_ABSORB_AMOUNT_CHANGED, and GROUP_ROSTER_UPDATE to refresh snapshots.
end

function M.Capture(unit)
  -- TODO: Return a table with hp_now, hp_max, absorbs, isDead, and isOffline values derived from the WoW API calls.
end

function M.FlagOfflineState(unit)
  -- TODO: Evaluate UnitIsDeadOrGhost and UnitIsConnected to set dead/offline indicators in cached snapshots.
end

return M
