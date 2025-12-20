# LeafFramework

**LeafFramework** - is a Roblox framework built on **components**, **services**, and **lifecycle events**. Created by me out of a longing for **Flamework** :)

## Features

- **Services/Controllers**: modular, dependency-aware, loaded in proper order.
- **Components**: used by controllers and services.
- **Dependency Resolver**: topological sorting, circular dependency detection.
- **Component Inheritance**: fast inherit components simply by specifying their name
- **Networking**: doesn't include any network utility

## Installation

### Wally

```ini
Leaf = "alexeylegasov63/leafframeworkrbx@0.2.6"
```

## Usage

### Initialization & Running

```lua

LeafFramework.addServices(game.ServerScriptService.Services)
LeafFramework.addComponents(game.ServerScriptService.Components)
LeafFramework.addComponentsDeep(game.ReplicatedStorage.Components)

-- And more more more

LeafFramework.run({
    profiling = true -- optional
}):catch(warn)

```

### Creating a Service

```lua
-- HelloService.lua
local HelloService = {
    LoadOrder = 2
}

function HelloService:onInit()
    print("Init")
end

function HelloService:onStart()
    print("Start")
end

function HelloService:onTick(dt)
    print("Tick")
end

return HelloService
```

### Creating a Component

```lua
local BobComponent = {
    -- Name = "BobComponent" (If you don't want to use the component's module script name as the name)
    Tag = "SomeCoolTag", -- For CollectionService watching
    Instance = "Player", -- Instance:IsA fast predicate
    Predicate = function(instance)
        return instance.Name == "Bob" -- Ensure that the player's name is Bob
    end
}

function BobComponent:onSpawn()
    print("Bob is here!")
end

function BobComponent:onDespawn()
    print("Bye Bob... :c")
end

return BobComponent
```

### Using a Component

```lua
local PlayerInfoController = {
    Depends = {
        Components = {} -- Use Components as dependency (Just like in Flamework)
    }
}

-- A hook to the start lifecycle event
function PlayerInfoController:onStart()
    self:_startLookingForComponents()
    self:_startLookingForPlayers()
end

function PlayerInfoController:_startLookingForComponents()
    -- Will invoke the callback when the component is added
    -- Also invokes the callback for already existing components
    local connection = self.Depends.Components.watchComponent("PlayerInfoComponent", function(component)
        print("PlayerInfoComponent added to", component.Instance.Name)
    end)
    -- connection:Disconnect() Can be disconnected later
end

-- Will invoke the callback when a player joins
function PlayerInfoController:_startLookingForPlayers()
    for _, player in pairs(Players:GetPlayers()) do
        task.defer(self._handlePlayerJoin, self, player) -- For already existing players
    end

    Players.PlayerAdded:Connect(function(player)
        self:_handlePlayerJoin(player)
    end)
end

function PlayerInfoController:_handlePlayerJoin(player)
    local onCharSpawn = function(character)
        self:_handleCharSpawn(character)
    end

    if player.Character then
        onCharSpawn(player.Character)
    end

    player.CharacterAdded:Connect(onCharSpawn)
end

function PlayerInfoController:_handleCharSpawn(character)
    -- Use the component's "Name" field in the table of the component definition or
    -- the component's module script name

    local playerInfo = self.Depends.Components.addComponent(character, "PlayerInfoComponent")

    -- Will add the component to the virtual component holder of the instance (Character)
    -- If the instance removes the component, it will be removed from the virtual component holder automatically

    -- ! It's impossible to have multiple instances of the same component on the same instance
end

return PlayerInfoController
```

### LifeCycle Events Hooks

```lua
function SomeService:onTick(dt)
    print("Heartbeat delta:", dt)
end

function SomeService:onPhysics()
    print("Physics step")
end

-- Client-only
function SomeService:onRender()
    print("Render update")
end
```
