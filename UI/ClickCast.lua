local NODHeal = _G.NODHeal or {}

local CastSpellByName = CastSpellByName
local IsUsableSpell = IsUsableSpell
local hooksecurefunc = hooksecurefunc

local binds = {
    ["LeftButton"] = "Healing Touch",
    ["RightButton"] = "Regrowth",
    ["Shift-LeftButton"] = "Rejuvenation",
}

hooksecurefunc("CompactUnitFrame_OnClick", function(frame, button)
    if not frame or not frame.unit then
        return
    end

    local spell = binds[button]
    if not spell then
        return
    end

    if CastSpellByName and IsUsableSpell and IsUsableSpell(spell) then
        CastSpellByName(spell, frame.unit)
    end
end)

NODHeal.Bindings = NODHeal.Bindings or {}

function NODHeal.Bindings:Set(button, spell)
    binds[button] = spell
end

function NODHeal.Bindings:Get(button)
    return binds[button]
end

function NODHeal.Bindings:List()
    return binds
end

_G.NODHeal = NODHeal
