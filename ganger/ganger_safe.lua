local log = require("ganger/ganger_logger.lua")
------------------------------------------------------------------------------------
-- Ganger customer error handler for xpcall
------------------------------------------------------------------------------------
local function traceback (err)
    local trace = debug.traceback(err, 2)
    log("Error trapped: %s", trace)
    return err
end
------------------------------------------------------------------------------------
-- GANGER SAFE
------------------------------------------------------------------------------------
function GANGSAFE (func)
    return xpcall(func, traceback)
end
------------------------------------------------------------------------------------