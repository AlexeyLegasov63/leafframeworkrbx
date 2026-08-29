--[[
    Typical component for a map.
]]

local Leaf = require("@pkg/Leaf")

type MapInstance = Model & {
	Camera: Part,
	Spawns: Folder,
}

local Map = {
	Tag = "Map",
}

function Map.onSpawn(self: Self)
	self.cameraPosition = self.Instance.Camera.Position
	self.spawns = self.Instance.Spawns:GetChildren()
end

export type Self = {
	cameraPosition: Vector3,
	spawns: { Part },
} & Leaf.BaseComponent<MapInstance, nil> & typeof(Map)

return Map
