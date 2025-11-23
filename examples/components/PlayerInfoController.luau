local Players = game:GetService("Players")

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