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
Leaf = "alexeylegasov63/leafframeworkrbx@0.2.8"
```

## Usage

### Initialization & Running

```lua

LeafFramework.addServices(game.ServerScriptService.Services)
LeafFramework.addComponentsDeep(game.ServerScriptService.Components)
LeafFramework.addComponents(game.ReplicatedStorage.Components)

-- And more more more

LeafFramework.run({
    profiling = true -- optional
}):catch(warn)

```

### Creating a Service/Controller

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
