-- Module: IncomingHeals (read-side)
-- Purpose: Read-only interface to collect incoming heals until tLand using LHC/API fallback.
-- Role: Provides aggregated view for solver consumption; no dispatch or persistent queues here.
-- See also: IncomingHealAggregator (write-side feed & dispatcher)
-- Referenz: /DOCU/NOD_Datenpfad_LHC_API.md §Ereignisfluss

local pairs = pairs
local tonumber = tonumber
local type = type
local format = string.format
local math_floor = math.floor

local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitGetIncomingHeals = UnitGetIncomingHeals

local aggregatorRef
local dispatcherRef
local lhcHandle
local callbacksRegistered = false

local M = {}

local landingEpsilon = 0.05

local function log(message)
  if message then
    print("[NOD] " .. message)
  end
end

local function namespace()
  return _G.NODHeal
end

local function state()
  local ns = namespace()
  return ns and ns.State
end

local function ensureAggregator()
  if aggregatorRef then
    return aggregatorRef
  end

  local ns = namespace()
  if ns and ns.GetModule then
    aggregatorRef = ns:GetModule("IncomingHealAggregator")
  end
  return aggregatorRef
end

local function ensureDispatcher()
  if dispatcherRef then
    return dispatcherRef
  end

  local ns = namespace()
  if ns and ns.GetModule then
    dispatcherRef = ns:GetModule("CoreDispatcher")
  end
  return dispatcherRef
end

local function normalizeLandingTime(value)
  if value == nil then
    return GetTime()
  end

  if type(value) ~= "number" then
    value = tonumber(value)
  end

  if not value then
    return GetTime()
  end

  if value > 1000000 then
    return value / 1000
  end

  return value
end

local function resolveTargets(targets, amount)
  if type(targets) == "table" then
    return targets
  end
  if type(amount) == "table" then
    return amount
  end
  return nil
end

local function feedAggregator(casterGUID, spellID, targets, tLand)
  local aggregator = ensureAggregator()
  if not aggregator or not aggregator.AddHeal then
    return
  end

  local healState = state()
  if healState and not healState.useLHC then
    log("LHC: ignored payload (LHC off)")
    return
  end

  local landing = normalizeLandingTime(tLand)
  for targetGUID, amount in pairs(targets) do
    local payload = {
      targetGUID = targetGUID,
      amount = math_floor((amount or 0) + 0.5),
      landTime = landing,
      sourceGUID = casterGUID,
      spellID = spellID,
      source = "LHC",
    }
    aggregator.AddHeal(payload)
  end
end

local function removeFromAggregator(casterGUID, spellID, targets)
  local aggregator = ensureAggregator()
  if not aggregator or not aggregator.RemoveHeal then
    return
  end

  aggregator.RemoveHeal({
    casterGUID = casterGUID,
    spellID = spellID,
    targets = targets,
  })
end

local function onHealScheduled(event, casterGUID, spellID, _, endTime, targets, amount)
  local resolved = resolveTargets(targets, amount)
  if not resolved then
    return
  end

  feedAggregator(casterGUID, spellID, resolved, endTime)
end

local function onHealStopped(_, casterGUID, spellID, _, targets)
  if type(targets) ~= "table" then
    return
  end
  removeFromAggregator(casterGUID, spellID, targets)
end

local function registerCallbacks()
  if callbacksRegistered then
    return true
  end

  if not lhcHandle then
    lhcHandle = LibStub and LibStub("LibHealComm-4.0", true)
  end

  if not lhcHandle then
    log("HealComm: library not available; fallback active")
    return false
  end

  lhcHandle:RegisterCallback(M, "HealComm_HealStarted", onHealScheduled)
  lhcHandle:RegisterCallback(M, "HealComm_HealUpdated", onHealScheduled)
  lhcHandle:RegisterCallback(M, "HealComm_HealDelayed", onHealScheduled)
  lhcHandle:RegisterCallback(M, "HealComm_HealStopped", onHealStopped)
  lhcHandle:RegisterCallback(M, "HealComm_HealSucceeded", onHealStopped)

  callbacksRegistered = true
  log("HealComm: callbacks registered")
  return true
end

