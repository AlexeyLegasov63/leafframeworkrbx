--[[
    Leaf Framework Components Module
    Provides component-based architecture for Roblox entities (instances).
    Handles creation, lifecycle management, dependency resolution, and tagging.
]]

local CollectionService = game:GetService("CollectionService")

local Root = script.Parent
local BaseComponent = require(script.BaseComponent)
local Symbols = require(script.Parent.Symbols)
local DependencyResolver = require(Root.DependencyResolver)
local LifeCycle = require(Root.LifeCycle)
local Signal = require(Root.Utils.Signal)
local Utils = require(Root.Utils)

local throw = Utils.throw
local try = Utils.try

local DEFAULT_ANCESTRY_BLACKLIST = {
	game:GetService("ReplicatedFirst"),
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerStorage"),
	game:GetService("StarterPack"),
	game:GetService("StarterGui"),
	game:GetService("StarterPlayer"),
}

--[[
    Components Leaf Framework Module
]]
local Components = {
	Name = "Components",
}

-- Signals for component spawn/despawn events
Components.onComponentSpawned = Signal.new()
Components.onComponentDespawned = Signal.new()

local loadedComponents = {} -- ComponentName -> ComponentClass
local instancesMap = Utils.newWeakMap() -- Instance -> { ComponentName -> ComponentInstance }

-- Ensures that the component exists
function assertIfNotExists(componentName)
	if loadedComponents[componentName] then
		return -- Component exists, all is ok
	end
	throw(`Component '{componentName}' does not exist!`, 3)
end

-- Ensures that the instance has a tag
function assureHasTag(instance, tag)
	if CollectionService:HasTag(instance, tag) then
		return
	end
	CollectionService:AddTag(instance, tag)
end

-- Ensures that the instance has a components container
function assureComponentContainerExists(instance)
	if instancesMap[instance] then
		return true
	end

	instancesMap[instance] = {} -- Instance -> { ComponentName -> ComponentInstance }

	return false
end

-- Test if the instance is a descendant of any of the whitelisted ancestors
function testForAncestry(component, instance)
	local whitelist = component.WhitelistedAncestors

	-- Check if the instance is a descendant of any of the whitelisted ancestors
	-- If so, it passes the test
	if type(whitelist) == "table" then
		for _, ancestor in whitelist do
			if instance:IsDescendantOf(ancestor) then
				return true
			end
		end
	end

	local blacklist = component.BlacklistedAncestors or DEFAULT_ANCESTRY_BLACKLIST

	-- Check if the instance is a descendant of any of the blacklisted ancestors
	-- If so, it doesn't pass the test
	if type(blacklist) == "table" then
		for _, ancestor in blacklist do
			if instance:IsDescendantOf(ancestor) then
				return false
			end
		end
	end

	-- All is ok <3
	return true
end

-- Ensures that the instance passes all the predicates
function testInstance(component, instance)
	if not testForAncestry(component, instance) then
		return false -- Doesn't pass the ancestry
	end

	-- Auto type predicate
	local autoIsA = component.Instance

	-- Check if the instance is of the correct type
	if type(autoIsA) == "string" and not instance:IsA(autoIsA) then
		return false
	end

	-- Custom predicate
	local predicate = component.Predicate

	-- There is no predicate
	if type(predicate) ~= "function" then
		return true
	end

	-- Custom predicate
	return predicate(instance)
end

-- Removes a tag from an instance
function removeTagFromInstance(instance, tag)
	CollectionService:RemoveTag(instance, tag)
end

