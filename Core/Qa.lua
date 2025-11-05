local _G = _G
local tostring = tostring
local type = type
local format = string.format
local min = math.min

local NODHeal = _G.NODHeal or {}
_G.NODHeal = NODHeal

local Qa = NODHeal.QA or {}
NODHeal.QA = Qa

local MAX_OUTPUT = 8

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

local function collectChecks()
    local results = {}
    checkSavedVariables(results)
    if #results < MAX_OUTPUT then
        checkDispatcher(results)
    end
    if #results < MAX_OUTPUT then
        checkHooks(results)
    end
    if #results < MAX_OUTPUT then
        checkUiModules(results)
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
