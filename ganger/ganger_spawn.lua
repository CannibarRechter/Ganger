local gtools = require("ganger/ganger_tools.lua")
local log = require("ganger/ganger_logger.lua")
local gwave = require("ganger/ganger_wave.lua")
require("ganger/ganger_safe.lua")
require("lua/utils/table_utils.lua")
-------------------------------------------------------------------------
-- CLASS PLUMBING
-------------------------------------------------------------------------
local ganger_spawn = { }
-- class 'ganger_spawn' ( LuaGraphNode )
-- function ganger_spawn:__init()
--     LuaGraphNode.__init(self, self)
-- end
-------------------------------------------------------------------------
-- function ganger_spawn:init()
-- GANGSAFE(function()
--     self.spawnPoints = {}

--     log("ganger_spawn:INIT()")
--     -- local selfStr = gtools.PrettyPrint( self.spawnPoints )
--     -- log("self:\n%s", selfStr)
-- end)
-- end
-------------------------------------------------------------------------
-- function ganger_spawn:OnLoad()
-- GANGSAFE(function()
--     log("ganger_spawn:LOAD()")
--     -- local selfStr = gtools.PrettyPrint( self.spawnPoints )
--     -- log("self:\n%s", selfStr)
-- end)
-- end
-------------------------------------------------------------------------
-- Spawn Waves: spawns a wave at many spawn points
-------------------------------------------------------------------------
function ganger_spawn:SpawnWaves( spawnPoints, currentWaveSet, attackSize )

    log("SPAWN POINTS (%d)", #spawnPoints)

    -- pseudo unique ID; need to have something to fetch againgst
    -- each time so that we don't inadvertently buff overlapping waves

    local waveName = string.format("Ganger:%.1f",GetLogicTime())
    --dom:InsertBuffList( waveName )

    -- at every spawnpoint, spawn a wave
    for _,spawnPoint in ipairs( spawnPoints ) do
        local pos = EntityService:GetPosition( spawnPoint )
        local x, y, z = pos.x, pos.y, pos.z

        local wave = gwave:CreateWave( currentWaveSet, attackSize )
        log("SPAWNPOINT: %d: %d,%d,%d ====> SPAWNING %d blueprint sets", spawnPoint, x, y, z, Size(wave))

        gwave:LogWave( wave )
        for blueprint, count in pairs ( wave ) do
            log("spawn_at_spawnpoint %s: %d", blueprint, count)
            self:SpawnAtSpawnPoint( blueprint, spawnPoint, waveName, count )
        end
        --local foundEntities = FindService:FindEntitiesByBlueprintInRadius( spawnPoint, blueprint, 50)
        --local foundEntities = FindService:FindEntitiesByNameInRadius( spawnPoint, "Ganger", 50 )
        --local foundEntities = FindService:FindEntitiesByGroupInRadius( spawnPoint, "objective", 50 )
        --EntityService:ChangeAIGroupsToAggressive( spawnPoint, 50, true)
    end
    local allGangers = FindService:FindEntitiesByName( waveName )
    log("====> spawned %d entities in all waves='%s'", #allGangers, waveName)
    --self:BuffEnemies( allGangers, dom.hpEffective )
end
-------------------------------------------------------------------------
-- Spawn: spawns "count" enemies of the blueprint ontop of the specified
-- point
-------------------------------------------------------------------------
function ganger_spawn:SpawnAtSpawnPoint ( blueprint, spawnPoint, waveName, count )

    local entities = {}
    for i = 1, count do
        local enemy = gtools:SpawnEnemy( blueprint, spawnPoint, waveName, UNIT_AGGRESSIVE )
        if enemy then
            self:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
            table.insert( entities, enemy )
        else
            log("#### invalid blueprint %s", blueprint )
        end
    end
    --log(">>>> created %d %s at spawnpoint", #entities, blueprint)
end
-------------------------------------------------------------------------
-- Picks spawn points (note: done earlier in dom so we can display the
-- warning decals at the map edges)
-------------------------------------------------------------------------
function ganger_spawn:PickSpawnPoints( spawnPointCount )
    --self.spawnPoints = { gtools:GetPlayer() }
    local allSpawnPoints = gtools:FindAllBorderSpawnPoints()
    -- local allSpawnPoints = self:FindAllPlayerSpawnPoints()
    self.spawnPoints = gtools:DrawDistinctRandomsFromTable( allSpawnPoints, spawnPointCount )
    return self.spawnPoints
end
------------------------------------------------------------------------------------
-- Buffs enemies; keeps a buff list so we don't buff twice
------------------------------------------------------------------------------------
function ganger_spawn:BuffEnemiesByWaveName( waveName, hpEffective )
    local allGangers = FindService:FindEntitiesByName( waveName )
    --gtools:InspectObject( allGangers )
    log(">>>> found: %d entities by %s", #allGangers, waveName)
    gtools:BuffEnemies( allGangers, hpEffective )
end
------------------------------------------------------------------------------------
return ganger_spawn