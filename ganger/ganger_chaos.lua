local gtools = require("ganger/ganger_tools.lua")
local gwave = require("ganger/ganger_wave.lua")
local log = require("ganger/ganger_logger.lua")
require("ganger/ganger_safe.lua")
-------------------------------------------------------------------------
class 'ganger_chaos' ( LuaGraphNode )
function ganger_chaos:__init()
    LuaGraphNode.__init(self, self)
end
GANGER_CHAOS = nil -- inited in Init/OnLoad
------------------------------------------------------------------------------------
-- Init; runs only once
------------------------------------------------------------------------------------
function ganger_chaos:init()
GANGSAFE(function()

    log("--------------------------------------------------------------------------------")
    log("ganger_chaos:INIT() self: %s", tostring(self))
    log("--------------------------------------------------------------------------------")

    self.eventTable = {
    ["total"]         = 0,
    ["events"]        = {
    --    weight:  name:          quant:
        -- { 0.75,  "dwellers",        50},  -- spawns a small wave of random utras
        -- { 1.00,  "wingmites",       30},  -- spawn annoying wingmites
        -- { 0.75,  "miniwave",        50},  -- spawns a small wave of random alphas
        { 0.50,  "assassins",        7},  -- spawns an ambush
        -- { 0.15,  "bossspawn",       50},  -- spawns wave on existing bosses
        -- { 0.05,  "boss",             1},  -- spawns a boss
        -- { 0.025, "aggro",            0},
        }
    }

    GANGER_CHAOS = self

    self.aggrom       = self:CreateStateMachine() -- warnmachine
    self.aggrom:AddState("aggro",   { enter=  "AggroStart",      exit="AggroEnd" 	}) 

    self.assm         = self:CreateStateMachine() -- warnmachine
    self.assm:AddState("assassins", { enter=  "AssassinsStart",  exit="AssassinsEnd" 	})
    self.assm.foo = 3

    -- local smID = string.match(tostring(self.warnm), "^[^:]*:[^:]*:[^:]*:(.*)$")    
    -- log("state machine ID: %s", smID)


end)
end
------------------------------------------------------------------------------------
-- Load; runs once when loading game
------------------------------------------------------------------------------------
function ganger_chaos:OnLoad()
GANGSAFE(function()

    log("--------------------------------------------------------------------------------")
    log("ganger_chaos:ON_LOAD()")
    log("--------------------------------------------------------------------------------")

    GANGER_CHAOS = self

end)
end
--------------------------------------------------------------------------
function ganger_chaos:LogChaos()
    local lines = {}
    for _,v in pairs(self.eventTable.events) do
        table.insert(lines,string.format("    %d: %20s: %d", v[1], v[2], v[3]))
    end
    log("chaos_table:\n    total: %d\n%s",self.eventTable.total, table.concat(lines,"\n"))
end
-------------------------------------------------------------------------
-- Init: sets cumulative weighting on table for pick list
-------------------------------------------------------------------------
function ganger_chaos:Init(  )
    --log("ganger_chaos:Init()")
    for _,v in ipairs (self.eventTable.events) do
        self.eventTable.total = self.eventTable.total + v[1]
    end
    -- sorting is a performance optimization for later random draws
    table.sort(self.eventTable.events, function(a, b) return a[1] > b[1] end)
end
-------------------------------------------------------------------------
-- Maybe Cause Chaos: decides to cause chaos or not
-------------------------------------------------------------------------
function ganger_chaos:MaybeCauseChaos( probability )
    --log("MaybeCauseChaos()")
    probability = probability or 0.5

    if self.eventTable.total == 0 then self:Init() end -- ensure probability table

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

    if not event then return nil end

    local level = math.max(GANGER_INSTANCE.level, 1)
    local mult = math.sqrt(level)
    local eventName = event[1]

    if GANGER_INSTANCE.level < 6 and 
        (string.find(eventName, "boss") or string.find(eventName, "aggro")) then
        log("Too early for boss or aggro")
        return nil
    end

    local eventQuant = event[2]
    local totalQuant = math.floor( eventQuant * mult + .5 )
    log("CHAOS: %s, %.1f, mult=%.1f, total %d", eventName, eventQuant, mult, totalQuant)
    self:ExecuteEvent( eventName, totalQuant )
    return { eventName, eventQuant }