-- Watch for instances with a specific tag
function watchForInstances(component)
	local name = component.Name
	local tag = component.Tag

	local wrapper = function(instance: Instance)
		if not testInstance(component, instance) then
			return -- Doesn't pass the predicate
		end

		-- Add the tag to the instance without checking cause we already did it
		local success, componentInstance = try(
			Components.addComponent,
			`Failed to call constructor for instance {instance:GetFullName()}`,
			Components,
			instance,
			name,
			true -- Skip test, we already did it
		)

		if not success then
			return
		end

		local connection
		connection = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(otherInstance)
			if otherInstance ~= instance then
				return
			end

			connection:Disconnect()

			try(
				Components.removeComponent,
				`Failed to remove component {name} from instance {instance:GetFullName()}`,
				Components,
				instance,
				name
			)
		end)

		-- Check if the component has BaseComponent as a super class
		if componentInstance:isA("BaseComponent") == BaseComponent then
			componentInstance[Symbols.Cleaner]:Add(connection) -- Manual cleanup
		end
	end

	-- Already existing instances
	for _, instance in pairs(CollectionService:GetTagged(tag)) do
		task.defer(wrapper, instance)
	end

	-- New instances
	CollectionService:GetInstanceAddedSignal(tag):Connect(wrapper)
end

--[[
    Invokes all the methods of the OOP hierarchy of the component
    @param componentInstance ComponentInstance
    @param methodName string
]]
function invokeSharedComponentMethod(componentInstance, methodName)
	local super = componentInstance.Super

	-- Invoke all the methods
	while super ~= nil do
		local method = super[methodName]

		if type(method) == "function" then
			method(componentInstance)
		end

		super = super.Super
	end
end

--[[
    Invokes a method of the component if it exists
]]
function invokeComponentMethod(componentInstance, methodName, ...)
	-- Auto invoke life cycle methods
	if methodName == "onSpawn" or methodName == "onDespawn" then
		invokeSharedComponentMethod(componentInstance, methodName)
	end

	local method = componentInstance[methodName]

	if type(method) ~= "function" then
		return
	end

	return method(componentInstance, ...)
end

--[[
    Creates a new instance of the component
]]
function createComponentInstance(component, instance)
	local componentInstance = setmetatable({}, component)
	componentInstance.Instance = instance
	return componentInstance
end

--[[
    Resolve component dependencies
    @param instance Instance
    @param component Component
    @param componentInstance ComponentInstance
]]
function resolveComponentDependencies(instance, component, componentInstance)
	if not component.Depends then
		return
	end

	componentInstance.Depends = {} -- I HATE THIS FUCKING LINE, I SPENT HOURS DEBUGGING IT

	for aliasName, dependencyName in pairs(component.Depends) do
		local dependency = DependencyResolver.resolve(dependencyName)

		if dependency[Symbols.Type] == Symbols.ServiceOrController then
			componentInstance.Depends[aliasName] = dependency -- Just add the child
			continue
		end

		-- Otherwise if it's a component
		local dependencyInstance = Components:addComponent(instance, dependencyName) -- Create component if it doesn't exist
		componentInstance.Depends[aliasName] = dependencyInstance
	end
end

--[[
    Get the super class
]]
function getSuperComponentClass(module)
	local superClass = module["Super"]

	-- Fully custom component
	if type(superClass) == "string" and superClass ~= "BaseComponent" then
		return DependencyResolver.resolve(superClass)
	end

	return BaseComponent -- Default
end

