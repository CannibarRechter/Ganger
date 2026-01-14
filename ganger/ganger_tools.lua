local log = require("ganger/ganger_logger.lua")
------------------------------------------------------------------------------------
local ganger_tools = {}
------------------------------------------------------------------------------------
-- Plays sound at player position
------------------------------------------------------------------------------------
function ganger_tools:PlaySoundOnPlayer( sound )

    if (GANGER_INSTANCE.silence)then return end
    if not EntityService:IsBlueprintExist( sound ) then
        log("#### invalid sound blueprint: %s", sound)
        return
    end

    local player = ganger_tools:GetPlayer()
    local ok, err = pcall(function()
        local entity = EntityService:SpawnEntity( sound, player, "" ) 
        --EntityService:CreateOrSetLifetime( entity, 120, "normal" ) -- unneeded if base bp is correct
        end)

    if not ok then
		log("sound failed: " .. sound .. ": " .. tostring(err))       
    end
end
------------------------------------------------------------------------------------
-- Return player entity
------------------------------------------------------------------------------------
function ganger_tools:GetPlayer()
    if PlayerService and PlayerService.GetPlayerControlledEnt then
        return PlayerService:GetPlayerControlledEnt(0)
    end
    return nil
end
------------------------------------------------------------------------------------
-- Spawn Validated Enemy
------------------------------------------------------------------------------------
function ganger_tools:SpawnEnemy( blueprint, spawnPoint, groupName, aggression )
    if ResourceManager:ResourceExists( "EntityBlueprint", blueprint ) then
        local enemy = nil
        if aggression == UNIT_AGGRESSIVE then
            enemy = EntityService:SpawnEntity( blueprint, spawnPoint, "wave_enemy")
            UnitService:SetInitialState( enemy, aggression )
        elseif aggression == UNIT_DEFENDER then 
            enemy = EntityService:SpawnEntity( blueprint, spawnPoint, "enemy")
            --UnitService:SetInitialState( enemy, aggression )
            UnitService:DefendSpot( enemy, 75, 250 )
        -- elseif aggression == UNIT_WANDER then -- this path is non-functional
        --     enemy = EntityService:SpawnEntity( blueprint, spawnPoint, "enemy")
        --     UnitService:SetInitialState( enemy, aggression )
        end
        if enemy then EntityService:SetName( enemy, groupName ) end
        return enemy
    else
        return nil
    end
end
-------------------------------------------------------------------------
-- Find All Border Spawn Points: returns all spawn points on map edges
-------------------------------------------------------------------------
function ganger_tools:FindAllBorderSpawnPoints()
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
-- Find Admissable Interior Spawnpoints (logic/spawn_objective)
-------------------------------------------------------------------------
function ganger_tools:MaybeRemoveSpawnPoints( spawnPoints, entity )

    if spawnPoints == nil then return end

    local countRemove = 0
    for i = #spawnPoints, 1, -1 do
        local entityPos = EntityService:GetPosition( entity )
        local spawnPointPos  = EntityService:GetPosition( spawnPoints[i] )
        if Distance( entityPos, spawnPointPos ) > 128 then
            table.remove(spawnPoints, i)
            countRemove = countRemove + 1
        end
    end
    log("removed %d spawnpoints", countRemove)

end
-------------------------------------------------------------------------
-- Find Admissable Spawnpoints 
-------------------------------------------------------------------------
function ganger_tools:FindAdmissibleInteriorSpawnPoints()
    return GANGER_INSTANCE.admissibleInteriorSpawnPoints
end
function ganger_tools:FindAdmissibleBorderSpawnPoints()
    return GANGER_INSTANCE.admissibleBorderSpawnPoints
end
-- function ganger_tools:FindAdmissibleInteriorSpawnPoints()

--     local denyEnt = nil

--     local hq = FindService:FindEntitiesByType("headquarters")
--     if hq and #hq > 0 then
--         denyEnt = hq[1]
--         --log("using HQ")
--     else 
--         denyEnt = self:GetPlayer()
--         --log("using player")
--     end

--     if not denyEnt then return nil end

