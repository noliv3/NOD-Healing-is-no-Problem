local addonName = ...
local NODHeal = _G.NODHeal

local UI = {}
UI.__index = UI

function UI:Initialize()
    -- Placeholder for upcoming frame creation and overlay logic.
end

return NODHeal:RegisterModule("UI", UI)
