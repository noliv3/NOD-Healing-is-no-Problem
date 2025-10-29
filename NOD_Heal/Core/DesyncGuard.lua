-- Module: DesyncGuard
-- Purpose: Prevent flickering overlay updates by buffering solver refreshes during cast start latency windows.
-- API: UNIT_SPELLCAST_START, UNIT_SPELLCAST_STOP, SPELL_HEAL events

local M = {}

function M.Initialize(dispatcher)
  -- TODO: Register cast lifecycle and heal landing events to control the short freeze window.
end

function M.OnCastStart(unit, spellID, castGUID)
  -- TODO: Suspend overlay updates for roughly 100–150 ms after the cast begins to mask latency jitter.
end

function M.OnCastResolved(unit, spellID, castGUID)
  -- TODO: Resume updates immediately when CAST_STOP, SPELL_HEAL, or interruption events fire for the tracked cast.
end

return M
