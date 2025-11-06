local Options = {}

NODHeal = NODHeal or {}
NODHeal.Options = Options
NODHeal.Config = NODHeal.Config or {}

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
local InCombatLockdown = InCombatLockdown
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue
local C_Timer = C_Timer
local pairs = pairs
local ipairs = ipairs
local math = math

local iconDefaults = {
    enabled = true,
    hotEnabled = true,
    debuffEnabled = true,
    size = 14,
}

local majorDefaults = {
    enabled = true,
    iconSize = 18,
    maxTotal = 4,
    capDEF = 2,
    capEXT = 1,
    capSELF = 1,
    capABSORB = 1,
    anchor = "TOPLEFT",
    offsetX = 2,
    offsetY = -2,
}

local defaults = (NODHeal and NODHeal.ConfigDefaults) or {
    scale = 1,
    columns = 5,
    spacing = 4,
    bgAlpha = 0.7,
    sortMode = "group",
    showIncoming = true,
    showOverheal = true,
    lockGrid = false,
    icons = iconDefaults,
}

local frame
local sliders = {}
local checkboxes = {}
local iconSliders = {}
local iconCheckboxes = {}
local majorSliders = {}
local majorCheckboxes = {}
local dropdown
local originalConfig

local function ensureConfig()
    if NODHeal and NODHeal.ApplyConfigDefaults then
        NODHeal.ApplyConfigDefaults()
    end

    NODHeal.Config = NODHeal.Config or {}

    local saved = _G.NODHealDB
    if type(saved) ~= "table" then
        saved = {}
        _G.NODHealDB = saved
    end

    saved.config = saved.config or {}

    local config = NODHeal.Config

    for key, defaultValue in pairs(defaults) do
        local stored = saved.config[key]
        if stored == nil then
            if config[key] == nil then
                stored = defaultValue
            else
                stored = config[key]
            end
            saved.config[key] = stored
        end

        config[key] = stored
    end

    config.icons = config.icons or {}
    saved.config.icons = saved.config.icons or {}

    local iconConfig = config.icons
    local savedIcons = saved.config.icons

    for key, defaultValue in pairs(iconDefaults) do
        local stored = savedIcons[key]
        if stored == nil then
            if iconConfig[key] == nil then
                stored = defaultValue
            else
                stored = iconConfig[key]
            end
            savedIcons[key] = stored
        end
        iconConfig[key] = stored
    end

    if config.sortMode == "class" then
        config.sortMode = "role"
        saved.config.sortMode = "role"
    end

    if type(savedIcons.hotWhitelist) ~= "table" then
        savedIcons.hotWhitelist = iconConfig.hotWhitelist or {}
    end
    if type(savedIcons.debuffPrio) ~= "table" then
        savedIcons.debuffPrio = iconConfig.debuffPrio or {}
    end

    iconConfig.hotWhitelist = savedIcons.hotWhitelist
    iconConfig.debuffPrio = savedIcons.debuffPrio

    return config
end

local function copyTrackedConfig(source)
    local snapshot = {}
    if not source then
        return snapshot
    end
    for key in pairs(defaults) do
        local value = source[key]
        if type(value) == "table" then
            local copy = {}
            for k, v in pairs(value) do
                copy[k] = v
            end
            snapshot[key] = copy
        else
            snapshot[key] = value
        end
    end

    local icons = source.icons or {}
    snapshot.icons = {}
    for key in pairs(iconDefaults) do
        snapshot.icons[key] = icons[key]
    end
    if type(icons.hotWhitelist) == "table" then
        local copy = {}
        for k, v in pairs(icons.hotWhitelist) do
            copy[k] = v
        end
        snapshot.icons.hotWhitelist = copy
    end
    if type(icons.debuffPrio) == "table" then
        local copy = {}
        for k, v in pairs(icons.debuffPrio) do
            copy[k] = v
        end
        snapshot.icons.debuffPrio = copy
    end

    local major = source.major or {}
    snapshot.major = {}
    for key in pairs(majorDefaults) do
        snapshot.major[key] = major[key]
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

