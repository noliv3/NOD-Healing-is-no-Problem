local addonName = ...

local CreateFrame = CreateFrame
local GetTime = GetTime
local tostring = tostring
local strlower = string.lower
local strmatch = string.match
local format = string.format
local ipairs = ipairs
local pairs = pairs
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
    local saved = _G.NODHealDB
    if type(saved) ~= "table" then
        saved = {}
        _G.NODHealDB = saved
    end
    if NODHeal.ApplyConfigDefaults then
        NODHeal.ApplyConfigDefaults()
        saved = _G.NODHealDB or saved
    end
    saved.learned = saved.learned or {}
    local learnedStore = saved.learned
    learnedStore.hots = learnedStore.hots or {}
    NODHeal.Learned = NODHeal.Learned or {}
    NODHeal.Learned.hots = NODHeal.Learned.hots or {}
    return saved
end

local function ensureLearnedRuntime()
    NODHeal.Learned = NODHeal.Learned or {}
    local learned = NODHeal.Learned
    learned.hots = learned.hots or {}
    return learned
end

NODHeal.Telemetry = NODHeal.Telemetry or {}
local Telemetry = NODHeal.Telemetry
Telemetry.interval = Telemetry.interval or 5
Telemetry.counters = Telemetry.counters or { solverCalls = 0, auraRefresh = 0 }
Telemetry.queueSize = Telemetry.queueSize or 0
Telemetry.lastFlush = Telemetry.lastFlush or GetTime()
Telemetry.feed = Telemetry.feed or { ring = {}, head = 1, max = 100 }

local function telemetryPush(self, message)
    if not message then
        return
    end
    local feed = self.feed or {}
    self.feed = feed
    feed.ring = feed.ring or {}
    local max = feed.max or 100
    if max <= 0 then
        max = 100
        feed.max = max
    end
    local head = feed.head or 1
    feed.ring[head] = message
    feed.head = head % max + 1
    if NODHeal and NODHeal.Logf then
        NODHeal:Logf(false, "%s", message)
    end
end

function Telemetry:Increment(metric, delta)
    if not metric then
        return
    end
    local counters = self.counters or {}
    self.counters = counters
    counters[metric] = (counters[metric] or 0) + (delta or 1)
end

function Telemetry:UpdateQueueSize(size)
    self.queueSize = size or 0
end

function Telemetry:Push(message)
    telemetryPush(self, message)
end

function Telemetry:Flush(now)
    local timestamp = now or GetTime()
    if not self.lastFlush then
        self.lastFlush = timestamp
    end
    local elapsed = timestamp - (self.lastFlush or timestamp)
    local interval = self.interval or 5
    if elapsed < interval then
        return
    end
    self.lastFlush = timestamp
    local counters = self.counters or {}
    self.counters = counters
    local cfg = getConfig()
    if not (cfg and cfg.debug) then
        counters.solverCalls = 0
        counters.auraRefresh = 0
        return
    end
    local span = elapsed > 0 and elapsed or interval
    local solverRate = (counters.solverCalls or 0) / span
    local auraRate = (counters.auraRefresh or 0) / span
    local message = format(
        "telemetry: solver_calls/s=%.1f aura_refresh/s=%.1f queue_after_combat=%d",
        solverRate,
        auraRate,
        self.queueSize or 0
    )
    telemetryPush(self, message)
    counters.solverCalls = 0
    counters.auraRefresh = 0
end

function Telemetry:OnTick()
    self:Flush(GetTime())
end

function Telemetry:Attach(dispatcher)
    if self._attached then
        return
    end
    self._attached = true
    local function tick()
        self:OnTick()
    end
    if dispatcher and dispatcher.RegisterTick then
        dispatcher:RegisterTick(tick)
        return
    end
    if C_Timer and C_Timer.NewTicker then
        if self._ticker and self._ticker.Cancel then
            self._ticker:Cancel()
        end
        self._ticker = C_Timer.NewTicker(1, tick)
    end
end

local function wipeTable(tbl)
    if type(tbl) ~= "table" then
        return
    end
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function copyEntry(source)
    if type(source) ~= "table" then
        return source
    end
    local target = {}
    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end

local function saveLearned()
    local db = _G.NODHealDB
    if type(db) ~= "table" then
        return
    end

    db.learned = db.learned or {}
    local target = db.learned.hots
    if type(target) ~= "table" then
        target = {}
        db.learned.hots = target
    end

    wipeTable(target)

    local learned = NODHeal.Learned and NODHeal.Learned.hots
    if type(learned) ~= "table" then
        return
    end

    for spellId, entry in pairs(learned) do
        if entry ~= nil then
            target[spellId] = copyEntry(entry)
        end
    end
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

    if Telemetry and Telemetry.Attach then
        Telemetry:Attach(dispatcher)
    end

    local death = fetchModule("DeathAuthority")
    if death and death.Initialize then
        death.Initialize(dispatcher)
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

local function handleEvent(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then
            return
        end

        ensureSavedVariables()
        ensureLearnedRuntime()

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
        return
    end

    if event == "PLAYER_LOGOUT" then
        saveLearned()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", handleEvent)

_G.NODHeal = NODHeal
