-- Module: DesyncGuard
-- Purpose: Gate overlay updates around cast transitions to avoid flicker from latency or delayed combat events.
-- API: UNIT_SPELLCAST_START/STOP/INTERRUPTED/FAILED/SUCCEEDED, GetTime

local GetTime = GetTime
local pairs = pairs
local wipe = wipe

local FREEZE_DURATION = 0.15
local dispatcherRef

local freezeState = {}

if not wipe then
  wipe = function(tbl)
    if not tbl then
      return
    end
    for k in pairs(tbl) do
      tbl[k] = nil
    end
  end
end

local function activateFreeze(unit)
  if not unit then
    return
  end

  local state = freezeState[unit]
  if not state then
    state = {}
    freezeState[unit] = state
  end

  state.releaseAt = GetTime() + FREEZE_DURATION
  state.active = true
end

local function clearFreeze(unit)
  if not unit then
    return
  end

  freezeState[unit] = nil
end

local function obtainDispatcher()
  if dispatcherRef then
    return dispatcherRef
  end

  local namespace = _G.NODHeal
  if namespace and namespace.GetModule then
    dispatcherRef = namespace:GetModule("CoreDispatcher")
  end

  return dispatcherRef
end

local M = {}

function M.Initialize(dispatcher)
  dispatcherRef = dispatcher or obtainDispatcher()

  local hub = dispatcherRef
  if not hub or type(hub.RegisterHandler) ~= "function" then
    return
  end

  hub:RegisterHandler("UNIT_SPELLCAST_START", function(_, unit)
    activateFreeze(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_CHANNEL_START", function(_, unit)
    activateFreeze(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit)
    clearFreeze(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_STOP", function(_, unit)
    clearFreeze(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_INTERRUPTED", function(_, unit)
    clearFreeze(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_FAILED", function(_, unit)
    clearFreeze(unit)
  end)
  hub:RegisterHandler("UNIT_SPELLCAST_SUCCEEDED", function(_, unit)
    clearFreeze(unit)
  end)
  hub:RegisterHandler("GROUP_ROSTER_UPDATE", function()
    wipe(freezeState)
  end)
end

function M.ApplyFreeze(unit)
  activateFreeze(unit)
end

function M.ReleaseFreeze(unit)
  clearFreeze(unit)
end

function M.IsFrozen(unit)
  local state = unit and freezeState[unit]
  if not state then
    return false
  end

  if state.releaseAt and GetTime() >= state.releaseAt then
    freezeState[unit] = nil
    return false
  end

  return state.active == true
end

local module = _G.NODHeal:RegisterModule("DesyncGuard", M)

if _G.NODHeal and _G.NODHeal.Core then
  _G.NODHeal.Core.DesyncGuard = M
end

return module
