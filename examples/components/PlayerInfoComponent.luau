-- A component that displays the name of the player

local PlayerInfoComponent = {
	-- Name = "PlayerInfo" (If you don't want to use the component's module script name as the name)

	Instance = "Model", -- Ensure the instance is a model
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
