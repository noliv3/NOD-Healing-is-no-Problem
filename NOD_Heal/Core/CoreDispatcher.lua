local CreateFrame = CreateFrame
local GetTime = GetTime
local C_Timer = C_Timer
local type = type
local pairs = pairs
local format = string.format
local tinsert = table.insert
local tostring = tostring
local date = date
local xpcall = xpcall

local NODHeal = _G.NODHeal or {}
_G.NODHeal = NODHeal

NODHeal.Config = NODHeal.Config or { debug = false, logThrottle = 0.25, overlay = true }
NODHeal.Err = NODHeal.Err or { ring = {}, head = 1, max = 100 }
NODHeal.Core = NODHeal.Core or {}

local function pushErr(msg)
  local payload = tostring(msg)
  local store = NODHeal.Err
  local ring = store.ring
  local head = store.head or 1
  local max = store.max or #ring or 0
  if max <= 0 then
    max = 100
    store.max = max
  end

  ring[head] = ("[%s] %s"):format(date("%H:%M:%S"), payload)
  head = head % max + 1
  store.head = head

  if NODHeal.Config and NODHeal.Config.debug then
    print("|cffff5555[NOD] ERROR:|r", payload)
  end
end

local function safeCall(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  return xpcall(fn, function(err)
    pushErr(err)
    return err
  end, ...)
end

local function debugLog(...)
  if NODHeal.Config and NODHeal.Config.debug then
    print("|cff88ff88[NOD]|r", ...)
  end
end

NODHeal.Core.safeCall = safeCall
NODHeal.Core.Log = debugLog
NODHeal.Core.pushErr = pushErr

local dispatcherFrame
local eventHandlers = {}
local registeredEvents = {}

local M = {}

local function log(message)
  if message then
    debugLog(message)
  end
end

local function namespace()
  return _G.NODHeal
end

local function getModule(name)
  local ns = namespace()
  if ns and ns.GetModule then
    return ns:GetModule(name)
  end
end

local function getState()
  local ns = namespace()
  return ns and ns.State
end

local function ensureFrame()
  if dispatcherFrame then
    return dispatcherFrame
  end

  dispatcherFrame = CreateFrame("Frame")

  dispatcherFrame:SetScript("OnEvent", function(self, event, ...)
    local cfg = NODHeal.Config or {}
    local throttle = cfg.logThrottle or 0.25
    local now = GetTime()
    if throttle < 0 then
      throttle = 0
    end

    if cfg.debug then
      if not self._lastLog or (now - self._lastLog) > throttle then
        print("|cff88ff88[NOD] Dispatcher: event|r", event)
        self._lastLog = now
      end
    end

    safeCall(NODHeal.Core.HandleEvent, event, ...)
  end)

  return dispatcherFrame
end

local function normalizeThrottle(options)
  if type(options) == "number" then
    return options
  end

  if type(options) == "table" then
    if type(options.throttleMs) == "number" then
      return options.throttleMs
    end
    if type(options.throttle) == "number" then
      if options.throttle > 10 then
        return options.throttle
      end
      return options.throttle * 1000
    end
  end

  return nil
end

local function addHandler(event, func, options)
  local handlers = eventHandlers[event]
  if not handlers then
    handlers = {}
    eventHandlers[event] = handlers
  end

  local throttleMs = normalizeThrottle(options)
  if throttleMs and throttleMs < 0 then
    throttleMs = 0
  end

  local entry = {
    callback = func,
    throttleMs = throttleMs,
    nextAllowed = 0,
  }

  tinsert(handlers, entry)
  return entry
end

local function cancelTicker()
  local tick = NODHeal._tick
  if tick and tick.Cancel then
    local cancelled = false
    if tick.IsCancelled then
      cancelled = tick:IsCancelled()
    end
    if not cancelled then
      tick:Cancel()
    end
  end
  NODHeal._tick = nil
end

local function scheduleTicker()
  cancelTicker()

  if not C_Timer or not C_Timer.NewTicker then
    return
  end

  local function tickerBody()
    local aggregator = getModule("IncomingHealAggregator")
    if aggregator and aggregator.CleanExpired then
      safeCall(aggregator.CleanExpired, nil)
    end

    local solver = getModule("PredictiveSolver")
    if solver and solver.CalculateProjectedHealth then
      safeCall(solver.CalculateProjectedHealth, solver, "player")
    end
  end

  NODHeal._tick = C_Timer.NewTicker(0.2, tickerBody)
end

local function bootstrapHandlers()
  M.RegisterHandler("PLAYER_LEAVING_WORLD", function()
    cancelTicker()
    log("Dispatcher: ticker cancelled (leaving world)")
  end)

  M.RegisterHandler("PLAYER_LOGOUT", function()
    cancelTicker()
    log("Dispatcher: ticker cancelled (logout)")
  end)
end

function M.Initialize()
  ensureFrame()
  M.Reset()

  log("Dispatcher: Initialize")
  bootstrapHandlers()
  scheduleTicker()

  local state = getState()
  local incoming = getModule("IncomingHeals")
  if state and incoming then
    if state.useLHC and incoming.RegisterHealComm then
      incoming.RegisterHealComm()
    elseif not state.useLHC and incoming.UnregisterHealComm then
      incoming.UnregisterHealComm()
    end
  end
end

function M.RegisterHandler(event, func, options)
  if not event or type(func) ~= "function" then
    return
  end

  ensureFrame()
  addHandler(event, func, options)

  if not registeredEvents[event] and dispatcherFrame.RegisterEvent then
    dispatcherFrame:RegisterEvent(event)
    registeredEvents[event] = true
  end
end

function M.Dispatch(event, ...)
  if not event then
    return
  end

  local handlers = eventHandlers[event]
  if not handlers then
    return
  end

  local now = GetTime()
  for index = 1, #handlers do
    local handler = handlers[index]
    if handler then
      local throttleMs = handler.throttleMs
      if throttleMs and throttleMs > 0 then
        local throttleSeconds = throttleMs / 1000
        if not handler.nextAllowed or handler.nextAllowed <= now then
          handler.nextAllowed = now + throttleSeconds
          safeCall(handler.callback, event, ...)
        end
      else
        safeCall(handler.callback, event, ...)
      end
    end
  end
end

function M.SetThrottle(event, throttleMs)
  if not event then
    return
  end

  local handlers = eventHandlers[event]
  if not handlers then
    return
  end

  local clamped = throttleMs
  if clamped and clamped < 0 then
    clamped = 0
  end

  local now = GetTime()
  for index = 1, #handlers do
    local handler = handlers[index]
    if handler then
      handler.throttleMs = clamped
      if not clamped or clamped == 0 then
        handler.nextAllowed = now
      elseif not handler.nextAllowed or handler.nextAllowed < now then
        handler.nextAllowed = now
      end
    end
  end
end

function M.Reset()
  cancelTicker()

  if dispatcherFrame then
    for event in pairs(registeredEvents) do
      if dispatcherFrame:IsEventRegistered(event) then
        dispatcherFrame:UnregisterEvent(event)
      end
      registeredEvents[event] = nil
    end
  end

  for k in pairs(eventHandlers) do
    eventHandlers[k] = nil
  end
end

function M.RegisterHealComm()
  local incoming = getModule("IncomingHeals")
  if incoming and incoming.RegisterHealComm then
    return incoming.RegisterHealComm()
  end
  return false
end

function M.UnregisterHealComm()
  local incoming = getModule("IncomingHeals")
  if incoming and incoming.UnregisterHealComm then
    incoming.UnregisterHealComm()
  end
end

function M.scheduleFromTargets(casterGUID, spellID, targets, amount, t_land)
  local incoming = getModule("IncomingHeals")
  if incoming and incoming.scheduleFromTargets then
    incoming.scheduleFromTargets(casterGUID, spellID, targets, amount, t_land)
  end
end

function M.FetchFallback(unit)
  local incoming = getModule("IncomingHeals")
  if incoming and incoming.FetchFallback then
    return incoming.FetchFallback(unit)
  end
  return { amount = 0, confidence = "low" }
end

function M.CleanExpired()
  local aggregator = getModule("IncomingHealAggregator")
  if aggregator and aggregator.CleanExpired then
    aggregator.CleanExpired()
  end
end

function M.ToggleHealComm(stateFlag)
  local state = getState()
  if state then
    state.useLHC = stateFlag and true or false
    state.lastSwitch = GetTime()
  end

  if stateFlag then
    M.RegisterHealComm()
  else
    M.UnregisterHealComm()
  end
end

local namespaceRef = namespace()
local module = M
if namespaceRef and namespaceRef.RegisterModule then
  module = namespaceRef:RegisterModule("CoreDispatcher", M)
end

NODHeal.Core.HandleEvent = NODHeal.Core.HandleEvent or function(event, ...)
  return module.Dispatch(event, ...)
end

return module
