local _G = _G
local tostring = tostring
local type = type
local format = string.format
local min = math.min
local ipairs = ipairs
local concat = table.concat
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

local function fetchHotDetector()
    local detector = (NODHeal.Core and NODHeal.Core.HotDetector)
    if not detector and NODHeal.GetModule then
        detector = NODHeal:GetModule("HotDetector")
    end
    return detector
end

local function collectCdLane(results)
    local classifier = fetchCooldownClassifier()
    if not classifier or not classifier.DebugSnapshot then
        return
    end

    local snapshot = classifier.DebugSnapshot and classifier.DebugSnapshot()
    if type(snapshot) ~= "table" then
        return
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
    push(results, "CD", format("Lane seeds=%d learned=%d blocked=%d visible=%d", seeds, learned, blocked, visibleCount))
    push(results, "CD", format("prevented=%s window=%.1fs", (classifier and classifier.EstimateMitigation) and "on" or "off", window))
    push(results, "CD", format("block_match: %s", blockMismatch))
    if #preview > 0 then
        push(results, "CD", "visible[1..3]: " .. concat(preview, ", "))
    end
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

local function collectIncomingFlags(results)
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
    push(results, "Heals", format("futureWindow=%s lhc=%s window=%.1fs", future, lhc, window))
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
    if #results < MAX_OUTPUT then
        collectCdLane(results)
    end
    if #results < MAX_OUTPUT then
        collectIncomingFlags(results)
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