local function applyIconsNow()
    local function performUpdate()
        if not NODHeal or not NODHeal.UI or not NODHeal.UI.Grid then
            return
        end

        local grid = NODHeal.UI.Grid
        if grid.UpdateAllIconLayout then
            grid.UpdateAllIconLayout()
        end

        if grid.RefreshAllAuraIcons then
            local frames
            if grid.GetTrackedFrames then
                frames = grid.GetTrackedFrames()
            end
            grid.RefreshAllAuraIcons(frames)
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, performUpdate)
        end
    else
        performUpdate()
    end
end

local function saveConfigValue(key, value, silent)
    if InCombatLockdown and InCombatLockdown() then
        log("Cannot change options while in combat", true)
        return
    end

    local config = ensureConfig()
    config[key] = value

    local saved = _G.NODHealDB
    if type(saved) ~= "table" then
        saved = {}
        _G.NODHealDB = saved
    end

    saved.config = saved.config or {}
    saved.config[key] = value

    applyGridRefresh()
    if not silent then
        if NODHeal and NODHeal.Logf then
            NODHeal:Logf(true, "Saved option: %s = %s", key, tostring(value))
        else
            log(string.format("Saved option: %s = %s", key, tostring(value)), true)
        end
    end
end

local function saveIconsConfigValue(key, value, silent)
    if InCombatLockdown and InCombatLockdown() then
        log("Cannot change icon options while in combat", true)
        return
    end

    local config = ensureConfig()
    config.icons = config.icons or {}
    config.icons[key] = value

    local saved = _G.NODHealDB
    if type(saved) ~= "table" then
        saved = {}
        _G.NODHealDB = saved
    end

    saved.config = saved.config or {}
    saved.config.icons = saved.config.icons or {}
    saved.config.icons[key] = value

    applyIconsNow()

    if not silent then
        if NODHeal and NODHeal.Logf then
            NODHeal:Logf(true, "Saved icon option: icons.%s = %s", key, tostring(value))
        else
            log(string.format("Saved icon option: icons.%s = %s", key, tostring(value)), true)
        end
    end
end

local function saveMajorConfigValue(key, value, silent)
    if InCombatLockdown and InCombatLockdown() then
        log("Cannot change major cooldown options while in combat", true)
        return
    end

    local config = ensureConfig()
    config.major = config.major or {}
    config.major[key] = value

    local saved = _G.NODHealDB
    if type(saved) ~= "table" then
        saved = {}
        _G.NODHealDB = saved
    end

    saved.config = saved.config or {}
    saved.config.major = saved.config.major or {}
    saved.config.major[key] = value

    applyIconsNow()

    if not silent then
        if NODHeal and NODHeal.Logf then
            NODHeal:Logf(true, "Saved major option: major.%s = %s", key, tostring(value))
        else
            log(string.format("Saved major option: major.%s = %s", key, tostring(value)), true)
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

local function createIconSlider(parent, label, key, minValue, maxValue, step, decimals)
    local sliderName = "NODHealOptionsIconsSlider" .. key
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
        saveIconsConfigValue(key, rounded)
    end)

    _G[sliderName .. "Low"]:SetText(tostring(minValue))
    _G[sliderName .. "High"]:SetText(tostring(maxValue))

    local iconConfig = ensureConfig().icons or {}
    local currentValue = iconConfig[key] or minValue
    slider._updating = true
    slider:SetValue(currentValue)
    slider._updating = nil
    updateSliderText(slider, currentValue)

    iconSliders[key] = slider
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

local function createIconCheckbox(parent, label, key)
    local checkbox = CreateFrame("CheckButton", "NODHealOptionsIconsCheck" .. key, parent, "ChatConfigCheckButtonTemplate")
    checkbox.Text:SetText(label)
    checkbox:SetScript("OnClick", function(self)
        if self._updating then
            return
        end
        saveIconsConfigValue(key, self:GetChecked() and true or false)
    end)
    iconCheckboxes[key] = checkbox
    return checkbox
end

