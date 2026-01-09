local log = require("ganger/ganger_logger.lua")
local enemy_blueprints = require("ganger/ganger_blueprints.lua")
local enemy_unittypes = require("ganger/ganger_unittypes.lua")
------------------------------------------------------------------------------------
local ganger_tools = {}
------------------------------------------------------------------------------------
-- Plays sound at player position
------------------------------------------------------------------------------------
function ganger_tools:PlaySoundOnPlayer( sound )

    if (GANGER_INSTANCE.silence)then
        --log("sound off for %s", sound)
        return
    end

    local playerEnt = ganger_tools:GetPlayer()
    local ok, err = pcall(function()
        local entity = EntityService:SpawnEntity( sound, playerEnt, "" ) 
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
            UnitService:SetInitialState( enemy, UNIT_AGGRESSIVE )
            UnitService:DefendSpot( enemy, 25, 100 )
        end
        if enemy then EntityService:SetName( enemy, groupName ) end
        return enemy
    else
        return nil
    end
    --local entity = EntityService:SpawnEntity( blueprint, x, y, z, "wave_enemy")
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
function ganger_tools:FindAdmissibleInteriorSpawnPoints()

    local denyEnt = nil

    local hq = FindService:FindEntitiesByType("Headquarters")
    if hq and #hq > 0 then
        denyEnt = hq[1]
        log("using HQ")
    else 
        denyEnt = self:GetPlayer()
        log("using player")
    end

    if not denyEnt then return nil end

    local objectives = self:FindAllInteriorSpawnPoints()
    local admissibleObjectives = {}

    log("scanning %d possible objectives", #objectives)
    
    for _,objective in ipairs( objectives ) do
        local denyPos = EntityService:GetPosition( denyEnt )
        local objPos  = EntityService:GetPosition( objective )
        if Distance( denyPos, objPos ) > 300 then
            table.insert( admissibleObjectives, objective )
        end
        --local x, y, z = pos.x, pos.y, pos.z
    end

    log("found %d admissible objectives", #admissibleObjectives)

    return admissibleObjectives

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
    
    n = math.min(n, #copy)
    
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
-- Find all map enemies (probably obsolete)
------------------------------------------------------------------------------------
function ganger_tools:FindAllMapEnemies()

    --local playable_min,playable_max = get_player_pos()
	-- local playable_min = MissionService:GetPlayableRegionMin()
	-- local playable_max = MissionService:GetPlayableRegionMax()

	-- local enemies = { }

	-- for _,bp in ipairs (enemy_blueprints) do
	-- 	local enemies_by_bp = FindService:FindEntitiesByBlueprintInBox( bp, playable_min, playable_max)
	-- 	Concat( enemies, enemies_by_bp )
	-- end
    -- log("FindAllMapEnemies(by bp)#####: " .. tostring(Size(enemies or {})))

    -- local counted_bps = { }
    -- for _, enemy in ipairs ( enemies ) do
    --     if not counted_bps[ enemy ] then
    --         local bp_name = EntityService:GetBlueprintName( enemy )
    --         if not counted_bps[ bp_name ] then
    --             counted_bps[ bp_name ] = 1
    --         else
    --             counted_bps[ bp_name ] = counted_bps[ bp_name] +1
    --         end
    --     end
    -- end

    -- log("First BPs: ")
    -- for bp, count in pairs(counted_bps) do
    --     log("    %s: %d", bp, count)
    -- end

 	-- temp alt
    -- local alt_enemies = FindService:FindEntitiesByTeamInBox("enemy", {playable_min, playable_max})
    -- if alt_enemies then
    --     log("FindAllMapEnemies(alt)#####: " .. tostring(Size(alt_enemies)))
    -- end
    
    local enemies = {}
	for _,unittype in ipairs ( enemy_unittypes ) do
		local enemies_by_type = FindService:FindEntitiesByType(unittype)
		Concat( enemies, enemies_by_type )
	end
    log("FindAllMapEnemies(by type)#####: " .. tostring(#enemies))

    local enemiesKVP = {}
    --local cull_count = 0
    for _,enemy in ipairs ( enemies ) do
        local bp_name = EntityService:GetBlueprintName( enemy )
        --log("enemy %s: %d", bp_name, enemy)
        if not enemiesKVP[ bp_name ] then
            enemiesKVP[ bp_name ] = 1
        else
            enemiesKVP[ bp_name ] = enemiesKVP[ bp_name] +1
        end      
        -- local teamStruct = EntityService:GetTeam( enemy )

        -- if teamStruct then
        --     log("typeof teamstruct: %s", tostring(type(teamStruct)))
        --     local json = require("scripts/dkjson.lua")
        --     local teamStr = json:encode( teamStruct )
        --     local InspectObject = require("ganger/ganger_inspector.lua")
        --     InspectObject( teamStruct )
        --     log("teamstruct %s", teamStr)
        --     -- if teamStruct.team == "neutral" then      
        --     -- -- if not EntityService:IsInTeamRelation(self:GetPlayer(), enemy, "hostility") then
        --     --     local bp_name = EntityService:GetBlueprintName( enemy )
        --     --     log(string.format("### Removing enemy %s: %d", bp_name, enemy))
        --     --     cull_count = cull_count + 1
        --     --     Remove ( enemies, enemy )
        --     -- else
        --     --     log("not removing >>> %s: %s", bp_name, teamStruct.team)
        --     -- end
        -- else
        --     log("not removing %s: (nil)", bp_name)
        -- end
    end

    --log("FindAllMapEnemies culled: %d ", cull_count)
    log("Enemies by type: ")
    for bp, count in pairs(enemiesKVP) do
        log("    %s: %d", bp, count)
    end

    -- local alt_enemies_kvp = {}
    -- for _,eid in ipairs (alt_enemies) do
    --     alt_enemies_kvp[ eid ] = true
    -- end

    -- -- reconcile check (Debug)
    -- local missing_bps = {}
    -- for _,enemy in ipairs (enemies) do
    --     if not alt_enemies_kvp[ enemy ] then
    --         local bp_name = EntityService:GetBlueprintName( enemy )
    --         if not missing_bps[ bp_name ] then
    --             missing_bps[ bp_name ] = 1
    --         else
    --             missing_bps[ bp_name ] = missing_bps[ bp_name] +1
    --         end
    --     end
    -- end

    -- log("Missing BPs: ")
    -- for bp, count in pairs(missing_bps) do
    --     log("    %s: %d", bp, count)
    -- end

	return enemies
end

-- local ep = require("lua/entity_patcher.lua")
-- function ganger_tools:BuffAllBlueprints( )
--     local patch = {
--         "units/ground/mushbit",
--         "units/ground/mushbit_alpha",
--         "units/ground/mushbit_ultra",
--     }

--     local map = {
--         ["HealthDesc"] = {
--             ["health*"] = 20
--         },
--         ["HealthComponent"] = {
--             ["health*"] = 20
--         }
--     }

--     ep:Apply( patch, map )
-- end

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

-- function ganger_tools:ToJson (obj)
--     return json.encode(obj)
-- end
------------------------------------------------------------------------------------
return ganger_tools