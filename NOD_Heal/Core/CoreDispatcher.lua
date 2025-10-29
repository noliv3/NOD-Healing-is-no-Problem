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

local function addHandler(event, func, options)
  local handlers = eventHandlers[event]
  if not handlers then
    handlers = {}
    eventHandlers[event] = handlers
  end

  local entry = {
    callback = func,
    throttle = options and options.throttle or nil,
    lastCall = 0,
  }

  tinsert(handlers, entry)
  return entry
end

function M.Initialize()
  ensureFrame()
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
      local throttle = handler.throttle
      if not throttle or (now - handler.lastCall) >= throttle then
        handler.lastCall = now
        handler.callback(event, ...)
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

return M
