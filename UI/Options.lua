local Options = {}

NODHeal = NODHeal or {}
NODHeal.Options = Options
NODHeal.Config = NODHeal.Config or {}
NODHealDB = NODHealDB or {}

local function log(message, force)
    if not message then
        return
    end
    if NODHeal and NODHeal.Log then
        NODHeal:Log(message, force)
    elseif force then
        print("[NOD] " .. message)
    end
end

local CreateFrame = CreateFrame
local UIParent = UIParent
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue
local pairs = pairs
local ipairs = ipairs
local math = math

local defaults = (NODHeal and NODHeal.ConfigDefaults) or {
    scale = 1,
    columns = 5,
    spacing = 4,
    bgAlpha = 0.7,
    sortMode = "group",
    showIncoming = true,
    showOverheal = true,
    lockGrid = false,
}

local frame
local sliders = {}
local checkboxes = {}
local dropdown
local originalConfig

local function ensureConfig()
    if NODHeal and NODHeal.ApplyConfigDefaults then
        NODHeal.ApplyConfigDefaults()
    end
    NODHeal.Config = NODHeal.Config or {}
    NODHealDB = NODHealDB or {}
    NODHealDB.config = NODHealDB.config or {}

    local config = NODHeal.Config

    for key, defaultValue in pairs(defaults) do
        local saved = NODHealDB.config[key]
        if saved == nil then
            if config[key] == nil then
                saved = defaultValue
            else
                saved = config[key]
            end
            NODHealDB.config[key] = saved
        end

        config[key] = saved
    end

    return config
end

local function copyTrackedConfig(source)
    local snapshot = {}
    if not source then
        return snapshot
    end
    for key in pairs(defaults) do
        snapshot[key] = source[key]
    end
    return snapshot
end

local function applyGridRefresh()
    if NODHeal.Grid and NODHeal.Grid.Initialize then
        NODHeal.Grid.Initialize()
    end
    local uiModule = NODHeal.GetModule and NODHeal:GetModule("UI")
    if uiModule and uiModule.Refresh then
        uiModule:Refresh()
    end
end

local function saveConfigValue(key, value, silent)
    local config = ensureConfig()
    config[key] = value
    NODHealDB.config[key] = value
    applyGridRefresh()
    if not silent then
        if NODHeal and NODHeal.Logf then
            NODHeal:Logf(true, "Saved option: %s = %s", key, tostring(value))
        else
            log(string.format("Saved option: %s = %s", key, tostring(value)), true)
        end
    end
end

local function updateSliderText(slider, value)
    local textRegion = _G[slider:GetName() .. "Text"]
    if textRegion then
        local displayValue
        if slider._decimals and slider._decimals > 0 then
            displayValue = string.format("%." .. slider._decimals .. "f", value)
        else
            displayValue = string.format("%d", math.floor(value + 0.5))
        end
        textRegion:SetText(string.format("%s: %s", slider._label, displayValue))
    end
end

local function createSlider(parent, label, key, minValue, maxValue, step, decimals)
    local sliderName = "NODHealOptionsSlider" .. key
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)
    slider._label = label
    slider._decimals = decimals or 0
    slider:SetScript("OnValueChanged", function(self, newValue)
        if self._updating then
            updateSliderText(self, newValue)
            return
        end
        local rounded
        if self._decimals and self._decimals > 0 then
            local multiplier = 10 ^ self._decimals
            rounded = math.floor(newValue * multiplier + 0.5) / multiplier
        else
            rounded = math.floor(newValue + 0.5)
        end
        updateSliderText(self, rounded)
        saveConfigValue(key, rounded)
    end)

    _G[sliderName .. "Low"]:SetText(tostring(minValue))
    _G[sliderName .. "High"]:SetText(tostring(maxValue))
    updateSliderText(slider, ensureConfig()[key] or minValue)

    sliders[key] = slider
    return slider
end

local function createCheckbox(parent, label, key)
    local checkbox = CreateFrame("CheckButton", "NODHealOptionsCheck" .. key, parent, "ChatConfigCheckButtonTemplate")
    checkbox.Text:SetText(label)
    checkbox:SetScript("OnClick", function(self)
        if self._updating then
            return
        end
        saveConfigValue(key, self:GetChecked() and true or false)
    end)
    checkboxes[key] = checkbox
    return checkbox
