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
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local IsInRaid = IsInRaid
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local math = math
local ipairs = ipairs
local pairs = pairs
local table_insert = table.insert

local unitFrames = {}
local container
local eventFrame

local FRAME_WIDTH = 90
local FRAME_HEIGHT = 35
local COLUMNS = 5
local SPACING = 4
local PADDING = 8

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
    incoming:SetPoint("BOTTOMLEFT", health, "BOTTOMRIGHT", 0, 0)
    incoming:SetPoint("TOPLEFT", health, "TOPRIGHT", 0, 0)
    incoming:SetColorTexture(0, 0.75, 0.95, 0.25)
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

    frame.incoming:SetWidth(0)
    frame.incoming:SetHeight(FRAME_HEIGHT - 2)

    frame.name:SetText(UnitName(frame.unit) or "???")
end

local function collectUnits()
    local units = {}

    if IsInRaid() then
        local total = GetNumGroupMembers() or 0
        for i = 1, total do
            local unit = "raid" .. i
            if UnitExists(unit) then
                table_insert(units, unit)
            end
        end
    else
        if UnitExists("player") then
            table_insert(units, "player")
        end

        local subgroupMembers = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, subgroupMembers do
            local unit = "party" .. i
            if UnitExists(unit) then
                table_insert(units, unit)
            end
        end
    end

    return units
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
    local units = collectUnits()
    layoutUnits(units)
end

local function updateAllFrames()
    for _, frame in ipairs(unitFrames) do
        updateUnitFrame(frame)
    end
end

local function onEvent(_, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
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
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", onEvent)
end

G.Initialize = initialize
