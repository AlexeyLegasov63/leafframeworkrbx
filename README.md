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
Leaf = "alexeylegasov63/leafframeworkrbx@0.2.2"
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
-- examples/components/PlayerInfoComponent.lua
local PlayerInfoComponent = {
    -- Name = "PlayerInfo" (If you don't want to use the component's module script name as the name)

    Predicate = function(instance)
        return instance:IsA("Player") -- Ensure the instance is a player
    end
}

function PlayerInfoComponent:onSpawn()
    self:_disableDefaultNickname()
    self:_createInfoBoard()
end

function PlayerInfoComponent:_disableDefaultNickname()
    -- Disable the default nickname
    local humanoid = self.Instance:WaitForChild("Humanoid")
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
end

function PlayerInfoComponent:_createInfoBoard()
    -- Create a billboard
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromScale(2, 0.5)
    billboard.Parent = self.Instance:WaitForChild("HumanoidRootPart")

    -- Create a text label (the name of the player)
    local label = Instance.new("TextLabel")
    label.Parent = billboard
    label.Text = self.Instance.Name -- Player character's name
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1

    -- Add the billboard to the cleaner for automatic cleanup after component removing
    self.Cleaner:Add(billboard)
end

return PlayerInfoComponent
```

### Using a Component

```lua
local PlayerInfoController = {
    Depends = {
        Components = {} -- ? Use Components as dependency (Just like in Flamework)
    }
}

-- ? A hook to the start lifecycle event
function PlayerInfoController:onStart()
    self:_startLookingForComponents()
    self:_startLookingForPlayers()
end

function PlayerInfoController:_startLookingForComponents()
    -- ? Will invoke the callback when the component is added
    -- ? Also invokes the callback for already existing components
    local connection = self.Depends.Components.watchComponent("PlayerInfoComponent", function(component)
        print("PlayerInfoComponent added to", component.Instance.Name)
    end)
    -- ? connection:Disconnect() Can be disconnected later
end

-- ? Will invoke the callback when a player joins
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
    -- ? Use the component's "Name" field in the table of the component definition or
    -- ? the component's module script name

    local playerInfo = self.Depends.Components.addComponent(character, "PlayerInfoComponent")

    -- ? Will add the component to the virtual component holder of the instance (Character)
    -- ? If the instance removes the component, it will be removed from the virtual component holder automatically

    -- ! It's impossible to have multiple instances of the same component on the same instance
end

return PlayerInfoController
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
