local M = {}
NODHeal = NODHeal or {}
NODHeal.Core = NODHeal.Core or {}
NODHeal.Core.HotDetector = M

local math = math
local GetTime = GetTime
local UnitClass = UnitClass
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local CreateFrame = CreateFrame
local pairs = pairs
local type = type
local tostring = tostring
local tremove = table.remove

-- small class seeds
local CLASS_SEED = {
    DRUID = { [774] = true, [33763] = true, [48438] = true },
    PRIEST = { [139] = true, [33076] = true },
    SHAMAN = { [61295] = true },
    MONK = { [115175] = true, [119611] = true },
    PALADIN = { [53563] = true },
}

local runtimeHots
local runtimeBlock
local pending = {}
local lastMinute, learnedCount = 0, 0

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

local function ensureSV()
    _G.NODHealDB = _G.NODHealDB or {}
    local DB = _G.NODHealDB
    DB.learned = DB.learned or {}
    DB.learned.hots = DB.learned.hots or {}
    DB.learned.block = DB.learned.block or {}

    NODHeal.Learned = NODHeal.Learned or {}
    NODHeal.Learned.hots = DB.learned.hots
    NODHeal.Learned.block = DB.learned.block
    runtimeHots = DB.learned.hots
    runtimeBlock = DB.learned.block

    return runtimeHots
end

local function migrate()
    local hots = ensureSV()
    for key, value in pairs(hots) do
        if type(key) == "number" and key < 0 then
            hots[key] = nil
        elseif type(value) == "table" and value.spellName and not value.learned then
            value.learned = true
        end
    end
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

local function isBlocked(spellId)
    if not spellId then
        return false
    end
    ensureSV()
    local block = runtimeBlock
    if type(block) ~= "table" then
        return false
    end
    local normalized = normalizeId(spellId)
    if normalized and block[normalized] then
        return true
    end
    if block[spellId] then
        return true
    end
    if normalized then
        local numericAsString = tostring(normalized)
        if numericAsString and block[numericAsString] then
            return true
        end
    end
    local asString = tostring(spellId)
    if asString and block[asString] then
        return true
    end
    return false
end

local function resetWindow()
    local nowMinute = math.floor(GetTime() / 60)
    if nowMinute ~= lastMinute then
        lastMinute = nowMinute
        learnedCount = 0
    end
end

local function drainQueue()
    local hots = ensureSV()
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
        local amount = item.amount
        local timestamp = item.timestamp
        local entry = hots[spellId]
        if entry == true then
            entry = { learned = true, avg_tick = amount or 0, seen = 1, lastSeen = GetTime(), lastTimestamp = timestamp }
            hots[spellId] = entry
        elseif type(entry) == "table" then
            local seen = (entry.seen or 0) + 1
            entry.seen = seen
            if amount and amount > 0 then
                local old = entry.avg_tick or 0
                entry.avg_tick = ((old * (seen - 1)) + amount) / seen
            end
            if entry.lastTimestamp and timestamp and timestamp > entry.lastTimestamp then
                local period = timestamp - entry.lastTimestamp
                if period > 0 then
                    local avg = entry.period or period
                    entry.period = ((avg * (seen - 1)) + period) / seen
                end
            end
            entry.lastTimestamp = timestamp
            entry.lastSeen = GetTime()
        else
            hots[spellId] = {
                learned = true,
                avg_tick = amount or 0,
                seen = 1,
                lastSeen = GetTime(),
                lastTimestamp = timestamp,
            }
        end
    end
end

local function queueLearn(spellId, amount, timestamp)
    if learnCap() <= 0 then
        return
    end
    pending[#pending + 1] = { spellId = spellId, amount = amount, timestamp = timestamp }
    drainQueue()
end

local function confidenceFor(spellId, source)
    local base = 0.3
    if source == "LEARNED" then
        base = 1.0
    elseif source == "SEED" then
        base = 0.7
    elseif source == "WL" then
        base = 0.6
    end
    local hots = ensureSV()
    local entry = hots[spellId]
    local lastSeen = (type(entry) == "table" and entry.lastSeen) or 0
    if lastSeen > 0 then
        local days = (GetTime() - lastSeen) / 86400
        local cfg = learnConfig()
        local soft = cfg.agingSoftDays or 30
        local hard = cfg.agingHardDays or 90
        if days > hard then
            return 0
        elseif days > soft then
            base = base * 0.5
        end
    end
    return base
end

local function countSeedSpells()
    local total = 0
    for _, spells in pairs(CLASS_SEED) do
        for _ in pairs(spells) do
            total = total + 1
        end
    end
    return total
end

local function gatherBlocked()
    ensureSV()
    local block = runtimeBlock
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
    ensureSV()
    local hots = runtimeHots
    local total = 0
    if type(hots) ~= "table" then
        return total
    end
    for _, entry in pairs(hots) do
        if entry ~= nil then
            total = total + 1
        end
    end
    return total
end

function M.IsHot(spellId)
    if not spellId then
        return false
    end
    if isBlocked(spellId) then
        return false
    end
    local hots = ensureSV()
    if hots[spellId] then
        return true
    end
    if UnitClass then
        local _, class = UnitClass("player")
        local seed = CLASS_SEED[class or ""]
        if seed and seed[spellId] then
            return true
        end
    end
    local wl = (NODHeal.Config and NODHeal.Config.icons and NODHeal.Config.icons.hotWhitelist) or {}
    return wl[spellId] or false
end

function M.GetConfidence(spellId)
    local hots = ensureSV()
    if hots[spellId] then
        return confidenceFor(spellId, "LEARNED")
    end
    local wl = (NODHeal.Config and NODHeal.Config.icons and NODHeal.Config.icons.hotWhitelist) or {}
    if wl[spellId] then
        return confidenceFor(spellId, "WL")
    end
    if UnitClass then
        local _, class = UnitClass("player")
        local seed = CLASS_SEED[class or ""]
        if seed and seed[spellId] then
            return confidenceFor(spellId, "SEED")
        end
    end
    return 0.3
end

function M.DebugSnapshot()
    local seeds = countSeedSpells()
    local learned = countLearned()
    local blocked, blockedSet = gatherBlocked()
    return {
        seeds = seeds,
        learned = learned,
        blocked = blocked,
        blockedSet = blockedSet,
    }
end

function M.EstimateHotValue(spellId, remain, stacks)
    local hots = ensureSV()
    local entry = hots[spellId]
    if type(entry) ~= "table" then
        return 0
    end
    local avg = entry.avg_tick or 0
    if avg <= 0 then
        return 0
    end
    local ticks = 1
    if entry.period and entry.period > 0 and remain and remain > 0 then
        ticks = math.max(1, math.ceil(remain / entry.period))
    elseif remain and remain > 0 then
        ticks = math.max(1, math.floor(remain / 3))
    end
    if stacks and stacks > 1 then
        ticks = ticks * stacks
    end
    return avg * ticks
end

local function handleCombatLog()
    drainQueue()
    local timestamp, subEvent, _, _, _, _, _, _, _, _, _, spellId, _, _, amount = CombatLogGetCurrentEventInfo()
    if subEvent ~= "SPELL_PERIODIC_HEAL" then
        return
    end
    if type(spellId) ~= "number" or spellId <= 0 then
        return
    end
    queueLearn(spellId, amount, timestamp)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        migrate()
        drainQueue()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        handleCombatLog()
    end
end)

return M
