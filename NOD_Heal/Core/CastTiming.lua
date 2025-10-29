local addonName = ...
local NODHeal = _G.NODHeal

local CastTiming = {}
CastTiming.__index = CastTiming

local function getLatency()
    local _, _, homeLatency, worldLatency = GetNetStats()
    local latency = math.max(homeLatency or 0, worldLatency or 0)
    return (latency or 0) / 1000
end

local function getSpellQueueWindow()
    local value = tonumber(C_CVar.GetCVar("SpellQueueWindow"))
    if not value then
        return 0.2
    end

    return value / 1000
end

function CastTiming:Compute(castTimeSeconds)
    local gcd = 1.5 -- placeholder; will be dynamic later
    local queueWindow = getSpellQueueWindow()
    local latency = getLatency()

    local total = (castTimeSeconds or 0) + gcd + queueWindow + latency

    return total
end

return NODHeal:RegisterModule("CastTiming", CastTiming)
