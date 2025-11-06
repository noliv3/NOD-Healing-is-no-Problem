local NODHeal = _G.NODHeal or {}
_G.NODHeal = NODHeal

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown
local type = type
local GetTimePreciseSec = GetTimePreciseSec or GetTime
local format = string.format
local unpack = unpack

local UI = {}
UI.__index = UI

local function log(message, force)
    if not message then
        return
    end
    if NODHeal and NODHeal.Log then
        NODHeal:Log(message, force)
    elseif force then
        print("[NOD] " .. message)
    end
end

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

    NODHeal.UI = NODHeal.UI or {}
    NODHeal.UI.StatusFrame = frame

    self.statusFrame = frame
    return frame
end

local function applySourceColor(fontString, sourceLabel)
    if not fontString then
        return
    end

    if sourceLabel == "API" then
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
    local source = state.dataSource or "API"
    local sourceText = frame.sourceText
    local timeText = frame.timeText

    local sourceLabel = source
    if sourceText then
        sourceText:SetText(format("Quelle: %s", sourceLabel))
        applySourceColor(sourceText, sourceLabel)
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

    if NODHeal.Grid and NODHeal.Grid.Initialize then
        NODHeal.Grid.Initialize()
    end

    log("UI initialized (Overlay active)", true)
end

SLASH_NODHEAL1 = "/nodbind"
SlashCmdList = SlashCmdList or {}
SlashCmdList["NODHEAL"] = function(msg)
    local combo, spell = msg:match("(%S+)%s+(.+)")
    if combo and spell then
        if NODHeal and NODHeal.Bindings and NODHeal.Bindings.Set then
            NODHeal.Bindings:Set(combo, spell)
        end
        log(string.format("Bound %s to %s", combo, spell), true)
    else
        if NODHeal and NODHeal.Bindings and NODHeal.Bindings.List then
            for key, value in pairs(NODHeal.Bindings:List()) do
                if NODHeal and NODHeal.Logf then
                    NODHeal:Logf(true, "%s → %s", key, value)
                else
                    log(string.format("%s → %s", tostring(key), tostring(value)), true)
                end
            end
        end
    end
end

SLASH_NODGUI1 = "/nodgui"
SlashCmdList["NODGUI"] = function()
    if NODHeal and NODHeal.BindUI and NODHeal.BindUI.Toggle then
        NODHeal.BindUI:Toggle()
    end
end

SLASH_NODOPTIONS1 = "/nodoptions"
SlashCmdList["NODOPTIONS"] = function()
    if NODHeal and NODHeal.Options and NODHeal.Options.Toggle then
        NODHeal.Options:Toggle()
    end
end

SLASH_NODSORT1 = "/nodsort"
SlashCmdList["NODSORT"] = function(msg)
    local mode = (msg or ""):lower()
    if mode == "class" then
        mode = "role"
    end
    if mode == "alpha" or mode == "group" or mode == "role" then
        if InCombatLockdown and InCombatLockdown() then
            log("Cannot change sort mode while in combat", true)
            return
        end
        NODHeal.Config = NODHeal.Config or {}
        NODHeal.Config.sortMode = mode
        local saved = _G.NODHealDB
        if type(saved) ~= "table" then
            saved = {}
            _G.NODHealDB = saved
        end
        saved.config = saved.config or {}
        saved.config.sortMode = mode
        log(string.format("Sort mode set to: %s", mode), true)
        if NODHeal.Grid and NODHeal.Grid.Initialize then
            NODHeal.Grid.Initialize()
        end
    else
        log("Usage: /nodsort group | alpha | role", true)
    end
end

return NODHeal:RegisterModule("UI", UI)
