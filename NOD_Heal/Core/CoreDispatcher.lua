-- Module: CoreDispatcher
-- Purpose: Coordinate event routing, throttled updates, and module notifications across the backend core.
-- API: UNIT_HEALTH, UNIT_AURA, UNIT_SPELLCAST_START/STOP/INTERRUPTED, COMBAT_LOG_EVENT_UNFILTERED, HealComm events

local M = {}

function M.Initialize()
  -- TODO: Build registration tables for event handlers and configure default throttle intervals (0.1–0.2s).
end

function M.RegisterHandler(event, handler)
  -- TODO: Allow backend modules to subscribe to Blizzard and LibHealComm events managed by the dispatcher.
end

function M.Dispatch(event, ...)
  -- TODO: Invoke registered handlers while respecting throttle settings and instant reaction requirements.
end

function M.SetThrottle(event, interval)
  -- TODO: Adjust throttling per event to maintain performance for 40-player raids.
end

return M
