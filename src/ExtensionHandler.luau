--[[
    ExtensionHandler
    
    Manages the registration and application of framework extensions.
    Extensions are used to mutate or inject functionality into Services 
    and Controllers (e.g., Networking, Logging) before their initialization.
]]

local Utils = require(script.Parent.Utils)

local try = Utils.try
local throw = Utils.throw

----------------------------------------------------------

type Extension = {
	Process: (any, boolean) -> (),
}

----------------------------------------------------------

local ExtensionHandler = {
	Extensions = {} :: { [string]: Extension },
}

-- Internal helper
local function assertIfExtensionExists(extensionName)
	if ExtensionHandler.Extensions[extensionName] then
		throw(`Extension '{extensionName}' already exists!`)
	end
end

--[[
    Registers a new extension to the framework
    @param extension ModuleScript The extension module containing mutation logic.
]]
function ExtensionHandler:addExtension(extension: ModuleScript)
	assertIfExtensionExists(extension.Name) -- Make sure the extension doesn't already exist
	local ok, required = try(require, `Failed to require extension {extension.Name}`, extension)

	if not ok then
		return -- Just ignore the extension
	end

	self.Extensions[extension.Name] = required
end

--[[
    Iterates through registered extensions and applies them to a module.
    This process occurs during the "Pre-Init" phase of the framework.
    @param module table The Service or Controller being processed.
    @param isComponent boolean True if the module is a component.
]]
function ExtensionHandler:applyTo(module, isComponent)
	for _, extension in pairs(self.Extensions) do
		if extension.Process then
			-- Apply the extension
			try(extension.Process, `Failed to apply extension {extension.Name} to {module.Name}`, module, isComponent)
		end
	end
end

return ExtensionHandler
