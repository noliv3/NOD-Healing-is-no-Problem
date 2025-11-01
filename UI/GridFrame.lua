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
local C_Timer = C_Timer
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

    if projectedTotal > max then
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
        startTicker()
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", onEvent)

    startTicker()
end

G.Initialize = initialize
