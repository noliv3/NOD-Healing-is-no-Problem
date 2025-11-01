local G = {}
NODHeal = NODHeal or {}
NODHeal.Grid = G

local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitName = UnitName
local UnitGetIncomingHeals = UnitGetIncomingHeals
local GetNumGroupMembers = GetNumGroupMembers
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitIsUnit = UnitIsUnit
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local IsUsableSpell = IsUsableSpell
local CastSpellByName = CastSpellByName
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local C_Timer = C_Timer
local math = math
local ipairs = ipairs
local pairs = pairs
local type = type

local unitFrames = {}
local container
local feedbackEntries = {}

local FRAME_WIDTH = 90
local FRAME_HEIGHT = 35
local COLUMNS = 5
local SPACING = 4
local PADDING = 8

local function getConfig()
    NODHeal.Config = NODHeal.Config or {}
    return NODHeal.Config
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

local function sortUnits(mode)
    local units = getUnits()
    mode = mode or "group"
    if mode == "class" then
        table.sort(units, function(a, b)
            local _, ca = UnitClass(a)
            local _, cb = UnitClass(b)
            return (ca or "") < (cb or "")
        end)
    elseif mode == "alpha" then
        table.sort(units, function(a, b)
            return (UnitName(a) or "") < (UnitName(b) or "")
        end)
    end
    return units
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
    local frame = CreateFrame("Button", "NODHeal_UnitFrame" .. index, parent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetClipsChildren(true)

    frame.border = frame:CreateTexture(nil, "BORDER")
    frame.border:SetAllPoints(frame)
    frame.border:SetColorTexture(1, 1, 1, 0)

    frame:RegisterForClicks("AnyUp")
    frame:SetScript("OnClick", function(self, button)
        if not self.unit then
            return
        end

        local combo = ""
        if IsAltKeyDown() then
            combo = combo .. "Alt-"
        end
        if IsControlKeyDown() then
            combo = combo .. "Ctrl-"
        end
        if IsShiftKeyDown() then
            combo = combo .. "Shift-"
        end
        combo = combo .. button

        local bindings = NODHeal and NODHeal.Bindings
        local spell
        if bindings and bindings.Get then
            spell = bindings:Get(combo) or bindings:Get(button)
        end

        local targetName = UnitName(self.unit) or "???"

        if spell and IsUsableSpell(spell) then
            CastSpellByName(spell, self.unit)
            print("[NOD] Cast:", spell, "→", targetName)
        else
            print("[NOD] No binding for", combo)
        end
    end)

    frame:SetScript("OnEnter", function(self)
        if not self.unit then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
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

    frame.health = health
    frame.incoming = incoming
    frame.name = name
    frame.unit = unit

    return frame
end

local function updateUnitFrame(frame, elapsed)
    if not frame or not frame.unit or not UnitExists(frame.unit) then
        if frame then
            frame._lastPct = nil
            frame:Hide()
        end
        return
    end

    frame:Show()

    local cur, max = UnitHealth(frame.unit), UnitHealthMax(frame.unit)
    if max <= 0 then
        max = 1
    end

    local incoming = UnitGetIncomingHeals and UnitGetIncomingHeals(frame.unit) or 0
    local predicted = 0

    if NODHeal.Core and NODHeal.Core.PredictiveSolver and NODHeal.Core.PredictiveSolver.CalculateProjectedHealth then
        local result = NODHeal.Core.PredictiveSolver.CalculateProjectedHealth(NODHeal.Core.PredictiveSolver, frame.unit)
        if type(result) == "number" then
            predicted = result - cur
        end
    end

    local projectedTotal = cur + incoming + predicted
    local targetHP = math.min(projectedTotal, max)
    local pct = cur / max
    local targetPct = targetHP / max

    frame._lastPct = frame._lastPct or pct
    local diff = targetPct - frame._lastPct
    frame._lastPct = frame._lastPct + diff * 0.25
    if frame._lastPct < 0 then
        frame._lastPct = 0
    elseif frame._lastPct > 1 then
        frame._lastPct = 1
    end

    local r, g, b = getClassColor(frame.unit)
    if pct < 0.35 then
        r, g, b = 1, 0.2, 0.2
    elseif pct < 0.7 then
        r, g, b = 1, 0.8, 0.2
    end

    frame.health:SetColorTexture(r, g, b)

    local frameWidth = frame:GetWidth() - 2
    if frameWidth < 0 then
        frameWidth = 0
    end

    frame.health:SetWidth(frameWidth * frame._lastPct)
    frame.health:SetHeight(FRAME_HEIGHT - 2)

    if isConfigEnabled("showIncoming", true) then
        local incPct = math.min((cur + incoming) / max, 1)
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

    if isConfigEnabled("showOverheal", true) and projectedTotal > max then
        local overWidth = frameWidth * ((projectedTotal / max) - 1)
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
        if UnitIsUnit(frame.unit, "player") then
            frame.border:SetColorTexture(1, 1, 1, 0.4)
        else
            frame.border:SetColorTexture(1, 1, 1, 0)
        end
    end
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

    local cfg = getConfig()
    local sortedUnits = sortUnits(cfg.sortMode or "group")
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
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
        updateUnitFrame(frame)
        frame:Show()

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
            frame:Hide()
        end
    end
end

local function updateAllFrames()
    for _, frame in ipairs(unitFrames) do
        updateUnitFrame(frame)
    end
end

local function startTicker()
    if G._ticker then
        G._ticker:Cancel()
    end

    G._ticker = C_Timer.NewTicker(0.1, function()
        for _, f in pairs(unitFrames) do
            updateUnitFrame(f, 0.1)
        end
    end)
end

function G.GetFeedbackEntries()
    return feedbackEntries
end

local function rebuildLater()
    C_Timer.After(0.2, rebuildGrid)
end

local function initialize()
    rebuildGrid()
    if G._eventFrame then
        startTicker()
        return
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:RegisterEvent("UNIT_HEALTH")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(_, event)
        if event == "UNIT_HEALTH" then
            updateAllFrames()
        else
            rebuildLater()
        end
    end)
    G._eventFrame = ev
    startTicker()
end

G.Initialize = initialize
