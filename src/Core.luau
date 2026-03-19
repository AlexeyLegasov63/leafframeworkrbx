--[[
    Core.lua - Core module of the LeafFramework
    @description
        Handles framework initialization, dependency resolution, lifecycle registration,
        and component startup logic. Integrates with the LifeCycle module for per-frame updates.

    Responsibilities:
      • Resolve topological dependencies between modules (services/controllers/components)
      • Sort modules by load priority
      • Register modules for lifecycle events
      • Initialize all components and services asynchronously
      • Start the framework and hook into RunService events
]]

local Components = require(script.Parent.Components)
local DependencyResolver = require(script.Parent.DependencyResolver)
local ExtensionHandler = require(script.Parent.ExtensionHandler)
local LifeCycle = require(script.Parent.LifeCycle)

local Utils = require(script.Parent.Utils)
local Promise = require(script.Parent.Parent.Promise)
local Symbols = require(script.Parent.Symbols)

local throw = Utils.throw
local try = Utils.try

--------------------------------------------------------------------------

export type FrameworkConfig = {
	profiling: boolean?, -- Enable/disable profiling
	promiseTimeout: number?, -- Timeout for promises in lifecycle hooks
}

--------------------------------------------------------------------------

local DEFAULT_CONFIG = {
	profiling = false,
	promiseTimeout = 10,
}

local Core = {
	config = {} :: FrameworkConfig, -- Framework config
}

--[[
    Sorted modules after dependency resolution
]]
local ordered = {}

--------------------------------------------------------------------------

--[[
    Perform topological sort to resolve dependencies.
    Throws an error if circular dependency is detected.
]]
function resolveDependencies()
	local children = DependencyResolver.listAll()

	local visited = {}
	local temp = {}

	local chain = {}

	-- Topological sort

	local function visit(name: string)
		if visited[name] then
			return -- Already visited
		elseif temp[name] then
			throw(`Circular dependency detected at {table.concat(chain, " -> ")} -> {name}`)
		end

		temp[name] = true

		-- Add to history
		table.insert(chain, name)

		local child = children[name]

		if not child then
			throw(`Missing dependency <{name}> in {table.concat(chain, " -> ")}`)
		end

		if child.Depends then
			for aliasName, depName in child.Depends do
				if type(depName) ~= "string" then
					throw(`Invalid dependency type of <{aliasName}> in <{name}>, expected string got {type(depName)}`)
					continue
				end
				visit(depName) -- Visit all dependencies
			end
		end

		-- Remove the last element from history
		table.remove(chain)

		visited[name] = true
		table.insert(ordered, child)
	end

	for name in pairs(children) do
		visit(name) -- Visit all children
	end

	-- Replace empty dependency tables with actual module references
	for _, child in pairs(children) do
		if not child.Depends then
			continue
		end
		for aliasName, depName in child.Depends do
			child.Depends[aliasName] = children[depName]
		end
	end
end

--[[
    Sort modules by LoadOrder.
    Higher priority modules (larger LoadOrder) load first.
]]
function sortLoadedChildren()
	-- Biggest priority == Earlier Load
	table.sort(ordered, function(a, b)
		-- Member Priority is nullable so we replace it with zero if nil
		local ap = a.LoadOrder or 0
		local bp = b.LoadOrder or 0
		return ap > bp
	end)
end

--[[
    Registers all non-component modules in the LifeCycle system.
]]
function registerChildrenInLifeCycle()
	for _, child in pairs(ordered) do
		if child[Symbols.Type] ~= Symbols.ServiceOrController then
			continue
		end

		LifeCycle.register(child)
	end
end

--[[
    Applies extensions to all modules
]]
function applyExtensions()
	for _, child in pairs(ordered) do
		local isComponent = child[Symbols.Type] == Symbols.Component

		ExtensionHandler:applyTo(child, isComponent)
	end
end

--[[
    Executes a lifecycle method for all children.
    @param lifeCycle string - method name (e.g. "onInit", "onStart")
]]
function invokeLifeCycleMethods(lifeCycle: "onInit" | "onStart")
	for _, child in ordered do
		local impl = child[lifeCycle] -- Get implementation
		if type(impl) ~= "function" then
			continue -- There's no such function in the child or it's not a function
		end

		debug.setmemorycategory(child.Name) -- Mark for profiling

		local co = coroutine.create(impl)
		local success, result = coroutine.resume(co, child)

		if coroutine.status(co) == "suspended" then
			throw(
				`Error invoking {child.Name}.{lifeCycle}\nYielding is not allowed in lifecycle events!\nConsider use promise or task instead!`
			)
		end

		if not success then
			throw(`Error invoking {child.Name}.{lifeCycle}: {result}`)
		elseif result ~= nil and Promise.is(result) then
			local status, message = result:timeout(Core.config.promiseTimeout):awaitStatus()

			-- Check if the promise was rejected
			if status == Promise.Status.Rejected then
				throw(`Rejected promise in {child.Name}.{lifeCycle}: {message}`)
			end
		end
	end

	debug.resetmemorycategory()
end

--[[
    Initializes the framework.
    @param config? FrameworkConfig - optional framework configuration
    @return Promise - resolves when all modules are initialized (onInit)
]]
function Core.initialize(config: FrameworkConfig?)
	return Promise.new(function(r)
		-- Initialize config
		Core.config = setmetatable(config or {}, {
			__index = DEFAULT_CONFIG, -- Use default for missing fields
		})

		-- TODO: Rewrite and use as an extension
		-- Add Components as a possible dependency
		DependencyResolver.addCustomDependency("Components", Components.dependency, Symbols.ServiceOrController) -- Add components as a custom dependency

		-- Resolve dependencies
		resolveDependencies()
		-- Sort loaded children (LoadOrder)
		sortLoadedChildren()

		-- Apply extensions
		applyExtensions()

		-- Register children
		registerChildrenInLifeCycle()

		-- Initialize components
		Components.initialize()

		-- Invoke onInit
		local success = try(invokeLifeCycleMethods, "onInit failed", "onInit")

		r(success)
	end)
end

--[[
    Starts the framework.
    @return Promise - resolves when all modules have started (onStart) and lifecycle events are hooked
]]
function Core.start()
	-- Invoke onInit
	local success = try(invokeLifeCycleMethods, "onStart failed", "onStart")

	if not success then
		throw(`Framework start was not successful, check logs for more info, lifecycle has not been initialized!`)
	end

	-- Initialize LifeCycle module (Heartbeat, PreSimulation, RenderStepped)
	LifeCycle.initialize(Core.config.profiling)
end

return Core
