--[[
    LifeCycle.lua
    Handles framework-wide lifecycle events and automatic per-frame updates.

    Features:
      • Manages per-frame callbacks like onTick, onRender, onPhysics
      • Automatically binds all registered objects with matching lifecycle methods
      • Uses a reusable coroutine thread for efficient task scheduling
      • Optional built-in profiling for debugging performance (debug.profilebegin)

    Typical usage:
        local LifeCycle = require(Framework.LifeCycle)
        LifeCycle.initialize()
        LifeCycle.register(MyComponent)

        function MyComponent:onTick(dt)
            print("Tick update:", dt)
        end
]]

local RunService = game:GetService("RunService")
local Utils = require(script.Parent.utils)

local throw = Utils.throw
local try = Utils.try

local LifeCycle = {}

--[[
    Internal registry of lifecycle events.
    Each lifecycle name maps to a RunService event.
]]
local events = {
    onTick = RunService.Heartbeat,
    onPhysics = RunService.PreSimulation
}

-- Client-only render event
if RunService:IsClient() then
    events.onRender = RunService.RenderStepped
end

--[[
    Internal registry of lifecycle connections.
    Each lifecycle name maps to a WeakMap<Object, Function>.
]]
local registers = {} -- LifeCycleName -> WeakMap<Object, Function>

-- Flags and thread cache
local isProfiling = false
local freeThread = nil -- Free thread for lifeCycle events

--[[
    Internal reusable coroutine worker.
    Runs a single task and yields for reuse instead of spawning new threads.
]]
local function reusableThread(func)
    local thread = coroutine.running()
    while true do
        if freeThread == thread then
            freeThread = nil
        end
        func()
        -- If there's a different idle thread, we should end the current thread.
        if freeThread ~= nil then
            break
        end
        freeThread = thread
        func = coroutine.yield()
    end
end

--[[
    Executes a function on the reusable coroutine.
    If an idle thread exists, reuse it; otherwise, spawn a new coroutine.
]]
local function reuseThread(func)
    if freeThread then
        task.spawn(freeThread, func)
    else
        task.spawn(reusableThread, func)
    end
end

--[[
    Optionally wraps a function call in profiling logic.

    When profiling is enabled, each lifecycle call gets its own profile section,
    allowing detailed timing and memory tracking in the microprofiler.
]]
local function profileYielding(func, identifier)
    if isProfiling then
        return function()
            -- `profilebegin` will end when this thread dies or yields.
            debug.profilebegin(identifier)
            debug.setmemorycategory(identifier)
            func()
            debug.resetmemorycategory()
        end
    else
        return func
    end
end

--[[
    Invokes all registered handlers for the specified lifecycle event.

    @param lifeCycle string - name of the lifecycle method (e.g. "onTick")
    @param a,b,c - any parameters passed from the RunService event
]]
local function invokeLifeCycleMethods(lifeCycle, a, b, c)
    local connected = registers[lifeCycle]

    if not connected then
        throw("No such lifeCycle method: " .. lifeCycle)
        return
    end

    for child, method in pairs(connected) do
		reuseThread(profileYielding(function()
			return method(child, a, b, c)
		end, child["Identifier"] or child.Name))
	end
end

--[[
    Initializes the lifecycle system.
    Connects all defined RunService events to their lifecycle handlers.
]]
function LifeCycle.initialize(profiling)
    isProfiling = profiling

    for lifeCycle, signal in pairs(events) do
        local errMessage = `Error invoking lifeCycle ({lifeCycle}) event`
        signal:Connect(function(...)
            try(invokeLifeCycleMethods, errMessage, lifeCycle, ...)
        end)
    end
end

--[[
    Registers a new object (component/service) for lifecycle updates.

    The object's methods matching lifecycle names (onTick, onRender, etc.)
    are automatically connected to their corresponding events.
]]
function LifeCycle.register(child)
    for lifeCycle in pairs(registers) do
        local impl = child[lifeCycle]

        if type(impl) ~= "function" then
            continue -- There's no such function in the child or it's not a function
        end

        registers[lifeCycle][child] = impl
    end
end

--[[
    Unregisters an object from all lifecycle events.
    Removes references to prevent memory leaks.
]]
function LifeCycle.unregister(child)
    for lifeCycle in pairs(registers) do
        registers[lifeCycle][child] = nil
    end
end

--[[
    Initializes the weak maps for all lifecycle event registries.
    Weak maps ensure automatic cleanup when components are garbage-collected.
]]
for lifeCycle in pairs(events) do
    registers[lifeCycle] = Utils.newWeakMap()
end

return LifeCycle
