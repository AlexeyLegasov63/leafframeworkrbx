local Utils = require(script.Parent)

local throw = Utils.throw
local try = Utils.try

local CLEANER_SYMBOL = newproxy()

--[[
    Cleaner (Maid) Utility Module
    Handles the automatic cleanup of disposable resources like RBXScriptConnections,
    Instances (Destroy), and cancellable functions (e.g., coroutines/tasks).
    Helps to prevent memory leaks and ensures proper resource disposal upon component despawn.
]]

local Cleaner = { [CLEANER_SYMBOL] = true }
Cleaner.__index = Cleaner

--[[
    Checks if a value is 'cleanable' (has a Destroy/Disconnect method or is a thread/connection).
    @param value The value to check
    @return True if the value can be cleaned up, otherwise false
]]
function assureIsCleanable(value: any): boolean
	if
		typeof(value) == "RBXScriptConnection"
		or (type(value) == "table" and value.ClassName == "LemonSignalConnection")
	then
		-- RBXScriptConnection, or custom SignalConnection (like LemonSignalConnection)
		return true
	elseif type(value) == "thread" then
		-- Cancellable threads (tasks)
		return true
	elseif type(value) == "table" then
		-- Table/Object with a Destroy/Disconnect/Cancel method
		return value.Destroy or value.Disconnect or value.Cancel or value[CLEANER_SYMBOL]
	end

	return false
end

--[[
    Clears a cleanable item (RBXScriptConnection, Instance, Thread, etc.)
    @param item The item to be cleaned up
]]
function clearItem(item)
	if typeof(item) == "RBXScriptConnection" or (type(item) == "table" and item.Disconnect) then
		item:Disconnect() -- For signals (for Connections)
	elseif type(item) == "table" then
		if item[CLEANER_SYMBOL] then
			item:cleanup() -- For Cleaner (for Maid-like objects)
			return
		end
		local method = item.Destroy or item.Cancel

		method(item) -- Custom Destroy/Cancel for
	elseif type(item) == "function" then
		item() -- For custom cancellable objects or tasks)
	elseif type(item) == "thread" then
		task.cancel(item) -- For Threads (task.cancel is usually used)
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
	for _, item in self._garbage do
		try(clearItem, "Unable to clean up item", item)
	end

	-- Clear the garbage list
	self._garbage = {}
end

return Cleaner
