local NODHeal = _G.NODHeal or {}

local CastSpellByName = CastSpellByName
local IsUsableSpell = IsUsableSpell
local hooksecurefunc = hooksecurefunc
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown

local binds = {
    ["LeftButton"] = "Healing Touch",
    ["RightButton"] = "Regrowth",
    ["Shift-LeftButton"] = "Rejuvenation",
}

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

hooksecurefunc("CompactUnitFrame_OnClick", function(frame, button)
    if not frame or not frame.unit then
        return
    end

    local combo = getKeyCombo(button)
    local spell = binds[combo] or binds[button]

    if spell and CastSpellByName and IsUsableSpell and IsUsableSpell(spell) then
        CastSpellByName(spell, frame.unit)
    end
end)

NODHeal.Bindings = NODHeal.Bindings or {}

function NODHeal.Bindings:Set(combo, spell)
    binds[combo] = spell
end

function NODHeal.Bindings:Get(combo)
    return binds[combo]
end

function NODHeal.Bindings:List()
    return binds
end

_G.NODHeal = NODHeal
