local addonName = ...
local NODHeal = _G.NODHeal

local PredictiveSolver = {}
PredictiveSolver.__index = PredictiveSolver

function PredictiveSolver:New(snapshotModule, aggregatorModule)
    local instance = setmetatable({
        snapshotModule = snapshotModule or NODHeal:GetModule("HealthSnapshot"),
        aggregatorModule = aggregatorModule or NODHeal:GetModule("IncomingHealAggregator"),
    }, self)

    return instance
end

local function clamp(value, minVal, maxVal)
    if value < minVal then
        return minVal
    end
    if value > maxVal then
        return maxVal
    end
    return value
end

function PredictiveSolver:Project(unit, horizon, expectedHeal)
    local snapshot = self.snapshotModule and self.snapshotModule:Capture(unit)
    if not snapshot then
        return nil
    end

    local incoming = 0
    if self.aggregatorModule then
        incoming = self.aggregatorModule:GetIncoming(unit, horizon)
    end

    local base = snapshot.hp_now + snapshot.absorbs
    local predicted = base + (expectedHeal or 0) + incoming
    local maxHP = snapshot.hp_max

    return clamp(predicted, 0, maxHP)
end

return NODHeal:RegisterModule("PredictiveSolver", PredictiveSolver)
