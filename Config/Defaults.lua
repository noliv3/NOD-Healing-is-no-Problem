local addonName = ...

local pairs = pairs
local type = type

local function cloneTable(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = cloneTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local NODHeal = _G.NODHeal or {}
_G.NODHeal = NODHeal

local PROFILE_DEFAULTS = {
    updateInterval = 0.1,
    throttle = 0.2,
}

local ICON_DEFAULTS = {
    enabled = true,
    size = 14,
    spacing = 1,
    rowSpacing = 1,
    hotEnabled = true,
    debuffEnabled = true,
    hotMax = 12,
    hotPerRow = 6,
    hotDirection = "RTL",
    hotWhitelist = {
        [774] = true,
        [33763] = true,
        [139] = true,
        [61295] = true,
        [115175] = true,
        [53563] = true,
    },
    debuffPrio = { Magic = 4, Curse = 3, Disease = 2, Poison = 1, [""] = 0 },
}

local LEARN_CONFIG_DEFAULTS = {
    enabled = true,
    maxPerMinute = 5,
    agingSoftDays = 30,
    agingHardDays = 90,
}

local MAJOR_DEFAULTS = {
    enabled = true,
    iconSize = 18,
    maxTotal = 4,
    capDEF = 2,
    capEXT = 1,
    capSELF = 1,
    capABSORB = 1,
    anchor = "TOPLEFT",
    offsetX = 2,
    offsetY = -2,
}

local LEARNED_DEFAULTS = {
    -- learned.hots = { [spellId] = { learned = true, class = "PRIEST", lastSeen = timestamp } }
    hots = {},
    cds = {},
    block = {},
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
    icons = ICON_DEFAULTS,
    learn = LEARN_CONFIG_DEFAULTS,
    major = MAJOR_DEFAULTS,
}

local function mergeDefaults(target, defaults)
    target = target or {}
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = cloneTable(value)
            else
                target[key] = value
            end
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

    local function ensureSubtable(key, defaultsTable)
        config[key] = config[key] or {}
        store.config[key] = store.config[key] or {}
        local runtime = config[key]
        local saved = store.config[key]

        for subKey, defaultValue in pairs(defaultsTable) do
            local stored = saved[subKey]
            if stored == nil then
                if runtime[subKey] ~= nil then
                    stored = runtime[subKey]
                elseif type(defaultValue) == "table" then
                    stored = cloneTable(defaultValue)
                else
                    stored = defaultValue
                end
                if type(stored) == "table" then
                    saved[subKey] = cloneTable(stored)
                else
                    saved[subKey] = stored
                end
            end

            if type(defaultValue) == "table" then
                if type(saved[subKey]) ~= "table" then
                    saved[subKey] = {}
                end
                runtime[subKey] = saved[subKey]
            else
                runtime[subKey] = saved[subKey]
            end
        end

        return runtime
    end

    local icons = ensureSubtable("icons", ICON_DEFAULTS)
    config.icons = icons

    local learnCfg = ensureSubtable("learn", LEARN_CONFIG_DEFAULTS)
    config.learn = learnCfg

    local majorCfg = ensureSubtable("major", MAJOR_DEFAULTS)
    config.major = majorCfg

    if type(config.logThrottle) == "number" and config.logThrottle < 0 then
        config.logThrottle = 0
    end

    NODHeal.Config = config
    return config
end

local function ensureLearned(store)
    store.learned = store.learned or {}
    local learnedStore = store.learned

    for key, defaultValue in pairs(LEARNED_DEFAULTS) do
        local saved = learnedStore[key]
        if saved == nil then
            if type(defaultValue) == "table" then
                learnedStore[key] = cloneTable(defaultValue)
            else
                learnedStore[key] = defaultValue
            end
        elseif type(defaultValue) == "table" and type(saved) ~= "table" then
            learnedStore[key] = cloneTable(defaultValue)
        end
    end

    NODHeal.Learned = NODHeal.Learned or {}
    NODHeal.Learned.hots = learnedStore.hots
    NODHeal.Learned.cds = learnedStore.cds
    NODHeal.Learned.block = learnedStore.block

    return NODHeal.Learned
end

local function ensureSavedVariables()
    local saved = _G.NODHealDB
    if type(saved) ~= "table" then
        saved = {}
        _G.NODHealDB = saved
    end

    local profile = ensureProfile(saved)
    local config = ensureConfig(saved)
    local learned = ensureLearned(saved)
    return profile, config, learned
end

NODHeal.ConfigDefaults = CONFIG_DEFAULTS
NODHeal.ApplyConfigDefaults = ensureSavedVariables
