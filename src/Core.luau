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
local LifeCycle = require(script.Parent.LifeCycle)
local Utils = require(script.Parent.Utils)
local Promise = require(script.Parent.Parent.Promise)
local Symbols = require(script.Parent.Symbols)

local throw = Utils.throw

export type FrameworkConfig = {
	profiling: boolean?, -- Enable/disable profiling for lifecycle events
}

local Core = {
	config = {} :: FrameworkConfig, -- Framework config
}

--[[
    Sorted modules after dependency resolution
]]
local ordered = {}

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
			for aliasName, depName in pairs(child.Depends) do
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
		for aliasName, depName in pairs(child.Depends) do
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
		if child[Symbols.Type] == DependencyResolver[Symbols.Component] then
			continue
		end
		LifeCycle.register(child)
	end
end

--[[
    Executes a lifecycle method asynchronously across all modules using Promise.
    @param lifeCycle string - method name (e.g. "onInit", "onStart")
    @param ... any - arguments passed to each module's method
    @return Promise - resolves when all lifecycle calls are completed
]]
function invokeLifeCycleMethodsAsync(lifeCycle, ...)
	local varargs = table.pack(...) -- Convert to array
	local promises = {} -- Promise array

	for _, child in pairs(ordered) do
		local impl = child[lifeCycle] -- Get implementation
		if type(impl) ~= "function" then
			continue -- There's no such function in the child or it's not a function
		end

		table.insert(
			promises,
			Promise.try(function()
				debug.setmemorycategory(child.Name) -- Mark for debug
				return impl(child, table.unpack(varargs)) -- Safe call
			end)
		)
	end

	return Promise.all(promises):andThen(function()
		debug.resetmemorycategory()
	end)
end

--[[
    Initializes the framework.
    @param config? FrameworkConfig - optional framework configuration
    @return Promise - resolves when all modules are initialized (onInit)
]]
function Core.initialize(config: FrameworkConfig?)
	return Promise.new(function()
		Core.config = config or {}

		-- Add Components as a possible dependency
		DependencyResolver.addCustomDependency("Components", Components.dependency, Symbols.ServiceOrController) -- Add components as a custom dependency

		-- Resolve dependencies
		resolveDependencies()
		-- Sort loaded children (LoadOrder)
		sortLoadedChildren()
		-- Register children
		registerChildrenInLifeCycle()

		-- Initialize components
		Components.initialize()

		-- Invoke onInit
		invokeLifeCycleMethodsAsync("onInit"):await()
	end)
end

--[[
    Starts the framework.
    @return Promise - resolves when all modules have started (onStart) and lifecycle events are hooked
]]
function Core.start()
	-- Invoke onStart
	return invokeLifeCycleMethodsAsync("onStart"):andThen(function()
		-- Initialize LifeCycle module (Heartbeat, PreSimulation, RenderStepped)
		LifeCycle.initialize(Core.config.profiling)
	end)
end

return Core
