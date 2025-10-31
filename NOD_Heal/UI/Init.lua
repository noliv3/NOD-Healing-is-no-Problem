local NODHeal = _G.NODHeal

local CreateFrame = CreateFrame
local GetTime = GetTime
local C_Timer = C_Timer
local format = string.format

local UI = {}
UI.__index = UI

function UI:GetState()
    return NODHeal and NODHeal.State
end

function UI:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "NODHealStatusFrame", UIParent)
    frame:SetSize(220, 32)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -30, 120)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.45)

    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.1, 0.1, 0.1, 0.6)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText("[NOD] Quelle: --")

    frame.text = text
    self.frame = frame
    return frame
end

function UI:Refresh()
    local frame = self:EnsureFrame()
    if not frame or not frame.text then
        return
    end

    local state = self:GetState() or {}
    local useLHC = state.useLHC ~= false
    local source = useLHC and "LHC" or "API"
    local color = useLHC and "|cff00ff00" or "|cffffff00"
    local now = GetTime() or 0
    local lastSwitch = state.lastSwitch or now
    local elapsed = now - lastSwitch
    if elapsed < 0 then
        elapsed = 0
    end

    frame.text:SetText(format("%sQuelle: %s|r t=%.3f", color, source, elapsed))
    print(format("[NOD] UI: source=%s t=%.3f", source, elapsed))
end

function UI:Initialize()
    if self.ticker then
        return
    end

    self:EnsureFrame()
    self:Refresh()

    self.ticker = C_Timer.NewTicker(0.5, function()
        self:Refresh()
    end)
end

return NODHeal:RegisterModule("UI", UI)
