local addonName = ...

local pairs = pairs
local type = type

local NODHeal = _G.NODHeal or {}
_G.NODHeal = NODHeal

local PROFILE_DEFAULTS = {
    updateInterval = 0.1,
    throttle = 0.2,
}

local CONFIG_DEFAULTS = {
    debug = false,
    logThrottle = 0.25,
    overlay = true,
    scale = 1,
    columns = 5,
    spacing = 4,
    bgAlpha = 0.7,
    sortMode = "group",
    showIncoming = true,
    showOverheal = true,
    lockGrid = false,
}

local function mergeDefaults(target, defaults)
    target = target or {}
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
    return target
end

local function ensureProfile(store)
    store.profile = store.profile or {}
    local profile = mergeDefaults(store.profile, PROFILE_DEFAULTS)
    NODHeal.defaults = profile
    return profile
end

local function ensureConfig(store)
    store.config = store.config or {}

    local config = NODHeal.Config or {}
    config = mergeDefaults(config, CONFIG_DEFAULTS)

    for key, defaultValue in pairs(CONFIG_DEFAULTS) do
        local stored = store.config[key]
        if stored == nil then
            stored = config[key] ~= nil and config[key] or defaultValue
            store.config[key] = stored
        end
        config[key] = stored
    end

    if type(config.logThrottle) == "number" and config.logThrottle < 0 then
        config.logThrottle = 0
    end

    NODHeal.Config = config
    return config
end

local function ensureSavedVariables()
    local saved = _G.NODHealDB
    if type(saved) ~= "table" then
        saved = {}
        _G.NODHealDB = saved
    end

    local profile = ensureProfile(saved)
    local config = ensureConfig(saved)
    return profile, config
end

NODHeal.ConfigDefaults = CONFIG_DEFAULTS
NODHeal.ApplyConfigDefaults = ensureSavedVariables
