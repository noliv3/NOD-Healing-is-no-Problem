local M = {}
NODHeal = NODHeal or {}
NODHeal.Core = NODHeal.Core or {}
NODHeal.Core.CooldownClassifier = M

local CreateFrame = CreateFrame
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetTime = GetTime
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitGUID = UnitGUID
local math = math
local pairs = pairs
local type = type
local tremove = table.remove
local math_min = math and math.min
local math_max = math and math.max
local math_floor = math and math.floor
local pcall = pcall

local SEED = {
    DEF = {
        [871] = true,
        [12975] = true,
        [118038] = true,
        [48792] = true,
        [22812] = true,
        [61336] = true,
        [115203] = true,
    },
    EXTERNAL = {
        [33206] = true,
        [47788] = true,
        [6940] = true,
        [116849] = true,
    },
    SELF = {
        [22842] = true,
        [85673] = true,
    },
    ABSORB = {
        [17] = true,
        [114908] = true,
    },
}

local pending = {}
local lastMinute, learnedCount = 0, 0

local MITIGATION_PCT = {
    DEF = 0.4,
    EXTERNAL = 0.3,
    SELF = 0.15,
}

local function clamp01(value)
    if type(value) ~= "number" then
        return 0
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function safeMin(a, b)
    if math_min then
        return math_min(a, b)
    end
    if a <= b then
        return a
    end
    return b
end

local function ensureSV()
    _G.NODHealDB = _G.NODHealDB or {}
    local DB = _G.NODHealDB
    DB.learned = DB.learned or {}
    DB.learned.cds = DB.learned.cds or {}
    DB.learned.block = DB.learned.block or {}

    NODHeal.Learned = NODHeal.Learned or {}
    NODHeal.Learned.cds = DB.learned.cds
    NODHeal.Learned.block = DB.learned.block

    return DB.learned.cds, DB.learned.block
end

local function getConfig()
    return NODHeal.Config or {}
end

local function getMajorConfig()
    local cfg = getConfig()
    local major = cfg.major
    if type(major) ~= "table" then
        return {}
    end
    return major
end

local function getHealsConfig()
    local cfg = getConfig()
    local heals = cfg.heals
    if type(heals) ~= "table" then
        return {}
    end
    return heals
end

local damageModule
local incomingAggregator

local function ensureDamageModule()
    if damageModule ~= nil then
        return damageModule
    end
    if NODHeal.GetModule then
        damageModule = NODHeal:GetModule("DamagePrediction")
    end
    if not damageModule and NODHeal.Core then
        damageModule = NODHeal.Core.DamagePrediction
    end
    return damageModule
end

local function ensureIncomingAggregator()
    if incomingAggregator ~= nil then
        return incomingAggregator
    end
    if NODHeal.GetModule then
        incomingAggregator = NODHeal:GetModule("IncomingHealAggregator")
    end
    if not incomingAggregator and NODHeal.Core then
        incomingAggregator = NODHeal.Core.Incoming
    end
    return incomingAggregator
end

local function getMajorWindow()
    local major = getMajorConfig()
    local window = major.window or 6
    if type(window) ~= "number" then
        window = 6
    end
    if window <= 0 then
        window = 6
    end
    return window
end

local function computeExpectedDamage(unit, window)
    if not unit then
        return 0
    end

    local horizon = window or getMajorWindow()
    if type(horizon) ~= "number" or horizon <= 0 then
        return 0
    end

    local predictor = ensureDamageModule()
    if predictor then
        local targetTime = GetTime and (GetTime() + horizon)
        if predictor.Estimate then
            local estimate = predictor.Estimate(unit, targetTime)
            if type(estimate) == "table" then
                local amount = estimate.amount or 0
                if (not amount or amount <= 0) and estimate.rate and estimate.rate > 0 then
                    amount = estimate.rate * horizon
                end
                if amount and amount > 0 then
                    return amount
                end
            end
        end
        if predictor.PredictDamage then
            local amount = predictor.PredictDamage(unit, targetTime)
            if amount and amount > 0 then
                return amount
            end
        end
    end

    return 0
