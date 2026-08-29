--[[
    Abstract tool component
    Use for items in your game
]]

local Players = game:GetService("Players")

local Leaf = require("@pkg/Leaf")

export type ToolComponent<I = Tool> = Leaf.BaseComponent<I, nil> & {
	Handle: BasePart?,

	onUnhold: <T>(t: T) -> T,

	onActivate: (who: Player) -> (),
	onEquip: (who: Player) -> (),
	onUnequip: (who: Player) -> (),
}

local ToolComponent = {
	Instance = "Tool", -- Ensure the instance is a tool
}

-- Returns the player holding the tool
local function getHolder(inst): Player
	local character = inst.Parent
	return Players:GetPlayerFromCharacter(character)
end

function ToolComponent:onSpawn()
	local cleaner = self.Cleaner
	local tool = self.Instance :: Tool

	-- Check if the tool has a handle
	if tool.RequiresHandle then
		self.Handle = tool:WaitForChild("Handle", 15)

		if not self.Handle then
			error(`Tool {tool:GetFullName()} has no handle`)
		end
	end

	local lastHolder = nil

	-- Create an additional cleaner for holding. Will be cleaned up when the tool is unequipped
	self._holdCleaner = cleaner:extend()

	cleaner:add(tool.Equipped:Connect(function()
		lastHolder = getHolder(tool)
		self:onEquip(lastHolder)
	end))

	cleaner:add(tool.Activated:Connect(function()
		self:onActivate(lastHolder)
	end))

	cleaner:add(tool.Unequipped:Connect(function()
		local ok, err = pcall(self.onUnequip, self, lastHolder)

		if not ok then
			warn("Error while unequipping tool", err)
		end

		self._holdCleaner:cleanup()

		lastHolder = nil
	end))
end

-- Abstract
function ToolComponent:onEquip(who: Player) end

-- Abstract
function ToolComponent:onActivate(who: Player) end

-- Abstract
function ToolComponent:onUnequip(who: Player) end

-- Add a task to the hold cleaner. Just like :onDestroy but for holding
function ToolComponent:onUnhold(t)
	self._holdCleaner:add(t)
	return t
end

return ToolComponent
