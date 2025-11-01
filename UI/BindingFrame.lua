local addon = _G.NODHeal or {}

local BindingUI = {}
addon.BindUI = BindingUI

local frame
local editBoxes = {}

local function getBindingAPI()
    if addon and addon.Bindings then
        return addon.Bindings
    end
end

local function applyBinding(combo, value)
    local bindings = getBindingAPI()
    if not bindings or not bindings.Set then
        return
    end

    if value and value ~= "" then
        bindings:Set(combo, value)
    else
        bindings:Set(combo, nil)
    end
end

local function fetchBinding(combo)
    local bindings = getBindingAPI()
    if not bindings or not bindings.Get then
        return ""
    end

    return bindings:Get(combo) or ""
end

function BindingUI:Refresh()
    for combo, box in pairs(editBoxes) do
        if box then
            local desired = fetchBinding(combo)
            if box:GetText() ~= desired then
                box:SetText(desired)
            elseif not box:GetText() then
                box:SetText("")
            end
        end
    end
end

function BindingUI:Create()
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", "NODHeal_BindingFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(440, 360)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", function()
        self:Refresh()
    end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", 0, -12)
    frame.title:SetText("NOD-Heal Spell Bindings")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -34, 48)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(380, 220)
    scrollFrame:SetScrollChild(content)

    local columnLabels = { "", "LeftButton", "RightButton", "MiddleButton" }
    local modifiers = {
        { key = "", label = "No Modifier" },
        { key = "Shift-", label = "Shift" },
        { key = "Ctrl-", label = "Ctrl" },
        { key = "Alt-", label = "Alt" },
    }

    for index = 2, #columnLabels do
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", 110 + (index - 2) * 105, -8)
        header:SetText(columnLabels[index])
    end

    local yOffset = -36
    for _, modifier in ipairs(modifiers) do
        local rowLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowLabel:SetPoint("TOPLEFT", 8, yOffset)
        rowLabel:SetText(modifier.label)

        for column = 2, #columnLabels do
            local combo = modifier.key .. columnLabels[column]
            local box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
            box:SetAutoFocus(false)
            box:SetSize(100, 24)
            box:SetPoint("TOPLEFT", 110 + (column - 2) * 105, yOffset - 4)
            box:SetText(fetchBinding(combo))
            box:SetCursorPosition(0)

            box:SetScript("OnEditFocusLost", function(element)
                applyBinding(combo, element:GetText())
            end)

            editBoxes[combo] = box
        end

        yOffset = yOffset - 38
    end

    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetSize(100, 26)
    saveButton:SetPoint("BOTTOMLEFT", 16, 12)
    saveButton:SetText("Save All")
    saveButton:SetScript("OnClick", function()
        print("[NOD] Spell bindings updated.")
        frame:Hide()
    end)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 26)
    closeButton:SetPoint("BOTTOMRIGHT", -16, 12)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:Hide()
    self:Refresh()

    return frame
end

function BindingUI:Toggle()
    if not frame then
        self:Create()
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

_G.NODHeal = addon
