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

local Trove = require(script.Parent.Parent.Packages.Trove)

local BaseComponent = { 
    Name = "BaseComponent" 
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
        local current = self.Instance:GetAttribute(key)
        if current == nil then
            self.Instance:SetAttribute(key, default)
            attributes[key] = default
        else
            attributes[key] = current
        end

        -- Watch for external changes on this attribute
        self.Cleaner:Add(self.Instance:GetAttributeChangedSignal(key):Connect(function()
            attributes[key] = self.Instance:GetAttribute(key)
        end))
    end

    -- Two-way binding between self.Attributes and Instance attributes
    self.Attributes = setmetatable({}, {
        __index = function(_, k)
            return attributes[k]
        end,
        __newindex = function(_, k, v)
            self.Instance:SetAttribute(k, v)
            attributes[k] = v
        end
    })
end

--[[
    Lifecycle hook: called when the component appears in the world (spawn phase)

    Responsibilities:
      • Creates a Trove cleaner instance for automatic disconnection.
      • Initializes and binds attributes.
      • Sets up internal state.

    Important:
      • Do not override this directly. Instead, call `self.Super.onSpawn(self)` 
        from your subclass's onSpawn method to preserve cleanup behavior.
--]]
function BaseComponent:onSpawn()
    self.Cleaner = Trove.new()
    storeInstanceAttributes(self)
end

--[[
    Lifecycle hook: called when the component is about to be removed or the instance destroyed

    Responsibilities:
      • Cleanup of any connections, threads, and data owned by the component.
      • Called automatically when the Instance is removed from the game or
        manually when the framework despawns this component.

    Override behavior:
      • You may extend this method but should always call `self.Super.onDespawn(self)`.
--]]
function BaseComponent:onDespawn()
    if not self.Cleaner then
        return
    end
    self.Cleaner:Destroy() -- Destroy all connections and etc.
    self.Cleaner = nil
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

    self.Cleaner:Add(connection) -- Automatically disconnect on despawn

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

-- Prevent changes to the super class
return setmetatable(BaseComponent, {
    __newindex = function()
        error(`[Leaf] The super class cannot be changed!`, 4)
    end
})
