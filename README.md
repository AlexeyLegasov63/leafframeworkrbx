# 🍃 Leaf

**A lightweight, strongly-typed lifecycle framework for Roblox.**

Leaf is a Roblox framework built around **Services, Controllers, Components, and explicit lifecycle management**.

It is designed to keep your code predictable without getting in the way of Luau's native module system.

> **Leaf manages when your code runs — not how your code depends on other modules.**

---

## ✨ Features

- 🧩 **Services & Controllers** — organize server and client-side logic into lifecycle-managed modules.
- 🌿 **Components** — CollectionService-based components with predicates, inheritance, cleanup, and lifecycle hooks.
- ⏱️ **Deterministic lifecycle** — Leaf exclusively controls initialization and startup.
- 🔢 **Load ordering** — control initialization order with `LoadOrder`.
- ⚡ **Async startup** — return a Promise from lifecycle hooks and let Leaf wait for it.
- 💥 **Startup timeouts** — prevent accidentally hanging the entire application during initialization.
- 🧹 **Automatic cleanup** — components have an integrated Cleaner and destruction lifecycle.
- 🧬 **Component inheritance** — extend existing components without rebuilding their behavior.
- 🎯 **Native Luau dependencies** — use regular `require()` for service dependencies and keep full type information.
- 🪶 **Lightweight** — Leaf does not try to replace Roblox's module system or add unnecessary abstractions.
- 🚫 **No networking layer** — use the networking solution that fits your project.

---

# 🧠 Philosophy

Leaf follows three simple rules.

### 1. Leaf owns the lifecycle

Your application has a single entry point:

```lua
Leaf.run()
```

After modules have been registered, **Leaf is responsible for initializing and starting them**.

Services and controllers should not start themselves from module scope.

---

### 2. Logic belongs inside lifecycle hooks

A module should describe what it is.

Runtime logic belongs in lifecycle hooks:

```lua
local DataService = {}

function DataService.onInit(self: Self)
	-- Prepare state
end

function DataService.onStart(self: Self)
	-- Start runtime behavior
end

return DataService
```

Avoid executing application logic directly in the module body.

This keeps module loading separate from application startup and makes the lifecycle predictable.

---

### 3. Initialization must be finite

`onInit` and `onStart` should never silently yield forever.

If an operation is asynchronous, return a Promise:

```lua
function DataService.onInit(self: Self)
	return Database:connect()
end
```

Leaf waits for the Promise to resolve.

If initialization exceeds the configured timeout, startup fails.

```text
Leaf.run()
    │
    ├── onInit()
    │      │
    │      └── Promise
    │             │
    │             ├── resolved ──► continue
    │             │
    │             └── timeout ───► startup failure
    │
    └── onStart()
```

This is intentional.

A framework should **fail loudly during startup rather than leave a server running in a partially initialized state**.

---

# 🚀 Installation

### Wally

```toml
Leaf = "alexeylegasov63/leafframeworkrbx@0.4.4"
```

Then:

```lua
local Leaf = require("@pkg/Leaf")
```

---

# 🏁 Getting Started

Register your services and components, then start Leaf once:

```lua
local Leaf = require("@pkg/Leaf")

Leaf.addServices(ServerScriptService.Services)

Leaf.addComponentsDeep(ServerScriptService.Components)
Leaf.addComponents(ReplicatedStorage.Components) -- From Shared

Leaf.run({
	profiling = true,
}):catch(warn)
```

`run()` is the only thing that actually starts the framework.

You can register as many services, controllers, and component locations as your project requires before calling it.

---

# 🧩 Services & Controllers

Services and controllers are ordinary Luau modules.

```lua
local HelloService = {
	LoadOrder = 2,
}

function HelloService.onInit(self: Self)
	print("HelloService initialized")
end

function HelloService.onStart(self: Self)
	print("HelloService started")
end

function HelloService.onTick(self: Self, delta: number)
	print("Tick:", delta)
end

return HelloService
```

### Load order

Use `LoadOrder` when a service must initialize before another one:

```lua
local DataService = {
	LoadOrder = 1,
}

return DataService
```

```lua
local InventoryService = {
	LoadOrder = 2,
}

return InventoryService
```

Leaf handles the lifecycle order for you.

---

# 🔗 Dependencies

Leaf does **not** require a service registry for dependencies.

Use normal Luau `require()`:

```lua
local DataService = require("./DataService")

local InventoryService = {}

function InventoryService.onStart(self: Self)
	local data = DataService:getPlayerData()
end

return InventoryService
```

This is intentional.

Regular `require()` provides:

- native Luau type inference;
- autocomplete;
- compile-time type checking;
- explicit dependencies;
- no string-based service lookup.

Leaf manages **lifecycle**, while Luau manages **module dependencies**.

---

# ⚡ Async Lifecycle

Lifecycle hooks can return a Promise.

```lua
local DataService = {}

function DataService.onInit(self: Self)
	return Database:connect() -- Promise
end

function DataService.onStart(self: Self)
	return Database:loadSchema() -- Promise
end

return DataService
```

Leaf waits for the returned Promise before continuing the startup sequence.

For long-running processes, create a separate task instead of blocking startup:

```lua
function DataService.onStart(self: Self)
	task.spawn(function()
		while true do
			self:process()
			task.wait(1)
		end
	end)
end
```

### Startup timeout

Leaf protects startup from accidental infinite waits.

The default timeout is **10 seconds** and can be configured.

If a lifecycle Promise does not finish in time, Leaf treats the startup as failed instead of silently continuing with an incomplete application.

---

# 🌿 Components

Components are built around Roblox's `CollectionService`.

A basic component:

