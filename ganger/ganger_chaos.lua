local gtools = require("ganger/ganger_tools.lua")
local log = require("ganger/ganger_logger.lua")
require("ganger/ganger_safe.lua")
require("lua/utils/table_utils.lua")
-------------------------------------------------------------------------
local ganger_chaos = {
    ["total"]         = 0,
    ["events"]        = {
    --    v1: v2:                v3(quant)
        { 3, "scatter",         500},
        { 3,  "assassins",       7},
        { 1,  "wingmites",       32},
        { 1,  "aggro",           0},
        { 99,  "boss",            1},
    }
}
--------------------------------------------------------------------------
function ganger_chaos:LogChaos()
    local lines = {}
    for _,v in pairs(ganger_chaos.events) do
        table.insert(lines,string.format("    %d: %20s: %d", v[1], v[2], v[3]))
    end
    log("chaos_table:\n    total: %d\n%s",ganger_chaos.total, table.concat(lines,"\n"))
end
-------------------------------------------------------------------------
-- Init: sets cumulative weighting on table for pick list
-------------------------------------------------------------------------
function ganger_chaos:Init(  )
    --log("ganger_chaos:Init()")
    for _,v in ipairs (ganger_chaos.events) do
        ganger_chaos.total = ganger_chaos.total + v[1]
    end
    -- sorting is a performance optimization for later random draws
    table.sort(ganger_chaos.events, function(a, b) return a[1] > b[1] end)
end
-------------------------------------------------------------------------
-- Maybe Cause Chaos: decides to cause chaos or not
-------------------------------------------------------------------------
function ganger_chaos:MaybeCauseChaos( probability )
    --log("MaybeCauseChaos()")
    probability = probability or 0.5

    if self.total == 0 then self:Init() end -- ensure probability table

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
        log("CHAOS: %s, %.1f, mult=%.1f, total %d", eventName, eventQuant, mult, totalQuant)
        self:ExecuteEvent( eventName, eventQuant )
        return { eventName, eventQuant }
    end
    return nil
end
-------------------------------------------------------------------------
-- Pick Event: picks a single event from table
-------------------------------------------------------------------------
function ganger_chaos:PickEvent()
    if self.total == 0 then return nil end
    
    local rand = RandFloat(0, self.total)
    
    for _, event in ipairs(self.events) do
        rand = rand - event[1]
        if rand < 0 then
            return { event[2], event[3] }
        end
    end

    local fallback = self.events[1]

    return { fallback[2], fallback[3] }
end
-------------------------------------------------------------------------
-- Dispatch event to method
-------------------------------------------------------------------------
function ganger_chaos:ExecuteEvent( eventName, eventQuant )

    local method = "Execute" .. eventName:sub(1,1):upper() .. eventName:sub(2):lower()
    if self[method] then
        log("chaos:%s()", method)
        self[method](self, eventName, eventQuant)
    else
    log("#### chaos event '%s' unimplemented", eventName )
    end

end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteAssassins( eventName, eventQuant )

    local blueprint = "units/ground/kermon_alpha"
    local groupName = "Ganger:" .. eventName
    local spawnDistance = RandInt(11, 17)
    local ignoreWater = true 

    local player = gtools:GetPlayer()
    local spawnPoints = UnitService:CreateDynamicSpawnPoints( player, spawnDistance, eventQuant, ignoreWater )

    for _,spawnPoint in ipairs( spawnPoints ) do
        EntityService:CreateOrSetLifetime( spawnPoint, 30, "normal" )
        local enemy = gtools:SpawnEnemy( blueprint, spawnPoint, groupName, UNIT_AGGRESSIVE )
        gtools:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
        log("spawned %d", enemy)
    end

end
-------------------------------------------------------------------------
function ganger_chaos:SpawnAtNearbySpawnPoints( blueprint, groupName, nSpawnPoints, eventQuant )

    local admissibleSpawnPoints = gtools:FindAdmissibleInteriorSpawnPoints()
    if not admissibleSpawnPoints then return end
    local spawnPointsToUse = gtools:DrawDistinctRandomsFromTable(admissibleSpawnPoints, nSpawnPoints)

    for _,spawnPoint in ipairs( spawnPointsToUse) do
        for i = 1, eventQuant do
            local enemy = gtools:SpawnEnemy( blueprint, spawnPoint, groupName, UNIT_AGGRESSIVE )
            if enemy then
                gtools:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
            else
                log("#### invalid blueprint %s", blueprint )
            end
        end
    end
end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteScatter( eventName, eventQuant )

    local blueprint = "units/ground/mushbit_ultra"
    local groupName = "Ganger:" .. eventName

    self:SpawnAtNearbySpawnPoints( blueprint, groupName, 1, eventQuant )
    -- local foundEntities = FindService:FindEntitiesByNameInRadius( gtools:GetPlayer(), groupName, 2000 )
    -- log("scatter spawned %d", #foundEntities)

end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteWingmites( eventName, eventQuant )

    local blueprint = "units/ground/wingmite_alpha"
    local groupName = "Ganger:" .. eventName

    self:SpawnAtNearbySpawnPoints( blueprint, groupName, 3, eventQuant )
    -- local foundEntities = FindService:FindEntitiesByNameInRadius( gtools:GetPlayer(), groupName, 2000 )
    -- log("scatter spawned %d", #foundEntities)

end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteBoss( eventName, eventQuant )

    local blueprint = "units/ground/stregaros_boss_random"
    local groupName = "Ganger:" .. eventName

    local spawnDistance = RandInt(11, 17)
    local ignoreWater = true 
    local player = gtools:GetPlayer()
    local spawnPoints = UnitService:CreateDynamicSpawnPoints( player, spawnDistance, eventQuant, ignoreWater )

    for _,spawnPoint in ipairs( spawnPoints ) do
        EntityService:CreateOrSetLifetime( spawnPoint, 30, "normal" )
        local enemy = gtools:SpawnEnemy( blueprint, spawnPoint, groupName, UNIT_DEFENDER )
        gtools:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
        log("spawned %d", enemy)
    end

end
-------------------------------------------------------------------------
function ganger_chaos:ExecuteAggro( eventQuant )

    local playerEnt = gtools:GetPlayer()
    EntityService:ChangeAIGroupsToAggressive(playerEnt, 2000, true)

end
-------------------------------------------------------------------------
return ganger_chaos