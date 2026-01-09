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

        --gwave:LogWave( wave )
        for blueprint, count in pairs ( wave ) do
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

        if ResourceManager:ResourceExists( "EntityBlueprint", blueprint ) then
            local enemy = EntityService:SpawnEntity( blueprint, spawnPoint, "wave_enemy")
            EntityService:SetName( enemy, waveName )
            UnitService:SetInitialState( enemy, UNIT_AGGRESSIVE)
            self:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
            table.insert( entities, enemy )
        else
            log("#### invalid blueprint %s", blueprint )
        end
        --local entity = EntityService:SpawnEntity( blueprint, x, y, z, "wave_enemy")
    end
    --log(">>>> created %d %s at spawnpoint", #entities, blueprint)
end
-------------------------------------------------------------------------
-- Picks spawn points (note: done earlier in dom so we can display the
-- warning decals at the map edges)
-------------------------------------------------------------------------
function ganger_spawn:PickSpawnPoints( spawnPointCount )
    --self.spawnPoints = { gtools:GetPlayer() }
    local allSpawnPoints = self:FindAllBorderSpawnPoints()
    -- local allSpawnPoints = self:FindAllPlayerSpawnPoints()
    self.spawnPoints = gtools:DrawRandomsFromTable( allSpawnPoints, spawnPointCount )
    return self.spawnPoints
end
-------------------------------------------------------------------------
-- Find All Border Spawn Points: returns all spawn points on map edges
-------------------------------------------------------------------------
function ganger_spawn:FindAllBorderSpawnPoints()
    local all_points = {}
    for _,region in ipairs({
        "spawn_enemy_border_south",
		"spawn_enemy_border_north",
		"spawn_enemy_border_east",
		"spawn_enemy_border_west"
        }) do

        local spawn_points = FindService:FindEntitiesByGroup(region)
        Concat( all_points, spawn_points )
    end
    return all_points
end
-------------------------------------------------------------------------
-- Find All Player Spawn Points: returns player spawn points (1/cell typ)
-------------------------------------------------------------------------
function ganger_spawn:FindAllPlayerSpawnPoints()
    local player_spawnpoints = FindService:FindEntitiesByBlueprint("logic/spawn_player")
    return player_spawnpoints
end
------------------------------------------------------------------------------------
-- Buffs single enemy
------------------------------------------------------------------------------------
function ganger_spawn:BuffSingleEnemy( enemy, hpEffective )

    -- protect against case of player in enemy list (more efficient to eliminate here)
    -- is an edge case for when the buff list pulls from the map

    if ( enemy == gtools:GetPlayer() ) then return end 

    --local healthComponent = EntityService:GetComponent( enemy, "HealthComponent" )

	local health = HealthService:GetHealth(enemy)
	local max_health = HealthService:GetMaxHealth(enemy)

    -- only buff uninjured enemies; protects for spawns in progress
	if health == max_health and health > 1 then
        --hpEffective = .1 -- tmp
		HealthService:SetMaxHealth ( enemy, max_health*hpEffective )
		HealthService:SetHealth ( enemy, health*hpEffective )

        local after_health = HealthService:GetHealth(enemy)
	    local after_max_health = HealthService:GetMaxHealth(enemy)

        --log("buffed %d: %d/%d (%.2f) --> %d/%d", enemy, health, max_health, hpEffective, after_health, after_max_health)
        return true
    else

        log("#### skipping %d: %d/%d", enemy,  health, max_health)
        return false
	end

end
------------------------------------------------------------------------------------
-- Buffs enemies; keeps a buff list so we don't buff twice
------------------------------------------------------------------------------------
function ganger_spawn:BuffEnemiesByWaveName( waveName, hpEffective )
    local allGangers = FindService:FindEntitiesByName( waveName )
    --gtools:InspectObject( allGangers )
    log(">>>> found: %d entities by %s", #allGangers, waveName)
    self:BuffEnemies( allGangers, hpEffective )
end
------------------------------------------------------------------------------------
-- Buffs enemies; keeps a buff list so we don't buff twice
------------------------------------------------------------------------------------
function ganger_spawn:BuffEnemies( enemies, hpEffective )

    local buff_count = 0

    for _,enemy in ipairs ( enemies ) do
        --log("buffing " .. k .. ":" .. v)
		if self:BuffSingleEnemy( enemy, hpEffective ) then
            buff_count = buff_count + 1
        end
	end

	log("BuffEnemies(): buffed enemies count#: %d", buff_count)

end
------------------------------------------------------------------------------------
return ganger_spawn