local function unregisterCallbacks()
  if not callbacksRegistered or not lhcHandle then
    callbacksRegistered = false
    return
  end

  lhcHandle:UnregisterCallback(M, "HealComm_HealStarted")
  lhcHandle:UnregisterCallback(M, "HealComm_HealUpdated")
  lhcHandle:UnregisterCallback(M, "HealComm_HealDelayed")
  lhcHandle:UnregisterCallback(M, "HealComm_HealStopped")
  lhcHandle:UnregisterCallback(M, "HealComm_HealSucceeded")

  callbacksRegistered = false
  log("HealComm: callbacks unregistered")
end

local function computeFallback(unit)
  local amount = 0
  if UnitGetIncomingHeals and unit then
    amount = UnitGetIncomingHeals(unit) or 0
  end

  if amount < 0 then
    amount = 0
  end

  local confidence = amount > 0 and "medium" or "low"
  log(format("API: UnitGetIncomingHeals(%s)=%d", tostring(unit), amount))
  return {
    amount = amount,
    confidence = confidence,
  }
end

local function iterateAggregator(unit, horizon, collector)
  local aggregator = ensureAggregator()
  if not aggregator or not aggregator.Iterate then
    return
  end

  aggregator.CleanExpired()
  aggregator.Iterate(unit, horizon, collector)
end

local function collectFromAggregator(unit, horizon)
  local total = 0
  local contributions = {}

  iterateAggregator(unit, horizon, function(entry)
    local amount = entry.amount or 0
    if amount > 0 then
      total = total + amount
      local key = entry.sourceGUID or entry.source or "unknown"
      contributions[key] = (contributions[key] or 0) + amount
    end
  end)

  return total, contributions
end

-- REGION: LHC Callbacks
function M.RegisterHealComm()
  return registerCallbacks()
end

function M.UnregisterHealComm()
  unregisterCallbacks()
  return true
end

function M.scheduleFromTargets(casterGUID, spellID, targets, amount, t_land)
  local resolved = resolveTargets(targets, amount)
  if not resolved then
    return
  end

  feedAggregator(casterGUID, spellID, resolved, t_land)
end
-- ENDREGION

-- REGION: HealComm Toggle
function M.ToggleHealComm(stateFlag)
  if stateFlag then
    return M.RegisterHealComm()
  end
  return M.UnregisterHealComm()
end
-- ENDREGION

function M.Initialize(libHealComm, dispatcher)
  lhcHandle = libHealComm or lhcHandle
  dispatcherRef = dispatcher or ensureDispatcher()
  ensureAggregator()

  if dispatcherRef and dispatcherRef.RegisterHandler then
    dispatcherRef.RegisterHandler("UNIT_SPELLCAST_STOP", function()
      M.CleanExpired()
    end)
  end
end

local function resolveGuid(unit)
  if not unit then
    return nil
  end
  if UnitGUID then
    return UnitGUID(unit)
  end
  return unit
end

function M.CollectUntil(unit, tLand)
  local guid = resolveGuid(unit)
  if not guid then
    return {
      amount = 0,
      confidence = "low",
      sources = {},
    }
  end

  local landing = normalizeLandingTime(tLand)
  local now = GetTime()
  local horizon
  if landing then
    horizon = (landing - now) + landingEpsilon
    if horizon < 0 then
      horizon = 0
    end
  end

  local total, contributions = collectFromAggregator(guid, horizon)

  if total > 0 then
    return {
      amount = total,
      confidence = "high",
      sources = contributions,
    }
  end

  local fallback = computeFallback(unit)
  fallback.sources = contributions
  return fallback
end

-- REGION: API Fallback
function M.FetchFallback(unit, tLand)
  local healState = state()
  if healState and healState.useLHC then
    local fallback = computeFallback(unit)
    fallback.confidence = fallback.amount > 0 and "medium" or "low"
    return fallback
  end

  return computeFallback(unit)
end
-- ENDREGION

-- REGION: Cleanup
function M.CleanExpired(now, unit)
  local aggregator = ensureAggregator()
  if not aggregator or not aggregator.CleanExpired then
    return
  end

  if unit then
    aggregator.CleanExpired(now, unit)
  else
    aggregator.CleanExpired(now)
  end
end
-- ENDREGION

return _G.NODHeal:RegisterModule("IncomingHeals", M)