end

local function computeSelfProjected(unit, casterGUID, window)
    if not unit or not casterGUID then
        return 0
    end

    local horizon = window or getMajorWindow()
    if type(horizon) ~= "number" or horizon <= 0 then
        return 0
    end

    local aggregator = ensureIncomingAggregator()
    if not aggregator then
        return 0
    end

    local total = 0
    if aggregator.Iterate then
        aggregator.Iterate(unit, horizon, function(entry)
            if entry and entry.sourceGUID == casterGUID then
                total = total + (entry.amount or 0)
            end
        end)
    end
    if aggregator.IterateScheduled then
        aggregator.IterateScheduled(unit, horizon, function(entry)
            if entry and entry.sourceGUID == casterGUID then
                total = total + (entry.amount or 0)
            end
        end)
    end

    return total
end

local function getAbsorbAmount(unit)
    if not UnitGetTotalAbsorbs or not unit then
        return 0
    end
    local ok, value = pcall(UnitGetTotalAbsorbs, unit)
    if not ok then
        return 0
    end
    if type(value) ~= "number" then
        return 0
    end
    if value < 0 then
        value = 0
    end
    return value
end

local function normalizeId(spellId)
    if type(spellId) == "number" then
        if spellId > 0 then
            return spellId
        end
        return nil
    end
    if type(spellId) == "string" then
        local asNumber = tonumber(spellId)
        if asNumber and asNumber > 0 then
            return asNumber
        end
    end
    return nil
end

local function hasStringMatch(block, spellId)
    if not block or not spellId then
        return false
    end
    local key = tostring(spellId)
    if key and block[key] == true then
        return true
    end
    return false
end

local function learnConfig()
    local cfg = NODHeal.Config and NODHeal.Config.learn
    return cfg or {}
end

local function learnCap()
    local cfg = learnConfig()
    if cfg.enabled == false then
        return 0
    end
    return cfg.maxPerMinute or 5
end

local function resetWindow()
    local nowMinute = math.floor(GetTime() / 60)
    if nowMinute ~= lastMinute then
        lastMinute = nowMinute
        learnedCount = 0
    end
end

local function classFor(spellId)
    for cat, spells in pairs(SEED) do
        if spells[spellId] then
            return cat
        end
    end
    local cds = ensureSV()
    local entry = cds[spellId]
    if type(entry) == "table" and entry.class and entry.class ~= "UNKNOWN" then
        return entry.class
    end
    return nil
end

local function drainQueue()
    local cds = ensureSV()
    local cfgCap = learnCap()
    if cfgCap <= 0 then
        pending = {}
        return
    end
    resetWindow()
    while learnedCount < cfgCap and #pending > 0 do
        learnedCount = learnedCount + 1
        local item = tremove(pending, 1)
        local spellId = item.spellId
        local cls = item.class
        local entry = cds[spellId]
        if type(entry) ~= "table" then
            entry = { class = cls or "UNKNOWN", lastSeen = GetTime() }
            cds[spellId] = entry
        else
            if cls and cls ~= "UNKNOWN" then
                entry.class = cls
            end
            entry.lastSeen = GetTime()
        end
    end
end

