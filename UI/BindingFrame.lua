local addon = _G.NODHeal or {}
local BindUI = {}
addon.BindUI = BindUI

local CreateFrame = CreateFrame
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local GetCursorInfo = GetCursorInfo
local ClearCursor = ClearCursor
local GetNumSpellTabs = GetNumSpellTabs
local GetSpellTabInfo = GetSpellTabInfo
local GetSpellBookItemName = GetSpellBookItemName
local GetSpellBookItemInfo = GetSpellBookItemInfo
local GetSpellInfo = GetSpellInfo
local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert
local sort = table.sort
local wipe = wipe
local format = string.format

local frame
local scrollFrame
local scrollContent
local addButton
local spellListFrame
local spellListScroll
local spellListContent
local spellButtons = {}
local rows = {}
local activeRow
local cachedSpells

local MOUSE_BUTTON_OPTIONS = {
    { key = "LeftButton", label = "Left Button" },
    { key = "RightButton", label = "Right Button" },
    { key = "MiddleButton", label = "Middle Button" },
    { key = "Button4", label = "Button 4" },
    { key = "Button5", label = "Button 5" },
}

local MODIFIER_OPTIONS = {
    { key = "", label = "No Modifier" },
    { key = "Alt-", label = "Alt" },
    { key = "Ctrl-", label = "Ctrl" },
    { key = "Shift-", label = "Shift" },
    { key = "Alt-Ctrl-", label = "Alt+Ctrl" },
    { key = "Alt-Shift-", label = "Alt+Shift" },
    { key = "Ctrl-Shift-", label = "Ctrl+Shift" },
    { key = "Alt-Ctrl-Shift-", label = "Alt+Ctrl+Shift" },
}

local ROW_HEIGHT = 52

local function getBindingAPI()
    if addon and addon.Bindings then
        return addon.Bindings
    end
end

local function canonicalizeModifier(prefix)
    if not prefix or prefix == "" then
        return ""
    end

    local hasAlt = prefix:find("Alt%-") ~= nil
    local hasCtrl = prefix:find("Ctrl%-") ~= nil
    local hasShift = prefix:find("Shift%-") ~= nil

    local result = ""
    if hasAlt then
        result = result .. "Alt-"
    end
    if hasCtrl then
        result = result .. "Ctrl-"
    end
    if hasShift then
        result = result .. "Shift-"
    end

    return result
end

