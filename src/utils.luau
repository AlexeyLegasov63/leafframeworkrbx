local Utils = {}

--[[
    A wrapper for xpcall
]]
function Utils.try(callback, message, ...)
    return xpcall(callback, function(errorReport: string)
        warn(`[Leaf] An error occurred!\n\tMessage: {message}\n\Report: {errorReport} \n\tTraceback: {debug.traceback()}`)
    end, ...)
end

--[[
    Creates a new weak map
]]
function Utils.newWeakMap()
    return setmetatable({}, {
        __mode = "k",
    })
end

return Utils
