local M = {}
NODHeal = NODHeal or {}
NODHeal.Grid = M
NODHeal.UI = NODHeal.UI or {}
NODHeal.UI.Grid = M

local HotDetector = NODHeal and NODHeal.Core and NODHeal.Core.HotDetector
local CooldownClassifier = NODHeal and NODHeal.Core and NODHeal.Core.CooldownClassifier
local DeathAuthority = NODHeal and NODHeal.Core and NODHeal.Core.DeathAuthority

local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitName = UnitName
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitInRaid = UnitInRaid
local UnitInParty = UnitInParty
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitGetIncomingHeals = UnitGetIncomingHeals
local UnitHasIncomingResurrection = UnitHasIncomingResurrection
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local GetNumGroupMembers = GetNumGroupMembers
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitIsUnit = UnitIsUnit
local GetTime = GetTime
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local C_Timer = C_Timer
local math = math
local ipairs = ipairs
local pairs = pairs
local type = type
local UnitAura = UnitAura
local UnitDebuff = UnitDebuff
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local tinsert = table.insert

local unitFrames = {}
local trackedFrames = {}

local solverModule
local landingModule
local desyncModule

local function getSolverModule()
    if solverModule and solverModule.CalculateProjectedHealth then
        return solverModule
    end

    local core = NODHeal and NODHeal.Core
    if core and core.PredictiveSolver and core.PredictiveSolver.CalculateProjectedHealth then
        solverModule = core.PredictiveSolver
        return solverModule
    end

    local ns = NODHeal
    if ns and ns.GetModule then
        local module = ns:GetModule("PredictiveSolver")
        if module and module.CalculateProjectedHealth then
            solverModule = module
            if core then
                core.PredictiveSolver = module
            end
            return solverModule
        end
    end

    return nil
end

local function getLandingModule()
    if landingModule and landingModule.ComputeLandingTime then
        return landingModule
    end

    local core = NODHeal and NODHeal.Core
    if core and core.CastLandingTime and core.CastLandingTime.ComputeLandingTime then
        landingModule = core.CastLandingTime
        return landingModule
    end

    local ns = NODHeal
    if ns and ns.GetModule then
        local module = ns:GetModule("CastLandingTime")
        if module and module.ComputeLandingTime then
            landingModule = module
            if core then
                core.CastLandingTime = module
            end
            return landingModule
        end
    end

    return nil
end

local function getDesyncModule()
    if desyncModule and desyncModule.IsFrozen then
        return desyncModule
    end

    local core = NODHeal and NODHeal.Core
    if core and core.DesyncGuard and core.DesyncGuard.IsFrozen then
        desyncModule = core.DesyncGuard
        return desyncModule
    end

    local ns = NODHeal
    if ns and ns.GetModule then
        local module = ns:GetModule("DesyncGuard")
        if module and module.IsFrozen then
            desyncModule = module
            if core then
                core.DesyncGuard = module
            end
            return desyncModule
        end
    end

    return nil
end

local function computeLandingForUnit(unit)
    if not UnitExists or not unit or not UnitExists(unit) then
        return nil, nil
    end

    local module = getLandingModule()
    if not module or not module.ComputeLandingTime then
        return nil, nil
    end

    local startMS, endMS, spellID

    if UnitCastingInfo then
        local name, _, _, castStart, castEnd, _, castID, _, castSpellID = UnitCastingInfo(unit)
        if name and castStart and castEnd and castEnd > castStart then
            startMS = castStart
            endMS = castEnd
            spellID = castSpellID or castID or spellID
        end
    end

    if (not startMS or not endMS) and UnitChannelInfo then
        local name, _, _, chanStart, chanEnd, _, _, channelSpellID = UnitChannelInfo(unit)
        if name and chanStart and chanEnd and chanEnd > chanStart then
            startMS = chanStart
            endMS = chanEnd
            spellID = channelSpellID or spellID
        end
    end

    if not startMS or not endMS or endMS <= startMS then
        return nil, nil
    end

    local castSeconds = (endMS - startMS) / 1000
    if castSeconds < 0 then
        return nil, nil
    end

    local landing = module.ComputeLandingTime(spellID, castSeconds, startMS)
    if not landing then
        return nil, nil
    end

    return landing, spellID
end

local function getDeathModule()
    if DeathAuthority and DeathAuthority.GetState then
        return DeathAuthority
    end
    local ns = NODHeal
    if ns and ns.GetModule then
        DeathAuthority = ns:GetModule("DeathAuthority")
        if DeathAuthority and DeathAuthority.GetState then
            return DeathAuthority
        end
    end
    if ns and ns.Core and ns.Core.DeathAuthority then
        DeathAuthority = ns.Core.DeathAuthority
    end
    return DeathAuthority
end

local STATE_ICON_TEXTURES = {
    DEAD = "Interface\\RaidFrame\\Raid-Icon-Skull",
    GHOST = "Interface\\RaidFrame\\Raid-Icon-Skull",
    FEIGN = "Interface\\Icons\\Ability_Rogue_FeignDeath",
}

local STATE_ICON_COLORS = {
    DEAD = { 0.75, 0.75, 0.75 },
    GHOST = { 0.6, 0.8, 1.0 },
    FEIGN = { 1.0, 0.85, 0.5 },
}

local STATE_LABELS = {
    DEAD = "DEAD",
    GHOST = "GHOST",
    FEIGN = "FEIGN",
    DYING = "DYING",
    UNKNOWN = "OFFLINE",
}

