local addon = _G.NODHeal or {}
_G.NODHeal = addon

local ClickCast = addon.ClickCast or {}
addon.ClickCast = ClickCast

local Bindings = addon.Bindings or {}
addon.Bindings = Bindings

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsLoggedIn = IsLoggedIn
local next = next
local pairs = pairs
local tostring = tostring
local type = type
local wipe = wipe

if not wipe then
    wipe = function(tbl)
        if not tbl then
            return
        end
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end
end

local defaultBindings = {
    ["LeftButton"] = "Healing Touch",
    ["RightButton"] = "Regrowth",
    ["Shift-LeftButton"] = "Rejuvenation",
}

local BUTTON_SUFFIX = {
    LeftButton = "1",
    RightButton = "2",
    MiddleButton = "3",
    Button4 = "-button4",
    Button5 = "-button5",
}

local MOD_ORDER = { "Alt", "Ctrl", "Shift" }

local function ensureBindingsStore()
    _G.NODHealDB = _G.NODHealDB or {}
    local store = _G.NODHealDB.bindings
    if type(store) ~= "table" then
        store = {}
        _G.NODHealDB.bindings = store
    end

    if not next(store) then
        for combo, spell in pairs(defaultBindings) do
            store[combo] = spell
        end
    end

    Bindings.data = store
    return store
end