local function createMajorCheckbox(parent, label, key)
    local checkbox = CreateFrame("CheckButton", "NODHealOptionsMajorCheck" .. key, parent, "ChatConfigCheckButtonTemplate")
    checkbox.Text:SetText(label)
    checkbox:SetScript("OnClick", function(self)
        if self._updating then
            return
        end
        saveMajorConfigValue(key, self:GetChecked() and true or false)
    end)
    majorCheckboxes[key] = checkbox
    return checkbox
end

local function createMajorSlider(parent, label, key, minValue, maxValue, step, decimals)
    local sliderName = "NODHealOptionsMajorSlider" .. key
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider._label = label
    slider._decimals = decimals or 0
    slider:SetScript("OnValueChanged", function(self, value)
        if self._updating then
            return
        end
        local rounded = value
        if not decimals or decimals == 0 then
            rounded = math.floor(value + 0.5)
        end
        updateSliderText(self, rounded)
        saveMajorConfigValue(key, rounded)
    end)

    _G[sliderName .. "Low"]:SetText(tostring(minValue))
    _G[sliderName .. "High"]:SetText(tostring(maxValue))

    local majorConfig = ensureConfig().major or {}
    local currentValue = majorConfig[key] or minValue
    slider._updating = true
    slider:SetValue(currentValue)
    slider._updating = nil
    updateSliderText(slider, currentValue)

    majorSliders[key] = slider
    return slider
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
        if key ~= "icons" and defaults[key] ~= nil then
            saveConfigValue(key, value, true)
        end
    end

    if snapshot.icons then
        for key, value in pairs(snapshot.icons) do
            if iconDefaults[key] ~= nil then
                saveIconsConfigValue(key, value, true)
            end
        end
    end

    if snapshot.major then
        for key, value in pairs(snapshot.major) do
            if majorDefaults[key] ~= nil then
                saveMajorConfigValue(key, value, true)
            end
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

    local iconConfig = config.icons or {}
    for key, checkbox in pairs(iconCheckboxes) do
        checkbox._updating = true
        checkbox:SetChecked(iconConfig[key] and true or false)
        checkbox._updating = nil
    end

    for key, slider in pairs(iconSliders) do
        local value = iconConfig[key] or iconDefaults[key]
        slider._updating = true
        slider:SetValue(value)
        slider._updating = nil
        updateSliderText(slider, value)
    end

    local majorConfig = config.major or {}
    for key, checkbox in pairs(majorCheckboxes) do
        checkbox._updating = true
        checkbox:SetChecked(majorConfig[key] and true or false)
        checkbox._updating = nil
    end

    for key, slider in pairs(majorSliders) do
        local value = majorConfig[key] or majorDefaults[key]
        slider._updating = true
        slider:SetValue(value)
        slider._updating = nil
        updateSliderText(slider, value)
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
    frame:SetSize(420, 520)
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

    local y = -40

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
    y = y - 40

    local iconsHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconsHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
    iconsHeader:SetText("Corner Icons")
    y = y - 26

    local iconsEnableCheck = createIconCheckbox(frame, "Enable corner icons", "enabled")
    iconsEnableCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
    y = y - 26

    local hotCheck = createIconCheckbox(frame, "Show HoT (top-right)", "hotEnabled")
    hotCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
    y = y - 26

    local debuffCheck = createIconCheckbox(frame, "Show Debuff (bottom-left)", "debuffEnabled")
    debuffCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
    y = y - 26

    local majorHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    majorHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
    majorHeader:SetText("Major Cooldown Lane")
    y = y - 24

    local majorEnableCheck = createMajorCheckbox(frame, "Show major cooldowns", "enabled")
    majorEnableCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
    y = y - 26

    local majorSizeSlider = createMajorSlider(frame, "Major icon size", "iconSize", 14, 24, 1, 0)
    majorSizeSlider:SetPoint("TOP", frame, "TOP", 0, y)
    y = y - 70

    local iconSizeSlider = createIconSlider(frame, "HoT icon size", "size", 8, 20, 1, 0)
    iconSizeSlider:SetPoint("TOP", frame, "TOP", 0, y)

    local sortDropdown = createDropdown(frame, "Sort Mode", "sortMode", { "group", "alpha", "role" })
    sortDropdown:SetPoint("TOP", iconSizeSlider, "BOTTOM", 0, -40)

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
