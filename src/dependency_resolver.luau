--[[
    Dependency resolver
]]
local DepedencyResolver = {}

local children = {}

DepedencyResolver.ServiceOrController = newproxy()
DepedencyResolver.Component = newproxy()

--[[
    Requires a module
    @param module The module
    @param isComponent True if the module is a component
]]
function requireModule(module, isComponent)
    local requiredModule = require(module) :: any

    if not requiredModule["Name"] then
        requiredModule.Name = module.Name -- Set the module name if empty
    end

    -- Set the module type
    requiredModule["Type"] = isComponent and DepedencyResolver.Component or DepedencyResolver.ServiceOrController
    -- Set the source
    requiredModule["Source"] = module

    if children[requiredModule.Name] then
        error(`[Framework] Duplicate module name: {module:GetFullName()} and {children[requiredModule.Name].Source:GetFullName()}`)
    end

    children[requiredModule.Name] = requiredModule -- Make a named node in the store
end

--[[
    Requires all modules in a directory
    @param directory The directory
    @param isComponent True if the modules are components
]]
function DepedencyResolver.requireModules(directory, isComponent)
    for _, module in ipairs(directory:GetChildren()) do
        if not module:IsA("ModuleScript") then
            continue
        end
        requireModule(module, isComponent)
    end
end

--[[
    Requires all modules in a directory recursively
    @param directory The directory
    @param isComponent True if the modules are components
]]
function DepedencyResolver.requireModulesDeep(directory, isComponent)
    for _, module in ipairs(directory:GetDescendants()) do
        if not module:IsA("ModuleScript") then
            continue
        end
        requireModule(module, isComponent)
    end
end

--[[
    Resolves a dependency
    @param name The name of the dependency
    @return The module
]]  
function DepedencyResolver.resolve(name)
    local module = children[name]

    if module then
        return module
    end

    error(`[Framework] Dependency '{name}' does not exist!`)
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
        error(`[Leaf] Duplicate module name: {name}`)
    end

    if not module["Name"] then
        module.Name = name -- Set the module name if empty
    end
    
    children[name] = module
end

return DepedencyResolver
