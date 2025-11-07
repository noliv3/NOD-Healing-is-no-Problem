local _G = _G
local tostring = tostring
local type = type
local format = string.format
local min = math.min
local ipairs = ipairs
local UnitExists = UnitExists

local NODHeal = _G.NODHeal or {}
_G.NODHeal = NODHeal

local Qa = NODHeal.QA or {}
NODHeal.QA = Qa

local MAX_OUTPUT = 16

local function getConfig()
    return NODHeal.Config or {}
end

local function push(results, status, label)
    results[#results + 1] = { status = status, label = label }
end

local function checkSavedVariables(results)
    local saved = _G.NODHealDB
    local hasSaved = type(saved) == "table"
    local hasConfig = hasSaved and type(saved.config) == "table"
    if hasSaved and hasConfig and type(NODHeal.Config) == "table" then
        push(results, "OK", "saved variables loaded")
    elseif hasSaved then
        push(results, "WARN", "config defaults missing (NODHeal.Config)")
    else
        push(results, "ERR", "saved variables missing")
    end
end

local function isTickerActive(ticker)
    if not ticker then
        return false
    end

    if type(ticker) == "table" or type(ticker) == "userdata" then
        if type(ticker.IsCancelled) == "function" and ticker:IsCancelled() then
            return false
        end
    end

    return true
end

local function checkDispatcher(results)
    local dispatcher = nil
    if NODHeal.GetModule then
        dispatcher = NODHeal:GetModule("CoreDispatcher")
    end
    dispatcher = dispatcher or NODHeal.CoreDispatcher or (NODHeal.Core and NODHeal.Core.Dispatcher)

    local tickerActive = isTickerActive(NODHeal._tick)
    if not tickerActive and NODHeal.Grid then
        tickerActive = isTickerActive(NODHeal.Grid._ticker)
    end

    if dispatcher and tickerActive then
        push(results, "OK", "dispatcher ready (ticker active)")
    elseif dispatcher then
        push(results, "WARN", "dispatcher ready (ticker idle)")
    else
        push(results, "WARN", "dispatcher module unavailable")
    end
end

local function checkSolver(results)
    local solver
    if NODHeal.GetModule then
        solver = NODHeal:GetModule("PredictiveSolver")
    end
    solver = solver or (NODHeal.Core and NODHeal.Core.PredictiveSolver)

    if solver and type(solver.CalculateProjectedHealth) == "function" then
        local unit = "player"
        if UnitExists and not UnitExists(unit) then
            push(results, "Solver", "OK (unit-flow)")
            return
        end

        local ok = pcall(solver.CalculateProjectedHealth, unit)
        if ok then
            push(results, "Solver", "OK (unit-flow)")
        else
            push(results, "Solver", "ERR (unit-flow)")
        end
    else
        push(results, "Solver", "missing")
    end
end

local function checkHooks(results)
    local targets = {
        "CompactUnitFrame_UpdateHealth",
        "CompactUnitFrame_UpdateVisible",
        "CompactUnitFrame_OnEnter",
        "CompactUnitFrame_OnLeave",
    }

    for index = 1, #targets do
        local name = targets[index]
        local fn = _G[name]
        if type(fn) == "function" then
            push(results, "OK", format("hook target %s available", name))
        else
            push(results, "WARN", format("hook target %s missing", name))
        end
        if #results >= MAX_OUTPUT then
            break
        end
    end
end

local function checkUiModules(results)
    local ui = (NODHeal.GetModule and NODHeal:GetModule("UI")) or NODHeal.UI
    if ui then
        push(results, "OK", "UI module loaded")
    else
        push(results, "WARN", "UI module not loaded")
    end

    if #results < MAX_OUTPUT then
        local grid = NODHeal.Grid or (ui and ui.Grid)
        if grid then
            push(results, "OK", "grid module present")
        else
            push(results, "WARN", "grid module missing")
        end
    end

    if #results < MAX_OUTPUT then
        local overlay = ui and (ui.EnableOverlay or ui.RefreshOverlay)
        if overlay then
            push(results, "OK", "overlay controls available")
        else
            push(results, "WARN", "overlay controls missing")
        end
    end
end

local function fetchCooldownClassifier()
    local classifier = (NODHeal.Core and NODHeal.Core.CooldownClassifier)
    if not classifier and NODHeal.GetModule then
        classifier = NODHeal:GetModule("CooldownClassifier")
    end
    return classifier
end

local function fetchGridModule()
    return NODHeal.Grid or (NODHeal.UI and NODHeal.UI.Grid)
end

local function fetchDispatcherModule()
    local dispatcher = (NODHeal.GetModule and NODHeal:GetModule("CoreDispatcher")) or NODHeal.CoreDispatcher
    return dispatcher
end

local function fetchHotDetector()
    local detector = (NODHeal.Core and NODHeal.Core.HotDetector)
    if not detector and NODHeal.GetModule then
        detector = NODHeal:GetModule("HotDetector")
    end
    return detector
end

local function collectCdLane()
    local classifier = fetchCooldownClassifier()
    if not classifier or not classifier.DebugSnapshot then
        return nil
    end

    local snapshot = classifier.DebugSnapshot and classifier.DebugSnapshot()
    if type(snapshot) ~= "table" then
        return nil
    end

    local seeds = snapshot.seeds or 0
    local learned = snapshot.learned or 0
    local blocked = snapshot.blocked or 0
    local blockedSet = snapshot.blockedSet or {}

    local visibleCount = 0
    local blockMismatch = "ok"
    local preview = {}

    local grid = fetchGridModule()
    if grid and grid.DebugSnapshot then
        local gridSnapshot = grid.DebugSnapshot()
        if type(gridSnapshot) == "table" then
            local list = gridSnapshot.majorVisible or {}
            visibleCount = gridSnapshot.visibleCount or (type(list) == "table" and #list or 0)
            if type(list) == "table" then
                for _, entry in ipairs(list) do
                    local spellId = entry and entry.spellId
                    if spellId and ((blockedSet and blockedSet[spellId]) or (classifier.IsBlocked and classifier.IsBlocked(spellId))) then
                        blockMismatch = "mismatch"
                        break
                    end
                end
                local limit = math.min(#list, 3)
                for index = 1, limit do
                    local entry = list[index]
                    if entry then
                        local spellId = entry.spellId
                        local blockedLabel = "no"
                        if spellId and ((blockedSet and blockedSet[spellId]) or (classifier.IsBlocked and classifier.IsBlocked(spellId))) then
                            blockedLabel = "yes"
                        end
                        preview[#preview + 1] = format(
                            "%s:%s (%s, blocked? %s)",
                            tostring(spellId or "?"),
                            tostring(entry.name or "?"),
                            tostring(entry.class or "?"),
                            blockedLabel
                        )
                    end
                end
            end
        end
    end

    local cfg = getConfig()
    local majorCfg = (cfg and cfg.major) or {}
    local window = majorCfg.window or 6
    if type(window) ~= "number" then
        window = 6
    end

    return {
        seeds = seeds,
        learned = learned,
        blocked = blocked,
        visible = visibleCount,
        match = blockMismatch,
        mitigation = (classifier and classifier.EstimateMitigation) and true or false,
        window = window,
        preview = preview,
    }
end

local function collectHotStats(results)
    local detector = fetchHotDetector()
    if not detector or not detector.DebugSnapshot then
        return
    end

    local snapshot = detector.DebugSnapshot and detector.DebugSnapshot()
    if type(snapshot) ~= "table" then
        return
    end

    local blocked = snapshot.blocked or 0
    if blocked <= 0 then
        return
    end

    local seeds = snapshot.seeds or 0
    local learned = snapshot.learned or 0
    push(results, "HoT", format("Learn/Block seeds=%d learned=%d blocked=%d", seeds, learned, blocked))
end

local function collectIncomingFlags()
    local cfg = getConfig()
    local healsCfg = (cfg and cfg.heals) or {}
    local future = healsCfg.futureWindow == false and "off" or "on"
    local lhc = healsCfg.useLHC and "on" or "off"
    local window = healsCfg.windowSec or 0
    if type(window) ~= "number" then
        window = 0
    end
    if window < 0 then
        window = 0
    end
    return {
        future = future,
        lhc = lhc,
        window = window,
    }
end

local function collectCombatQueue()
    local rebuild = 0
    local ops = 0

    local grid = fetchGridModule()
    if grid and grid.DebugQueue then
        local snapshot = grid.DebugQueue()
        if type(snapshot) == "table" then
            if type(snapshot.rebuild) == "number" then
                rebuild = snapshot.rebuild
            elseif type(snapshot.pending) == "number" then
                rebuild = snapshot.pending
            end
        end
    end

    local dispatcher = fetchDispatcherModule()
    if dispatcher and dispatcher.DebugQueue then
        local snapshot = dispatcher.DebugQueue()
        if type(snapshot) == "table" then
            if type(snapshot.pending) == "number" then
                ops = snapshot.pending
            elseif type(snapshot.size) == "number" then
                ops = snapshot.size
            end
        end
    end

    return {
        rebuild = rebuild,
        ops = ops,
    }
end

local function collectPerfSnapshot()
    local grid = fetchGridModule()
    local tick = 0.2
    if grid and grid.GetTickInterval then
        local value = grid.GetTickInterval()
        if type(value) == "number" and value > 0 then
            tick = value
        end
    end

    local aura = 0.15
    if grid and grid.GetAuraRefreshThrottle then
        local value = grid.GetAuraRefreshThrottle()
        if type(value) == "number" and value > 0 then
            aura = value
        end
    end

    local logFeed = NODHeal.LogFeed
    local ringSize = 100
    if type(logFeed) == "table" and type(logFeed.max) == "number" and logFeed.max > 0 then
        ringSize = logFeed.max
    end

    return {
        tick = tick,
        aura = aura,
        logs = ringSize,
    }
end

local function buildSummaryLines()
    local lines = {}

    local cd = collectCdLane()
    if cd then
        lines[#lines + 1] = {
            status = "QA",
            label = format(
                "CD Lane: seeds=%d learned=%d blocked=%d visible=%d match=%s",
                cd.seeds or 0,
                cd.learned or 0,
                cd.blocked or 0,
                cd.visible or 0,
                tostring(cd.match or "ok")
            ),
        }
    end

    local heals = collectIncomingFlags()
    if heals then
        lines[#lines + 1] = {
            status = "QA",
            label = format(
                "IncomingHeals: futureWindow=%s lhc=%s window=%.1fs",
                heals.future or "off",
                heals.lhc or "off",
                heals.window or 0
            ),
        }
    end

    local queue = collectCombatQueue()
    if queue then
        lines[#lines + 1] = {
            status = "QA",
            label = format(
                "CombatQueue: rebuild=%d ops=%d",
                queue.rebuild or 0,
                queue.ops or 0
            ),
        }
    end

    local perf = collectPerfSnapshot()
    if perf then
        lines[#lines + 1] = {
            status = "QA",
            label = format(
                "Perf: tick=%.1fs aura>=%.2fs logs=ring(%d)",
                perf.tick or 0,
                perf.aura or 0,
                perf.logs or 0
            ),
        }
    end

    return lines
end

local function collectChecks()
    local results = {}
    checkSavedVariables(results)
    if #results < MAX_OUTPUT then
        checkDispatcher(results)
    end
    if #results < MAX_OUTPUT then
        checkSolver(results)
    end
    if #results < MAX_OUTPUT then
        checkHooks(results)
    end
    if #results < MAX_OUTPUT then
        checkUiModules(results)
    end
    local summaryLines = buildSummaryLines()
    for index = 1, #summaryLines do
        local entry = summaryLines[index]
        push(results, entry.status, entry.label)
    end
    if #results < MAX_OUTPUT then
        collectHotStats(results)
    end
    return results
end

function Qa:Run()
    local results = collectChecks()
    if #results == 0 then
        return
    end

    local emit = nil
    if NODHeal.Logf then
        emit = function(status, label)
            NODHeal:Logf(true, "QA: %s: %s", status, label)
        end
    else
        emit = function(status, label)
            print(format("[NOD] QA: %s: %s", tostring(status), tostring(label)))
        end
    end

    local limit = min(#results, MAX_OUTPUT)
    for index = 1, limit do
        local entry = results[index]
        emit(entry.status, entry.label)
    end
end

return NODHeal:RegisterModule("QA", Qa)
