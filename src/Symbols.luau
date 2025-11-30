--[[
    Sleitnick's Symbol (https://github.com/Sleitnick)
]]

--[[
    Symbols used for defining safe keys
    @param name string
]]
local function Symbol(name)
	local symbol = newproxy(true)

	getmetatable(symbol).__tostring = function()
		return "Leaf@" .. name
	end

	return symbol
end

return table.freeze({
	-- Common
	Source = Symbol("Source"),
	Type = Symbol("Type"),

	Component = Symbol("Component"),
	ServiceOrController = Symbol("ServiceOrController"),

	-- Components
	Cleaner = Symbol("Cleaner"),
})
