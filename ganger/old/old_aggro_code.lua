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