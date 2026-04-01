--[=[
    Root entry point of the Leaf framework.
    Provides unified APIs for adding services, controllers, and components,
    then runs initialization and startup lifecycle.
]=]

local RunService = game:GetService("RunService")

local Core = require(script.Core)
local DependencyResolver = require(script.DependencyResolver)
local ExtensionHandler = require(script.ExtensionHandler)
local Symbols = require(script.Symbols)
local Utils = require(script.Utils)

local throw = Utils.throw
local printStackTrace = Utils.printStackTrace

--------------------------------------------------------------------------

export type FrameworkConfig = Core.FrameworkConfig

--------------------------------------------------------------------------

local LeafFramework = {}

-- Internal state
local started = false

-- Internal helper
local function assertIfStarted()
	if started then
		throw("Leaf has already been started.")
	end
end

--------------------------------------------------------------------------

--[=[
    Adds controllers/services from a directory.
    @param directory - The directory to scan
]=]
function addChildren(directory)
	assertIfStarted()
	DependencyResolver.requireModules(directory, Symbols.ServiceOrController)
end

--[=[
    Recursively adds controllers/services from a directory and its subdirectories.
    @param directory - The directory to scan
]=]
function addDeep(directory)
	assertIfStarted()
	DependencyResolver.requireModulesDeep(directory, Symbols.ServiceOrController)
end

--[=[
    Adds module loader aliases based on runtime context.

    On the **Client**, controllers are the equivalent of services on the server.
    On the **Server**, only services exist, but they share the same structure
    and dependency injection model internally.
]=]
if RunService:IsClient() then
	LeafFramework.addControllers = addChildren
	LeafFramework.addControllersDeep = addDeep
else
	LeafFramework.addServices = addChildren
	LeafFramework.addServicesDeep = addDeep
end

--[=[
    Registers component modules for automatic instantiation and lifecycle handling.

    @param directory - The Folder or ModuleScript directory containing components.
    Components are treated as dependency-aware, attribute-synced modules.
]=]
LeafFramework.addComponents = function(directory)
	assertIfStarted()
	DependencyResolver.requireModules(directory, Symbols.Component)
end

--[=[
    Recursively registers components, scanning all subdirectories.

    @param directory - The Folder or ModuleScript directory to traverse.
    Useful when organizing components in nested folders by feature or domain.
]=]
LeafFramework.addComponentsDeep = function(directory)
	assertIfStarted()
	DependencyResolver.requireModulesDeep(directory, Symbols.Component)
end

--[=[
    Adds an extension module to the framework.
    
    @param module - The extension module to add
]=]
function LeafFramework.addExtension(module: ModuleScript)
	assertIfStarted()
	return ExtensionHandler:addExtension(module)
end

--------------------------------------------------------------------------

--[[
    Bootstraps the framework.
    
    Steps:
      1. Calls Core.initialize() - builds dependency graph, resolves all bindings.
      2. On successful init, Core.start() - invokes all lifecycle onStart hooks.

    @param config - Optional configuration table (see Core.FrameworkConfig).
    @return Promise<void> - resolves once the framework is fully started.
]]
function LeafFramework.run(config: FrameworkConfig?)
	assertIfStarted()

	started = true

	return Core.initialize(config):andThen(Core.start):catch(function(msg)
		printStackTrace(tostring(msg), "Leaf failed to start")
	end)
end

--------------------------------------------------------------------------

return LeafFramework
