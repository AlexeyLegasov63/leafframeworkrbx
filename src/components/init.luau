-- components.luau

local CollectionService = game:GetService("CollectionService")

local Root = script.Parent
local BaseComponent = require(script.base_component)
local DependencyResolver = require(Root.dependency_resolver)
local LemonSignal = require(Root.Packages.LemonSignal)
local LifeCycle = require(script.Parent.life_cycle)
local Utils = require(Root.utils)

--[[
    Components Leaf Framework Module
]] 
local Components = {
    Name = "Components",
}

Components.onComponentSpawned = LemonSignal.new()
Components.onComponentDespawned = LemonSignal.new()

local loadedComponents = {} -- ComponentName -> ComponentClass
local instancesMap = Utils.newWeakMap() -- Instance -> { ComponentName -> ComponentInstance }

-- Ensures that the component exists
function assertIfNotExists(componentName)
    if loadedComponents[componentName] then
        return -- Component exists, all is ok
    end
    error(`[Leaf] Component '{componentName}' does not exist!`, 3)
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

-- Ensures that the instance passes the predicate
function testInstance(predicate, instance)
    if not predicate then
        return true
    end
    return predicate(instance)
end

-- Removes a tag from an instance
function removeTagFromInstance(instance, tag)
	CollectionService:RemoveTag(instance, tag)
end

-- Watch for instances with a specific tag
function watchForInstances(tag, predicate, constructor)
    local wrapper = function(instance: Instance)
        if not testInstance(predicate, instance) then
            return -- Doesn't pass the predicate
        end
        local success, destructor = pcall(constructor, instance)
        if not success then
            warn(`Failed to call constructor for instance {instance:GetFullName()}:\n\t{destructor}`)
            return
        end
        local connection
        connection = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(otherInstance)
            if otherInstance ~= instance then
                return
            end

            connection:Disconnect()

            local success, err = pcall(destructor)

            if success then
                return
            end

            warn(`[Leaf] Failed to call destructor for instance {instance:GetFullName()}:\n\t{err}`)
        end)
    end

	for _, instance in pairs(CollectionService:GetTagged(tag)) do
		task.defer(wrapper, instance)
	end

    CollectionService:GetInstanceAddedSignal(tag):Connect(wrapper)
end

--[[
    Invokes a method of the component super class if it exists
]]
function invokeLifeCycleComponentMethod(componentInstance, methodName, ...)
    local method = componentInstance.Super[methodName]

    if type(method) ~= "function" then
        return
    end

    return method(componentInstance, ...)
end

--[[
    Invokes a method of the component if it exists
]]
function invokeComponentMethod(componentInstance, methodName, ...)
    -- Auto invoke life cycle methods
    invokeLifeCycleComponentMethod(componentInstance, methodName, ...)

    local method = componentInstance[methodName]

    if type(method) ~= "function" then
        return
    end

    return method(componentInstance, ...)
end

--[[
    Creates a new component class
]]
function createNewComponent(class, super)
    class.__index = class
    class.Super = super
    return setmetatable(class, super)
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

    for dependencyName in pairs(component.Depends) do
        local dependency = DependencyResolver.resolve(dependencyName)

        if dependency.Type == DependencyResolver.ServiceOrController then
            componentInstance.Depends[dependencyName] = dependency -- Just add the child
            continue
        end

        -- Otherwise if it's a component
        local dependencyInstance = Components.addComponent(instance, dependencyName) -- Create component if it doesn't exist
        componentInstance.Depends[dependencyName] = dependencyInstance
    end
end

--[[
    Get the super class
]]
function getSuperComponentClass(module)
    local superClass = module["Super"]

    -- Fully custom component
    if type(superClass) == "table" then
        return superClass
    elseif superClass then
        error(`[Leaf] Invalid super class '{superClass}' in component '{module.Name}'!`)
    end

    return BaseComponent -- Default
end

--[[
    Load a component module
    @param module The module
]]
function loadComponent(module)
    local component = createNewComponent(module, getSuperComponentClass(module))

    loadedComponents[module.Name] = component

    if not component.Tag then
        return -- Doesn't have a tag, so we don't need to do anything
    end

    watchForInstances(component.Tag, function(instance)
        local componentInstance = Components.addComponent(instance, component.Name)

        Components.onComponentSpawned:Fire(component.Tag, componentInstance)

        return function()
            Components.removeComponent(instance, component.Name)
            Components.onComponentDespawned:Fire(component.Tag, componentInstance)
        end
    end)
end

--[[
    Initializes all the components
]]
function initializeComponents()
    local loaded = DependencyResolver.listAll()

    for _, module in pairs(loaded) do
        if module.Type ~= DependencyResolver.Component then
            continue
        end
        loadComponent(module)
    end
end

----------------------------------------

--[[
    Get all the component instances
    @param componentName Name of the component
    @return An array of component instances
]]
function Components.getComponents(componentName: string)
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
function Components.getInstancesWithComponent(componentName:  string)
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
function Components.getComponent(instance: Instance, componentName: string)
    assertIfNotExists(componentName)
    return instancesMap[instance] and instancesMap[instance][componentName]
end

--[[
    Check if instance has component
    @param instance Instance to check
    @param componentName Name of the component
    @return True if the instance has the component otherwise false
]]
function Components.hasComponent(instance: Instance, componentName: string)
    return Components.getComponent(instance, componentName) ~= nil
end

--[[
    Add component to instance
    @param instance Instance to add the component
    @param componentName Name of the component
    @return A component instance that was added otherwise the already existing one
]]
function Components.addComponent(instance: Instance, componentName: string)
    assertIfNotExists(componentName)
    assureComponentContainerExists(instance)

    local component = loadedComponents[componentName]

    if not testInstance(component.Predicate, instance) then
        error(`[Leaf] Instance '{instance:GetFullName()}' does not pass the predicate for component '{componentName}'!`, 3)
    end

    -- Check if the component already exists
    if instancesMap[instance][componentName] then
         -- Component really exists so return it
        return instancesMap[instance][componentName]
    end

    -- Create the component with the instance
    local componentInstance = createComponentInstance(component, instance)

    -- Put the component into the instance components container
    instancesMap[instance][componentName] = componentInstance

    resolveComponentDependencies(instance, component, componentInstance)

    -- Call onSpawn
    Utils.try(function()
        invokeComponentMethod(componentInstance, "onSpawn")
    end, `Failed to spawn component: {component.Tag}, instance: {instance:GetFullName()}`)

    -- Register the component
    LifeCycle.register(componentInstance)

    -- Check if the component has tag
    if component.Tag then
        -- Add the tag to the instance if missing
        assureHasTag(instance, component.Tag)
    end

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
function Components.removeComponent(instance, componentName)
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

    return true
end

--[[
    Watch for component instances
    @param component Name of the component
    @param callback Callback function
    @return Callback that removes the connection 
]]
function Components.watchComponent(component, callback)
    assertIfNotExists(component)
    do
        -- Do it in a new block to not keep the references
        local alreadyExisting = Components.getComponents(component)

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
    initialize = initializeComponents
}