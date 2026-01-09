local gtools = require("ganger/ganger_tools.lua")
local log = require("ganger/ganger_logger.lua")
require("ganger/ganger_safe.lua")
require("lua/utils/table_utils.lua")
-------------------------------------------------------------------------
local ganger_chaos = {
    ["total"]         = 0,
    ["events"]        = {
    --    v1: v2: v3:                v4(quant)
        { 3,  0,  "kermons-scatter", 32},
        { 99,  0, "kermons-player",   3},
        { 1,  0,  "wingmites",       32},
        { 1,  0,  "aggro",            0},
    }
}
-------------------------------------------------------------------------
function ganger_chaos:LogChaos()
    local lines = {}
    for _,v in pairs(ganger_chaos.events) do
        table.insert(lines,string.format("    %2d: %3d: %20s: %d", v[1], v[2], v[3], v[4]))
    end
    log("chaos_table:\n    total: %d\n    %s",ganger_chaos.total, table.concat(lines,"\n"))
end
-------------------------------------------------------------------------
-- Init: sets cumulative weighting on table for pick list
-------------------------------------------------------------------------
function ganger_chaos:Init(  )
    log("ganger_chaos:Init()")
    self:LogChaos()
    local total = 0
    for _,v in ipairs (ganger_chaos.events) do
        total = total + v[1]
        v[2] = total
        ganger_chaos.total = total
    end
    -- sorting is a performance optimization for later random draws
    table.sort(ganger_chaos.events, function(a, b) return a[1] > b[1] end)
    self:LogChaos()
end
-------------------------------------------------------------------------
-- Maybe Cause Chaos: decides to cause chaos or not
-------------------------------------------------------------------------
function ganger_chaos:MaybeCauseChaos( probability )
    log("MaybeCauseChaos()")
    probability = probability or 0.5

    if not self.total then self:Init() end -- ensure probability table

    if RandFloat(0, 1) < probability then
        return self:CauseChaos()     
    else
        return nil
    end
end
-------------------------------------------------------------------------
-- Cause Chaos: picks events at random to select
-------------------------------------------------------------------------
function ganger_chaos:CauseChaos()
    log("CauseChaos()")
    self:LogChaos()
    local event = self:PickEvent()

    if event then
        local level = GANGER_INSTANCE.level or 1
        local mult = math.sqrt(level)
        local eventName = event[1]
        local eventQuant = event[2]
        local totalQuant = math.floor( eventQuant * mult + .5 )
        log("Chaos event: %s, %.1f, mult=%.1f, total %d", eventName, eventQuant, mult, totalQuant)
        self:ExecuteEvent( eventName, eventQuant )
        return { eventName, eventQuant }
    end
    return nil
end
-------------------------------------------------------------------------
-- Pick Event: picks a single event from table
-------------------------------------------------------------------------
function ganger_chaos:PickEvent( )
    local rand = RandFloat(0, self.total)
    for _,v in ipairs (self.events) do
        if rand <= v[2] then
            return { v[3], v[4] }
        end
    end
end
-------------------------------------------------------------------------
-- Dispatch event to method
-------------------------------------------------------------------------
function ganger_chaos:ExecuteEvent( eventName, eventQuant )

    -- don't run aggro until level 5
    -- if eventName == "aggro" and GANGER_INSTANCE.level and GANGER_INSTANCE.level < 5 then
    --     eventName = "wingmites"
    -- end

    if eventName     == "kermons-scatter" then self:ExecuteKermonsScatter( eventQuant )
    elseif eventName == "kermons-player"  then self:ExecuteKermonsPlayer( eventQuant )
    elseif eventName == "wingmites"       then self:ExecuteWingmites( eventQuant )
    elseif eventName == "aggro"           then self:ExecuteAggro( eventQuant )
    end

end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteKermonsScatter( eventQuant )

	log("ExecuteKermonsScatter()")

end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteKermonsPlayer( eventQuant )

    local spawnDistance = RandInt(5, 11)
    local ignoreWater = true 

	log("ExecuteKermonsPlayer()")
    local player = gtools:GetPlayer()
    local spawnPoints = UnitService:CreateDynamicSpawnPoints( player, spawnDistance, eventQuant, ignoreWater )

    for _,spawnPoint in ipairs( spawnPoints ) do
        EntityService:CreateOrSetLifetime( spawnPoint, 30, "normal" )
        local enemy = EntityService:SpawnEntity( "units/ground/kermon_alpha", spawnPoint, "wave_enemy")
        log("spawned %d", enemy)
        UnitService:SetInitialState( enemy, UNIT_AGGRESSIVE)
        self:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
    end

end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteWingmites( eventQuant )

	log("ExecuteWingmites()")

end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteAggro( eventQuant )

	log("ExecuteAggro()")
    local playerEnt = gtools:GetPlayer()
    EntityService:ChangeAIGroupsToAggressive(playerEnt, 2000, true)

end
-------------------------------------------------------------------------
return ganger_chaos