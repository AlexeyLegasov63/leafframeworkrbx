--[[
    This is an example of a service in Leaf
    Actually this service is right from one of my games built with Leaf :d
]]

local Store = require("@server/Store")
local Charm = require("@pkg/Charm")
local PlayersUtils = require("@utils/PlayersUtils")

-- List of leaderstats
local LEADERSTATS = { "Currency" }

-------------------------------------------------------------------

local LeaderstatsService = {}

function LeaderstatsService:onStart()
	-- Create leaderstats for all players, including existing
	PlayersUtils.onJoinEvent(function(player, cleanup)
		self:_createLeaderstats(player, cleanup)
	end)
end

function LeaderstatsService:_createLeaderstats(player, cleanup)
	-- Default roblox leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	for _, id in LEADERSTATS do
		local stat = Instance.new("IntValue")
		stat.Name = id
		stat.Parent = leaderstats

		cleanup(Charm.effect(function()
			local save = Store.selectSave(player)
			if not save then
				return -- No save, the player is just joined or disconnected
			end

			stat.Value = save[id]
		end))
	end
end

return LeaderstatsService
