local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Just for example

local FullyExampleComponent = {
	-- Name = "NiceComponent" (If you don't want to use the component's module script name as the name)

	--[[ 
        The tag to watch for (Via CollectionService)
        Don't add if you don't want to use tags
    ]]
	Tag = "SomeCoolTag",

	--[[ 
        Short auto predicate that would be useful
        If you have only one type of instances that you want to work with
        Has more priority than Predicate, so if it returns false, the instance will be ignored 
        And Predicate will not be called

        string - Instance ClassName (:IsA)
    ]]
	Instance = "Player",

	--[[
        The predicate for the instances
        Return true if the instance suits your needs
        Otherwise false and the instance will be ignored
        And the component will not be added

        (instance: Instance) -> boolean
    ]]
	Predicate = function(instance)
		return true
	end,

	--[[
        List of dependencies
        {any string: DependencyName}
    ]]
	Depends = {
		abc = "DependencyName",
	},

	--[[
        Custom superclass for the component (Auto OOP)
        
    Super = "BaseComponent"

        Will be automatically set to "BaseComponent" if not specified
    ]]

	--[[
        Ignore all descendants of these instances

        {Instance}
    ]]
	BlacklistedAncestors = { Workspace, ReplicatedStorage },

	--[[
        Whitelist ancestors for blacklisted instances

        {Instance}
    ]]
	WhitelistedAncestors = { Workspace.CoolDir, ReplicatedStorage.Somewhere },

	--[[
        BaseComponent attributes like in Flamework
        Synchronized attributes proxy to Instance attributes

        {string: Any Roblox attributes supported type}
    ]]
	Attributes = {
		Num = 1,
	},
}

function FullyExampleComponent:onSpawn()
	--[[
        Inherited auto cleaner from BaseComponent:

    self.Cleaner = Trove.new()
    
        Will be automatically destroyed on despawn. Use it to store connections and etc.
    ]]

	print("Spawned")

	print(self.Depends.abc.Name) -- Will print "DependencyName"

	--[[
        Also inherited from BaseComponent
        Listens for the attribute changes

        Returns a connection that can be disconnected manually
        Or automatically disconnected on despawn (Via Cleaner)
    ]]
	local optionalConnection = self.onAttributeChanged("Num", function(newValue, oldValue)
		print("Num changed from", oldValue, "to", newValue)
	end)

	-- optionalConnection:Disconnect() It's a basic RBXScriptConnection
end

function FullyExampleComponent:onDespawn()
	print("Despawned")
end

-- Heartbeat LifeCycle Hook
function FullyExampleComponent:onTick(dt)
	print("Tick", dt)

	self.Attributes.Num += 1 -- Will update the Instance attribute
end

-- Post-Simulation LifeCycle Hook
function FullyExampleComponent:onPhysics(dt)
	print("Physics", dt)
end

-- RenderStepped LifeCycle Hook
-- Won't work on server cause it's client-only
function FullyExampleComponent:onRender(dt)
	print("Render", dt)
end

return FullyExampleComponent
