--[[
    Cleaner (Maid by Quenty) Utility Module
    Handles the automatic cleanup of disposable resources like RBXScriptConnections,
    Instances (Destroy), and cancellable functions (e.g., coroutines/tasks).
    Helps to prevent memory leaks and ensures proper resource disposal upon component despawn.
]]

local Utils = require(script.Parent)

local throw = Utils.throw
local try = Utils.try

local CLEANER_SYMBOL = newproxy()

local CLEANER_ALLOWED_TYPES = {
	["Instance"] = true,
	["RBXScriptConnection"] = true,
	["thread"] = true,
	["table"] = true,
	["function"] = true,
}

local CLEANER_CLEAN_METHODS = {
	"Destroy",
	"Disconnect",
	"Cancel",
	"destroy",
	"disconnect",
	"cancel",
}

local Cleaner = { [CLEANER_SYMBOL] = true }
Cleaner.__index = Cleaner

--[[
    Checks if a value is 'cleanable' (has a Destroy/Disconnect method or is a thread/connection).
    @param value The value to check
    @return True if the value can be cleaned up, otherwise false
]]
function assureIsCleanable(value: any): boolean
	local primaryType = type(value)

	-- Check custom types
	if primaryType == "table" then
		if value[CLEANER_SYMBOL] then
			return true -- It's a cleaner, sub garbage
		end

		for _, method in CLEANER_CLEAN_METHODS do
			if not value[method] then
				continue
			end

			return true
		end

		return false
	end

	return CLEANER_ALLOWED_TYPES[primaryType] -- For primitive types
		or CLEANER_ALLOWED_TYPES[typeof(value)] -- For Roblox types
end

--[[
    Clears a cleanable item (RBXScriptConnection, Instance, Thread, etc.)
    @param item The item to be cleaned up
]]
function clearItem(item)
	local primaryType = type(item)

	if primaryType == "function" then
		item() -- Call the function
		return
	elseif primaryType == "thread" then
		task.cancel(item) -- Cancel the thread

		local cancelled
		if coroutine.running() ~= item then
			cancelled = pcall(function()
				task.cancel(item)
			end)
		end

		if not cancelled then
			local toCancel = item
			task.defer(function()
				task.cancel(toCancel)
			end)
		end

		return
	elseif primaryType == "table" then
		if item[CLEANER_SYMBOL] then
			item:cleanup()
			return -- It's a cleaner, sub garbage
		end

		for _, method in CLEANER_CLEAN_METHODS do
			if not item[method] then
				return
			end

			item[method](item) -- Call the method

			return
		end
	end

	local secondaryType = typeof(item)

	if secondaryType == "RBXScriptConnection" then
		item:Disconnect()
	elseif secondaryType == "Instance" then
		item:Destroy()
	end
end

--[[
    Creates a new Cleaner instance
    @return A new Cleaner (Maid) object
]]
function Cleaner.new()
	return setmetatable({
		_garbage = {}, -- Array of cleanable resources
	}, Cleaner)
end

--[[
    Adds a cleanable item to the garbage list.
    @param item The item to be cleaned up later (Connection, Instance, Thread, etc.)
]]
function Cleaner:add(item: any)
	if not assureIsCleanable(item) then
		throw(`Cleaner: Item '{typeof(item)}' is not cleanable!`)
	end

	table.insert(self._garbage, item)
end

--[[
    Creates a new Cleaner instance and adds it to the garbage list.
    @return A new Cleaner (Maid) object that is added to the garbage list
]]
function Cleaner:extend()
	local subCleaner = Cleaner.new()
	table.insert(self._garbage, subCleaner) -- Add the subCleaner to the garbage list
	return subCleaner
end

--[[
    Runs the cleanup process on all registered items.
    Calls Disconnect, Destroy, or Cancel as appropriate.
]]
function Cleaner:cleanup()
	local garbage = self._garbage

	-- Clear the garbage list
	local index, item = next(garbage)
	while item ~= nil do
		garbage[index] = nil

		try(clearItem, "Unable to clean up item", item)

		index, item = next(garbage)
	end
end

return Cleaner
