local addonName = ...

local CreateFrame = CreateFrame
local GetTime = GetTime
local tostring = tostring
local strlower = string.lower
local strmatch = string.match
local format = string.format
local ipairs = ipairs
local select = select

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

function NODHeal.Log(self, message, force)
    if self ~= NODHeal then
        message, force = self, message
    end
    log(message, force)
end

function NODHeal.Logf(self, force, pattern, ...)
    if self ~= NODHeal then
        pattern, force, self = force, self, NODHeal
    end
    if type(force) ~= "boolean" then
        pattern, force = force, false
    end
    if not pattern then
        return
    end
    local msg = pattern
    if select("#", ...) > 0 then
        msg = format(pattern, ...)
    end
    log(msg, force)
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
        dataSource = "API",
        lastSourceUpdate = GetTime() or 0,
    }
    return NODHeal.State
end

local function ensureSavedVariables()
    NODHealDB = NODHealDB or {}
    if NODHeal.ApplyConfigDefaults then
        NODHeal.ApplyConfigDefaults()
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

local function stampDataSource()
    local state = ensureState()
    state.dataSource = "API"
    state.lastSourceUpdate = GetTime() or state.lastSourceUpdate or 0
    updateUi()
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
    rest = rest or ""
    local restLower = strlower(rest)

    if command == "debug" then
        if restLower == "on" then
            setDebugState(true)
        elseif restLower == "off" then
            setDebugState(false)
        elseif restLower == "status" or restLower == "" then
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

    if command == "options" then
        if SlashCmdList and SlashCmdList.NODOPTIONS then
            SlashCmdList.NODOPTIONS()
        elseif NODHeal.Options and NODHeal.Options.Toggle then
            NODHeal.Options:Toggle()
        else
            log("Options module unavailable", true)
        end
        return
    end

    if command == "bind" then
        if SlashCmdList and SlashCmdList.NODHEAL then
            SlashCmdList.NODHEAL(rest)
        else
            log("Bindings module unavailable", true)
        end
        return
    end

    if command == "sort" then
        if SlashCmdList and SlashCmdList.NODSORT then
            SlashCmdList.NODSORT(rest)
        else
            log("Sort command unavailable", true)
        end
        return
    end

    if command == "qa" then
        local qaModule = fetchModule("QA") or NODHeal.QA
        if qaModule and qaModule.Run then
            qaModule:Run()
        else
            log("QA module unavailable", true)
        end
        return
    end

    log("Unknown command. Usage: /nod debug|errors|options|bind|sort|qa", true)
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
        incoming.Initialize(dispatcher)
    end

    local ui = fetchModule("UI")
    if ui and ui.Initialize then
        ui:Initialize()
    end
    stampDataSource()
end

local function handleAddonLoaded(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= addonName then
        return
    end

    ensureSavedVariables()
    local state = ensureState()
    state.dataSource = "API"
    state.lastSourceUpdate = GetTime() or state.lastSourceUpdate or 0

    log(format("Init: dataSource=%s", tostring(state.dataSource)))

    SlashCmdList = SlashCmdList or {}
    SlashCmdList.NOD = handleSlashCommand

    _G.SLASH_NOD1 = SLASH_NODHEAL1

    if NODHeal.Bindings and NODHeal.Bindings.Ensure then
        NODHeal.Bindings:Ensure()
    end

    bootstrapDispatcher()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", handleAddonLoaded)

_G.NODHeal = NODHeal