```lua
local Leaf = require("@pkg/Leaf")

type HeadInstance = Model & {
    Eye1: Part,
    Eye2: Part
}

local Head = {
	Tag = "Head",
}

function Head.onSpawn(self: Self)
	print("Head spawned:", self.Instance.Name)
end

function Head.onDespawn(self: Self)
	print("Head removed")
end

export type Self = {} & Leaf.BaseComponent<HeadInstance, nil> & typeof(Head)

return Head
```

Components are automatically created when their tag and predicates match an instance.

---

# 🎯 Component Type Safety

Leaf provides `BaseComponent` to make component APIs strongly typed.

A typical component can define its Instance type:

```lua
type EnemyInstance = Model & {
    Head: Part
}
```

and expose the complete component type through `Self`:

```lua
export type Self =
	{} &
	Leaf.BaseComponent<EnemyInstance, nil> &
	typeof(Enemy)
```

This allows methods to use the fully composed component type:

```lua
function Enemy.onSpawn(self: Self)
	self.Instance.Name = "Enemy"

	local tag = self:onDestroy(Tag:Clone())
    tag.Parent = self.Instance

	self:remove() -- Remove the component only
    self:destroy() -- Destroy the instance
end
```

The same `Self` pattern can be used for other component methods:

```lua
function Enemy.onDespawn(self: Self)
	-- ...
end

function Enemy.someMethod(self: Self)
	-- ...
end
```

---

# 🧬 Component Inheritance

Components can inherit from another component.

```lua
local Enemy = {
	Tag = "Enemy",
}

local FlyingEnemy = {
	Tag = "FlyingEnemy",
	Super = Enemy,
}
```

This allows components to share behavior while extending it for more specialized use cases.

---

# 🧹 Component Cleanup

Every `BaseComponent` has an integrated `Cleaner`.

Use `onDestroy()` as a convenient shortcut:

```lua
function Enemy.onSpawn(self: Self)
	local connection = RunService.Heartbeat
		:Connect(function()
			-- ...
		end)

	self:onDestroy(connection)

    -- Or self.Cleaner:add(connection)
end
```

When the component is destroyed, registered cleanup tasks are automatically executed.

---

# 📦 Component Bundles

Components can also own other components.

```lua
self:componentsBundle({
	HealthComponent,
	CombatComponent,
})
```

The bundled components are destroyed together with their parent component.

This makes it possible to compose complex behavior while keeping ownership explicit.

---

# 🏷️ Attributes

Components can react to Roblox Attributes:

```lua
function Enemy.onSpawn(self: Self)
	self:onAttributeChanged("Health", function(newValue, oldValue)
		print("Health:", oldValue, "→", newValue)
	end)
end
```

---

# 🔍 Component Predicates

Components can restrict which instances they attach to.

For example:

```lua
local BobComponent = {
	Tag = "Player",
	Predicate = function(instance)
		return instance.Name == "Bob"
	end,
}
```

Only matching instances will receive the component.

Components can also restrict their ancestors using:

```lua
WhitelistedAncestors
BlacklistedAncestors
```

---

# 🔄 Lifecycle Hooks

Leaf provides lifecycle hooks for different execution stages.

### Services / Controllers

```lua
function SomeService.onInit(self: Self)
end

function SomeService.onStart(self: Self)
end
```

### Runtime

```lua
function SomeService.onTick(self: Self, delta: number)
end

function SomeService.onPhysics(self: Self, delta: number)
end
```

### Client

```lua
-- Beside onTick and onPhysics
function SomeController.onRender(self: Self, delta: number)
end
```

### Components

```lua
function SomeComponent.onSpawn(self: Self)
end

function SomeComponent.onDespawn(self: Self)
end
```

The exact execution environment depends on the hook.

---

# 📊 Profiling

Leaf can collect profiling information during startup/runtime:

```lua
Leaf.run({
	profiling = true,
})
```

This can be useful when diagnosing slow initialization or lifecycle execution.

---

# 🏗️ Recommended Structure

A project using Leaf can be organized however you prefer. A typical structure might look like:

```text
src/
├── Server/
│   ├── Services/
│   │   ├── DataService.luau
│   │   ├── InventoryService.luau
│   │   └── CombatService.luau
│   │
│   └── Components/
│       ├── Enemy.luau
│       └── Item.luau
│
├── Client/
│   ├── Controllers/
│   │   ├── UIController.luau
│   │   └── InputController.luau
│   │
│   └── Components/
│       └── ...
│
└── Shared/
    └── ...
```

The structure itself is not enforced by Leaf.

**Leaf manages execution. You decide how your project is organized.**

---

# 🆚 What Leaf Does — and Doesn't Do

Leaf intentionally focuses on a small set of problems.

| Leaf provides         | Leaf does not provide          |
| --------------------- | ------------------------------ |
| Lifecycle management  | Networking                     |
| Services              | Remote abstraction             |
| Controllers           | Dependency injection container |
| Components            | String-based service lookup    |
| Component inheritance | Opinionated project structure  |
| Load ordering         | Custom module system           |
| Async startup         | Unnecessary abstractions       |
| Component cleanup     | —                              |

Leaf is not intended to replace Roblox's architecture.

It sits on top of it.

---

# 🍃 The Core Idea

Leaf can be summarized in one sentence:

> **Write normal Luau modules. Let Leaf decide when they run.**

Use `require()` for dependencies to save their types.

Use lifecycle hooks for runtime logic.

Use Promises for finite asynchronous initialization with automatic timeout.

Use Components when behavior should be attached to instances.

And let Leaf own the lifecycle.

---

## License

Leaf is available under the [MIT License](https://github.com/AlexeyLegasov63/leafframeworkrbx/blob/master/LICENSE.md).