local function queueLearn(spellId, cls)
    if learnCap() <= 0 then
        return
    end
    pending[#pending + 1] = { spellId = spellId, class = cls }
    drainQueue()
end

local function isBlocked(spellId)
    if not spellId then
        return false
    end
    local _, block = ensureSV()
    if type(block) ~= "table" then
        return false
    end
    local normalized = normalizeId(spellId)
    if normalized and block[normalized] == true then
        return true
    end
    if block[spellId] == true then
        return true
    end
    if normalized and hasStringMatch(block, normalized) then
        return true
    end
    if hasStringMatch(block, spellId) then
        return true
    end
    return false
end

local function countSeeds()
    local total = 0
    for _, spells in pairs(SEED) do
        for _ in pairs(spells) do
            total = total + 1
        end
    end
    return total
end

local function gatherBlocked()
    local _, block = ensureSV()
    local seen = {}
    local unique = 0
    if type(block) ~= "table" then
        return unique, seen
    end
    for key, value in pairs(block) do
        if value then
            local normalized = normalizeId(key)
            if normalized then
                seen[normalized] = true
            end
            local asString = tostring(key)
            if asString then
                local numeric = tonumber(asString)
                if numeric and numeric > 0 then
                    seen[numeric] = true
                end
            end
        end
    end
    for _ in pairs(seen) do
        unique = unique + 1
    end
    return unique, seen
end

local function countLearned()
    local cds = ensureSV()
    local total = 0
    if type(cds) ~= "table" then
        return total
    end
    for _, entry in pairs(cds) do
        if entry ~= nil then
            total = total + 1
        end
    end
    return total
end

function M.EstimateMitigation(unit, auraEntry, context)
    if type(auraEntry) ~= "table" then
        return 0
    end

    local class = auraEntry.class
    if not class then
        return 0
    end

    local window = context and context.window
    if type(window) ~= "number" or window <= 0 then
        window = getMajorWindow()
    end

    local estimate = 0
    if class == "ABSORB" then
        estimate = getAbsorbAmount(unit)
    elseif class == "SELF" then
        local casterGUID
        if auraEntry.caster and UnitGUID then
            casterGUID = UnitGUID(auraEntry.caster)
        end
        if not casterGUID and unit and UnitGUID then
            casterGUID = UnitGUID(unit)
        end
        if casterGUID then
            local projected = computeSelfProjected(unit, casterGUID, window)
            if projected > 0 then
                local expected = computeExpectedDamage(unit, window)
                if expected > 0 then
                    estimate = safeMin(projected, expected)
                end
            end
        end
    else
        local expected = computeExpectedDamage(unit, window)
        if expected > 0 then
            local pct = MITIGATION_PCT[class] or 0
            estimate = clamp01(pct) * expected
        end
    end

    if estimate and estimate < 0 then
        estimate = 0
    end
    if math_floor then
        estimate = math_floor((estimate or 0) + 0.5)
    end
    return estimate or 0
end

function M.IsBlocked(spellId)
    return isBlocked(spellId)
end

function M.DebugSnapshot()
    local seeds = countSeeds()
    local learned = countLearned()
    local blocked, blockedSet = gatherBlocked()
    return {
        seeds = seeds,
        learned = learned,
        blocked = blocked,
        blockedSet = blockedSet,
    }
end

function M.Classify(spellId)
    if not spellId or isBlocked(spellId) then
        return nil, 0
    end
    local cls = classFor(spellId)
    if not cls then
        return nil, 0
    end
    if cls == "UNKNOWN" then
        return nil, 0
    end
    local base = 0.6
    if SEED[cls] and SEED[cls][spellId] then
        base = 1.0
    end
    local cds = ensureSV()
    local entry = cds[spellId]
    if type(entry) == "table" and entry.lastSeen then
        local days = (GetTime() - entry.lastSeen) / 86400
        local cfg = learnConfig()
        local soft = cfg.agingSoftDays or 30
        local hard = cfg.agingHardDays or 90
        if days > hard then
            return nil, 0
        elseif days > soft then
            base = base * 0.5
        end
    end
    return cls, base
end

local function handleCombatLog()
    drainQueue()
    local _, subEvent, _, _, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()
    if subEvent ~= "SPELL_AURA_APPLIED" and subEvent ~= "SPELL_AURA_REFRESH" and subEvent ~= "SPELL_AURA_REMOVED" then
        return
    end
    if type(spellId) ~= "number" or spellId <= 0 then
        return
    end
    local cls = classFor(spellId) or "UNKNOWN"
    queueLearn(spellId, cls)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        drainQueue()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        handleCombatLog()
    end
end)

return M
