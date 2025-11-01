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
local GetNumSubgroupMembers = GetNumSubgroupMembers
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local IsUsableSpell = IsUsableSpell
local CastSpellByName = CastSpellByName
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local math = math
local ipairs = ipairs
local pairs = pairs

local unitFrames = {}
local container
local eventFrame
local feedbackEntries = {}

local FRAME_WIDTH = 90
local FRAME_HEIGHT = 35
local COLUMNS = 5
local SPACING = 4
local PADDING = 8

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

local function updateUnitFrame(frame)
    if not frame or not frame.unit or not UnitExists(frame.unit) then
        if frame then
            frame:Hide()
        end
        return
    end

    frame:Show()

    local current, maximum = UnitHealth(frame.unit), UnitHealthMax(frame.unit)
    maximum = maximum > 0 and maximum or 1
    local ratio = current / maximum
    if ratio < 0 then
        ratio = 0
    elseif ratio > 1 then
        ratio = 1
    end

    local r, g, b = getClassColor(frame.unit)
    frame.health:SetColorTexture(r, g, b)

    local barWidth = (FRAME_WIDTH - 2) * ratio
    frame.health:SetWidth(barWidth)
    frame.health:SetHeight(FRAME_HEIGHT - 2)

    local incomingAmount = UnitGetIncomingHeals and UnitGetIncomingHeals(frame.unit) or 0
    if incomingAmount > 0 then
        local incPct = math.min((current + incomingAmount) / maximum, 1)
        local incWidth = (FRAME_WIDTH - 2) * incPct
        frame.incoming:SetHeight(FRAME_HEIGHT - 2)
        frame.incoming:SetWidth(math.max(incWidth - barWidth, 0))
        frame.incoming:Show()
    else
        frame.incoming:SetWidth(0)
        frame.incoming:Hide()
    end

    frame.name:SetText(UnitName(frame.unit) or "???")
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
    container:SetScript("OnDragStart", container.StartMoving)
    container:SetScript("OnDragStop", container.StopMovingOrSizing)
    container:SetBackdrop({bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark"})
    container:SetBackdropColor(0, 0, 0, 0.7)

    addFeedback("Container frame created")

    return container
end

local function layoutUnits(units)
    local host = ensureContainer()

    local total = #units
    if total == 0 then
        for _, frame in pairs(unitFrames) do
            frame:Hide()
        end
        host:SetSize(FRAME_WIDTH + (PADDING * 2), FRAME_HEIGHT + (PADDING * 2))
        return
    end

    local rows = math.ceil(total / COLUMNS)
    local usedColumns = math.min(total, COLUMNS)
    local width = (usedColumns * FRAME_WIDTH) + ((usedColumns - 1) * SPACING) + (PADDING * 2)
    local height = (rows * FRAME_HEIGHT) + ((rows - 1) * SPACING) + (PADDING * 2)
    host:SetSize(width, height)

    for index, unit in ipairs(units) do
        local frame = unitFrames[index]
        if not frame then
            frame = createUnitFrame(host, unit, index)
            unitFrames[index] = frame
        end

        frame.unit = unit
        frame:ClearAllPoints()

        local column = (index - 1) % COLUMNS
        local row = math.floor((index - 1) / COLUMNS)
        local offsetX = PADDING + column * (FRAME_WIDTH + SPACING)
        local offsetY = -PADDING - row * (FRAME_HEIGHT + SPACING)

        frame:SetPoint("TOPLEFT", host, "TOPLEFT", offsetX, offsetY)
        updateUnitFrame(frame)

        addFeedback("Frame " .. index .. " assigned to unit '" .. unit .. "'")
    end

    local count = #unitFrames
    for i = total + 1, count do
        local frame = unitFrames[i]
        if frame then
            frame.unit = nil
            frame:Hide()
        end
    end
end

local function rebuildGrid()
    addFeedback("Rebuilding Grid Layout")

    ensureContainer()

    local units = {"player"}

    if IsInRaid() then
        local total = GetNumGroupMembers() or 0
        for i = 1, total do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        local total = GetNumGroupMembers() or 0
        for i = 1, math.max(total - 1, 0) do
            units[#units + 1] = "party" .. i
        end
    else
        local subgroupMembers = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, subgroupMembers do
            units[#units + 1] = "party" .. i
        end
    end

    local filtered = {}
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            filtered[#filtered + 1] = unit
        end
    end

    layoutUnits(filtered)
end

local function updateAllFrames()
    for _, frame in ipairs(unitFrames) do
        updateUnitFrame(frame)
    end
end

function G.GetFeedbackEntries()
    return feedbackEntries
end

local function onEvent(_, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_HEAL_PREDICTION" then
        if not arg1 then
            updateAllFrames()
            return
        end

        for _, frame in ipairs(unitFrames) do
            if frame.unit == arg1 then
                updateUnitFrame(frame)
                return
            end
        end
    else
        rebuildGrid()
    end
end

local function initialize()
    ensureContainer()
    rebuildGrid()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_HEAL_PREDICTION")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", onEvent)
end

G.Initialize = initialize
