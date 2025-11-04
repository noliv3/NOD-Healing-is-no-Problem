local NODHeal = _G.NODHeal or {}

if not NODHeal.Bindings then
    NODHeal.Bindings = {}
end

-- Load saved bindings from DB
local bindingsLoaded = false

local function loadBindings()
    if bindingsLoaded then
        return
    end

    if NODHealDB and type(NODHealDB.bindings) == "table" then
        NODHeal.Bindings.data = NODHealDB.bindings
        bindingsLoaded = true
        print("[NOD] Loaded saved spell bindings")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", loadBindings)

if IsLoggedIn and IsLoggedIn() then
    loadBindings()
end

local CastSpellByName = CastSpellByName
local IsUsableSpell = IsUsableSpell
local hooksecurefunc = hooksecurefunc
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown

local defaultBindings = {
    ["LeftButton"] = "Healing Touch",
    ["RightButton"] = "Regrowth",
    ["Shift-LeftButton"] = "Rejuvenation",
}

local ClickCast = NODHeal.ClickCast or {}
NODHeal.ClickCast = ClickCast

local function ensureBindingsStore()
    if not NODHeal.Bindings.data then
        local store = {}
        for combo, spell in pairs(defaultBindings) do
            store[combo] = spell
        end
        NODHeal.Bindings.data = store
    end

    return NODHeal.Bindings.data
end

local function getKeyCombo(button)
    local prefix = ""

    if IsAltKeyDown and IsAltKeyDown() then
        prefix = prefix .. "Alt-"
    end

    if IsControlKeyDown and IsControlKeyDown() then
        prefix = prefix .. "Ctrl-"
    end

    if IsShiftKeyDown and IsShiftKeyDown() then
        prefix = prefix .. "Shift-"
    end

    return prefix .. (button or "")
end

local function resolveHealthBar(frame)
    if not frame then
        return nil
    end

    return frame.healthBar or frame.healthbar or frame.health or frame.HealthBar
end

local function highlightFrame(frame, on)
    local bar = resolveHealthBar(frame)
    if not bar then
        return
    end

    if on then
        if not bar._nodBorder then
            bar._nodBorder = bar:CreateTexture(nil, "OVERLAY")
            bar._nodBorder:SetAllPoints(bar)
        end

        if (IsShiftKeyDown and IsShiftKeyDown()) or (IsAltKeyDown and IsAltKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then
            bar._nodBorder:SetColorTexture(0.2, 0.6, 1, 0.4)
        else
            bar._nodBorder:SetColorTexture(0, 1, 0, 0.25)
        end

        bar._nodBorder:Show()
    elseif bar._nodBorder then
        bar._nodBorder:Hide()
    end
end

if type(CompactUnitFrame_OnEnter) == "function" then
    hooksecurefunc("CompactUnitFrame_OnEnter", function(frame)
        if not frame then
            return
        end

        highlightFrame(frame, true)

        if frame.unit then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetUnit(frame.unit)
            GameTooltip:Show()
        end
    end)
else
    -- Classic fallback: hook GridFrames manually
    local grid = NODHeal.Grid and NODHeal.Grid.unitFrames
    if grid then
        for _, f in pairs(grid) do
            f:SetScript("OnEnter", function(self)
                highlightFrame(self, true)
                if self.unit then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetUnit(self.unit)
                    GameTooltip:Show()
                end
            end)
            f:SetScript("OnLeave", function(self)
                highlightFrame(self, false)
                GameTooltip_Hide()
            end)
        end
    end
end

hooksecurefunc("CompactUnitFrame_OnLeave", function(frame)
    highlightFrame(frame, false)
    GameTooltip_Hide()
end)

hooksecurefunc("CompactUnitFrame_OnClick", function(frame, button)
    if not frame or not frame.unit then
        return
    end

    local combo = getKeyCombo(button)
    local spell = NODHeal.Bindings:Get(combo) or NODHeal.Bindings:Get(button)

    if spell and CastSpellByName and IsUsableSpell and IsUsableSpell(spell) then
        CastSpellByName(spell, frame.unit)
        highlightFrame(frame, false)
    end
end)

local function registerExtraFrames()
    for _, name in ipairs({ "PlayerFrame", "PartyFrame", "RaidFrameContainer" }) do
        local f = _G[name]
        if f and not f._nodHooked then
            f:HookScript("OnEnter", function(self)
                highlightFrame(self, true)
            end)
            f:HookScript("OnLeave", function(self)
                highlightFrame(self, false)
            end)
            f._nodHooked = true
        end
    end
end

registerExtraFrames()
ClickCast.RegisterExtraFrames = registerExtraFrames

function NODHeal.Bindings:Set(combo, spell)
    local store = ensureBindingsStore()
    store[combo] = spell
end

function NODHeal.Bindings:Get(combo)
    local store = ensureBindingsStore()
    return store[combo]
end

function NODHeal.Bindings:List()
    return ensureBindingsStore()
end

_G.NODHeal = NODHeal
