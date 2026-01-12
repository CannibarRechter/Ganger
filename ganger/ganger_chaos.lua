local gtools = require("ganger/ganger_tools.lua")
local gwave = require("ganger/ganger_wave.lua")
local log = require("ganger/ganger_logger.lua")
require("ganger/ganger_safe.lua")
-------------------------------------------------------------------------
local ganger_chaos = {
    ["total"]         = 0,
    ["events"]        = {
    --    v1:  v2:                v3(quant)
--        {  09,  "miniwave",        50},  -- spawns a small wave of random alphas
--        {  07,  "assassins",       7},   -- spawns an ambush
--        {  05,  "wingmites",       32},  -- spawn annoying wingmites
        {  03, "boss",             1},  -- spawns a boss
        {  01, "bossspawn",       50},  -- spawns wave on existing bosses
--      {  01,  "aggro",            0},
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

    if math.random(0, 1) < probability then
        return self:CauseChaos()
    else
        return nil
    end
end
-------------------------------------------------------------------------
-- Cause Chaos: picks events at random to select
-------------------------------------------------------------------------
function ganger_chaos:CauseChaos()
    --log("CauseChaos()")
    --self:LogChaos()
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

    local method = "Chaos" .. eventName:sub(1,1):upper() .. eventName:sub(2):lower()
    if self[method] then
        --log("%s()", method)
        self[method](self, eventName, eventQuant)
    else
    log("#### chaos event '%s' unimplemented", eventName )
    end

end
-------------------------------------------------------------------------
function ganger_chaos:ChaosAssassins( eventName, eventQuant )

    local blueprint = "units/ground/kermon_alpha"
    local groupName = "Ganger:" .. eventName

    gtools:SpawnAroundPlayer( blueprint, groupName, eventQuant )
    gtools:PlaySoundOnPlayer( "ganger/effects/ambient_horror" )

end
-------------------------------------------------------------------------
function ganger_chaos:ChaosMiniwave( eventName, eventQuant )

    local blueprint = gwave:GetRandomBlueprintByPattern( "_alpha" )
    local groupName = "Ganger:" .. eventName

--[[
    local previousGangers = FindService:FindEntitiesByName( groupName )
    log("ChaosMiniwave found previousGangers = %d,", #previousGangers)
    if #previousGangers > 1000 then
        log("too many %s; sleeping", groupName)
        return
    end
]]--

    --local spawnPoints = gtools:SpawnAtDynamicSpawnPoints( blueprint, groupName, 1, eventQuant, UNIT_AGGRESSIVE )
    local spawnPoints = gtools:SpawnAtNearbySpawnPoints( blueprint, groupName, 1, eventQuant, UNIT_DEFENDER )

    for _,spawnPoint in ipairs(spawnPoints) do
--effects/messages_and_markers/warning_marker_red
--effects/messages_and_markers/wave_marker_nest
        local indicator = EntityService:SpawnEntity( "effects/messages_and_markers/wave_marker_nest", spawnPoint, "no_team" )
	    local indicatorDuration = 10
	    EntityService:CreateLifeTime( indicator, indicatorDuration, "normal" )
    end
end
-------------------------------------------------------------------------
local wingmites_waveset = {
    ["total"] = 0,
    ["blueprints"] = { -- TODO
        -- v1:   v2:
        { 2.00,  "units/ground/wingmite", },
        { 0.20,  "units/ground/wingmite_alpha", },
        { 0.10,  "units/ground/wingmite_ultra", },
        { 0.02,  "units/ground/wingmite_boss", },
    }
}
function ganger_chaos:ChaosWingmites( eventName, eventQuant )

    local groupName = "Ganger:" .. eventName

    gwave:GrowWaveSetToLevel( wingmites_waveset, GANGER_INSTANCE.level )

    local wave = gwave:CreateWave( wingmites_waveset, eventQuant )

    gtools:SpawnAtWaveAtNearbySpawnPoints( wave, groupName, 1 )

    gtools:PlaySoundOnPlayer( "ganger/effects/ambient_horror" )

end
-------------------------------------------------------------------------
function ganger_chaos:ChaosBoss( eventName, eventQuant )

    local blueprint = gwave:GetRandomBlueprintByPattern( "_boss" )
    local groupName = "Ganger:" .. eventName

    local previousGangers = FindService:FindEntitiesByName( groupName )
    if #previousGangers >= 20 then
        log("too many %s; sleeping", groupName)
        return
    end
    gtools:PlaySoundOnPlayer( "ganger/effects/minialert" )
    log("**** BOSS spawning: %s", blueprint)
    gtools:SpawnAtDynamicSpawnPoints( blueprint, groupName, 1, eventQuant, UNIT_WANDER )

end
-------------------------------------------------------------------------
function ganger_chaos:ChaosBossspawn( eventName, eventQuant )

    local groupName = "Ganger:" .. eventName
    local bosses = FindService:FindEntitiesByName( "Ganger:boss" )

    if bosses and #bosses > 0 then
        log("ChaosBossspawn found #bosses = %d,", #bosses)
        gtools:PlaySoundOnPlayer( "ganger/effects/minialert" )
        for _,boss in ipairs( bosses ) do

            local blueprint = EntityService:GetBlueprintName( boss )
            local basebp = string.match( blueprint, "units/ground/(.+)_boss" )
            local ultrabp = "units/ground/" .. basebp .. "_ultra"

            if ultrabp and #ultrabp > 0 then
                log("spawning wave for boss: %s:%s", blueprint, ultrabp )

                local indicator = EntityService:SpawnEntity( "effects/messages_and_markers/wave_marker_nest", boss, "no_team" )
                local indicatorDuration = 10
                EntityService:CreateLifeTime( indicator, indicatorDuration, "normal" )

                gtools:SpawnAtSpawnPoint( ultrabp, boss, groupName, eventQuant, UNIT_AGGRESSIVE )
            else
                log("no ultras for %s", blueprint)
            end
        end
    else
        log("no bosses to spawn waves on")
    end

end
-------------------------------------------------------------------------
function ganger_chaos:ChaosAggro( eventQuant )

    local enemies = gtools:FindAllMapEnemies()
    local waveTeam = EntityService:GetTeam( "wave_enemy" )

    if enemies and #enemies > 100 then
        gtools:PlaySoundOnPlayer( "ganger/effects/minialert" )
    end

    log("Aggro found #enemies = %d", #enemies)
    for _,enemy in pairs ( enemies ) do
        EntityService:SetTeam( enemy, waveTeam ) -- coordinate together all
    end

    log("***AGGRO***")
    EntityService:ChangeAIGroupsToAggressive(gtools:GetPlayer(), 2000, true)

end
-------------------------------------------------------------------------
--[[
function ganger_chaos:ChaosAggroSAVE( eventQuant )

    local player = gtools:GetPlayer()
    local spawners = gtools:FindAllMapSpawners()
    local waveTeam = EntityService:GetTeam( "wave_enemy" )

    log("SPAWNERS:")
    for _,spawner in pairs( spawners ) do

        local spawnerName = EntityService:GetName( spawner )
        local children = EntityService:GetChildren( spawner, true )
        if children and #children > 0 then
            log("spawner = %d:%s", spawner, spawnerName)
            for _,child in pairs( children ) do
                local childName = EntityService:GetName( child )
                log("    child = %d:%s", child, childName)
                -- if it's not a ganger, tag it ganger touched so we don't keep
                -- hitting/buffing it
                -- EntityService:SetTeam( enemy, waveTeam ) -- coordinate together all
                -- QueueEvent( "UnitAggressiveStateEvent", enemy )
                -- UnitService:SetInitialState( enemy, UNIT_AGGRESSIVE );
                -- UnitService:SetUnitState( enemy, UNIT_AGGRESSIVE );
                -- UnitService:SetCurrentTarget( enemy, "action", player )
                -- EntityService:SetName( enemy, "Ganger:touched" )       
                --buff unit TODO
            end
        end
    end
end
]]--

--[[
function ganger_chaos:ChaosAggroSAVE( eventQuant )

    local player = gtools:GetPlayer()
    local enemies = gtools:FindAllMapEnemies()

    local countGangers = 0
    local waveTeam = EntityService:GetTeam( "wave_enemy" )

    for _,enemy in pairs ( enemies ) do
        EntityService:SetTeam( enemy, waveTeam ) -- coordinate together all

        local enemyName = EntityService:GetName( enemy )
        if string.find( enemyName, "Ganger") then
            countGangers = countGangers + 1
            -- if its a ganger, handle ganger lurk specials;
            -- all other gangers are on separate logic

            if enemyName == "Ganger:miniwave" then
                EntityService:SetTeam( enemy, waveTeam ) -- coordinate together all
			    --QueueEvent( "UnitAggressiveStateEvent", enemy )
                UnitService:SetInitialState( enemy, UNIT_AGGRESSIVE );
                UnitService:SetUnitState( enemy, UNIT_AGGRESSIVE );
                --UnitService:SetCurrentTarget( enemy, "action", player )
                --UnitService:DefendSpot( enemy, 990, 1000 )
                --EntityService:SetName( enemy, "Ganger:miniwave:aggro" ) 
            end
        else

            -- if it's not a ganger, tag it ganger touched so we don't keep
            -- hitting/buffing it
            -- EntityService:SetTeam( enemy, waveTeam ) -- coordinate together all
			-- QueueEvent( "UnitAggressiveStateEvent", enemy )
            -- UnitService:SetInitialState( enemy, UNIT_AGGRESSIVE );
            -- UnitService:SetUnitState( enemy, UNIT_AGGRESSIVE );
            -- UnitService:SetCurrentTarget( enemy, "action", player )
            -- EntityService:SetName( enemy, "Ganger:touched" )       
            --buff unit TODO
        end

    end

    self.chaoscount = (self.chaoscount or 0) + 1

    if self.chaoscount == 5 then
        self.chaoscount=0
        log("***AGGRESSIVE***")
        EntityService:ChangeAIGroupsToAggressive(player, 2000, true)
    end

    log("Aggro found %d enemies; %d gangers", #enemies, countGangers)
    --    if enemy then EntityService:SetName( enemy, groupName ) end
    -- GetName( unsigned int): string

    --local entities = FindService:FindEntitiesByName("enemy")
end
]]--
-------------------------------------------------------------------------
return ganger_chaos