--[[
    Topological sort for component inheritance
]]
function topologicalComponentsInheritanceSort(components)
	local sorted, inheritance, visited, temp = {}, {}, {}, {}

	local function visit(name)
		if visited[name] then
			return
		elseif temp[name] then
			throw(`Circular class inheritance detected: {table.concat(inheritance, " -> ")} -> {name}`)
		end

		temp[name] = true

		local component = components[name]

		if not component then
			throw(`Unknown super class <{name}> in {table.concat(inheritance, " -> ")}`)
		end

		-- Add to history
		table.insert(inheritance, name)

		if type(component.Super) == "string" and component.Super ~= "BaseComponent" then
			visit(component.Super) -- Visit the super class
		elseif component.Super then
			throw(`Unknown super class {component.Super} for component {name}`)
		end

		-- Remove the last element from history
		table.remove(inheritance, #inheritance)

		temp[name] = nil
		visited[name] = true

		table.insert(sorted, name)
	end

	-- Visit all components
	for name in pairs(components) do
		visit(name)
	end

	return sorted
end

--[[
    Check if componentClass is a descendant of otherComponentClass
    @param componentClass Component
    @param otherComponentClass Component or string
]]
function componentClassIs(componentClass, otherComponentClass)
	local otherClassName = type(otherComponentClass) == "string" and otherComponentClass or otherComponentClass.Name
	local selfClass = componentClass

	while selfClass ~= nil do
		local selfClassName = selfClass.Name

		if selfClassName == otherClassName then
			return true
		elseif selfClassName == "BaseComponent" then
			return false
		end

		selfClass = selfClass.Super
	end

	return false
end

--[[
    Resolve component inheritance (super class)
    @param component Component
]]
function resolveComponentsInheritance(components)
	local sorted = topologicalComponentsInheritanceSort(components)

	for _, name in pairs(sorted) do
		local component = components[name]

		-- Check for reserved symbol
		if component.isA then
			throw(`Component {name} has a reserved symbol "isA", use a different name for it.`)
		end

		-- Useful for OOP inheritance checking
		component.isA = componentClassIs

		-- Get super class
		local super = getSuperComponentClass(component)

		component = setmetatable(component, {
			__index = super, -- Inherit from the super class
			__tostring = function()
				return name -- Use the name as a symbol
			end,
		})
		component.__index = component

		component.Super = super -- Set super class table
	end
end

--[[
    Load a component module
    @param module The module
]]
function loadComponent(component)
	loadedComponents[component.Name] = component

	if not component.Tag then
		return -- Doesn't have a tag, so we don't need to do anything
	end

	-- Watch for instances with the tag
	watchForInstances(component)
end

--[[
    Initializes all the components
]]
function initializeComponents()
	local loaded = DependencyResolver.listAll()

	local components = {}

	for _, module in pairs(loaded) do
		if module[Symbols.Type] ~= Symbols.Component then
			continue
		end
		components[module.Name] = module
	end

	resolveComponentsInheritance(components)

	for _, module in pairs(components) do
		loadComponent(module)
	end
end

----------------------------------------

--[[
    Get all the component instances
    @param componentName Name of the component
    @return An array of component instances
]]
function Components:getComponents(componentName: string)
	assertIfNotExists(componentName)

	local instances = {}

	for _, instanceComponents in pairs(instancesMap) do
		local componentInstance = instanceComponents[componentName]

		-- Check if the component exists in the instance
		if not componentInstance then
			continue
		end

		table.insert(instances, componentInstance)
	end

	return instances
end

--[[
    Get all instances with a specific component
    @param componentName Name of the component
    @return An array of instances
]]
function Components:getInstancesWithComponent(componentName: string)
	assertIfNotExists(componentName)

	local withComponent = {}

	for _, instance in pairs(instancesMap) do
		if instance[componentName] then
			table.insert(withComponent, instance)
		end
	end

	return withComponent
end

--[[
    Get component from instance
    @param instance Instance to get the component
    @param componentName Name of the component
    @return A component instance or nil
]]
function Components:getComponent(instance: Instance, componentName: string)
	assertIfNotExists(componentName)
	return instancesMap[instance] and instancesMap[instance][componentName]
end

--[[
    Check if instance has component
    @param instance Instance to check
    @param componentName Name of the component
    @return True if the instance has the component otherwise false
]]
function Components:hasComponent(instance: Instance, componentName: string)
	return Components:getComponent(instance, componentName) ~= nil
end

--[[
    Check if component is a descendant of otherComponent (InstanceOf)
    @param componentName Name of the component
    @param otherComponentName Name of the other component
    @return True if the component is a descendant otherwise false
]]
function Components:componentIsA(componentName, otherComponentName)
	assertIfNotExists(componentName) -- Component
	assertIfNotExists(otherComponentName) -- Other component

	local component = loadedComponents[componentName]
	local otherComponent = loadedComponents[otherComponentName]

	return componentClassIs(component, otherComponent)
end

--[[
    Add component to instance
    @param instance Instance to add the component
    @param componentName Name of the component
    @param skipTest Skip the test (Ancestry, type, predicate checkings)
    @return A component instance that was added otherwise the already existing one
]]
function Components:addComponent(instance: Instance, componentName: string, skipTest: boolean?)
	assertIfNotExists(componentName)
	assureComponentContainerExists(instance)

	local component = loadedComponents[componentName]

	if not skipTest and not testInstance(component.Predicate, instance) then
		throw(`Instance '{instance:GetFullName()}' does not pass test for component '{componentName}'!`, 3)
	end

	-- Check if the component already exists
	if instancesMap[instance][componentName] then
		-- Component really exists so return it
		return instancesMap[instance][componentName]
	end

	-- Create the component with the instance
	local componentInstance = createComponentInstance(component, instance)

	resolveComponentDependencies(instance, component, componentInstance)

	-- Call onSpawn
	local success = Utils.try(function()
		invokeComponentMethod(componentInstance, "onSpawn")
	end, `Failed to spawn component: {component.Tag}, instance: {instance:GetFullName()}`)

	if not success then
		return
	end

	-- Put the component into the instance components container
	instancesMap[instance][componentName] = componentInstance

	-- Register the component
	LifeCycle.register(componentInstance)

	-- Check if the component has tag
	if component.Tag then
		-- Add the tag to the instance if missing
		assureHasTag(instance, component.Tag)
	end

	-- Fire public event
	Components.onComponentSpawned:Fire(component.Name, componentInstance)

	return componentInstance
end

-- Check for collisions
function componentHasCollisions(componentInstance, componentsContainer)
	for _, child in pairs(componentsContainer) do
		if child.Depends[componentInstance.Name] then
			return true
		end
	end
	return false
end

--[[
    Remove component from instance
    @param instance Instance to remove the component
    @param componentName string Name of the component
    @return True if the component was removed otherwise false
]]
function Components:removeComponent(instance, componentName)
	assertIfNotExists(componentName)

	local component = loadedComponents[componentName]

	-- Check if the component exists, here we don't call assureComponentContainerExists
	-- To avoid unnecessary allocation in the instancesMap
	if not instancesMap[instance] or not instancesMap[instance][componentName] then
		return false
	end

	local componentInstance = instancesMap[instance][componentName]

	-- Remove the tag from the instance
	removeTagFromInstance(instance, component.Tag)

	-- Unregister the component
	LifeCycle.unregister(componentInstance)

	-- Update the instance's components container
	instancesMap[instance][componentName] = nil

	-- Call destructor
	Utils.try(function()
		invokeComponentMethod(componentInstance, "onDespawn")
	end, `Failed to despawn component: {component.Tag}, instance: {instance:GetFullName()}`)

	-- Check if the instance has no more components
	if next(instancesMap[instance]) == nil then
		-- No more components
		instancesMap[instance] = nil
	else
		-- There are more components, check for collisions and remove them
		-- (Components that depend on this one)
		for _, anotherComponentInstance in pairs(instancesMap[instance]) do
			-- Check for collisions (If another component has a dependency on this one)
			if not componentHasCollisions(anotherComponentInstance, instancesMap[instance]) then
				continue
			end
			-- Otherwise remove the component with its dependencies
			Components.removeComponent(instance, anotherComponentInstance.Name)
		end
	end

	-- Fire public event
	Components.onComponentDespawned:Fire(component.Name, componentInstance)

	return true
end

--[[
    Watch for component instances
    @param component Name of the component
    @param callback Callback function
    @return Callback that removes the connection 
]]
function Components:watchComponent(component, callback)
	assertIfNotExists(component)
	do
		-- Do it in a new block to not keep the references
		local alreadyExisting = Components:getComponents(component)

		-- Invoke the callback for the already existing instances
		for _, instance in pairs(alreadyExisting) do
			task.defer(callback, instance)
		end
	end

	-- Watch for new instances
	return Components.onComponentSpawned:Connect(function(tag, instance)
		if tag ~= component then
			return
		end
		callback(instance)
	end)
end

----------------------------------------

-- Export
return {
	dependency = Components,
	initialize = initializeComponents,
}