local function applyStateDecor(frame, state, healable)
    if not frame then
        return
    end
    frame._nod_state = state

    if frame.stateIcon then
        local texture = STATE_ICON_TEXTURES[state]
        if texture then
            frame.stateIcon:SetTexture(texture)
            local tint = STATE_ICON_COLORS[state]
            if tint then
                frame.stateIcon:SetVertexColor(tint[1], tint[2], tint[3])
            else
                frame.stateIcon:SetVertexColor(1, 1, 1)
            end
            frame.stateIcon:Show()
        else
            frame.stateIcon:Hide()
        end
    end

    if frame.stateText then
        local label = STATE_LABELS[state]
        if label then
            frame.stateText:SetText(label)
            if state == "DEAD" then
                frame.stateText:SetTextColor(0.7, 0.7, 0.7)
            elseif state == "GHOST" then
                frame.stateText:SetTextColor(0.6, 0.8, 1.0)
            elseif state == "FEIGN" then
                frame.stateText:SetTextColor(1.0, 0.85, 0.5)
            elseif state == "DYING" then
                frame.stateText:SetTextColor(1.0, 0.45, 0.45)
            elseif state == "UNKNOWN" then
                frame.stateText:SetTextColor(0.7, 0.7, 0.7)
            else
                frame.stateText:SetTextColor(0.9, 0.9, 0.9)
            end
            frame.stateText:Show()
        else
            frame.stateText:SetText("")
            frame.stateText:Hide()
        end
    end

    if frame.hotCont then
        frame.hotCont:SetAlpha(healable and 1 or 0.25)
    end
    if frame.debuffIcon then
        frame.debuffIcon:SetAlpha(healable and 1 or 0.3)
    end

    if frame.name then
        if state == "DEAD" then
            frame.name:SetTextColor(0.7, 0.7, 0.7)
        elseif state == "GHOST" then
            frame.name:SetTextColor(0.6, 0.8, 1.0)
        elseif state == "FEIGN" then
            frame.name:SetTextColor(1.0, 0.85, 0.5)
        elseif state == "DYING" then
            frame.name:SetTextColor(1.0, 0.5, 0.5)
        elseif state == "UNKNOWN" then
            frame.name:SetTextColor(0.7, 0.7, 0.7)
        else
            frame.name:SetTextColor(1, 1, 1)
        end
    end

    if frame.resIcon then
        local showRes = false
        if UnitHasIncomingResurrection and (state == "DEAD" or state == "GHOST") and frame.unit then
            showRes = UnitHasIncomingResurrection(frame.unit) and true or false
        end
        if showRes then
            frame.resIcon:Show()
        else
            frame.resIcon:Hide()
        end
    end
end

-- Determine the anchor frame and offsets for the unit tooltip.
local function getTooltipAnchor()
    local ui = NODHeal and NODHeal.UI
    local status = ui and ui.StatusFrame
    if status and status:IsShown() then
        return status, "TOPRIGHT", "TOPRIGHT", 0, 6
    end
    return UIParent, "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 96
end

local CATEGORY_COLORS = {
    DEF = { 0.2, 0.6, 1.0 },
    EXTERNAL = { 1.0, 0.8, 0.2 },
    SELF = { 0.3, 1.0, 0.3 },
    ABSORB = { 0.9, 0.3, 0.9 },
}

local function getHotConfidence(spellId)
    if HotDetector and HotDetector.GetConfidence then
        return HotDetector.GetConfidence(spellId)
    end
    return 0.3
end

local function estimateHotValue(spellId, remain, stacks)
    if HotDetector and HotDetector.EstimateHotValue then
        return HotDetector.EstimateHotValue(spellId, remain, stacks)
    end
    return 0
end
local cfg

local function getConfig()
    NODHeal.Config = NODHeal.Config or {}
    cfg = NODHeal.Config
    return cfg
end
local function safeGet(tbl, k, def)
    if type(tbl) == "table" and tbl[k] ~= nil then
        return tbl[k]
    end
    return def
end
local container
local feedbackEntries = {}

local function isHotSpell(spellId)
    if HotDetector and HotDetector.IsHot then
        return HotDetector.IsHot(spellId)
    end
    -- Fallback auf Config-Whitelist, falls Modul nicht geladen
    local wl = (NODHeal.Config and NODHeal.Config.icons and NODHeal.Config.icons.hotWhitelist) or {}
    return wl[spellId] or false
end

local FRAME_WIDTH = 90
local FRAME_HEIGHT = 35
local COLUMNS = 5
local SPACING = 4
local PADDING = 8

local function getDebuffPriority(list, name, spellId)
    if type(list) ~= "table" then
        return 0
    end

    local candidates = {
        spellId,
        tostring(spellId),
        name,
    }

    for _, key in ipairs(candidates) do
        if key ~= nil then
            local weight = list[key]
            if weight ~= nil then
                if type(weight) == "number" then
                    return weight
                end
                if weight == true then
                    return 1
                end
            end
        end
    end

    for _, value in pairs(list) do
        if value == spellId or value == name then
            return 1
        end
    end

    return 0
end

local function scoreHot(entry)
    local confidence = entry.confidence or 0.3
    local expected = entry.expected or 0
    local selfBonus = entry.own and 0.15 or 0
    local stackBonus = math.min(entry.stacks or 0, 3) * 0.05
    return (expected * confidence) + selfBonus + stackBonus
end

local function collectHotAuras(unit)
    local iconsCfg = (cfg and cfg.icons) or {}
    local own, other = {}, {}
    local now = GetTime()
    for i = 1, 40 do
        local name, icon, count, _, duration, expirationTime, unitCaster, _, _, spellId = UnitAura(unit, i, "HELPFUL")
        if not name then
            break
        end
        if icon and isHotSpell(spellId) then
            local remain = (expirationTime or 0) - now
            local stacks = count or 0
            local confidence = getHotConfidence(spellId)
            if confidence > 0 then
                local expected = estimateHotValue(spellId, remain, stacks)
                local entry = {
                    icon = icon,
                    remain = remain,
                    spellId = spellId,
                    own = unitCaster and (UnitIsUnit(unitCaster, "player") or UnitIsUnit(unitCaster, "pet")),
                    stacks = stacks,
                    confidence = confidence,
                    expected = expected,
                    duration = duration or 0,
                    expiration = expirationTime or 0,
                }
                if entry.own then
                    tinsert(own, entry)
                else
                    tinsert(other, entry)
                end
            end
        end
    end
    table.sort(own, function(a, b)
        return scoreHot(a) > scoreHot(b)
    end)
    table.sort(other, function(a, b)
        return scoreHot(a) > scoreHot(b)
    end)
    local res = {}
    local maxN = safeGet(iconsCfg, "hotMax", 12)
    for _, e in ipairs(own) do
        if #res < maxN then
            tinsert(res, e)
        end
    end
    for _, e in ipairs(other) do
        if #res < maxN then
            tinsert(res, e)
        end
    end
    return res
