local Utils = require(script.Parent)

local throw = Utils.throw
local try = Utils.try

--[[
    Cleaner (Maid) Utility Module
    Handles the automatic cleanup of disposable resources like RBXScriptConnections,
    Instances (Destroy), and cancellable functions (e.g., coroutines/tasks).
    Helps to prevent memory leaks and ensures proper resource disposal upon component despawn.
]]

local Cleaner = {}
Cleaner.__index = Cleaner

--[[
    Checks if a value is 'cleanable' (has a Destroy/Disconnect method or is a thread/connection).
    @param value The value to check
    @return True if the value can be cleaned up, otherwise false
]]
function assureIsCleanable(value: any): boolean
    if typeof(value) == "RBXScriptConnection" or (type(value) == "table" and value.ClassName == "LemonSignalConnection") then
        -- RBXScriptConnection, or custom SignalConnection (like LemonSignalConnection)
        return true
    elseif type(value) == "thread" then
        -- Cancellable threads (tasks)
        return true
    elseif type(value) == "table" then
        -- Table/Object with a Destroy/Disconnect/Cancel method
        return value.Destroy or value.Disconnect or value.Cancel
    end

    return false
end

--[[
    Clears a cleanable item (RBXScriptConnection, Instance, Thread, etc.)
    @param item The item to be cleaned up
]]
function clearItem(item)
    if typeof(item) == "RBXScriptConnection" or (type(item) == "table" and item.Disconnect) then
        item:Disconnect() -- Check for Disconnect (for Connections)
    elseif type(item) == "table" and item.Destroy then
        item:Destroy() -- Check for Destroy (for Instances or other disposable objects)
    elseif type(item) == "function" then
        item() -- Check for Cancel (for custom cancellable objects or tasks)
    elseif type(item) == "thread" then
        task.cancel(item) -- Check for Threads (task.cancel is usually used)
    end
end

--[[
    Creates a new Cleaner instance
    @return A new Cleaner (Maid) object
]]
function Cleaner.new()
    return setmetatable({
        _garbage = {} -- Array of cleanable resources
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