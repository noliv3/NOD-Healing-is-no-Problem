local NODHeal = _G.NODHeal

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer
local GetTimePreciseSec = GetTimePreciseSec or GetTime
local format = string.format
local unpack = unpack

local UI = {}
UI.__index = UI

local STATUS_WIDTH = 200
local STATUS_HEIGHT = 40
local STATUS_POINT = {"BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 80}
local STATUS_UPDATE_INTERVAL = 0.5

function UI:GetState()
    return NODHeal and NODHeal.State
end

function UI:EnsureStatusFrame()
    if self.statusFrame then
        return self.statusFrame
    end

    local frame = CreateFrame("Frame", "NODHealStatusFrame", UIParent)
    frame:SetSize(STATUS_WIDTH, STATUS_HEIGHT)
    frame:SetPoint(unpack(STATUS_POINT))
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(false)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.6)

    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.12, 0.12, 0.12, 0.85)

    local sourceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    sourceText:SetText("Quelle: --")

    local timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeText:SetPoint("TOPLEFT", sourceText, "BOTTOMLEFT", 0, -4)
    timeText:SetText("Zeit: 0.000")

    frame.sourceText = sourceText
    frame.timeText = timeText

    self.statusFrame = frame
    return frame
end

local function applySourceColor(fontString, useLHC)
    if not fontString then
        return
    end

    if useLHC then
        fontString:SetTextColor(0.1, 0.85, 0.1)
    else
        fontString:SetTextColor(0.9, 0.8, 0.1)
    end
end

function UI:UpdateStatus()
    local frame = self:EnsureStatusFrame()
    if not frame then
        return
    end

    local state = self:GetState() or {}
    local useLHC = state.useLHC and true or false
    local sourceText = frame.sourceText
    local timeText = frame.timeText

    local sourceLabel = useLHC and "LHC" or "API"
    if sourceText then
        sourceText:SetText(format("Quelle: %s", sourceLabel))
        applySourceColor(sourceText, useLHC)
    end

    if timeText then
        local now = GetTimePreciseSec() or 0
        timeText:SetText(format("Zeit: %.3f", now))
        timeText:SetTextColor(0.85, 0.85, 0.85)
    end
end

function UI:Refresh()
    self:UpdateStatus()
    if self.RefreshOverlay then
        self:RefreshOverlay()
    end
end

function UI:CancelTicker()
    if self.statusTicker then
        self.statusTicker:Cancel()
        self.statusTicker = nil
    end
end

function UI:HandlePlayerLogout()
    self:CancelTicker()
end

function UI:EnsureLogoutWatcher()
    if self.logoutWatcher then
        return
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_LOGOUT")
    watcher:SetScript("OnEvent", function()
        self:HandlePlayerLogout()
    end)

    self.logoutWatcher = watcher
end

function UI:Initialize()
    if self.statusTicker then
        return
    end

    self:EnsureStatusFrame()
    self:EnsureLogoutWatcher()
    self:UpdateStatus()

    self.statusTicker = C_Timer.NewTicker(STATUS_UPDATE_INTERVAL, function()
        self:UpdateStatus()
    end)

    print("[NOD] UI initialized (Overlay active)")
end

SLASH_NODHEAL1 = "/nodbind"
SlashCmdList["NODHEAL"] = function(msg)
    local btn, spell = msg:match("(%S+)%s+(.+)")
    if btn and spell then
        if NODHeal and NODHeal.Bindings and NODHeal.Bindings.Set then
            NODHeal.Bindings:Set(btn, spell)
        end
        print("[NOD]", btn, "→", spell)
    else
        if NODHeal and NODHeal.Bindings and NODHeal.Bindings.List then
            for key, value in pairs(NODHeal.Bindings:List()) do
                print(key, "→", value)
            end
        end
    end
end

return NODHeal:RegisterModule("UI", UI)
