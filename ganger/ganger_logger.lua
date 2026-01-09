------------------------------------------------------------------------------------
-- Ganger logger
------------------------------------------------------------------------------------
local function log(formatString, ...)

	local message = string.format(formatString, ...)

	local nsl = debug.getinfo(2) -- 1 for this function, 2 for caller

    local func = nsl.name or "EXOR"

	local header = string.format("[Ganger][%s():%d] t=%.1f ", func, nsl.currentline or 0, GetLogicTime())

    -- Prefixes subsequent lines to the first with [Ganger]: faciliates tail view of log for debugging (all lines tagged)

	local prefixed = string.gsub(tostring(message), "\n", "\n[Ganger]")

	LogService:Log(header .. tostring(prefixed))
end
return log