local function parseCombo(combo)
    if type(combo) ~= "string" then
        return { alt = false, ctrl = false, shift = false }, "LeftButton"
    end

    local button = "LeftButton"
    local prefix = combo
    for name in pairs(BUTTON_SUFFIX) do
        if prefix:sub(-#name) == name then
            button = name
            prefix = prefix:sub(1, #prefix - #name)
            break
        end
    end

    prefix = prefix:gsub("-+$", "")

    local mods = { alt = false, ctrl = false, shift = false }
    for token in prefix:gmatch("[^-]+") do
        local lowered = token:lower()
        if lowered == "alt" then
            mods.alt = true
        elseif lowered == "ctrl" then
            mods.ctrl = true
        elseif lowered == "shift" then
            mods.shift = true
        end
    end

    return mods, button
end

local function buildCanonicalCombo(mods, button)
    local parts = {}
    for index = 1, #MOD_ORDER do
        local key = MOD_ORDER[index]
        local flag = mods[key:lower()]
        if flag then
            parts[#parts + 1] = key
        end
    end

    if #parts > 0 then
        parts[#parts + 1] = button
        return table.concat(parts, "-")
    end

    return button
end

local function buildAttributePrefix(mods)
    local prefix = ""
    if mods.alt then
        prefix = prefix .. "alt-"
    end
    if mods.ctrl then
        prefix = prefix .. "ctrl-"
    end
    if mods.shift then
        prefix = prefix .. "shift-"
    end
    return prefix
end

local function buildAttributeKeys(mods, button)
    local suffix = BUTTON_SUFFIX[button]
    if not suffix then
        return nil, nil
    end

    local prefix = buildAttributePrefix(mods)
    local typeKey = prefix .. "type" .. suffix
    local macroKey = prefix .. "macrotext" .. suffix
    return typeKey, macroKey
end

local function canonicalize(combo)
    local mods, button = parseCombo(combo)
    local canonical = buildCanonicalCombo(mods, button)
    return canonical, mods, button
end

function Bindings:Ensure()
    return ensureBindingsStore()
end

function Bindings:Get(combo)
    local store = ensureBindingsStore()
    local canonical = canonicalize(combo)
    return store[canonical]
end

function Bindings:Set(combo, spell)
    local store = ensureBindingsStore()
    local canonical, mods, button = canonicalize(combo)
    if not canonical then
        return
    end

    if spell and spell ~= "" then
        store[canonical] = tostring(spell)
    else
        store[canonical] = nil
    end

    if ClickCast.MarkBindingsDirty then
        ClickCast:MarkBindingsDirty()
    end

    return canonical, mods, button
end

function Bindings:List()
    return ensureBindingsStore()
end

function Bindings:Clear()
    local store = ensureBindingsStore()
    wipe(store)
    return store
end

local function ensureEventFrame()
    if ClickCast._eventFrame then
        return ClickCast._eventFrame
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            Bindings:Ensure()
            ClickCast:ApplyAllBindings()
        elseif event == "PLAYER_REGEN_ENABLED" then
            ClickCast:HandleCombatEnd()
        end
    end)

    ClickCast._eventFrame = frame
    return frame
end

local function isSecure(frame)
    return frame and type(frame.SetAttribute) == "function"
end

function ClickCast:HandleCombatEnd()
    if self._pendingUnits then
        for frame, unit in pairs(self._pendingUnits) do
            if isSecure(frame) then
                frame:SetAttribute("unit", unit)
            end
            self._pendingUnits[frame] = nil
        end
    end

    if self._pendingBindings then
        for frame in pairs(self._pendingBindings) do
            if isSecure(frame) then
                self:ApplyBindingsToFrame(frame)
            end
            self._pendingBindings[frame] = nil
        end
    end

    if self._needsReapply then
        self:ApplyAllBindings()
    end
end

local function ensureTrackingTables()
    ClickCast._frames = ClickCast._frames or {}
    ClickCast._pendingUnits = ClickCast._pendingUnits or {}
    ClickCast._pendingBindings = ClickCast._pendingBindings or {}
end

function ClickCast:RegisterFrame(frame)
    if not isSecure(frame) then
        return
    end

    ensureTrackingTables()
    ensureEventFrame()

    self._frames[frame] = true
    frame._nodBindingKeys = frame._nodBindingKeys or {}

    self:ApplyBindingsToFrame(frame)
end

function ClickCast:SetFrameUnit(frame, unit)
    if not isSecure(frame) then
        return
    end

    ensureTrackingTables()

    if InCombatLockdown and InCombatLockdown() then
        self._pendingUnits[frame] = unit
        return
    end

    self._pendingUnits[frame] = nil
    frame:SetAttribute("unit", unit)
end

local function clearFrameAttributes(frame)
    local keys = frame._nodBindingKeys
    if not keys then
        return
    end

    for index = 1, #keys do
        local attribute = keys[index]
        frame:SetAttribute(attribute, nil)
    end

    wipe(keys)
end

function ClickCast:ApplyBindingsToFrame(frame)
    if not isSecure(frame) then
        return
    end

    ensureTrackingTables()

    if InCombatLockdown and InCombatLockdown() then
        self._pendingBindings[frame] = true
        self._needsReapply = true
        return
    end

    self._pendingBindings[frame] = nil

    clearFrameAttributes(frame)

    -- Fallbacks: target on left click, menu on right click
    frame:SetAttribute("type1", "target")
    frame:SetAttribute("type2", "togglemenu")

    local keys = frame._nodBindingKeys
    local store = Bindings:List()
    for combo, spell in pairs(store) do
        if type(spell) == "string" and spell ~= "" then
            local _, mods, button = canonicalize(combo)
            local typeKey, macroKey = buildAttributeKeys(mods, button)
            if typeKey and macroKey then
                frame:SetAttribute(typeKey, "macro")
                frame:SetAttribute(macroKey, ([[#showtooltip %s
/cast [@mouseover,help,nodead] %s
/stopspelltargeting]]):format(spell, spell))
                keys[#keys + 1] = typeKey
                keys[#keys + 1] = macroKey
            end
        end
    end
end

function ClickCast:ApplyAllBindings()
    ensureTrackingTables()
    ensureEventFrame()

    if InCombatLockdown and InCombatLockdown() then
        self._needsReapply = true
        return
    end

    self._needsReapply = nil
    if not self._frames then
        return
    end

    for frame in pairs(self._frames) do
        if isSecure(frame) then
            self:ApplyBindingsToFrame(frame)
        end
    end
end

function ClickCast:MarkBindingsDirty()
    self._needsReapply = true
    self:ApplyAllBindings()
end

ensureTrackingTables()
ensureEventFrame()

if IsLoggedIn and IsLoggedIn() then
    Bindings:Ensure()
    ClickCast:ApplyAllBindings()
end

addon.Bindings = Bindings
addon.ClickCast = ClickCast

