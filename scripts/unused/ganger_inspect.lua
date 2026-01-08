local log = require("scripts/ganger_logger.lua")

local function InspectObject(obj)
    
    -- Direct properties
    log("Direct properties:")
    for key, value in pairs(obj) do
        log("  " .. key .. " = " .. type(value) .. ": " .. tostring(value))
    end
    
    -- Metatable
    local mt = getmetatable(obj)
    if mt then
        log("Metatable:")
        for key, value in pairs(mt) do
            log("  " .. key .. " = " .. type(value))
        end
        
        -- Check __index (common for methods)
        if mt.__index then
            log("__index contents:")
            if type(mt.__index) == "table" then
                for key, value in pairs(mt.__index) do
                    log("    " .. key .. " = " .. type(value) .. ": " .. tostring(value))
                end
            else
                log("    __index is a " .. type(mt.__index))
            end
        end
	end
end

return InspectObject

