-- Module: HealthSnapshot
-- Purpose: Collect current HP state, death/offline flags, and absorbs per unit as baseline for solver calculations.
-- API: UnitHealth, UnitHealthMax, UnitIsDeadOrGhost, UnitGetTotalAbsorbs

local snapshotCache = {}

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs

local M = {}

function M.Initialize(dispatcher)
  local function invalidate(_, unit)
    if unit then
      snapshotCache[unit] = nil
    end
  end

  if dispatcher and dispatcher.RegisterHandler then
    dispatcher:RegisterHandler("UNIT_HEALTH", invalidate)
    dispatcher:RegisterHandler("UNIT_MAXHEALTH", invalidate)
    dispatcher:RegisterHandler("UNIT_ABSORB_AMOUNT_CHANGED", invalidate)
    dispatcher:RegisterHandler("GROUP_ROSTER_UPDATE", function()
      for k in pairs(snapshotCache) do
        snapshotCache[k] = nil
      end
    end)
  end
end

function M.Capture(unit)
  if not unit then
    return nil
  end

  local cached = snapshotCache[unit]
  if cached then
    return cached
  end

  local hpNow = UnitHealth(unit) or 0
  local hpMax = UnitHealthMax(unit) or 1
  local absorbs = UnitGetTotalAbsorbs and (UnitGetTotalAbsorbs(unit) or 0) or 0
  local isDead = UnitIsDeadOrGhost(unit) or false
  local isConnected = UnitIsConnected and UnitIsConnected(unit)
  local isOffline = isConnected == false

  local snapshot = {
    hp_now = hpNow,
    hp_max = hpMax > 0 and hpMax or 1,
    absorbs = absorbs,
    isDead = isDead,
    isOffline = isOffline,
  }

  snapshotCache[unit] = snapshot
  return snapshot
end

function M.FlagOfflineState(unit)
  if not unit then
    return
  end

  local snapshot = snapshotCache[unit]
  if not snapshot then
    snapshot = M.Capture(unit)
  end

  snapshot.isDead = UnitIsDeadOrGhost(unit) or false
  local isConnected = UnitIsConnected and UnitIsConnected(unit)
  snapshot.isOffline = isConnected == false
end

return M
