local addonName = ...

local CreateFrame = CreateFrame
local GetTime = GetTime
local tostring = tostring
local strlower = string.lower
local strmatch = string.match
local format = string.format

local SLASH_NODHEAL1 = "/nod"

local NODHeal = _G.NODHeal or {}
NODHeal.modules = NODHeal.modules or {}
NODHeal.events = NODHeal.events or {}

local function log(message)
    if message then
        print("[NOD] " .. message)
    end
end

function NODHeal:RegisterModule(name, module)
    if not name or type(name) ~= "string" then
        error("Module name must be a string")
    end

    self.modules[name] = module
    return module
end

function NODHeal:GetModule(name)
    return self.modules[name]
end

local function ensureState()
    NODHeal.State = NODHeal.State or {
        useLHC = true,
        lastSwitch = GetTime() or 0,
    }
    return NODHeal.State
end

local function ensureSavedVariables()
    NODHealDB = NODHealDB or {}
    if type(NODHealDB.useLHC) ~= "boolean" then
        NODHealDB.useLHC = true
    end
    return NODHealDB
end

local function fetchModule(name)
    if not name then
        return nil
    end
    if NODHeal.GetModule then
        return NODHeal:GetModule(name)
    end
    return nil
end

local function updateUi()
    local ui = fetchModule("UI")
    if ui and ui.Refresh then
        ui:Refresh()
    end
end

local function applyHealCommState(enabled)
    local state = ensureState()
    state.useLHC = enabled and true or false
    state.lastSwitch = GetTime() or state.lastSwitch or 0
    NODHealDB.useLHC = state.useLHC

    local incoming = fetchModule("IncomingHeals")
    if incoming then
        if state.useLHC and incoming.RegisterHealComm then
            incoming.RegisterHealComm()
        elseif not state.useLHC and incoming.UnregisterHealComm then
            incoming.UnregisterHealComm()
        end
    end

    local aggregator = fetchModule("IncomingHealAggregator")
    if aggregator and aggregator.CleanExpired then
        aggregator.CleanExpired()
    end

    updateUi()

    if state.useLHC then
        log("HealComm: enabled")
    else
        log("HealComm: disabled; using API fallback")
    end
end

local function printStatus()
    local state = ensureState()
    local source = state.useLHC and "LHC" or "API"
    local elapsed = (GetTime() or state.lastSwitch or 0) - (state.lastSwitch or 0)
    log(format("Status: Quelle=%s t=%.3f", source, elapsed))
end

local function handleSlashCommand(message)
    local command, rest = strmatch(message or "", "^(%S+)%s*(.*)$")
    command = command and strlower(command) or ""
    rest = rest and strlower(rest) or ""

    if command == "healcomm" then
        if rest == "on" then
            applyHealCommState(true)
        elseif rest == "off" then
            applyHealCommState(false)
        elseif rest == "status" or rest == "" then
            printStatus()
        else
            log("HealComm: usage /nod healcomm on|off|status")
        end
        return
    end

    log("Unknown command. Usage: /nod healcomm on|off|status")
end

local function bootstrapDispatcher()
    local dispatcher = fetchModule("CoreDispatcher")
    if dispatcher and dispatcher.Initialize then
        dispatcher.Initialize()
    end

    local aggregator = fetchModule("IncomingHealAggregator")
    if aggregator and aggregator.Initialize then
        aggregator.Initialize(dispatcher)
    end

    local incoming = fetchModule("IncomingHeals")
    if incoming and incoming.Initialize then
        local LHC = LibStub and LibStub("LibHealComm-4.0", true)
        incoming.Initialize(LHC, dispatcher)
    end

    local ui = fetchModule("UI")
    if ui and ui.Initialize then
        ui:Initialize()
    end

    applyHealCommState(NODHealDB.useLHC)
end

local function handleAddonLoaded(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= addonName then
        return
    end

    ensureSavedVariables()
    local state = ensureState()
    state.useLHC = NODHealDB.useLHC and true or false
    state.lastSwitch = GetTime() or state.lastSwitch or 0

    log(format("Init: useLHC=%s, lastSwitch=%.3f", tostring(state.useLHC), state.lastSwitch))

    SlashCmdList = SlashCmdList or {}
    SlashCmdList.NOD = handleSlashCommand

    _G.SLASH_NOD1 = SLASH_NODHEAL1

    bootstrapDispatcher()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", handleAddonLoaded)

_G.NODHeal = NODHeal
