--[=[
    Handles framework-wide lifecycle events and automatic per-frame updates.

    Features:
      • Manages per-frame callbacks like onTick, onRender, onPhysics
      • Automatically binds all registered objects with matching lifecycle methods
      • Supports dynamic registration and unregistration at runtime
      • Uses reusable coroutine threads for efficient asynchronous task scheduling
      • Optional built-in profiling for debugging performance (debug.profilebegin)
]=]

local RunService = game:GetService("RunService")

local Utils = require(script.Parent.Utils)

local throw = Utils.throw
local try = Utils.try

local LifeCycle = {}

--[[
    Internal registry of lifecycle events.
    Each lifecycle name maps to a RunService event.
]]
local events = {
	onTick = RunService.Heartbeat,
	onPhysics = RunService.PreSimulation,
}

-- Client-only render event
if RunService:IsClient() then
	events.onRender = RunService.RenderStepped
end

--[[
    Internal registry of lifecycle handlers.

    Each lifecycle name maps to a WeakMap<Object, Handler>.
    Handlers are prepared once during registration instead of every frame.
]]
local registers = {} -- LifeCycleName -> WeakMap<Object, Function>

-- Flags and thread cache
local isProfiling = false
local freeThread = nil -- Free thread for lifecycle events

--[[
    Internal reusable coroutine worker.

    Runs a single task and yields for reuse instead of creating a new
    coroutine for every lifecycle invocation.
]]
local function reusableThread(func)
	local thread = coroutine.running()

	while true do
		-- This thread is no longer idle once it starts executing work.
		if freeThread == thread then
			freeThread = nil
		end

		func()

		-- Another thread became idle while this one was running.
		-- There is no reason to keep both workers cached.
		if freeThread ~= nil then
			break
		end

		freeThread = thread
		func = coroutine.yield()
	end
end

--[[
    Executes a function asynchronously using a reusable coroutine.

    If an idle worker exists it is resumed, otherwise a new worker
    is spawned. Lifecycle handlers therefore never block each other.
]]
local function reuseThread(func)
	if freeThread then
		local thread = freeThread
		freeThread = nil

		task.spawn(thread, func)
	else
		task.spawn(reusableThread, func)
	end
end

--[[
    Executes a lifecycle handler with optional profiling.

    Profiling happens at invocation time rather than registration time,
    allowing profiling to be enabled or disabled without rebuilding
    the lifecycle registry.

    `profilebegin` automatically ends if the handler yields.
]]
local function invokeProfiled(func, identifier, ...)
	if not isProfiling then
		return func(...)
	end

	debug.profilebegin(identifier)
	debug.setmemorycategory(identifier)

	func(...)

	debug.resetmemorycategory()
	debug.profileend()

	return nil
end

--[[
    Creates a lifecycle handler for an object.

    The closure is created only once when the object is registered,
    avoiding closure allocations every frame.
]]
local function createHandler(child, method, lifeCycle)
	local name = child["Identifier"] or child.Name or "Leaf"
	local identifier = `{lifeCycle}:{name}`

	return function(a, b, c)
		invokeProfiled(method, identifier, child, a, b, c)
	end
end

--[[
    Invokes all currently registered handlers for a lifecycle event.

    Every handler is scheduled independently, allowing lifecycle
    implementations to yield without blocking other objects.

    Objects may be registered or unregistered dynamically.
]]
local function invokeLifeCycleMethods(lifeCycle, a, b, c)
	local connected = registers[lifeCycle]

	if not connected then
		throw("No such lifeCycle method: " .. lifeCycle)
		return
	end

	for _, handler in connected do
		reuseThread(function()
			handler(a, b, c)
		end)
	end
end

--[[
    Initializes the lifecycle system.

    Connects all defined RunService events to their lifecycle handlers.
    Profiling may optionally be enabled for individual lifecycle calls.
]]
function LifeCycle.initialize(profiling)
	isProfiling = profiling

	for lifeCycle, signal in events do
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

    Registration may happen at any point during runtime.
]]
function LifeCycle.register(child)
	for lifeCycle, registry in registers do
		local method = child[lifeCycle]

		if type(method) ~= "function" then
			continue -- There's no such function in the child or it's not a function
		end

		registry[child] = createHandler(child, method, lifeCycle)
	end
end

--[[
    Unregisters an object from all lifecycle events.

    Since registries use weak keys, objects may also be garbage-collected
    automatically when no strong references to them remain.

    Unregistration only prevents future lifecycle invocations.
    A handler that has already been scheduled may still finish normally.
]]
function LifeCycle.unregister(child)
	for _, registry in registers do
		registry[child] = nil
	end
end

--[[
    Initializes the weak maps for all lifecycle event registries.

    Weak keys allow registered objects to disappear automatically
    once the framework no longer holds any other references to them.
]]
for lifeCycle in events do
	registers[lifeCycle] = Utils.newWeakMap()
end

return LifeCycle
