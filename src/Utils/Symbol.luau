--[[
    Sleitnick's Symbol (https://github.com/Sleitnick)
]]

--[[
    Symbols used for defining safe keys
    @param name string
]]
local function symbol(name)
	local symbol = newproxy(true)

	getmetatable(symbol).__tostring = function()
		return "Leaf@" .. name
	end

	return symbol
end

return symbol
