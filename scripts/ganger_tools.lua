local log = require("scripts/ganger_logger.lua")
local enemy_blueprints = require("scripts/ganger_blueprints.lua")
local enemy_unittypes = require("scripts/ganger_unittypes.lua")
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
        EntityService:CreateOrSetLifetime( entity, 120, "normal" ) -- sound no longer than 2 min
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
-- Takes n random draws from a table
------------------------------------------------------------------------------------
function ganger_tools:DrawRandomsFromTable(table, count)

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
        --     local InspectObject = require("scripts/ganger_inspector.lua")
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