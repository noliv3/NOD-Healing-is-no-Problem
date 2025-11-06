local _G = _G
local NODHeal = _G.NODHeal or {}
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitGetIncomingHeals = UnitGetIncomingHeals
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
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

local solverModule
local landingModule
local desyncModule

local function getSolverModule()
    if solverModule and solverModule.CalculateProjectedHealth then
        return solverModule
    end

    local core = NODHeal and NODHeal.Core
    if core and core.PredictiveSolver and core.PredictiveSolver.CalculateProjectedHealth then
        solverModule = core.PredictiveSolver
        return solverModule
    end

    if NODHeal and NODHeal.GetModule then
        local module = NODHeal:GetModule("PredictiveSolver")
        if module and module.CalculateProjectedHealth then
            solverModule = module
            if core then
                core.PredictiveSolver = module
            end
            return solverModule
        end
    end

    return nil
end

local function getLandingModule()
    if landingModule and landingModule.ComputeLandingTime then
        return landingModule
    end

    local core = NODHeal and NODHeal.Core
    if core and core.CastLandingTime and core.CastLandingTime.ComputeLandingTime then
        landingModule = core.CastLandingTime
        return landingModule
    end

    if NODHeal and NODHeal.GetModule then
        local module = NODHeal:GetModule("CastLandingTime")
        if module and module.ComputeLandingTime then
            landingModule = module
            if core then
                core.CastLandingTime = module
            end
            return landingModule
        end
    end

    return nil
end

local function getDesyncModule()
    if desyncModule and desyncModule.IsFrozen then
        return desyncModule
    end

    local core = NODHeal and NODHeal.Core
    if core and core.DesyncGuard and core.DesyncGuard.IsFrozen then
        desyncModule = core.DesyncGuard
        return desyncModule
    end

    if NODHeal and NODHeal.GetModule then
        local module = NODHeal:GetModule("DesyncGuard")
        if module and module.IsFrozen then
            desyncModule = module
            if core then
                core.DesyncGuard = module
            end
            return desyncModule
        end
    end

    return nil
end

local function computeLandingForUnit(unit)
    if not UnitExists or not unit or not UnitExists(unit) then
        return nil, nil
    end

    local module = getLandingModule()
    if not module or not module.ComputeLandingTime then
        return nil, nil
    end

    local startMS, endMS, spellID

    if UnitCastingInfo then
        local name, _, _, castStart, castEnd, _, castID, _, castSpellID = UnitCastingInfo(unit)
        if name and castStart and castEnd and castEnd > castStart then
            startMS = castStart
            endMS = castEnd
            spellID = castSpellID or castID or spellID
        end
    end

    if (not startMS or not endMS) and UnitChannelInfo then
        local name, _, _, chanStart, chanEnd, _, _, channelSpellID = UnitChannelInfo(unit)
        if name and chanStart and chanEnd and chanEnd > chanStart then
            startMS = chanStart
            endMS = chanEnd
            spellID = channelSpellID or spellID
        end
    end

    if not startMS or not endMS or endMS <= startMS then
        return nil, nil
    end

    local castSeconds = (endMS - startMS) / 1000
    if castSeconds < 0 then
        return nil, nil
    end

    local landing = module.ComputeLandingTime(spellID, castSeconds, startMS)
    if not landing then
        return nil, nil
    end

    return landing, spellID
end

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

local function computeSolverProjection(unit)
    local solver = getSolverModule()
    if not solver or not solver.CalculateProjectedHealth then
        return nil
    end

    local opts
    local tLand, spellID = computeLandingForUnit(unit)
    if tLand or spellID then
        opts = {}
        if tLand then
            opts.tLand = tLand
        end
        if spellID then
            opts.spellID = spellID
        end
    end

    local telemetry = NODHeal and NODHeal.Telemetry
    if telemetry and telemetry.Increment then
        telemetry:Increment("solverCalls")
    end
    local ok, result
    if opts then
        ok, result = pcall(solver.CalculateProjectedHealth, unit, opts)
    else
        ok, result = pcall(solver.CalculateProjectedHealth, unit)
    end

    if not ok or type(result) ~= "table" then
        return nil
    end

    local hpNow = result.hp_now
    if type(hpNow) ~= "number" then
        hpNow = UnitHealth and UnitHealth(unit) or 0
    end

    local hpMax = result.hp_max
    if type(hpMax) ~= "number" or hpMax <= 0 then
        hpMax = UnitHealthMax and UnitHealthMax(unit) or 1
    end

    if hpMax <= 0 then
        hpMax = 1
    end

    if hpNow < 0 then
        hpNow = 0
    elseif hpNow > hpMax then
        hpNow = hpMax
    end

    local projected = result.projectedHealth or result.hp_proj or hpNow
    if projected < hpNow then
        projected = hpNow
    elseif projected > hpMax then
        projected = hpMax
    end

    local gain = projected - hpNow
    local overheal = math.max(result.overheal or 0, 0)

    if gain <= 0 and overheal <= 0 then
        return nil
    end

    return hpNow, gain, hpMax, overheal
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

    local guard = getDesyncModule()
    if guard and guard.IsFrozen and guard:IsFrozen(frame.unit) then
        return
    end

    local cur = UnitHealth and UnitHealth(frame.unit) or 0
    local max = UnitHealthMax and UnitHealthMax(frame.unit) or 1
    if not max or max <= 0 then
        hideBar(frame)
        return
    end

    local solverCur, solverGain, solverMax = computeSolverProjection(frame.unit)
    local gain = 0

    if solverCur then
        cur = solverCur
        max = solverMax or max
        if not max or max <= 0 then
            hideBar(frame)
            return
        end
        gain = solverGain or 0
    else
        local guid = UnitGUID and UnitGUID(frame.unit)
        if not guid then
            hideBar(frame)
            return
        end

        local horizon = (GetTime and GetTime() or 0) + 1.5
        local incoming = fetchIncoming(frame.unit, guid, horizon)
        if not incoming or incoming <= 0 then
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

        gain = projected - cur
        if not gain or gain <= 0 then
            hideBar(frame)
            return
        end
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
