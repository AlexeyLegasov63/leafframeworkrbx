--[[
    BaseComponent.lua
    Leaf Framework - Base Component Class
    
    Overview:
        The BaseComponent class defines the abstract foundation for all 
        gameplay components in the Leaf framework. 
        Each component is bound to a Roblox Instance and synchronized 
        bi-directionally with that instance's Attributes.
        
        This class provides:
        - Automatic default attribute application
        - Cached attribute access through self.Attributes
        - Cleaner-based lifecycle management (via Trove by Sleitnick)
        - Hooks for spawn/despawn phases
        - Utility for reacting to attribute changes
        
        Components inheriting from this class **must** define:
            • Tag        (string) - CollectionService tag
            • Attributes (table)  - Default attributes and types
--]]

local Symbols = require(script.Parent.Parent.Symbols)
local Utils = require(script.Parent.Parent.Utils)
local Cleaner = require(script.Parent.Parent.Utils.Cleaner)

local try = Utils.try

local BaseComponent = {
	Name = "BaseComponent",
}
BaseComponent.__index = BaseComponent

--[[
    Internal helper.
    Synchronizes default and live attributes between the Instance and the component.

    Responsibilities:
      • Apply default values to the instance if missing.
      • Cache current attribute values for quick access.
      • Create a proxy table that keeps instance attributes and Lua table in sync.

    Example:
        self.Attributes = {
            Health = 100,
            MaxHealth = 200,
        }
        -> When onSpawn runs, the instance will receive these attributes.
        -> Any change to self.Attributes.Health updates the instance, and vice versa.
--]]
local function storeInstanceAttributes(self)
	local attributes = {}

	-- Setup attributes from Instance
	for key, default in pairs(self.Attributes or {}) do
		try(
			function()
				local current = self.Instance:GetAttribute(key)
				if current == nil then
					self.Instance:SetAttribute(key, default)
					attributes[key] = default
				else
					attributes[key] = current
				end

				-- Watch for external changes on this attribute
				self[Symbols.Cleaner]:add(self.Instance:GetAttributeChangedSignal(key):Connect(function()
					attributes[key] = self.Instance:GetAttribute(key)
				end))
			end,
			`Failed to load attribute {key} for component {self.Name}. Is it a valid Roblox attribute type? {typeof(
				default
			)}`
		)
	end

	-- Two-way binding between self.Attributes and Instance attributes
	self.Attributes = setmetatable({}, {
		__index = function(_, k)
			return attributes[k]
		end,
		__newindex = function(_, k, v)
			self.Instance:SetAttribute(k, v)
			attributes[k] = v
		end,
	})
end

--[[
    Lifecycle hook: called when the component appears in the world (spawn phase)

    Responsibilities:
      • Creates a simple cleaner instance for automatic disconnection.
      • Initializes and binds attributes.
      • Sets up internal state.
    
    Init Properties:
      • self.Name: Custom name for this component (Default is module script name)
      • self.Super: Super component name (Default is "BaseComponent")
      • self.Instance: Short instance ClassName validator
      • self.Attributes: Proxy table for accessing instance attributes
      • self.WhitelistedAncestors: List of whitelisted ancestors for this component
      • self.BlacklistedAncestors: List of blacklisted ancestors for this component
            Default: [ 
                ReplicatedFirst, 
                ReplicatedStorage,
                ServerStorage,
                StarterPack, 
                StarterGui,
                StarterPlayer
            ]
      • self.Tag: CollectionService tag for this component
      • self.Predicate: Predicate for this component
    
    Result Properties:
      • self.Attributes: Proxy table
      • self.Cleaner: Cleaner instance
      • self.Instance: Roblox Instance that this component is bound to
      • self.Tag: CollectionService tag
      • self.Name: Current component name
      • self.Super: Super component class (Use for calling super methods and access fields)
--]]
function BaseComponent:onSpawn()
	self[Symbols.Cleaner] = Cleaner.new()

	-- Initialize attributes
	storeInstanceAttributes(self)

	-- Create another cleaner instance for custom tasks
	self.Cleaner = self[Symbols.Cleaner]:extend()
end

--[[
    Lifecycle hook: called when the component is about to be removed or the instance destroyed

    Responsibilities:
      • Cleanup of any connections, threads, and data owned by the component.
      • Called automatically when the Instance is removed from the game or
        manually when the framework despawns this component.
--]]
function BaseComponent:onDespawn()
	self[Symbols.Cleaner]:cleanup() -- Destroy all connections and etc.
end

--[[
    Registers a callback that fires whenever a specific Attribute changes.

    @param attribute string  -- The attribute name to watch
    @param callback function -- Function(newValue, oldValue)

    @return RBXScriptConnection
        A connection object that can be disconnected manually if needed.

    Example:
        self:onAttributeChanged("Health", function(new, old)
            if new < old then
                print("Damage taken:", old - new)
            end
        end)
--]]
function BaseComponent:onAttributeChanged(attribute, callback)
	local lastValue = self.Attributes[attribute]

	-- Watch for attribute changes
	local connection = self.Instance:GetAttributeChangedSignal(attribute):Connect(function()
		local newValue = self.Instance:GetAttribute(attribute)
		local oldValue = lastValue
		lastValue = newValue
		self.Attributes[attribute] = newValue
		callback(newValue, oldValue)
	end)

	self[Symbols.Cleaner]:add(connection) -- Automatically disconnect on despawn

	return connection
end

--[[
    Destroys the underlying Instance.
    This is a convenience method for cases where a component should
    explicitly delete its associated object (e.g., temporary visual effects)
--]]
function BaseComponent:destroy()
	if not self.Instance then
		return
	end
	self.Instance:Destroy()
end

return BaseComponent
