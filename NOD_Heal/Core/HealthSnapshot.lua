local addonName = ...
local NODHeal = _G.NODHeal

local HealthSnapshot = {}
HealthSnapshot.__index = HealthSnapshot

function HealthSnapshot:Capture(unit)
    if not unit then
        return nil
    end

    local snapshot = {
        hp_now = UnitHealth(unit) or 0,
        hp_max = UnitHealthMax(unit) or 1,
        absorbs = UnitGetTotalAbsorbs(unit) or 0,
        isDead = UnitIsDeadOrGhost(unit) or false,
        isOffline = not UnitIsConnected(unit) or false,
    }

    return snapshot
end

return NODHeal:RegisterModule("HealthSnapshot", HealthSnapshot)
