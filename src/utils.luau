local Utils = {}

--[[
    A wrapper for error
]]
function Utils.throw(message)
    return error(message, 4)
end

--[[
    A wrapper for error reporting
]]
function Utils.printStackTrace(errorReport: string, message: string?)
    warn(`[Leaf] An error occurred!\n\t{ message and `Message: {message}\n\t` or "" }Traceback: {debug.traceback(errorReport, 4)}`)
end

--[[
    A wrapper for xpcall
]]
function Utils.try(callback, message, ...)
    return xpcall(callback, function(errorReport: string)
        Utils.printStackTrace(errorReport, message)
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
