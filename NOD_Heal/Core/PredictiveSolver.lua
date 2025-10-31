-- Module: PredictiveSolver
-- Purpose: Project unit HP at landing time by combining snapshots, incoming heals, damage forecasts, and estimated heal output.
-- API: Depends on upstream modules (HealthSnapshot, IncomingHeals, DamagePrediction, HealValueEstimator)

local math_max = math.max
local pairs = pairs

local moduleRefs = {}
local aliasMap = {
  snapshot = "HealthSnapshot",
  incoming = "IncomingHeals",
  damage = "DamagePrediction",
  estimator = "HealValueEstimator",
  ticks = "AuraTickPredictor",
  latency = "LatencyTools",
}

local confidenceWeights = {
  low = 1,
  medium = 2,
  high = 3,
}

local function resolveModule(name)
  if moduleRefs[name] ~= nil then
    return moduleRefs[name]
  end

  local namespace = _G.NODHeal
  local module
  if namespace and namespace.GetModule then
    module = namespace:GetModule(name)
  end

  if not module then
    local alias = aliasMap[name]
    if alias and namespace and namespace.GetModule then
      module = namespace:GetModule(alias)
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

local function accumulateConfidence(...)
  local total = 0
  local count = 0

  for i = 1, select("#", ...) do
    local level = select(i, ...)
    if level then
      local weight = confidenceWeights[level]
      if weight then
        total = total + weight
        count = count + 1
      end
    end
  end

  if count == 0 then
    return "low"
  end

  local average = total / count
  if average >= 2.5 then
    return "high"
  elseif average >= 1.75 then
    return "medium"
  end

  return "low"
end

local M = {}

function M.Initialize(deps)
  moduleRefs = {}

  if type(deps) == "table" then
    for key, value in pairs(deps) do
      moduleRefs[key] = value
      local alias = aliasMap[key]
      if alias then
        moduleRefs[alias] = value
      end
    end
  end
end

local function fetchSnapshot(unit)
  local module = resolveModule("HealthSnapshot")
  if module and module.Capture then
    return module.Capture(unit)
  end
  return nil
end

local function evaluateDamage(unit, tLand)
  local module = resolveModule("DamagePrediction")
  if module and module.Estimate then
    local estimate = module.Estimate(unit, tLand)
    if type(estimate) == "table" then
      estimate.amount = math_max(estimate.amount or 0, 0)
      return estimate.amount, estimate
    elseif type(estimate) == "number" then
      return math_max(estimate, 0), { amount = math_max(estimate, 0) }
    end
  end
  return 0, { amount = 0, confidence = "low", samples = 0 }
end

local function evaluateIncoming(unit, tLand)
  local module = resolveModule("IncomingHeals")
  if module and module.CollectUntil then
    local data = module.CollectUntil(unit, tLand)
    if type(data) == "table" then
      local amount = math_max(data.amount or 0, 0)
      return amount, data.confidence or "low", data
    end
    if type(data) == "number" then
      local amount = math_max(data, 0)
      return amount, amount > 0 and "medium" or "low", nil
    end
  end

  if module and module.FetchFallback then
    local amount = module.FetchFallback(unit, tLand)
    if type(amount) == "number" and amount > 0 then
      return amount, "medium", nil
    end
  end
  return 0, "low", nil
end

local function evaluateHoTs(unit, spellID, tLand)
  local module = resolveModule("AuraTickPredictor")
  if not module then
    return 0, nil
  end

  if module.CollectHoTs and spellID and type(spellID) == "table" then
    local data = module.CollectHoTs(unit, spellID, tLand)
    local total = 0
    if type(data) == "table" then
      total = math_max(data.total or 0, 0)
    end
    return total, data
  elseif module.GetHoTTicks and spellID then
    local schedule = module.GetHoTTicks(unit, spellID, tLand)
    local total = 0
    if type(schedule) == "table" then
      total = math_max(schedule.total or 0, 0)
    end
    return total, schedule
  end

  return 0, nil
end

local function evaluateHealValue(spellID, stats)
  local module = resolveModule("HealValueEstimator")
  if module and module.Estimate then
    local estimate = module.Estimate(spellID, stats)
    if type(estimate) == "table" then
      local mean = math_max(estimate.mean or 0, 0)
      return mean, estimate
    elseif type(estimate) == "number" then
      return math_max(estimate, 0), { mean = math_max(estimate, 0) }
    end
  end
  return 0, { mean = 0 }
end

local function fetchLatencyMeta()
  local module = resolveModule("LatencyTools")
  if not module then
    return { latency = 0, queue = 0 }
  end

  local latency = module.GetLatency and module.GetLatency() or 0
  local queue = module.GetSpellQueueWindow and module.GetSpellQueueWindow() or 0

  if latency < 0 then latency = 0 end
  if queue < 0 then queue = 0 end

  return { latency = latency, queue = queue }
end

function M.CalculateProjectedHealth(unit, spellID, tLand)
  if not unit then
    return nil
  end

  local snapshot = fetchSnapshot(unit)
  if not snapshot then
    return nil
  end

  local hpNow = snapshot.hp_now or 0
  local hpMax = snapshot.hp_max or 1
  if hpMax <= 0 then
    hpMax = 1
  end

  local damageAmount, damageData = evaluateDamage(unit, tLand)
  local incomingAmount, incomingConfidence = evaluateIncoming(unit, tLand)
  local hotAmount = evaluateHoTs(unit, spellID, tLand)
  local healAmount, healData = evaluateHealValue(spellID, nil)

  local rawProjected = hpNow - damageAmount + incomingAmount + hotAmount + healAmount
  local projected = clamp(rawProjected, 0, hpMax)

  local absorbs = snapshot.absorbs or 0
  if absorbs < 0 then
    absorbs = 0
  end

  local overheal = math_max(rawProjected - hpMax, 0)

  local damageConfidence = (damageData and damageData.confidence) or "low"
  local healConfidence
  if healData and healData.mean and healData.mean > 0 then
    healConfidence = "medium"
  else
    healConfidence = "low"
  end

  local combinedConfidence = accumulateConfidence(incomingConfidence, damageConfidence, healConfidence)

  local components = {
    dmg = damageAmount,
    incHeals = incomingAmount,
    hots = hotAmount,
    healValue = healAmount,
    absorbs = absorbs,
  }

  local meta = fetchLatencyMeta()
  meta.tLand = tLand

  return M.ComposeResult(snapshot, projected, components, meta, combinedConfidence, overheal)
end

function M.ComposeResult(snapshot, projectedHP, components, meta, confidence, overhealValue)
  if not snapshot then
    return nil
  end

  local hpNow = snapshot.hp_now or 0
  local hpMax = snapshot.hp_max or 1
  if hpMax <= 0 then
    hpMax = 1
  end

  local projected = projectedHP or hpNow
  projected = clamp(projected, 0, hpMax)

  local absorbs = snapshot.absorbs or 0
  if absorbs < 0 then
    absorbs = 0
  end

  local overheal = math_max(overhealValue or 0, 0)

  return {
    hp_now = hpNow,
    hp_max = hpMax,
    hp_proj = projected,
    overheal = overheal,
    confidence = confidence or "low",
    components = components or {
      dmg = 0,
      incHeals = 0,
      hots = 0,
      healValue = 0,
      absorbs = absorbs,
    },
    meta = meta or {},
  }
end

return _G.NODHeal:RegisterModule("PredictiveSolver", M)