end
-------------------------------------------------------------------------
-- Pick Event: picks a single event from table
-------------------------------------------------------------------------
function ganger_chaos:PickEvent()

    local eventTable = self.eventTable

    if eventTable.total == 0 then return nil end
    
    local rand = RandFloat(0, eventTable.total)
    
    for _, event in ipairs(eventTable.events) do
        rand = rand - event[1]
        if rand < 0 then
            return { event[2], event[3] }
        end
    end

    local fallback = eventTable.events[1]

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

    self.assm:ChangeState("assassins")
    self.eventName = eventName
    self.eventQuant = eventQuant

end
-------------------------------------------------------------------------
function ganger_chaos:ChaosDwellers( eventName, eventQuant )

    local blueprint = gwave:GetRandomBlueprintByPattern( "_alpha" )
    local groupName = "Ganger:" .. eventName
    log("ChaosDwellers: %s", tostring(UNIT_DEFENDER))
--[[
    local previousGangers = FindService:FindEntitiesByName( groupName )
    log("ChaosDwellers found previousGangers = %d,", #previousGangers)
    if #previousGangers > 1000 then
        log("too many %s; sleeping", groupName)
        return
    end
]]--

    local spawnPoints = gtools:SpawnAtDynamicSpawnPoints( blueprint, groupName, 1, eventQuant, UNIT_DEFENDER )
    gtools:PlaySoundOnPlayer( "ganger/effects/short_rumble" )
    for _,spawnPoint in ipairs(spawnPoints) do
--effects/messages_and_markers/warning_marker_red
--effects/messages_and_markers/wave_marker_nest
        local indicator = EntityService:SpawnEntity( "effects/messages_and_markers/wave_marker_nest", spawnPoint, "no_team" )
	    local indicatorDuration = 10
	    EntityService:CreateLifeTime( indicator, indicatorDuration, "normal" )
    end
end
-------------------------------------------------------------------------
function ganger_chaos:ChaosMiniwave( eventName, eventQuant )

    local blueprint = gwave:GetRandomBlueprintByPattern( "_ultra" )
    local groupName = "Ganger:" .. eventName

    local spawnPoints = gtools:SpawnAtNearbySpawnPoints( blueprint, groupName, 1, eventQuant, UNIT_AGGRESSIVE )
    gtools:PlaySoundOnPlayer( "ganger/effects/minoralert" )

    for _,spawnPoint in ipairs(spawnPoints) do
--effects/messages_and_markers/warning_marker_red
--effects/messages_and_markers/wave_marker_nest
        local indicator = EntityService:SpawnEntity( "effects/messages_and_markers/wave_marker_nest", spawnPoint, "no_team" )
	    local indicatorDuration = 5
	    EntityService:CreateLifeTime( indicator, indicatorDuration, "normal" )
    end
end
-------------------------------------------------------------------------
local wingmites_waveset = {
    ["total"] = 0,
    ["blueprints"] = {
        -- v1:   v2:
        { 1.00,  "units/ground/wingmite", },
        { 0.10,  "units/ground/wingmite_alpha", },
        { 0.05,  "units/ground/wingmite_ultra", },
        { 0.01,  "units/ground/wingmite_boss", },
    }
}
function ganger_chaos:ChaosWingmites( eventName, eventQuant )

    local groupName = "Ganger:" .. eventName

    gwave:GrowWaveSetToLevel( wingmites_waveset, GANGER_INSTANCE.level )

    local wave = gwave:CreateWave( wingmites_waveset, eventQuant )

    log("GANGER_INSTANCE.admissibleInteriorSpawnPoints = %d", #GANGER_INSTANCE.admissibleInteriorSpawnPoints)
    local spawnPoints = gtools:SpawnWaveAtNearbySpawnPoints( wave, groupName, 1 )
    log("spawning wingmites at %d spawnpoints:", #spawnPoints)
    for blueprint, count in pairs( wave ) do
        log("%s: %d", blueprint, count)
    end

    for _,spawnPoint in ipairs( spawnPoints ) do
        local indicator = EntityService:SpawnEntity( "effects/messages_and_markers/ganger_wingmites", spawnPoint, "no_team" )
        local indicatorDuration = 5
        EntityService:CreateLifeTime( indicator, indicatorDuration, "normal" )        
    end

    gtools:PlaySoundOnPlayer( "ganger/effects/wingmites" )

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
    gtools:PlaySoundOnPlayer( "ganger/effects/minoralert" )
    log("**** BOSS spawning: %s", blueprint)
    gtools:SpawnAtDynamicSpawnPoints( blueprint, groupName, 1, eventQuant, UNIT_DEFENDER )

end
-------------------------------------------------------------------------
function ganger_chaos:ChaosBossspawn( eventName, eventQuant )

    local groupName = "Ganger:" .. eventName
    local bosses = FindService:FindEntitiesByName( "Ganger:boss" )

    if bosses and #bosses > 0 then
        log("ChaosBossspawn found #bosses = %d,", #bosses)
        gtools:PlaySoundOnPlayer( "ganger/effects/minoralert" )
        for _,boss in ipairs( bosses ) do

            local blueprint = EntityService:GetBlueprintName( boss )
            local basebp = string.match( blueprint, "units/ground/(.+)_boss" )
            local ultrabp = "units/ground/" .. basebp .. "_ultra"

            if ultrabp and #ultrabp > 0 then
                log("spawning wave for boss: %s:%s", blueprint, ultrabp )

                local indicator = EntityService:SpawnEntity( "effects/messages_and_markers/wave_marker", boss, "no_team" )
                local indicatorDuration = 30
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

    self.aggrom:ChangeState("aggro")

end
------------------------------------------------------------------------
function ganger_chaos:AssassinsStart(state)
GANGSAFE(function()

    GANGER_INSTANCE:DisplayTimer( 3, "Stalkers detected")
    state:SetDurationLimit( 3 )

end)
end
------------------------------------------------------------------------
function ganger_chaos:AssassinsEnd(state)
GANGSAFE(function()

    local blueprint = "units/ground/kermon_ultra"
    local groupName = "Ganger:" .. self.eventName
    local spawnPoints = gtools:SpawnAroundPlayer( blueprint, groupName, self.eventQuant )
    gtools:PlaySoundOnPlayer( "ganger/effects/ambient_horror" )

end)
end
------------------------------------------------------------------------
function ganger_chaos:AggroStart(state)
GANGSAFE(function()

    --gtools:PlaySoundOnPlayer("ganger/effects/redalert") 
    GANGER_INSTANCE:DisplayTimer(10, "Map-wide horde incoming")
    state:SetDurationLimit( 10 )

end)
end
------------------------------------------------------------------------
function ganger_chaos:AggroEnd(state)
GANGSAFE(function()

    local enemies = gtools:FindAllMapEnemies()
    local waveTeam = EntityService:GetTeam( "wave_enemy" )

    if enemies and #enemies > 100 then
        gtools:PlaySoundOnPlayer( "ganger/effects/minoralert" )
    end

    -- update teams and buff existing enemies

    for _,enemy in pairs ( enemies ) do
        EntityService:SetTeam( enemy, waveTeam ) -- coordinate together all
        local enemyName = EntityService:GetName( enemy )
        if string.find(enemyName, "Ganger:") then
            if enemyName == "Ganger:dwellers" then
                log("try aggro ganger %d", enemy)
                QueueEvent( "UnitAggressiveStateEvent", enemy )
            end
        else -- all non-ganger enemies
            EntityService:SetName( enemy, "Ganger:aggro" )
            gtools:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
        end
    end

    EntityService:ChangeAIGroupsToAggressive(gtools:GetPlayer(), 2000, true)

    -- add buffed enemies in hostile state

    for _,enemy in pairs ( enemies ) do
        local blueprint = EntityService:GetBlueprintName( enemy )
        for _ = 1, math.floor(math.pow(GANGER_INSTANCE.level, .334)) do
            gtools:SpawnAtSpawnPoint( blueprint, enemy, "Ganger:aggro", 1, UNIT_AGGRESSIVE )
        end
    end

end)
end
-------------------------------------------------------------------------
return ganger_chaos