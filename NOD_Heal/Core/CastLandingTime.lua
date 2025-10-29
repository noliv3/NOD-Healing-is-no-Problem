-- Module: CastLandingTime
-- Purpose: Compute the expected spell landing timestamp (T_land) including cast time, GCD, spell queue window, and latency adjustments.
-- API: GetSpellCooldown, GetNetStats, C_CVar.GetCVar

local M = {}

function M.Initialize(dispatcher)
  -- TODO: Register UNIT_SPELLCAST_START, UNIT_SPELLCAST_CHANNEL_START, UNIT_SPELLCAST_DELAYED, and UNIT_SPELLCAST_STOP to maintain cast timing state.
end

function M.ComputeLandingTime(castInfo)
  -- TODO: Apply T_land = CastTime + GCD + SpellQueueWindow + Latency using data from castInfo and latency helpers.
end

function M.TrackUnitCast(unit, spellID)
  -- TODO: Capture t_start, t_end, and t_land for the active cast so downstream modules can query expected landing times.
end

return M