local function splitCombo(combo)
    if not combo or combo == "" then
        return "", "LeftButton"
    end

    for _, option in ipairs(MOUSE_BUTTON_OPTIONS) do
        if combo:sub(-#option.key) == option.key then
            local prefix = combo:sub(1, #combo - #option.key)
            prefix = canonicalizeModifier(prefix)
            return prefix or "", option.key
        end
    end

    return canonicalizeModifier(combo), "LeftButton"
end

local function composeCombo(modKey, buttonKey)
    return (modKey or "") .. (buttonKey or "")
end

local function ensureUIStore()
    _G.NODHealDB = _G.NODHealDB or {}
    _G.NODHealDB.ui = _G.NODHealDB.ui or {}
    return _G.NODHealDB.ui
end

local function saveFramePosition(target)
    if not target then
        return
    end

    local uiStore = ensureUIStore()
    uiStore.bindingFrame = uiStore.bindingFrame or {}

    local point, relativeTo, relativePoint, xOfs, yOfs = target:GetPoint(1)
    uiStore.bindingFrame.point = point
    uiStore.bindingFrame.relativePoint = relativePoint
    uiStore.bindingFrame.x = xOfs
    uiStore.bindingFrame.y = yOfs
end

local function restoreFramePosition(target)
    if not target then
        return
    end

    local uiStore = ensureUIStore()
    local position = uiStore.bindingFrame
    if position and position.point and position.relativePoint then
        target:ClearAllPoints()
        target:SetPoint(position.point, UIParent, position.relativePoint, position.x or 0, position.y or 0)
    else
        target:SetPoint("CENTER")
    end
end

local function getSpellList()
    if cachedSpells then
        return cachedSpells
    end

    cachedSpells = {}
    local seen = {}

    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = 1, numSpells do
            local index = offset + i
            local spellName = GetSpellBookItemName(index, BOOKTYPE_SPELL)
            local spellType = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
            if spellType == "SPELL" and spellName and spellName ~= "" and not seen[spellName] then
                seen[spellName] = true
                tinsert(cachedSpells, spellName)
            end
        end
    end

    sort(cachedSpells)
    return cachedSpells
end

local function invalidateSpellCache()
    if cachedSpells then
        wipe(cachedSpells)
        cachedSpells = nil
    end
end

local function highlightRow(row, state)
    if not row or not row.highlight then
        return
    end

    if state then
        row.highlight:Show()
    else
        row.highlight:Hide()
    end
end

local function findRowByCombo(combo, ignoreRow)
    for _, row in ipairs(rows) do
        if row.comboKey == combo and row ~= ignoreRow then
            return row
        end
    end
end

local function updateBinding(combo, spell)
    local bindingAPI = getBindingAPI()
    if not bindingAPI or not bindingAPI.Set then
        return
    end

    if spell and spell ~= "" then
        bindingAPI:Set(combo, spell)
    else
        bindingAPI:Set(combo, nil)
    end
end

local function fetchBinding(combo)
    local bindingAPI = getBindingAPI()
    if not bindingAPI or not bindingAPI.Get then
        return nil
    end

    return bindingAPI:Get(combo)
end

local function getDisplayName(spell)
    if not spell or spell == "" then
        return "Select Spell"
    end

    return spell
end

local function handleDropdownSelection(dropdown, value, text)
    UIDropDownMenu_SetSelectedValue(dropdown, value)
    UIDropDownMenu_SetText(dropdown, text)
    dropdown._value = value
end

local function refreshRowDisplay(row)
    if not row or not row.spellButton then
        return
    end

    row.spellButton:SetText(getDisplayName(row.spell))
    row.spellButton:SetEnabled(row.comboKey ~= nil)
end

local function handleSpellAssignment(row, spellName)
    if not row then
        return
    end

    row.spell = spellName or ""
    refreshRowDisplay(row)
    if row.comboKey then
        updateBinding(row.comboKey, row.spell)
    end
end

local function handleSpellDrop(row)
    if not row then
        return
    end

    local cursorType, param1, param2 = GetCursorInfo()
    if cursorType == "spell" then
        local spellName = GetSpellInfo(param1, param2)
        if spellName then
            handleSpellAssignment(row, spellName)
            ClearCursor()
        end
    end
end

local function ensureSpellList()
    if spellListFrame then
        return spellListFrame
    end

    spellListFrame = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    spellListFrame:SetSize(220, 420)
    spellListFrame:SetPoint("LEFT", frame, "RIGHT", 12, 0)
    spellListFrame:Hide()

    local title = spellListFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Spellbook")

    spellListScroll = CreateFrame("ScrollFrame", nil, spellListFrame, "UIPanelScrollFrameTemplate")
    spellListScroll:SetPoint("TOPLEFT", 12, -30)
    spellListScroll:SetPoint("BOTTOMRIGHT", -30, 14)

    spellListContent = CreateFrame("Frame", nil, spellListScroll)
    spellListContent:SetSize(180, 380)
    spellListScroll:SetScrollChild(spellListContent)

    return spellListFrame
end

local function setActiveRow(row)
    activeRow = row
end

local function showSpellList(row)
    local list = ensureSpellList()
    setActiveRow(row)
    BindUI:RefreshSpellList()
    list:Show()
end

local function hideSpellList()
    if spellListFrame then
        spellListFrame:Hide()
    end
    setActiveRow(nil)
end

local function createSpellButton(index)
    local button = spellButtons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, spellListContent, "UIPanelButtonTemplate")
    button:SetSize(160, 22)
    button:SetScript("OnClick", function(self)
        if activeRow and self.spellName then
            handleSpellAssignment(activeRow, self.spellName)
            hideSpellList()
        end
    end)

    button:SetScript("OnEnter", function(self)
        if self.hover then
            self.hover:Show()
        end
    end)

    button:SetScript("OnLeave", function(self)
        if self.hover then
            self.hover:Hide()
        end
    end)

    button.hover = button:CreateTexture(nil, "BACKGROUND")
    button.hover:SetAllPoints()
    button.hover:SetColorTexture(0.1, 0.6, 1, 0.25)
    button.hover:Hide()

    spellButtons[index] = button
    return button
end

local function layoutSpellButtons(spells)
    if not spellListContent then
        return
    end

    local offsetY = -6
    for index, name in ipairs(spells) do
        local button = createSpellButton(index)
        button:ClearAllPoints()
        button:SetPoint("TOP", 0, offsetY)
        button:SetText(name)
        button.spellName = name
        button:Show()
        offsetY = offsetY - 24
    end

    for i = #spells + 1, #spellButtons do
        local button = spellButtons[i]
        if button then
            button:Hide()
            button.spellName = nil
        end
    end

    local height = (#spells * 24) + 20
    spellListContent:SetHeight(height)
end

local function findFirstAvailableCombo()
    for _, modOption in ipairs(MODIFIER_OPTIONS) do
        for _, buttonOption in ipairs(MOUSE_BUTTON_OPTIONS) do
            local combo = composeCombo(modOption.key, buttonOption.key)
            if not findRowByCombo(combo) and not fetchBinding(combo) then
                return modOption.key, buttonOption.key
            end
        end
    end

    return "", "LeftButton"
end

local function initializeDropdown(dropdown, options, onSelect)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        if not level then
            return
        end

        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.key
            info.func = function()
                onSelect(option.key, option.label)
            end
            info.checked = dropdown._value == option.key
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

local function setDropdownValue(dropdown, value, options)
    for _, option in ipairs(options) do
        if option.key == value then
            handleDropdownSelection(dropdown, option.key, option.label)
            return
        end
    end

    local default = options[1]
    handleDropdownSelection(dropdown, default.key, default.label)
end

local function clearBinding(row)
    if row and row.comboKey then
        updateBinding(row.comboKey, nil)
    end
    if row then
        row.spell = ""
        refreshRowDisplay(row)
    end
end

local function createRow(modKey, buttonKey, spellName)
    if not scrollContent then
        return
    end

    local row = CreateFrame("Frame", nil, scrollContent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT")
    row:SetPoint("RIGHT")
    row:EnableMouse(true)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(0.1, 0.7, 1, 0.15)
    row.highlight:Hide()

    row:SetScript("OnEnter", function(self)
        highlightRow(self, true)
    end)
    row:SetScript("OnLeave", function(self)
        highlightRow(self, false)
    end)

    local modifierLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modifierLabel:SetPoint("TOPLEFT", 10, -6)
    modifierLabel:SetText("Modifier")

    local modifierDropdown = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    modifierDropdown:SetPoint("TOPLEFT", modifierLabel, "BOTTOMLEFT", -12, -4)
    UIDropDownMenu_SetWidth(modifierDropdown, 120)

    local buttonLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buttonLabel:SetPoint("TOPLEFT", modifierDropdown, "TOPRIGHT", 6, 6)
    buttonLabel:SetText("Mouse Button")

    local buttonDropdown = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    buttonDropdown:SetPoint("TOPLEFT", buttonLabel, "BOTTOMLEFT", -12, -4)
    UIDropDownMenu_SetWidth(buttonDropdown, 120)

    local spellButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    spellButton:SetSize(160, 24)
    spellButton:SetPoint("TOPLEFT", buttonDropdown, "TOPRIGHT", 8, -2)
    spellButton:SetText("Select Spell")

    spellButton:RegisterForDrag("LeftButton")
    spellButton:SetScript("OnReceiveDrag", function()
        handleSpellDrop(row)
    end)
    spellButton:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            local cursorType = GetCursorInfo()
            if cursorType then
                handleSpellDrop(row)
            else
                showSpellList(row)
            end
        end
    end)

    spellButton:SetScript("OnEnter", function(self)
        highlightRow(row, true)
    end)
    spellButton:SetScript("OnLeave", function(self)
        highlightRow(row, false)
    end)

    local clearButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    clearButton:SetSize(60, 22)
    clearButton:SetPoint("LEFT", spellButton, "RIGHT", 6, 0)
    clearButton:SetText("Clear")
    clearButton:SetScript("OnClick", function()
        clearBinding(row)
    end)

    row.modDropdown = modifierDropdown
    row.buttonDropdown = buttonDropdown
    row.spellButton = spellButton
    row.clearButton = clearButton
    row.modifier = canonicalizeModifier(modKey)
    row.button = buttonKey or "LeftButton"
    row.spell = spellName or ""
    row.comboKey = composeCombo(row.modifier, row.button)

    initializeDropdown(modifierDropdown, MODIFIER_OPTIONS, function(value, label)
        if findRowByCombo(composeCombo(value, row.button), row) then
            print(format("[NOD] Binding %s%s already used.", value, row.button))
            setDropdownValue(modifierDropdown, row.modifier, MODIFIER_OPTIONS)
            return
        end

        local previousCombo = row.comboKey
        row.modifier = value
        row.comboKey = composeCombo(row.modifier, row.button)
        if previousCombo ~= row.comboKey then
            updateBinding(previousCombo, nil)
        end
        if row.spell and row.spell ~= "" then
            updateBinding(row.comboKey, row.spell)
        end
        setDropdownValue(modifierDropdown, value, MODIFIER_OPTIONS)
        refreshRowDisplay(row)
    end)

    initializeDropdown(buttonDropdown, MOUSE_BUTTON_OPTIONS, function(value, label)
        if findRowByCombo(composeCombo(row.modifier, value), row) then
            print(format("[NOD] Binding %s%s already used.", row.modifier, value))
            setDropdownValue(buttonDropdown, row.button, MOUSE_BUTTON_OPTIONS)
            return
        end

        local previousCombo = row.comboKey
        row.button = value
        row.comboKey = composeCombo(row.modifier, row.button)
        if previousCombo ~= row.comboKey then
            updateBinding(previousCombo, nil)
        end
        if row.spell and row.spell ~= "" then
            updateBinding(row.comboKey, row.spell)
        end
        setDropdownValue(buttonDropdown, value, MOUSE_BUTTON_OPTIONS)
        refreshRowDisplay(row)
    end)

    setDropdownValue(modifierDropdown, row.modifier, MODIFIER_OPTIONS)
    setDropdownValue(buttonDropdown, row.button, MOUSE_BUTTON_OPTIONS)
    refreshRowDisplay(row)

    tinsert(rows, row)
    return row
end

local function layoutRows()
    if not scrollContent then
        return
    end

    local anchorY = -6
    for index, row in ipairs(rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 6, anchorY)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -6, anchorY)
        anchorY = anchorY - ROW_HEIGHT
    end

    local height = (#rows * ROW_HEIGHT) + 12
    scrollContent:SetHeight(height)
end

function BindUI:RefreshSpellList()
    local list = ensureSpellList()
    if not list or not spellListContent then
        return
    end

    local spells = getSpellList()
    layoutSpellButtons(spells)
end

function BindUI:AddRow(modKey, buttonKey, spellName)
    local row = createRow(modKey, buttonKey, spellName)
    if row then
        layoutRows()
    end
    return row
end

function BindUI:EnsureInitialRows()
    local bindingAPI = getBindingAPI()
    local existing = bindingAPI and bindingAPI.List and bindingAPI:List() or {}

    local added = false
    local seen = {}
    if existing then
        local ordered = {}
        for combo, spell in pairs(existing) do
            tinsert(ordered, { combo = combo, spell = spell })
        end
        sort(ordered, function(a, b)
            return a.combo < b.combo
        end)

        for _, entry in ipairs(ordered) do
            local modifier, button = splitCombo(entry.combo)
            local canonicalCombo = composeCombo(modifier, button)
            if not seen[canonicalCombo] then
                if canonicalCombo ~= entry.combo then
                    updateBinding(entry.combo, nil)
                    updateBinding(canonicalCombo, entry.spell)
                end
                self:AddRow(modifier, button, entry.spell)
                seen[canonicalCombo] = true
                added = true
            end
        end
    end

    if not added then
        local defaultMod, defaultButton = findFirstAvailableCombo()
        self:AddRow(defaultMod, defaultButton, "")
    end

    layoutRows()
end

function BindUI:RefreshRowsFromBindings()
    local bindingAPI = getBindingAPI()
    if not bindingAPI or not bindingAPI.List then
        return
    end

    local data = bindingAPI:List()
    for _, row in ipairs(rows) do
        row.spell = data[row.comboKey] or ""
        refreshRowDisplay(row)
    end
end

function BindUI:ClearAll()
    for _, row in ipairs(rows) do
        clearBinding(row)
    end
end

local function onFrameShow()
    BindUI:RefreshRowsFromBindings()
    BindUI:RefreshSpellList()
end

function BindUI:Create()
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", "NODHeal_BindingsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(520, 480)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveFramePosition(self)
    end)
    frame:SetScript("OnShow", onFrameShow)
    frame:SetScript("OnHide", function()
        hideSpellList()
    end)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    restoreFramePosition(frame)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", 0, -8)
    frame.title:SetText("NOD-Heal: Spell Bindings")

    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 16, -36)
    infoText:SetText("Drag spells here or pick from the list.")

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -34, 50)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(440, 360)
    scrollFrame:SetScrollChild(scrollContent)

    addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addButton:SetSize(110, 24)
    addButton:SetPoint("BOTTOMLEFT", 16, 16)
    addButton:SetText("Add Binding")
    addButton:SetScript("OnClick", function()
        local modKey, buttonKey = findFirstAvailableCombo()
        BindUI:AddRow(modKey, buttonKey, fetchBinding(composeCombo(modKey, buttonKey)) or "")
        layoutRows()
        if PlaySound and SOUNDKIT then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 24)
    closeButton:SetPoint("BOTTOMRIGHT", -16, 16)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:RegisterEvent("SPELLS_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" then
            invalidateSpellCache()
            if spellListFrame and spellListFrame:IsShown() then
                BindUI:RefreshSpellList()
            end
        end
    end)

    self:EnsureInitialRows()
    frame:Hide()

    return frame
end

function BindUI:Toggle()
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
