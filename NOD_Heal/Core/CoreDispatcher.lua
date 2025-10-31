-- Module: CoreDispatcher
-- Purpose: Provide a central frame-backed event hub with lightweight throttling for backend coordination.
-- API: CreateFrame, RegisterEvent, GetTime

local CreateFrame = CreateFrame
local GetTime = GetTime
local type = type
local pairs = pairs
local tinsert = table.insert

local dispatcherFrame
local eventHandlers = {}
local registeredEvents = {}

local M = {}

-- REGION: Toggle Handling
-- [D1-LHCAPI] Toggle-Kommandos für /nod healcomm
function M.ToggleHealComm(state)
  print("[NOD] ToggleHealComm()", state)
end
-- ENDREGION

local function ensureFrame()
  if dispatcherFrame then
    return dispatcherFrame
  end

  dispatcherFrame = CreateFrame("Frame")
  dispatcherFrame:SetScript("OnEvent", function(_, event, ...)
    M.Dispatch(event, ...)
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
      -- Compatibility with older callers passing seconds
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

function M.Initialize()
  ensureFrame()
  for event in pairs(registeredEvents) do
    registeredEvents[event] = nil
  end
  for key in pairs(eventHandlers) do
    eventHandlers[key] = nil
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
          handler.callback(event, ...)
        end
      else
        handler.callback(event, ...)
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
end

function M.Reset()
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

local namespace = _G.NODHeal
local module = M
if namespace and namespace.RegisterModule then
  module = namespace:RegisterModule("CoreDispatcher", M)
end

-- [D1-LHCAPI] Placeholder verification
if DEBUG then
  print("[NOD] LHC/API stub loaded")
end

return module