end

local function createDropdown(parent, label, key, values)
    local dropdownName = "NODHealOptionsDropdown" .. key
    local dd = CreateFrame("Frame", dropdownName, parent, "UIDropDownMenuTemplate")
    dd._label = label
    dd.values = values

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 16, 3)
    title:SetText(label)

    UIDropDownMenu_SetWidth(dd, 160)

    UIDropDownMenu_Initialize(dd, function(_, level)
        if not level then
            return
        end
        for _, value in ipairs(values) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = value
            info.value = value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dd, value)
                UIDropDownMenu_SetText(dd, value)
                saveConfigValue(key, value)
            end
            info.checked = (ensureConfig()[key] == value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dropdown = dd
    return dd
end

local function restoreSnapshot(snapshot)
    if not snapshot then
        return
    end
    for key, value in pairs(snapshot) do
        if defaults[key] ~= nil then
            saveConfigValue(key, value, true)
        end
    end
end

function Options:RefreshControls()
    local config = ensureConfig()

    for key, slider in pairs(sliders) do
        local value = config[key] or defaults[key]
        slider._updating = true
        slider:SetValue(value)
        slider._updating = nil
        updateSliderText(slider, value)
    end

    for key, checkbox in pairs(checkboxes) do
        checkbox._updating = true
        checkbox:SetChecked(config[key] and true or false)
        checkbox._updating = nil
    end

    if dropdown then
        local value = config.sortMode or defaults.sortMode
        UIDropDownMenu_SetSelectedValue(dropdown, value)
        UIDropDownMenu_SetText(dropdown, value)
    end
end

function Options:EnsureFrame()
    if frame then
        return frame
    end

    ensureConfig()

    frame = CreateFrame("Frame", "NODHealOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(420, 420)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", 0, -12)
    frame.title:SetText("NOD-Heal Options")

    local y = -50

    local scaleSlider = createSlider(frame, "Grid Scale", "scale", 0.5, 2.0, 0.1, 1)
    scaleSlider:SetPoint("TOP", frame, "TOP", 0, y)
    y = y - 70

    local columnSlider = createSlider(frame, "Columns", "columns", 1, 8, 1, 0)
    columnSlider:SetPoint("TOP", frame, "TOP", 0, y)
    y = y - 70

    local spacingSlider = createSlider(frame, "Spacing", "spacing", 0, 20, 1, 0)
    spacingSlider:SetPoint("TOP", frame, "TOP", 0, y)
    y = y - 70

    local bgSlider = createSlider(frame, "Background Alpha", "bgAlpha", 0, 1, 0.05, 2)
    bgSlider:SetPoint("TOP", frame, "TOP", 0, y)
    y = y - 80

    local incomingCheck = createCheckbox(frame, "Show Incoming Heals", "showIncoming")
    incomingCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
    y = y - 30

    local overhealCheck = createCheckbox(frame, "Show Overheal Overlay", "showOverheal")
    overhealCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
    y = y - 30

    local lockCheck = createCheckbox(frame, "Lock Grid Position", "lockGrid")
    lockCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)

    local sortDropdown = createDropdown(frame, "Sort Mode", "sortMode", { "group", "class", "alpha" })
    sortDropdown:SetPoint("TOP", frame, "TOP", 0, -320)

    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetSize(100, 24)
    saveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        originalConfig = copyTrackedConfig(ensureConfig())
        frame:Hide()
    end)

    local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelButton:SetSize(100, 24)
    cancelButton:SetPoint("RIGHT", saveButton, "LEFT", -12, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        if originalConfig then
            restoreSnapshot(originalConfig)
        end
        frame:Hide()
    end)

    table.insert(UISpecialFrames, frame:GetName())

    frame:SetScript("OnShow", function()
        ensureConfig()
        originalConfig = copyTrackedConfig(NODHeal.Config)
        Options:RefreshControls()
    end)

    frame:Hide()

    return frame
end

function Options:Toggle()
    local optionsFrame = self:EnsureFrame()
    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        optionsFrame:Show()
    end
end

ensureConfig()

return Options
