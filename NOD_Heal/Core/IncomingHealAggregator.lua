local addonName = ...
local NODHeal = _G.NODHeal

local IncomingHealAggregator = {}
IncomingHealAggregator.__index = IncomingHealAggregator

function IncomingHealAggregator:New()
    local instance = setmetatable({
        heals = {},
        listeners = {},
    }, self)

    return instance
end

function IncomingHealAggregator:AddHeal(unit, amount, eta, source)
    if not unit then
        return
    end

    if not self.heals[unit] then
        self.heals[unit] = {}
    end

    table.insert(self.heals[unit], {
        amount = amount or 0,
        eta = eta or 0,
        source = source or "unknown",
    })
end

function IncomingHealAggregator:GetIncoming(unit, horizon)
    local heals = self.heals[unit]
    if not heals then
        return 0
    end

    local total = 0
    local cutoff = GetTime() + (horizon or math.huge)

    for _, entry in ipairs(heals) do
        if entry.eta <= cutoff then
            total = total + (entry.amount or 0)
        end
    end

    return total
end

return NODHeal:RegisterModule("IncomingHealAggregator", IncomingHealAggregator)