--     local interiorSpawnPoints = self:FindAllInteriorSpawnPoints()
--     local admissibleSpawnPoints = {}

--     --log("scanning %d possible objectives", #objectives)
    
--     for _,objective in ipairs( interiorSpawnPoints ) do
--         local denyPos = EntityService:GetPosition( denyEnt )
--         local objPos  = EntityService:GetPosition( objective )
--         if Distance( denyPos, objPos ) > 300 then
--             table.insert( admissibleSpawnPoints, objective )
--         end
--         --local x, y, z = pos.x, pos.y, pos.z
--     end

--     --log("found %d admissible interiorSpawnPoints", #admissibleObjectives)

--     return admissibleSpawnPoints

-- end
-------------------------------------------------------------------------
-- Spawns AROUND admissable interior spawn points (spread out)
-------------------------------------------------------------------------
function ganger_tools:SpawnAtDynamicSpawnPoints( blueprint, groupName, nSpawnPoints, eventQuant, aggression, maxDistance )
    aggression = aggression or UNIT_AGGRESSIVE
    maxDistance = maxDistance or 17

    local admissibleSpawnPoints = self:FindAdmissibleInteriorSpawnPoints()
    if not admissibleSpawnPoints then return end
    local spawnPointsToUse = self:DrawDistinctRandomsFromTable(admissibleSpawnPoints, nSpawnPoints)
    --log("using %d spawn points", #spawnPointsToUse)

    for _,spawnPoint in ipairs( spawnPointsToUse) do
        --log("spawnpoint %d", spawnPoint)
        local ignoreWater = true 
        local dynPoints = UnitService:CreateDynamicSpawnPoints( spawnPoint, maxDistance, eventQuant, ignoreWater )

        for _,dynPoint in ipairs( dynPoints ) do
            EntityService:CreateOrSetLifetime( dynPoint, 30, "normal" )
            local enemy = self:SpawnEnemy( blueprint, dynPoint, groupName, aggression )
            self:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
            --log("spawned %d", enemy)
        end

    end
    return spawnPointsToUse
end
------------------------------------------------------------------------
-- Spawns on randomized interior spawn points, away from base
-------------------------------------------------------------------------
function ganger_tools:SpawnAtNearbySpawnPoints( blueprint, groupName, nSpawnPoints, eventQuant, aggression )
    aggression = aggression or UNIT_AGGRESSIVE

    local admissibleSpawnPoints = self:FindAdmissibleInteriorSpawnPoints()
    if not admissibleSpawnPoints then return end
    local spawnPointsToUse = self:DrawDistinctRandomsFromTable(admissibleSpawnPoints, nSpawnPoints)

    --log("using %d spawn points", #spawnPointsToUse)

    for _,spawnPoint in ipairs( spawnPointsToUse) do
        --log("of #%d, using spawnpoint %d", #spawnPointsToUse, spawnPoint)
        for i = 1, eventQuant do
            local enemy = self:SpawnEnemy( blueprint, spawnPoint, groupName, aggression )
            if enemy then
                self:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
            else
                log("#### invalid blueprint %s", blueprint )
            end
        end
    end
   return spawnPointsToUse
end
------------------------------------------------------------------------
-- Spawns a full wave at nearby spawnpoints
-------------------------------------------------------------------------
function ganger_tools:SpawnWaveAtNearbySpawnPoints( wave, groupName, nSpawnPoints )
    --aggression = aggression or UNIT_AGGRESSIVE

    local admissibleSpawnPoints = self:FindAdmissibleInteriorSpawnPoints()
    if not admissibleSpawnPoints then return end
    local spawnPointsToUse = self:DrawDistinctRandomsFromTable(admissibleSpawnPoints, nSpawnPoints)

    --log("using %d spawn points", #spawnPointsToUse)

    for _,spawnPoint in ipairs( spawnPointsToUse) do
        --log("of #%d, using spawnpoint %d", #spawnPointsToUse, spawnPoint)
        for blueprint, n in pairs ( wave ) do
            for _ = 1, n do
                local enemy = self:SpawnEnemy( blueprint, spawnPoint, groupName, UNIT_AGGRESSIVE )
                if enemy then
                    self:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
                else
                    log("#### invalid blueprint %s", blueprint )
                end
            end
        end
    end
   return spawnPointsToUse
end
------------------------------------------------------------------------
-- Spawns on randomized interior spawn points, away from base
-------------------------------------------------------------------------
function ganger_tools:SpawnAtSpawnPoint( blueprint, spawnPoint, groupName, eventQuant, aggression )
    aggression = aggression or UNIT_AGGRESSIVE

    for i = 1, eventQuant do
        local enemy = self:SpawnEnemy( blueprint, spawnPoint, groupName, aggression )
        if enemy then
            self:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
        else
            log("#### invalid blueprint %s", blueprint )
        end
    end

end
-------------------------------------------------------------------------
-- Spawn Around Player
-------------------------------------------------------------------------
function ganger_tools:SpawnAroundPlayer( blueprint, groupName, n )
    n = n or 1

    local spawnDistance = RandInt(7, 13)
    local ignoreWater = true 
    local player = self:GetPlayer()
    local spawnPoints = UnitService:CreateDynamicSpawnPoints( player, spawnDistance, n, ignoreWater )

    for _,spawnPoint in ipairs( spawnPoints ) do
        EntityService:CreateOrSetLifetime( spawnPoint, 30, "normal" )
        local enemy = self:SpawnEnemy( blueprint, spawnPoint, groupName, UNIT_AGGRESSIVE )
        self:BuffSingleEnemy( enemy, GANGER_INSTANCE.hpEffective )
        --log("spawned %d", enemy)
    end

end
-------------------------------------------------------------------------
-- Find Admissable Interior Spawnpoints (logic/spawn_objective)
-------------------------------------------------------------------------
function ganger_tools:FindAllInteriorSpawnPoints()
    local object_spawnpoints = FindService:FindEntitiesByBlueprint("logic/spawn_objective")
    return object_spawnpoints
end
-------------------------------------------------------------------------
-- Find All Player Spawn Points: returns player spawn points (1/cell typ)
-------------------------------------------------------------------------
function ganger_tools:FindAllPlayerSpawnPoints()
    local player_spawnpoints = FindService:FindEntitiesByBlueprint("logic/spawn_player")
    return player_spawnpoints
end
------------------------------------------------------------------------------------
-- Takes n random draws from a table
------------------------------------------------------------------------------------
function ganger_tools:DrawDistinctRandomsFromTable(table, count)

    local n = math.floor( count + 0.5 )
    local copy = {}
    for i = 1, #table do
        copy[i] = table[i]
    end
    
    n = math.min(n, #copy) -- overdraw protection
    
    -- shuffle
    for i = 1, n do
        local j = math.random(i, #copy)
        copy[i], copy[j] = copy[j], copy[i]
    end
    
    -- Take first n elements
    local result = {}
    for i = 1, n do
        result[i] = copy[i]
    end
    
    return result
end
------------------------------------------------------------------------------------
-- Buffs enemies; keeps a buff list so we don't buff twice
------------------------------------------------------------------------------------
function ganger_tools:BuffEnemies( enemies, hpEffective )

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
-- Buffs single enemy
------------------------------------------------------------------------------------
function ganger_tools:BuffSingleEnemy( enemy, hpEffective )

    -- protect against case of player in enemy list (more efficient to eliminate here)
    -- is an edge case for when the buff list pulls from the map

    if ( enemy == self:GetPlayer() ) then return end 

    --local healthComponent = EntityService:GetComponent( enemy, "HealthComponent" )

	local health = HealthService:GetHealth(enemy)
	local max_health = HealthService:GetMaxHealth(enemy)

    -- only buff uninjured enemies; protects for spawns in progress
	if health == max_health and health > 0 then
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
-- Find all map enemies 
------------------------------------------------------------------------------------
function ganger_tools:FindAllMapEnemies()

    local player = self:GetPlayer()
    local enemies = {}

	local enemies_by_type = FindService:FindEntitiesByType("ground_unit")
	Concat( enemies, enemies_by_type )

    -- remove the player (they are a ground unit)
    for i = 1, #enemies do
        if enemies[i] == player then
            table.remove(enemies, i)
            break
        end
    end
	return enemies
    -- SAVE FOR DEBUGGING
    -- local enemiesKVP = {}
    -- --local cull_count = 0
    -- for _,enemy in ipairs ( enemies ) do
    --     local bp_name = EntityService:GetBlueprintName( enemy )
    --     if not enemiesKVP[ bp_name ] then
    --         enemiesKVP[ bp_name ] = 1
    --     else
    --         enemiesKVP[ bp_name ] = enemiesKVP[ bp_name] +1
    --     end
    -- end
end
------------------------------------------------------------------------------------
-- Find all map spawners
------------------------------------------------------------------------------------
local spawner_blueprints = {
    "units/spawner/volume_boss_units_spawner",
    "units/spawner/volume_regular_units_spawner",
    "units/spawner/volume_resources_units_spawner",
--    "units/spawner/volume_resources_units_spawner",
}
------------------------------------------------------------------------------------
function ganger_tools:FindAllMapSpawners()

    local spawners = {}

    for _,blueprint in ipairs( spawner_blueprints ) do
        local spawnersByBlueprint = FindService:FindEntitiesByBlueprint( blueprint )
	    Concat( spawners, spawnersByBlueprint )
    end

    log("found #spawners %d", #spawners)

    return spawners
end
------------------------------------------------------------------------------------
-- function ganger_tools:LoadCdata (key)
--     local cd = CampaignService and CampaignService:GetCampaignData()
-- 	if not cd then return 0 end
--     return cd:GetIntOrDefault(key, 0)
-- end

-- function ganger_tools:StoreCdata (key, value)
--     local cd = CampaignService and CampaignService:GetCampaignData()
-- 	if not cd then return end
--     cd:SetInt(key, value)
-- end
------------------------------------------------------------------------------------
-- Send a LUA object to be printed
------------------------------------------------------------------------------------
function ganger_tools:InspectObject(obj)
    
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
function ganger_tools:PrettyPrintToStr(tbl, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    local result = {}
    
    -- Check if table is an array (consecutive integer keys starting at 1)
    local isArray = true
    local maxIndex = 0
    for k, v in pairs(tbl) do
        if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
            isArray = false
            break
        end
        maxIndex = math.max(maxIndex, k)
    end
    if isArray then
        for i = 1, maxIndex do
            if tbl[i] == nil then
                isArray = false
                break
            end
        end
    end
    
    if isArray then
        -- Print as array
        table.insert(result, "[\n")
        for i, v in ipairs(tbl) do
            if type(v) == "table" then
                table.insert(result, spaces .. "  " .. ganger_tools:PrettyPrintToStr(v, indent + 1))
            elseif type(v) == "string" then
                table.insert(result, spaces .. "  \"" .. v .. "\"\n")
            elseif type(v) == "number" then
                table.insert(result, spaces .. "  " .. tostring(v) .. "\n")
            else
                table.insert(result, spaces .. "  " .. tostring(v) .. "\n")
            end
        end
        table.insert(result, spaces .. "]\n")
    else
        -- Print as dictionary
        table.insert(result, "{\n")
        for k, v in pairs(tbl) do
            local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
            if type(v) == "table" then
                table.insert(result, spaces .. "  " .. key .. ": " .. ganger_tools:PrettyPrintToStr(v, indent + 1))
            elseif type(v) == "string" then
                table.insert(result, spaces .. "  " .. key .. ": \"" .. v .. "\"\n")
            elseif type(v) == "number" then
                table.insert(result, spaces .. "  " .. key .. ": " .. tostring(v) .. "\n")
            else
                table.insert(result, spaces .. "  " .. key .. ": " .. tostring(v) .. "\n")
            end
        end
        table.insert(result, spaces .. "}\n")
    end
    
    return table.concat(result)
end
------------------------------------------------------------------------------------
return ganger_tools