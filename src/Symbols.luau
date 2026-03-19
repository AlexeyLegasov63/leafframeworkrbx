--[[
    Symbols used for defining safe keys
]]
local symbol = require(script.Parent.Utils.Symbol)

return table.freeze({
	-- Common
	Source = symbol("Source"),
	Type = symbol("Type"),

	Component = symbol("Component"),
	ServiceOrController = symbol("ServiceOrController"),

	-- Components
	Cleaner = symbol("Cleaner"),
})
