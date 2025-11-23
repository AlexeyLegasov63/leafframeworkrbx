--!nolint ImplicitReturn
--[[
    Dependency resolver
]]

local Utils = require(script.Parent.utils)

local throw = Utils.throw

local DepedencyResolver = {}

local children = {}

DepedencyResolver.ServiceOrController = newproxy()
DepedencyResolver.Component = newproxy()

--[[
    Requires a module
    @param module The module
    @param type Dependency type
]]
function requireModule(module, type)
    local requiredModule = require(module) :: any

    if not requiredModule["Name"] then
        requiredModule.Name = module.Name -- Set the module name if empty
    end

    -- Set the module type
    requiredModule["Type"] = type
    -- Set the source
    requiredModule["Source"] = module

    if children[requiredModule.Name] then
        throw(`Duplicate module name: {module:GetFullName()} and {children[requiredModule.Name].Source:GetFullName()}`)
    end

    children[requiredModule.Name] = requiredModule -- Make a named node in the store
end

--[[
    Requires all modules in a directory
    @param directory The directory
    @param type Dependency type
]]
function DepedencyResolver.requireModules(directory, type)
    for _, module in ipairs(directory:GetChildren()) do
        if not module:IsA("ModuleScript") then
            continue
        end
        requireModule(module, type)
    end
end

--[[
    Requires all modules in a directory recursively
    @param directory The directory
    @param type Dependency type
]]
function DepedencyResolver.requireModulesDeep(directory, type)
    for _, module in ipairs(directory:GetDescendants()) do
        if not module:IsA("ModuleScript") then
            continue
        end
        requireModule(module, type)
    end
end

--[[
    selene: allow()
    Resolves a dependency
    @param name The name of the dependency
    @return The module
]]  
function DepedencyResolver.resolve(name)
    local module = children[name]

    if module then
        return module
    end

    throw(`Dependency '{name}' does not exist!`)
end

--[[
    Lists all loaded modules
    @return An array of modules
]]
function DepedencyResolver.listAll()
    return children
end

--[[
    Adds a custom dependency
    @param name The name of the dependency
    @param module The module
]]
function DepedencyResolver.addCustomDependency(name, module)
    if children[name] then
        throw(`Duplicate module name: {name}`)
    end

    if not module["Name"] then
        module.Name = name -- Set the module name if empty
    end
    
    children[name] = module
end

return DepedencyResolver
