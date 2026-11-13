-- Core/Events.lua
-- One event frame for the addon, internal messages, and throttling.

local _, ns = ...

local frame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then ns.Debug("cannot register", event) end
    end
    table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do
        local ok, err = pcall(fn, event, ...)
        if not ok then ns.Debug("handler error", event, err) end
    end
end)

-- Internal messages (UI refreshes etc.).
local listeners = {}

function ns.Listen(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function ns.Fire(message, ...)
    for _, fn in ipairs(listeners[message] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then ns.Debug("listener error", message, err) end
    end
end

-- Run fn once, `delay` seconds after the last call with the same key.
local pending = {}
function ns.Throttle(key, delay, fn)
    if pending[key] then
        pending[key].fn = fn
        return
    end
    pending[key] = { fn = fn }
    C_Timer.After(delay, function()
        local job = pending[key]
        pending[key] = nil
        if job then
            local ok, err = pcall(job.fn)
            if not ok then ns.Debug("throttled job error", key, err) end
        end
    end)
end
