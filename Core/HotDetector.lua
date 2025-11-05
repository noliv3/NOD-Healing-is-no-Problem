local CreateFrame = CreateFrame
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetTime = GetTime
local UnitClass = UnitClass
local pairs = pairs
local type = type

local namespace = _G.NODHeal or {}
_G.NODHeal = namespace
namespace.Core = namespace.Core or {}

local function ensureLearned()
    namespace.Learned = namespace.Learned or {}
    local learned = namespace.Learned
    learned.hots = learned.hots or {}
    return learned.hots
end

local function getSeedWhitelist()
    local config = namespace.Config
    if type(config) ~= "table" then
        return nil
    end
    local icons = config.icons
    if type(icons) ~= "table" then
        return nil
    end
    local list = icons.hotWhitelist
    if type(list) ~= "table" then
        return nil
    end
    return list
end

local M = {}

local function markLearned(spellId, spellName)
    if not spellId then
        return
    end

    local learned = ensureLearned()
    local entry = learned[spellId]
    local now = GetTime and GetTime() or 0

    if type(entry) ~= "table" then
        entry = {}
        learned[spellId] = entry
    end

    local wasLearned = entry.learned and true or false

    entry.learned = true
    entry.lastSeen = now
    entry.spellName = spellName or entry.spellName

    if UnitClass then
        local _, classTag = UnitClass("player")
        if classTag then
            entry.class = classTag
        end
    end

    if namespace.Log and not wasLearned then
        namespace:Log(("learned HoT: %s (%d)"):format(spellName or "?", spellId))
    end
end

function M.IsHot(spellId)
    if not spellId then
        return false
    end

    local learned = namespace.Learned and namespace.Learned.hots
    if type(learned) == "table" then
        local data = learned[spellId]
        if type(data) == "table" and data.learned then
            return true
        end
        if data == true then
            return true
        end
    end

    local seed = getSeedWhitelist()
    if seed and seed[spellId] then
        return true
    end

    return false
end

function M.Touch(spellId, spellName)
    markLearned(spellId, spellName)
end

function M.CheckTooltipFallback()
    return false
end

local eventFrame
if type(CreateFrame) == "function" then
    eventFrame = CreateFrame("Frame")
end

if eventFrame and type(eventFrame.RegisterEvent) == "function" then
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", function()
        if type(CombatLogGetCurrentEventInfo) ~= "function" then
            return
        end

        local _, subEvent,
            _, _, _, _,
            _, _, _, _,
            spellId, spellName = CombatLogGetCurrentEventInfo()

        if subEvent == "SPELL_PERIODIC_HEAL" and spellId then
            markLearned(spellId, spellName)
        end
    end)
end

namespace.Core.HotDetector = M
_G.NODHeal_HotDetector = M

return namespace:RegisterModule("HotDetector", M)
