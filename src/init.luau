--[[
    LeafFramework.lua
    Root entry point of the Leaf framework.
    Provides unified APIs for adding services, controllers, and components,
    then runs initialization and startup lifecycle.
]]

local RunService = game:GetService("RunService")

local Core = require(script.Core)
local DependencyResolver = require(script.DependencyResolver)
local Utils = require(script.Utils)

local throw = Utils.throw

export type FrameworkConfig = Core.FrameworkConfig

local LeafFramework = {}

-- Internal state
local started = false

--[[
    Adds controllers/services from a directory.
    @param directory - The directory to scan
]]
function addChildren(directory)
	DependencyResolver.requireModules(directory, DependencyResolver.ServiceOrController)
end

--[[
    Recursively adds controllers/services from a directory and its subdirectories.
    @param directory - The directory to scan
]]
function addDeep(directory)
	DependencyResolver.requireModulesDeep(directory, DependencyResolver.ServiceOrController)
end

--[[
    Adds module loader aliases based on runtime context.

    On the **Client**, controllers are the equivalent of services on the server.
    On the **Server**, only services exist, but they share the same structure
    and dependency injection model internally.
]]
if RunService:IsClient() then
	LeafFramework.addControllers = addChildren
	LeafFramework.addControllersDeep = addDeep
else
	LeafFramework.addServices = addChildren
	LeafFramework.addServicesDeep = addDeep
end

--[[
    Registers component modules for automatic instantiation and lifecycle handling.

    @param directory - The Folder or ModuleScript directory containing components.
    Components are treated as dependency-aware, attribute-synced modules.
]]
LeafFramework.addComponents = function(directory)
	DependencyResolver.requireModules(directory, DependencyResolver.Component)
end

--[[
    Recursively registers components, scanning all subdirectories.

    @param directory - The Folder or ModuleScript directory to traverse.
    Useful when organizing components in nested folders by feature or domain.
]]
LeafFramework.addComponentsDeep = function(directory)
	DependencyResolver.requireModulesDeep(directory, DependencyResolver.Component)
end

--[[
    Bootstraps the framework.
    
    Steps:
      1. Calls Core.initialize() - builds dependency graph, resolves all bindings.
      2. On successful init, Core.start() - invokes all lifecycle onStart hooks.

    @param config - Optional configuration table (see Core.FrameworkConfig).
    @return Promise<void> - resolves once the framework is fully started.
]]
function LeafFramework.run(config: FrameworkConfig?)
	if started then
		throw("Framework has already been started.")
	end

	started = true

	return Core.initialize(config):andThen(function()
		return Core.start()
	end)
end

return LeafFramework
