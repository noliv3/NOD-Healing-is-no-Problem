-- Module: PredictiveSolver
-- Purpose: Project unit HP at landing time by combining snapshots, incoming heals, damage forecasts, and estimated heal output.
-- API: Depends on upstream modules (HealthSnapshot, IncomingHeals, DamagePrediction, HealValueEstimator)

local math_max = math.max

local moduleRefs = {}
local aliasMap = {
  snapshot = "HealthSnapshot",
  incoming = "IncomingHeals",
  damage = "DamagePrediction",
  estimator = "HealValueEstimator",
}

local function resolveModule(name)
  if moduleRefs[name] ~= nil then
    return moduleRefs[name]
  end

  local alias = aliasMap[name]
  if alias and moduleRefs[alias] ~= nil then
    moduleRefs[name] = moduleRefs[alias]
    return moduleRefs[name]
  end

  local namespace = _G.NODHeal
  local module
  if namespace and namespace.GetModule then
    module = namespace:GetModule(name)
    if not module and alias then
      module = namespace:GetModule(alias)
      if module then
        moduleRefs[alias] = module
      end
    end
  end

  moduleRefs[name] = module
  return module
end

local function clamp(value, lower, upper)
  if value < lower then
    return lower
  end
  if value > upper then
    return upper
  end
  return value
end

local M = {}

function M.Initialize(deps)
  if type(deps) ~= "table" then
    return
  end

  for key, module in pairs(deps) do
    moduleRefs[key] = module
    local alias = aliasMap[key]
    if alias then
      moduleRefs[alias] = module
    end
  end

  for alias, canonical in pairs(aliasMap) do
    if moduleRefs[canonical] and not moduleRefs[alias] then
      moduleRefs[alias] = moduleRefs[canonical]
    elseif moduleRefs[alias] and not moduleRefs[canonical] then
      moduleRefs[canonical] = moduleRefs[alias]
    end
  end
end

function M.CalculateProjectedHealth(state)
  if not state then
    return nil
  end

  local snapshot = state.snapshot
  local snapshotModule = resolveModule("HealthSnapshot") or resolveModule("snapshot")
  if not snapshot and snapshotModule and snapshotModule.Capture then
    snapshot = snapshotModule.Capture(state.unit)
  end
  if not snapshot then
    return nil
  end

  local hpNow = snapshot.hp_now or 0
  local maxHP = snapshot.hp_max or 1

  local damage = state.predictedDamage
  local damageModule = resolveModule("DamagePrediction") or resolveModule("damage")
  if damage == nil and damageModule and damageModule.Estimate then
    damage = damageModule.Estimate(state.unit, state.tLand)
  end
  damage = damage or 0

  local incoming = state.incoming
  local incomingModule = resolveModule("IncomingHeals") or resolveModule("incoming")
  if not incoming and incomingModule and incomingModule.CollectUntil then
    incoming = incomingModule.CollectUntil(state.unit, state.tLand)
  end

  local incomingAmount = 0
  local incomingConfidence = "low"
  if type(incoming) == "table" then
    incomingAmount = incoming.total or incoming.amount or 0
    incomingConfidence = incoming.confidence or incomingConfidence
  elseif type(incoming) == "number" then
    incomingAmount = incoming
  end

  local healValue = state.healValue
  local estimator = resolveModule("HealValueEstimator") or resolveModule("estimator")
  if not healValue and estimator and estimator.Estimate then
    local estimate = estimator.Estimate(state.spellID, state.stats)
    if type(estimate) == "table" then
      healValue = estimate.amount
      state.healVariance = estimate.variance
      state.healConfidence = estimate.confidence
    else
      healValue = estimate
    end
  end
  healValue = healValue or 0

  local total = hpNow - damage + incomingAmount + healValue
  local projected = clamp(total, 0, maxHP)

  return {
    snapshot = snapshot,
    projected = projected,
    incoming = incomingAmount,
    incomingConfidence = incomingConfidence,
    healValue = healValue,
    damage = damage,
  }
end

function M.ComposeResult(snapshot, projected, metadata)
  if not snapshot then
    return nil
  end

  local projectedHP = type(projected) == "table" and projected.projected or projected
  projectedHP = projectedHP or snapshot.hp_now or 0

  local healValue = metadata and metadata.healValue or (type(projected) == "table" and projected.healValue) or 0
  local maxHP = snapshot.hp_max or 1

  local overheal = 0
  if healValue > 0 then
    local effective = math_max(projectedHP - maxHP, 0)
    overheal = effective / healValue
  end

  local confidence = metadata and metadata.confidence or (type(projected) == "table" and projected.incomingConfidence) or "low"

  return {
    projectedHP = clamp(projectedHP, 0, maxHP),
    overheal = overheal,
    absorbs = snapshot.absorbs or 0,
    effectiveHP = (snapshot.hp_now or 0) + (snapshot.absorbs or 0),
    confidence = confidence,
  }
end

return M