end

local function layoutHotIcons(frame, list)
    if not frame.hotCont or not frame.hotTex then
        return
    end
    local iconsCfg = (cfg and cfg.icons) or {}
    local size = safeGet(iconsCfg, "size", 14)
    local perRow = math.max(1, math.min(safeGet(iconsCfg, "hotPerRow", 6), 12))
    local spacing = safeGet(iconsCfg, "spacing", 1)
    local rowGap = safeGet(iconsCfg, "rowSpacing", 1)
    local dir = safeGet(iconsCfg, "hotDirection", "RTL")

    for i = 1, 12 do
        local tex = frame.hotTex[i]
        if tex then
            tex:Hide()
        end
        local stack = frame.hotStacks and frame.hotStacks[i]
        if stack then
            stack:Hide()
        end
    end
    if not list or #list == 0 then
        frame.hotCont:SetSize(1, 1)
        return
    end

    local cols = math.min(#list, perRow)
    local rows = math.ceil(#list / perRow)

    for i, entry in ipairs(list) do
        local tex = frame.hotTex[i]
        if not tex then
            break
        end
        tex:SetTexture(entry.icon)
        tex:SetSize(size, size)

        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow

        tex:ClearAllPoints()
        if dir == "RTL" then
            tex:SetPoint("TOPRIGHT", frame.hotCont, "TOPRIGHT", -(col * (size + spacing)), -(row * (size + rowGap)))
        else
            tex:SetPoint("TOPLEFT", frame.hotCont, "TOPLEFT", col * (size + spacing), -(row * (size + rowGap)))
        end

        tex:SetAlpha(math.max(0.2, math.min(entry.confidence or 0.3, 1)))
        tex:Show()

        local stack = frame.hotStacks and frame.hotStacks[i]
        if stack then
            if entry.stacks and entry.stacks > 1 then
                stack:SetText(entry.stacks)
                stack:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", -1, 1)
                stack:SetAlpha(tex:GetAlpha())
                stack:Show()
            else
                stack:SetText("")
                stack:Hide()
            end
        end
    end

    local width = cols * size + (cols - 1) * spacing
    local height = rows * size + (rows - 1) * rowGap
    frame.hotCont:SetSize(width, height)
end

local function pickDebuffIcon(unit)
    if not unit then
        return nil
    end

    local iconsCfg = (cfg and cfg.icons) or {}
    local priorityList = iconsCfg.debuffPrio
    local bestTexture
    local bestPriority

    for index = 1, 40 do
        local name, iconTexture, _, dispelType, _, _, _, _, _, spellId = UnitDebuff(unit, index)
        if not name then
            break
        end

        local priority = getDebuffPriority(priorityList, name, spellId)
        if not bestPriority or priority > bestPriority or (priority == bestPriority and not bestTexture) then
            bestPriority = priority
            bestTexture = iconTexture
        end
    end

    return bestTexture
end

local function scoreMajor(entry)
    local base = 0.5
    if entry.class == "DEF" then
        base = 1.0
    elseif entry.class == "EXTERNAL" then
        base = 0.9
    elseif entry.class == "SELF" then
        base = 0.7
    elseif entry.class == "ABSORB" then
        base = 0.6
    end
    local mitigation = entry.estimated or 0
    local extBonus = entry.class == "EXTERNAL" and 0.2 or 0
    return (base + mitigation + extBonus) * (entry.confidence or 0.3)
end

local function collectMajorAuras(frame, unit)
    if not CooldownClassifier or not CooldownClassifier.Classify then
        return {}
    end
    local list = {}
    local now = GetTime()
    for i = 1, 40 do
        local name, icon, count, _, duration, expirationTime, caster, _, _, spellId = UnitAura(unit, i, "HELPFUL")
        if not name then
            break
        end
        local class, confidence = CooldownClassifier.Classify and CooldownClassifier.Classify(spellId)
        if class and confidence and confidence > 0 then
            local remain = (expirationTime or 0) - now
            if remain > 0 then
                list[#list + 1] = {
                    name = name,
                    spellId = spellId,
                    icon = icon,
                    class = class,
                    confidence = confidence,
                    remain = remain,
                    duration = duration or 0,
                    expiration = expirationTime or 0,
                    stacks = count or 0,
                    caster = caster,
                    estimated = 0,
                }
            end
        end
    end
    for _, entry in ipairs(list) do
        entry.score = scoreMajor(entry)
    end
    table.sort(list, function(a, b)
        return (a.score or 0) > (b.score or 0)
    end)
    return list
end

local function layoutMajorIcons(frame, list)
    if not frame.majorSlots then
        return
    end
    local majorCfg = (cfg and cfg.major) or {}
    if not majorCfg.enabled then
        for i = 1, #frame.majorSlots do
            frame.majorSlots[i]:Hide()
            frame.majorSlots[i].data = nil
        end
        return
    end
    local caps = {
        DEF = majorCfg.capDEF or 2,
        EXTERNAL = majorCfg.capEXT or 1,
        SELF = majorCfg.capSELF or 1,
        ABSORB = majorCfg.capABSORB or 1,
    }
    local limit = majorCfg.maxTotal or 4
    local filtered = {}
    local used = { DEF = 0, EXTERNAL = 0, SELF = 0, ABSORB = 0 }
    for _, entry in ipairs(list or {}) do
        if #filtered >= limit then
            break
        end
        local cap = caps[entry.class] or 0
        if used[entry.class] < cap then
            used[entry.class] = used[entry.class] + 1
            filtered[#filtered + 1] = entry
        end
    end

    frame.majorCont:ClearAllPoints()
    frame.majorCont:SetPoint(majorCfg.anchor or "TOPLEFT", frame, majorCfg.anchor or "TOPLEFT", majorCfg.offsetX or 2, majorCfg.offsetY or -2)

    local size = majorCfg.iconSize or 18
    local spacing = safeGet(cfg and cfg.icons, "spacing", 1)
    for i, slot in ipairs(frame.majorSlots) do
        local entry = filtered[i]
        slot:SetSize(size, size)
        slot.icon:SetSize(size, size)
        slot:ClearAllPoints()
        if i == 1 then
            slot:SetPoint("TOPLEFT", frame.majorCont, "TOPLEFT", 0, 0)
        else
            slot:SetPoint("LEFT", frame.majorSlots[i - 1], "RIGHT", spacing + 1, 0)
        end
        if entry then
            slot.icon:SetTexture(entry.icon)
            local color = CATEGORY_COLORS[entry.class]
            if color then
                slot.border:SetColorTexture(color[1], color[2], color[3], 0.85)
            else
                slot.border:SetColorTexture(1, 1, 1, 0.5)
            end
            local start = entry.expiration > 0 and entry.expiration - entry.duration or GetTime()
            if entry.duration and entry.duration > 0 then
                slot.cooldown:SetCooldown(start, entry.duration)
                slot.cooldown:Show()
            else
                slot.cooldown:Hide()
            end
            slot:SetAlpha(math.max(0.2, math.min(entry.confidence or 0.3, 1)))
            slot.data = entry
            slot:Show()
        else
            slot.cooldown:Hide()
            slot.data = nil
            slot:Hide()
        end
    end
    local count = math.min(#filtered, #frame.majorSlots)
    if count > 0 then
        local width = count * size + (count - 1) * (spacing + 1)
        frame.majorCont:SetSize(width, size)
    else
        frame.majorCont:SetSize(size, size)
    end
end

local function updateIconLayout(frame)
    if not frame then
        return
    end

    cfg = getConfig()
    local iconsCfg = (cfg and cfg.icons) or {}
    local size = safeGet(iconsCfg, "size", 14)

    if frame.hotTex then
        for i = 1, 12 do
            local tex = frame.hotTex[i]
            if tex then
                tex:SetSize(size, size)
            end
        end
    end

    if frame.debuffIcon then
        frame.debuffIcon:SetSize(size, size)
    end
end

local function updateAllIconLayout()
    for _, frame in ipairs(trackedFrames) do
        updateIconLayout(frame)
    end
end

local function updateAuraIcons(frame)
    if not frame then
        return
    end

    cfg = getConfig()
    frame._nod_refreshPending = nil
    frame._nod_lastRefresh = GetTime()
    local iconsCfg = (cfg and cfg.icons) or {}
    local majorCfg = (cfg and cfg.major) or {}
    local enabled = safeGet(iconsCfg, "enabled", true)

    if not frame.unit or not UnitExists(frame.unit) then
        if frame.debuffIcon then
            frame.debuffIcon:SetTexture(nil)
            frame.debuffIcon:Hide()
        end
        if frame.hotTex then
            for i = 1, 12 do
                local tex = frame.hotTex[i]
                if tex then
                    tex:Hide()
                end
                local stack = frame.hotStacks and frame.hotStacks[i]
                if stack then
                    stack:Hide()
                end
            end
        end
        if frame.hotCont then
            frame.hotCont:SetSize(1, 1)
        end
        if frame.majorSlots then
            for i = 1, #frame.majorSlots do
                frame.majorSlots[i]:Hide()
                frame.majorSlots[i].data = nil
            end
        end
        return
    end

    if frame.majorSlots then
        if majorCfg.enabled then
            local cds = collectMajorAuras(frame, frame.unit)
            layoutMajorIcons(frame, cds)
        else
            for i = 1, #frame.majorSlots do
                frame.majorSlots[i]:Hide()
                frame.majorSlots[i].data = nil
            end
        end
    end

    if enabled and safeGet(iconsCfg, "hotEnabled", true) and frame.hotTex then
        local list = collectHotAuras(frame.unit)
        layoutHotIcons(frame, list)
    elseif frame.hotTex then
        for i = 1, 12 do
            local tex = frame.hotTex[i]
            if tex then
                tex:Hide()
            end
            local stack = frame.hotStacks and frame.hotStacks[i]
            if stack then
                stack:Hide()
            end
        end
        if frame.hotCont then
            frame.hotCont:SetSize(1, 1)
        end
    end

    if frame.debuffIcon then
        if enabled and safeGet(iconsCfg, "debuffEnabled", true) then
            local iconTexture = pickDebuffIcon(frame.unit)
            if iconTexture then
                frame.debuffIcon:SetTexture(iconTexture)
                frame.debuffIcon:Show()
            else
                frame.debuffIcon:SetTexture(nil)
                frame.debuffIcon:Hide()
            end
        else
            frame.debuffIcon:SetTexture(nil)
            frame.debuffIcon:Hide()
        end
    end
end

local function refreshAllAuraIcons(frames)
    local list = frames
    if type(list) ~= "table" then
        list = trackedFrames
    end

    for _, frame in ipairs(list) do
        updateAuraIcons(frame)
    end
end

local function refreshAllIconState()
    updateAllIconLayout()
    refreshAllAuraIcons(trackedFrames)
end

local function requestAuraRefresh(frame)
    if not frame then
        return
    end
    local now = GetTime()
    local last = frame._nod_lastRefresh or 0
    local minInterval = 0.15
    if now - last >= minInterval then
        updateAuraIcons(frame)
        return
    end
    if frame._nod_refreshPending then
        return
    end
    frame._nod_refreshPending = true
    local delay = minInterval - (now - last)
    if delay < 0.05 then
        delay = 0.05
    end
    if not (C_Timer and C_Timer.After) then
        frame._nod_refreshPending = nil
        updateAuraIcons(frame)
        return
    end
    C_Timer.After(delay, function()
        if frame._nod_refreshPending then
            frame._nod_refreshPending = nil
            updateAuraIcons(frame)
        end
    end)
end

local function _RefreshAll()
    local Grid = NODHeal and NODHeal.UI and NODHeal.UI.Grid
    if Grid then
        Grid.UpdateAllIconLayout()
        Grid.RefreshAllAuraIcons(Grid.GetTrackedFrames())
    end
end

local refreshEventFrame = CreateFrame("Frame")
refreshEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
refreshEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
refreshEventFrame:SetScript("OnEvent", _RefreshAll)

function M.UpdateIconLayout(frame)
    updateIconLayout(frame)
end

function M.UpdateAllIconLayout()
    updateAllIconLayout()
end

function M.GetTrackedFrames()
    return trackedFrames
end

function M.UpdateAuraIcons(frame)
    updateAuraIcons(frame)
end

function M.RefreshAllAuraIcons(frames)
    refreshAllAuraIcons(frames)
end

local function isConfigEnabled(key, defaultValue)
    local value = getConfig()[key]
    if value == nil then
        return defaultValue
    end
    return value and true or false
end

local function getUnits()
    local list = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) then
                table.insert(list, unit)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            if UnitExists(unit) then
                table.insert(list, unit)
            end
        end
        table.insert(list, "player")
    else
        table.insert(list, "player")
    end

    return list
end

local ROLE_ORDER = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

local function getRoleWeight(unit)
    if not UnitGroupRolesAssigned then
        return ROLE_ORDER.NONE
    end
    local role = UnitGroupRolesAssigned(unit)
    return ROLE_ORDER[role or "NONE"] or ROLE_ORDER.NONE
end

local function getGroupWeight(unit)
    if not unit then
        return 9000
    end

    if UnitInRaid then
        local raidIndex = UnitInRaid(unit)
        if raidIndex then
            local subgroup = 0
            if GetRaidRosterInfo then
                local _, _, groupId = GetRaidRosterInfo(raidIndex)
                subgroup = groupId or subgroup
            end
            if subgroup and subgroup > 0 then
                return subgroup * 100 + raidIndex
            end
            return 500 + raidIndex
        end
    end

    if UnitInParty then
        local partyIndex = UnitInParty(unit)
        if partyIndex then
            return 1000 + partyIndex
        end
    end

    if unit == "player" then
        return 1010
    end

    return 9000
end

local function sortUnits(roster)
    local list = {}
    if type(roster) == "table" then
        for index = 1, #roster do
            list[index] = roster[index]
        end
    end

    local config = cfg or getConfig()
    local mode = (config and config.sortMode) or "group"
    if mode == "class" then
        mode = "role"
    end

    if mode == "alpha" then
        table.sort(list, function(a, b)
            local nameA = UnitName(a) or ""
            local nameB = UnitName(b) or ""
            return nameA < nameB
        end)
    elseif mode == "role" then
        table.sort(list, function(a, b)
            local weightA = getRoleWeight(a)
            local weightB = getRoleWeight(b)
            if weightA == weightB then
                local nameA = UnitName(a) or ""
                local nameB = UnitName(b) or ""
                return nameA < nameB
            end
            return weightA < weightB
        end)
    else
        table.sort(list, function(a, b)
            local groupA = getGroupWeight(a)
            local groupB = getGroupWeight(b)
            if groupA == groupB then
                local nameA = UnitName(a) or ""
                local nameB = UnitName(b) or ""
                return nameA < nameB
            end
            return groupA < groupB
        end)
    end

    return list
end

local function addFeedback(message)
    if not message then
        return
    end

    feedbackEntries[#feedbackEntries + 1] = message

    NODHeal.Feedback = NODHeal.Feedback or {}
    NODHeal.Feedback.Grid = feedbackEntries
end

local function getClassColor(unit)
    local _, class = UnitClass(unit)
    if not class then
        return 0.5, 0.5, 0.5
    end

    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not color then
        return 0.5, 0.5, 0.5
    end

    return color.r, color.g, color.b
end

local function createUnitFrame(parent, unit, index)
    local frame = CreateFrame("Button", "NODHeal_UnitFrame" .. index, parent, "SecureUnitButtonTemplate,BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetClipsChildren(true)

    frame.border = frame:CreateTexture(nil, "BORDER")
    frame.border:SetAllPoints(frame)
    frame.border:SetColorTexture(1, 1, 1, 0)

    frame:RegisterForClicks("AnyDown")

    frame:SetScript("OnEnter", function(self)
        if not self.unit or not UnitExists(self.unit) or not GameTooltip then
            return
        end
        local owner, point, relativePoint, offsetX, offsetY = getTooltipAnchor()
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint(point, owner, relativePoint, offsetX, offsetY)
        GameTooltip:SetUnit(self.unit, true)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    local health = frame:CreateTexture(nil, "ARTWORK")
    health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    health:SetColorTexture(0, 1, 0)

    local incoming = frame:CreateTexture(nil, "ARTWORK")
    incoming:SetPoint("LEFT", health, "RIGHT", 0, 0)
    incoming:SetPoint("TOP", health, "TOP", 0, 0)
    incoming:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
    incoming:SetColorTexture(0, 1, 0.4, 0.3)
    incoming:SetHeight(FRAME_HEIGHT - 2)
    incoming:SetWidth(0)
    incoming:Hide()

    local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("CENTER")
    name:SetText(UnitName(unit) or "???")

    local stateText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stateText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    stateText:SetText("")

    local stateIcon = frame:CreateTexture(nil, "OVERLAY")
    stateIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    stateIcon:SetSize(20, 20)
    stateIcon:Hide()

    local resIcon = frame:CreateTexture(nil, "OVERLAY")
    resIcon:SetPoint("TOP", frame, "TOP", 0, -4)
    resIcon:SetSize(16, 16)
    resIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Resurrection")
    resIcon:Hide()

    frame.health = health
    frame.incoming = incoming
    frame.name = name
    frame.stateText = stateText
    frame.stateIcon = stateIcon
    frame.resIcon = resIcon
    frame.unit = unit

    -- HoT-Container (oben rechts)
    frame.hotCont = CreateFrame("Frame", nil, frame)
    frame.hotCont:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    frame.hotCont:SetSize(1, 1)
    frame.hotTex = frame.hotTex or {}
    for i = 1, 12 do
        local t = frame.hotTex[i] or frame.hotCont:CreateTexture(nil, "OVERLAY")
        t:SetSize(14, 14)
        t:Hide()
        frame.hotTex[i] = t
    end
    frame.hotStacks = frame.hotStacks or {}
    for i = 1, 12 do
        local stack = frame.hotStacks[i]
        if not stack then
            stack = frame.hotCont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            stack:SetJustifyH("RIGHT")
            stack:SetJustifyV("BOTTOM")
        end
        stack:SetText("")
        stack:Hide()
        frame.hotStacks[i] = stack
    end

    frame.majorCont = frame.majorCont or CreateFrame("Frame", nil, frame)
    frame.majorCont:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    frame.majorCont:SetSize(1, 1)
    frame.majorSlots = frame.majorSlots or {}
    for i = 1, 4 do
        local slot = frame.majorSlots[i]
        if not slot then
            slot = CreateFrame("Frame", nil, frame.majorCont)
            slot:SetSize(18, 18)
            slot:EnableMouse(true)
            local icon = slot:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(slot)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            slot.icon = icon
            local border = slot:CreateTexture(nil, "OVERLAY")
            border:SetAllPoints(slot)
            border:SetColorTexture(1, 1, 1, 0.5)
            slot.border = border
            local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
            cooldown:SetAllPoints(slot)
            cooldown:SetReverse(false)
            cooldown:SetHideCountdownNumbers(true)
            slot.cooldown = cooldown
            slot:SetScript("OnEnter", function(self)
                if not self.data or not GameTooltip then
                    return
                end
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                if GameTooltip.SetSpellByID and self.data.spellId then
                    GameTooltip:SetSpellByID(self.data.spellId)
                else
                    GameTooltip:SetText(self.data.name or "", 1, 1, 1)
                end
                local remain = math.max(0, self.data.remain or 0)
                GameTooltip:AddLine(string.format("Remaining: %.1fs", remain), 0.8, 0.8, 0.8)
                if self.data.caster and UnitExists and UnitExists(self.data.caster) then
                    GameTooltip:AddLine(string.format("Source: %s", UnitName(self.data.caster) or "?"), 0.7, 0.9, 1.0)
                end
                if self.data.estimated and self.data.estimated > 0 then
                    GameTooltip:AddLine(string.format("Prevented ~%d", self.data.estimated), 0.6, 1.0, 0.6)
                else
                    GameTooltip:AddLine("Prevented: n/a", 0.6, 0.6, 0.6)
                end
                GameTooltip:Show()
            end)
            slot:SetScript("OnLeave", function()
                if GameTooltip then
                    GameTooltip:Hide()
                end
            end)
            frame.majorSlots[i] = slot
        end
        frame.majorSlots[i]:Hide()
        frame.majorSlots[i].data = nil
    end

    local debuffIcon = frame:CreateTexture(nil, "OVERLAY")
    debuffIcon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    debuffIcon:SetSize(14, 14)
    debuffIcon:Hide()

    frame.debuffIcon = debuffIcon

    M.UpdateIconLayout(frame)
    tinsert(trackedFrames, frame)
    updateAuraIcons(frame)

    if NODHeal and NODHeal.ClickCast and NODHeal.ClickCast.RegisterFrame then
        NODHeal.ClickCast:RegisterFrame(frame)
    end

    return frame
end

local function updateUnitFrame(frame, elapsed)
    if not frame or type(frame.unit) ~= "string" or not UnitExists(frame.unit) then
        if frame then
            frame._lastPct = nil
            if frame.hotTex then
                for i = 1, 12 do
                    local tex = frame.hotTex[i]
                    if tex then
                        tex:Hide()
                    end
                end
            end
            if frame.debuffIcon then
                frame.debuffIcon:SetTexture(nil)
                frame.debuffIcon:Hide()
            end
            if frame.stateIcon then
                frame.stateIcon:Hide()
            end
            if frame.stateText then
                frame.stateText:SetText("")
                frame.stateText:Hide()
            end
            if frame.resIcon then
                frame.resIcon:Hide()
            end
            if frame.incoming then
                frame.incoming:SetWidth(0)
                frame.incoming:Hide()
            end
            if frame.overheal then
                frame.overheal:Hide()
            end
            frame:Hide()
        end
        return
    end

    frame:Show()

    local death = getDeathModule()
    local state = death and death.GetState and death.GetState(frame.unit) or nil
    if not state or state == "" then
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost(frame.unit) then
            if UnitIsGhost and UnitIsGhost(frame.unit) then
                state = "GHOST"
            else
                state = "DEAD"
            end
        else
            state = "ALIVE"
        end
    end

    local healable = (state == "ALIVE" or state == "DYING")
    local cur = UnitHealth(frame.unit) or 0
    local max = UnitHealthMax(frame.unit) or 1
    if max <= 0 then
        max = 1
    end
    if cur < 0 then
        cur = 0
    elseif cur > max then
        cur = max
    end
    if not healable then
        cur = 0
    end

    local guard = getDesyncModule()
    local isFrozen = false
    if healable and guard and guard.IsFrozen then
        isFrozen = guard:IsFrozen(frame.unit)
    end

    local projectedHP = cur
    local incomingGain = 0
    local overheal = 0

    local solverResult
    if healable and not isFrozen then
        local solver = getSolverModule()
        if solver and solver.CalculateProjectedHealth then
            local opts
            local tLand, spellID = computeLandingForUnit(frame.unit)
            if tLand or spellID then
                opts = {}
                if tLand then
                    opts.tLand = tLand
                end
                if spellID then
                    opts.spellID = spellID
                end
            end

            local ok, result
            if opts then
                ok, result = pcall(solver.CalculateProjectedHealth, frame.unit, opts)
            else
                ok, result = pcall(solver.CalculateProjectedHealth, frame.unit)
            end

            if ok and type(result) == "table" then
                solverResult = result
            end
        end
    end

    if solverResult then
        local resultMax = solverResult.hp_max
        if type(resultMax) == "number" and resultMax > 0 then
            max = resultMax
        end

        local resultNow = solverResult.hp_now
        if type(resultNow) == "number" then
            cur = resultNow
            if cur < 0 then
                cur = 0
            elseif cur > max then
                cur = max
            end
        end

        projectedHP = solverResult.projectedHealth or solverResult.hp_proj or cur
        if projectedHP < cur then
            projectedHP = cur
        elseif projectedHP > max then
            projectedHP = max
        end

        overheal = math.max(solverResult.overheal or 0, 0)
        incomingGain = math.max(projectedHP - cur, 0)
    else
        if healable and UnitGetIncomingHeals then
            incomingGain = UnitGetIncomingHeals(frame.unit) or 0
            if incomingGain < 0 then
                incomingGain = 0
            end
        end

        projectedHP = cur + incomingGain
        if projectedHP > max then
            overheal = projectedHP - max
            projectedHP = max
        end
    end

    local targetHP = projectedHP
    local pct = max > 0 and (cur / max) or 0
    local targetPct = max > 0 and (targetHP / max) or 0

    if healable then
        frame._lastPct = frame._lastPct or pct
        local diff = targetPct - frame._lastPct
        frame._lastPct = frame._lastPct + diff * 0.25
        if frame._lastPct < 0 then
            frame._lastPct = 0
        elseif frame._lastPct > 1 then
            frame._lastPct = 1
        end
    else
        frame._lastPct = 0
    end

    local r, g, b
    if healable then
        r, g, b = getClassColor(frame.unit)
        if pct < 0.35 then
            r, g, b = 1, 0.2, 0.2
        elseif pct < 0.7 then
            r, g, b = 1, 0.8, 0.2
        end
    else
        if state == "GHOST" then
            r, g, b = 0.4, 0.5, 0.8
        elseif state == "FEIGN" then
            r, g, b = 0.45, 0.35, 0.2
        elseif state == "UNKNOWN" then
            r, g, b = 0.3, 0.3, 0.45
        else
            r, g, b = 0.3, 0.3, 0.3
        end
    end

    frame.health:SetColorTexture(r, g, b)

    local frameWidth = frame:GetWidth() - 2
    if frameWidth < 0 then
        frameWidth = 0
    end

    frame.health:SetWidth(frameWidth * (frame._lastPct or 0))
    frame.health:SetHeight(FRAME_HEIGHT - 2)

    if healable and isConfigEnabled("showIncoming", true) then
        local incPct = math.min((cur + incomingGain) / max, 1)
        local incWidth = frameWidth * incPct
        local healthWidth = frame.health:GetWidth()
        local overlayWidth = incWidth - healthWidth
        if overlayWidth > 0 then
            frame.incoming:SetHeight(FRAME_HEIGHT - 2)
            frame.incoming:SetWidth(overlayWidth)
            frame.incoming:SetColorTexture(0, 1, 0.3, 0.4)
            frame.incoming:Show()
        else
            frame.incoming:SetWidth(0)
            frame.incoming:Hide()
        end
    else
        frame.incoming:SetWidth(0)
        frame.incoming:Hide()
    end

    if healable and isConfigEnabled("showOverheal", true) and overheal > 0 then
        local overWidth = frameWidth * (overheal / max)
        if overWidth < 0 then
            overWidth = 0
        end

        if not frame.overheal then
            frame.overheal = frame:CreateTexture(nil, "OVERLAY")
            frame.overheal:SetPoint("LEFT", frame, "LEFT", frame:GetWidth(), 0)
            frame.overheal:SetHeight(FRAME_HEIGHT - 2)
        end

        frame.overheal:SetColorTexture(0.8, 1, 0.8, 0.3)
        frame.overheal:SetWidth(overWidth)
        frame.overheal:Show()
    elseif frame.overheal then
        frame.overheal:Hide()
    end

    frame.name:SetText(UnitName(frame.unit) or "???")

    if frame.border then
        if state == "DYING" then
            frame.border:SetColorTexture(1, 0.3, 0.3, 0.8)
        elseif UnitIsUnit(frame.unit, "player") then
            frame.border:SetColorTexture(1, 1, 1, 0.4)
        else
            frame.border:SetColorTexture(1, 1, 1, 0)
        end
    end

    applyStateDecor(frame, state, healable)
end

local function ensureContainer()
    if container then
        return container
    end

    container = CreateFrame("Frame", "NODHeal_GridFrame", UIParent, "BackdropTemplate")
    container:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    container:SetMovable(true)
    container:EnableMouse(true)
    container:SetClampedToScreen(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function(frame)
        if not isConfigEnabled("lockGrid", false) then
            frame:StartMoving()
        end
    end)
    container:SetScript("OnDragStop", container.StopMovingOrSizing)
    container:SetBackdrop({bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark"})

    addFeedback("Container frame created")

    return container
end

local function rebuildGrid()
    local host = ensureContainer()

    cfg = getConfig()
    local roster = getUnits()
    local sortedUnits = sortUnits(roster)
    addFeedback("Rebuilding Grid Layout (Sorted)")

    local cols = cfg.columns
    if type(cols) ~= "number" then
        cols = COLUMNS
    end
    cols = math.floor(cols + 0.5)
    if cols < 1 then
        cols = 1
    elseif cols > 40 then
        cols = 40
    end

    local spacing = cfg.spacing
    if type(spacing) ~= "number" then
        spacing = SPACING
    end
    if spacing < 0 then
        spacing = 0
    end

    local scale = cfg.scale
    if type(scale) ~= "number" then
        scale = 1
    end
    if scale < 0.3 then
        scale = 0.3
    elseif scale > 3 then
        scale = 3
    end
    host:SetScale(scale)

    local alpha = cfg.bgAlpha
    if type(alpha) ~= "number" then
        alpha = 0.7
    end
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    host:SetBackdropColor(0, 0, 0, alpha)

    local locked = isConfigEnabled("lockGrid", false)
    host:SetMovable(not locked)
    host:EnableMouse(not locked)
    if locked then
        host:RegisterForDrag()
    else
        host:RegisterForDrag("LeftButton")
    end

    local total = #sortedUnits
    if total == 0 then
        for _, frame in ipairs(unitFrames) do
            frame.unit = nil
            frame:Hide()
        end
        host:SetSize(FRAME_WIDTH + (PADDING * 2), FRAME_HEIGHT + (PADDING * 2))
        return
    end

    local rows = math.ceil(total / cols)
    local usedColumns = math.min(total, cols)
    local width = (usedColumns * FRAME_WIDTH) + ((usedColumns - 1) * spacing) + (PADDING * 2)
    local height = (rows * FRAME_HEIGHT) + ((rows - 1) * spacing) + (PADDING * 2)
    host:SetSize(width, height)

    local index = 1
    local x = PADDING
    local y = -PADDING

    for _, unit in ipairs(sortedUnits) do
        local frame = unitFrames[index]
        if not frame then
            frame = createUnitFrame(host, unit, index)
            unitFrames[index] = frame
        end

    frame.unit = unit
        if NODHeal and NODHeal.ClickCast and NODHeal.ClickCast.SetFrameUnit then
            NODHeal.ClickCast:SetFrameUnit(frame, unit)
        end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
        updateUnitFrame(frame)
        frame:Show()
        updateAuraIcons(frame)

        index = index + 1
        if (index - 1) % cols == 0 then
            x = PADDING
            y = y - (FRAME_HEIGHT + spacing)
        else
            x = x + (FRAME_WIDTH + spacing)
        end
    end

    for i = index, #unitFrames do
        local frame = unitFrames[i]
        if frame then
            frame.unit = nil
            if NODHeal and NODHeal.ClickCast and NODHeal.ClickCast.SetFrameUnit then
                NODHeal.ClickCast:SetFrameUnit(frame, nil)
            end
            if frame.hotTex then
                for j = 1, 12 do
                    local tex = frame.hotTex[j]
                    if tex then
                        tex:Hide()
                    end
                end
            end
            if frame.debuffIcon then
                frame.debuffIcon:SetTexture(nil)
                frame.debuffIcon:Hide()
            end
            frame:Hide()
        end
    end

    M.UpdateAllIconLayout()
    M.RefreshAllAuraIcons(M.GetTrackedFrames())
end

local function updateAllFrames()
    for index = 1, #unitFrames do
        local frame = unitFrames[index]
        if frame then
            updateUnitFrame(frame)
        end
    end
end

local GRID_TICK_INTERVAL = 0.2

local function sharedTick()
    for index = 1, #unitFrames do
        local frame = unitFrames[index]
        if frame then
            updateUnitFrame(frame, GRID_TICK_INTERVAL)
        end
    end
end

local function startTicker()
    if M._tickerRegistered then
        return
    end

    local dispatcher = (NODHeal.GetModule and NODHeal:GetModule("CoreDispatcher")) or NODHeal.CoreDispatcher
    if dispatcher and dispatcher.RegisterTick then
        if dispatcher.RegisterTick(sharedTick) then
            M._tickerRegistered = true
            return
        end
    end

    if M._ticker then
        M._ticker:Cancel()
    end

    if C_Timer and C_Timer.NewTicker then
        M._ticker = C_Timer.NewTicker(GRID_TICK_INTERVAL, sharedTick)
    end
end

function M.GetFeedbackEntries()
    return feedbackEntries
end

local function rebuildLater()
    C_Timer.After(0.2, rebuildGrid)
end

local function initialize()
    rebuildGrid()
    M.UpdateAllIconLayout()
    M.RefreshAllAuraIcons(M.GetTrackedFrames())
    if not M._deathListenerRegistered then
        local mod = getDeathModule()
        if mod and mod.RegisterListener then
            mod.RegisterListener(function(unit)
                if unit == nil then
                    for _, frame in ipairs(unitFrames) do
                        updateUnitFrame(frame)
                    end
                    return
                end
                for _, frame in ipairs(unitFrames) do
                    if frame.unit == unit then
                        updateUnitFrame(frame)
                    end
                end
            end)
            M._deathListenerRegistered = true
        end
    end
    if M._eventFrame then
        startTicker()
        return
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:RegisterEvent("UNIT_HEALTH")
    ev:RegisterEvent("UNIT_CONNECTION")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    ev:RegisterEvent("UNIT_AURA")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_HEALTH" then
            if not unit or type(unit) ~= "string" then
                updateAllFrames()
            else
                for _, frame in ipairs(unitFrames) do
                    if frame.unit == unit then
                        updateUnitFrame(frame)
                    end
                end
            end
        elseif event == "UNIT_AURA" then
            if not unit or type(unit) ~= "string" then
                for _, frame in ipairs(trackedFrames) do
                    requestAuraRefresh(frame)
                end
            else
                for _, frame in ipairs(unitFrames) do
                    if frame.unit == unit then
                        requestAuraRefresh(frame)
                    end
                end
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
            refreshAllIconState()
            rebuildLater()
        elseif event == "PLAYER_TARGET_CHANGED" then
            refreshAllIconState()
        else
            rebuildLater()
        end
    end)
    M._eventFrame = ev
    startTicker()
end

M.Initialize = initialize
M.unitFrames = unitFrames
