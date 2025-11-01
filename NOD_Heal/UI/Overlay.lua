local overlay = CreateFrame("Frame", "NOD_HealOverlay", UIParent)
overlay:SetAllPoints(UIParent)
overlay:SetFrameStrata("LOW")
overlay:EnableMouse(false)
overlay.bars = {}

function overlay:ShowProjectedHeal(unit, pct)
    print("[NOD] Overlay placeholder:", unit, pct)
end

-- TODO: Attach overlay bars to CompactUnitFrame (Day 3)

_G.NODHeal = _G.NODHeal or {}
_G.NODHeal.Overlay = overlay
