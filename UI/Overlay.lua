local _G = _G
local NODHeal = _G.NODHeal or {}
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitGetIncomingHeals = UnitGetIncomingHeals
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc

local function secureHook(name, handler)
    if type(_G[name]) == "function" then
        hooksecurefunc(name, handler)
        return true
    end
    return false
end

local UI = (NODHeal.GetModule and NODHeal:GetModule("UI")) or NODHeal.UI or {}
NODHeal.UI = UI

local function getConfig()
    return (NODHeal and NODHeal.Config) or {}
end

UI.barByFrame = UI.barByFrame or {}

local function ensureBar(frame)
    local existing = UI.barByFrame[frame]
    if existing then
        frame._nodHeal = existing
        return existing
    end

    local hb = frame.healthBar or frame.healthbar or frame.health
    if not hb then
        return nil
    end

    local tex = hb:CreateTexture(nil, "OVERLAY")
    tex:SetPoint("LEFT", hb, "LEFT", 0, 0)
    tex:SetHeight(hb:GetHeight() or 0)
    tex:SetColorTexture(0, 1, 0, 0.35)
    tex:SetWidth(0)
    tex:Hide()

    frame._nodHeal = tex

    UI.barByFrame[frame] = tex
    return tex
end

local function hideBar(frame)
    local tex = UI.barByFrame[frame]
    if tex then
        tex:SetWidth(0)
        tex:Hide()
    end
end

local function isOverlayEnabled()
    local cfg = getConfig()
    return cfg.overlay ~= false
end

local function fetchIncoming(unit, guid, horizon)
    local incoming = 0
    local core = NODHeal.Core
    local provider = core and core.Incoming
    if provider and provider.GetIncomingForGUID then
        local ok, value = pcall(provider.GetIncomingForGUID, provider, guid, horizon)
        if ok and type(value) == "number" then
            incoming = value
        end
    end

    if incoming <= 0 then
        incoming = UnitGetIncomingHeals and UnitGetIncomingHeals(unit) or 0
    end

    return incoming or 0
end

local function showProjection(frame, hb, cur, incoming, max)
    local tex = ensureBar(frame)
    if not tex then
        return
    end

    local baseWidth = hb:GetWidth() or 0
    if baseWidth <= 0 then
        hideBar(frame)
        return
    end

    local pct = (cur + incoming) / max
    if pct <= 0 then
        hideBar(frame)
        return
    end

    tex:SetHeight(hb:GetHeight() or 0)
    tex:SetWidth(baseWidth * math.min(pct, 1))
    tex:Show()
end

local function refreshAll()
    for frame in pairs(UI.barByFrame) do
        if frame and frame.unit then
            if isOverlayEnabled() and frame:IsShown() then
                local updater = _G.CompactUnitFrame_UpdateHealth
                if type(updater) == "function" then
                    updater(frame)
                end
            else
                hideBar(frame)
            end
        end
    end
end

secureHook("CompactUnitFrame_UpdateHealth", function(frame)
    if not frame then
        return
    end

    if not isOverlayEnabled() then
        hideBar(frame)
        return
    end

    if not frame.unit or not UnitExists(frame.unit) then
        hideBar(frame)
        return
    end

    local hb = frame.healthBar or frame.healthbar or frame.health
    if not hb then
        hideBar(frame)
        return
    end

    local cur = UnitHealth and UnitHealth(frame.unit) or 0
    local max = UnitHealthMax and UnitHealthMax(frame.unit) or 1
    if not max or max <= 0 then
        hideBar(frame)
        return
    end

    local guid = UnitGUID and UnitGUID(frame.unit)
    if not guid then
        hideBar(frame)
        return
    end

    local horizon = (GetTime and GetTime() or 0) + 1.5
    local incoming = fetchIncoming(frame.unit, guid, horizon)
    if incoming <= 0 then
        hideBar(frame)
        return
    end

    local projected = cur + incoming
    if projected <= cur then
        hideBar(frame)
        return
    end

    if projected > max then
        projected = max
    end

    local gain = projected - cur
    if not gain or gain <= 0 then
        hideBar(frame)
        return
    end

    showProjection(frame, hb, cur, gain, max)
end)

secureHook("CompactUnitFrame_UpdateVisible", function(frame)
    if not frame or not frame:IsShown() or not isOverlayEnabled() then
        hideBar(frame)
    end
end)

local function fadeIn(frame)
    if frame and frame.healthBar then
        frame.healthBar:SetAlpha(0.8)
    end
end

if type(CompactUnitFrame_OnEnter) == "function" then
    secureHook("CompactUnitFrame_OnEnter", function(frame)
        fadeIn(frame)

        if frame and frame.unit then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetUnit(frame.unit)
            GameTooltip:Show()
        end
    end)
else
    -- Classic fallback: hook GridFrames manually
    local grid = NODHeal and NODHeal.Grid and NODHeal.Grid.unitFrames
    if grid then
        for _, f in pairs(grid) do
            f:SetScript("OnEnter", function(self)
                fadeIn(self)
                if self.unit then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetUnit(self.unit)
                    GameTooltip:Show()
                end
            end)
            f:SetScript("OnLeave", function(self)
                if self and self.healthBar then
                    self.healthBar:SetAlpha(1)
                end
                GameTooltip_Hide()
            end)
        end
    end
end

secureHook("CompactUnitFrame_OnLeave", function(frame)
    if frame and frame.healthBar then
        frame.healthBar:SetAlpha(1)
    end
    GameTooltip_Hide()
end)

function UI.EnableOverlay(on)
    local cfg = getConfig()
    cfg.overlay = not not on

    if cfg.overlay then
        refreshAll()
    else
        for frame in pairs(UI.barByFrame) do
            hideBar(frame)
        end
    end
end

UI.RefreshOverlay = refreshAll

if NODHeal and NODHeal.ClickCast and NODHeal.ClickCast.RegisterExtraFrames then
    NODHeal.ClickCast.RegisterExtraFrames()
end
