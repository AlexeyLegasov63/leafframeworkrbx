# LeafFramework

**LeafFramework** — lightweight, modular Roblox framework built around **components**, **services**, and **lifecycle events**. Manages dependencies, asynchronous initialization, and per-frame updates efficiently. Very influenced by the **Flamework**.

## Features

- **Components**: attachable to any `Instance` via `CollectionService` tags.
- **Services / Controllers**: modular, dependency-aware, loaded in proper order.
- **Lifecycle**: `onInit`, `onStart`, `onTick`, `onPhysics`, `onRender`.
- **Asynchronous initialization** using `Promise`.
- **Attributes**: synchronized properties on components (`self.Attributes`), auto-updates with Instance.
- **Reusable thread system** for efficient lifecycle execution.
- **Dependency Resolver**: topological sorting, circular dependency detection.

## Installation

### Wally

```ini
[dependencies]
Leaf = "alexeylegasov63/leafframeworkrbx@0.1.2"
```

## Usage

### Initialization & Running

```lua
LeafFramework.addServices(game.ServerScriptService.Services)
LeafFramework.addComponents(game.ServerScriptService.Components)
LeafFramework.addComponentsDeep(game.ReplicatedStorage.Components)
W
-- And more more more

LeafFramework.run({
    profiling = true -- optional
}):catch(warn)
```

### Creating a Service

```lua
-- DamageService.lua
local DamageService = {
    LoadOrder = 2
}

function DamageService:onInit()
    self._time = 0
end

function DamageService:onTick(dt)
    self._time += dt
end

function DamageService:calculateDamage(damager)
    return damager.Attributes.Damage * self._time
end

return DamageService
```

### Creating a Component

```lua
-- DamagerComponent.lua
local DamagerComponent = {
    Name = "Damager",
    Tag = "Damager", -- Optional
    Attributes = {
        Damage = 10,
        LastDamage = 0,
    },
    Depends = {
        DamageService = {}
    }
}

function DamagerComponent:onSpawn()
	self.Super.onSpawn(self) -- If you wish to have BaseComponent stuff

    print(self.Depends.DamageService:calculateDamage(self)) -- Use the dependency

	self:onAttributeChanged("Damage", function(new, last)
		print("Hello, Flamework!", new, last)
	end)
end

    print(self.Depends.DamageService:calculateDamage(self)) -- Use the dependency

	self:onAttributeChanged("Damage", function(new, last)
		print("Hello, Flamework!", new, last)
	end)
end


return DamagerComponent
```

### Using a Component

```lua
local Components = require(game.ServerScriptService.LeafFramework.Components)

local damager = Components.addComponent(somePart, "Damager")
print(damager.Attributes.Damage) -- 10

damager.Attributes.LastDamage = 5
print(damager.Instance:GetAttribute("LastDamage")) -- 5
```

### Lifecycle Methods

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

```bash
argon build
```
