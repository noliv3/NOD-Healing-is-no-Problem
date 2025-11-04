local addonName = ...

NODHealDB = NODHealDB or {}
NODHealDB.profile = NODHealDB.profile or {
    updateInterval = 0.1,
    throttle = 0.2,
}

local defaults = NODHealDB.profile

local NODHeal = _G.NODHeal or {}
NODHeal.defaults = defaults

_G.NODHeal = NODHeal
