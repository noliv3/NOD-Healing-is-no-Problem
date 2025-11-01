local addonName = ...

local CreateFrame = CreateFrame
local GetTime = GetTime
local tostring = tostring
local strlower = string.lower
local strmatch = string.match
local format = string.format
local ipairs = ipairs

local SLASH_NODHEAL1 = "/nod"

local NODHeal = _G.NODHeal or {}
_G.NODHeal = NODHeal
NODHeal.Config = NODHeal.Config or { debug = false, logThrottle = 0.25, overlay = true }
NODHeal.Err = NODHeal.Err or { ring = {}, head = 1, max = 100 }
NODHeal.Core = NODHeal.Core or {}
NODHeal.modules = NODHeal.modules or {}
NODHeal.events = NODHeal.events or {}

local function getConfig()
    return NODHeal.Config or {}
end

local function log(message, force)
    if not message then
        return
    end

    local cfg = getConfig()
    if force or cfg.debug then
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

local function applyHealCommState(enabled, opts)
    local options = opts or {}
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

    local message = state.useLHC and "HealComm: enabled" or "HealComm: disabled; using API fallback"
    if options.announce then
        log(message, true)
    else
        log(message)
    end
end

local function printStatus(force)
    local state = ensureState()
    local source = state.useLHC and "LHC" or "API"
    local elapsed = (GetTime() or state.lastSwitch or 0) - (state.lastSwitch or 0)
    log(format("Status: Quelle=%s t=%.3f", source, elapsed), force)
end

local function setDebugState(flag)
    local cfg = getConfig()
    cfg.debug = flag and true or false
    log("Debug logging " .. (cfg.debug and "enabled" or "disabled"), true)
end

local function printDebugStatus()
    local cfg = getConfig()
    local label = cfg.debug and "enabled" or "disabled"
    log("Debug logging is " .. label, true)
end

local function dumpErrors()
    local err = NODHeal.Err
    if not err then
        print("[NOD] No error buffer available")
        return
    end

    local ring = err.ring or {}
    local maxEntries = err.max or #ring or 0
    if maxEntries <= 0 then
        maxEntries = #ring
    end
    if maxEntries <= 0 then
        print("[NOD] No errors recorded")
        return
    end

    local head = err.head or 1
    local limit = 20
    local entries = {}
    local fetched = 0
    for step = 0, maxEntries - 1 do
        if fetched >= limit then
            break
        end
        local index = ((head - 1 - step) % maxEntries) + 1
        local entry = ring[index]
        if entry then
            table.insert(entries, 1, entry)
            fetched = fetched + 1
        elseif step >= (#ring) then
            break
        end
    end

    if #entries == 0 then
        print("[NOD] No errors recorded")
        return
    end

    print("[NOD] Error history (latest 20 entries):")
    for _, line in ipairs(entries) do
        print("  " .. line)
    end
end

local function handleSlashCommand(message)
    local command, rest = strmatch(message or "", "^(%S+)%s*(.*)$")
    command = command and strlower(command) or ""
    rest = rest and strlower(rest) or ""

    if command == "healcomm" then
        if rest == "on" then
            applyHealCommState(true, { announce = true })
        elseif rest == "off" then
            applyHealCommState(false, { announce = true })
        elseif rest == "status" or rest == "" then
            printStatus(true)
        else
            log("HealComm: usage /nod healcomm on|off|status", true)
        end
        return
    end

    if command == "debug" then
        if rest == "on" then
            setDebugState(true)
        elseif rest == "off" then
            setDebugState(false)
        elseif rest == "status" or rest == "" then
            printDebugStatus()
        else
            log("Debug: usage /nod debug on|off|status", true)
        end
        return
    end

    if command == "errors" then
        dumpErrors()
        return
    end

    log("Unknown command. Usage: /nod healcomm|debug|errors", true)
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
