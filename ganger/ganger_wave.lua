require("lua/utils/table_utils.lua")
local gtools = require("ganger/ganger_tools.lua")
local log = require("ganger/ganger_logger.lua")
-------------------------------------------------------------------------
-- CLASS PLUMBING
-------------------------------------------------------------------------
local ganger_wave = { }
-------------------------------------------------------------------------
-- Ganger wave sets (weighted compositions by biome)
-------------------------------------------------------------------------
local wave_sets = require("ganger/ganger_wave_sets.lua")
-------------------------------------------------------------------------
-- Get Blueprint by Pattern (caches first requests); can use "*" to get them
-- all, and they will be cached under an all entry
-------------------------------------------------------------------------
local function MatchBluePrints( blueprints, pattern ) -- internal only
    local result = {}
    for _, blueprint in ipairs( blueprints ) do
        if pattern == "*" or string.find( blueprint[2], pattern) then
            table.insert( result, blueprint[2] )
        end
    end
    return result
end
function ganger_wave:GetRandomBlueprintByPattern( pattern, biome )
    biome = biome or MissionService:GetCurrentBiomeName()
    local blueprints = self:GetBlueprintsByPattern( pattern, biome )
    if not blueprints or #blueprints == 0 then return nil end
    local random = math.random(1, #blueprints)
    log("GetRandomBlueprintByPattern: %s --> %s", pattern, blueprints[random])
    return blueprints[random]
end
function ganger_wave:GetBlueprintsByPattern( pattern, biome )
    biome = biome or MissionService:GetCurrentBiomeName()
    wave_sets[biome].cache = wave_sets[biome].cache or {}

    -- ensure cache is present
    if not wave_sets[biome].cache[pattern] then
        wave_sets[biome].cache[pattern] = MatchBluePrints( wave_sets[biome].blueprints, pattern )
    end
    
    return wave_sets[biome].cache[pattern]
end
-------------------------------------------------------------------------
-- Get an initialized Wave Set (defaults to current biome)
-------------------------------------------------------------------------
function ganger_wave:GetWaveSet( biome )

    biome = biome or MissionService:GetCurrentBiomeName()

    local wave_set = wave_sets[biome]
    if not wave_set then
        log("#### ERROR: unsupported biome %s", biome)
        return
    end
    self:InitWaveSet ( wave_set )

    --self.waveSet = wave_set
    return DeepCopy( wave_set )

end
-------------------------------------------------------------------------
-- Init Wave Set: calculates initial cumulative weights
-------------------------------------------------------------------------
function ganger_wave:InitWaveSet( wave_set )
    wave_set.total = 0
    for _,wave in ipairs (wave_set.blueprints) do
        wave_set.total = wave_set.total + wave[1]
    end
    -- sorting is a performance optimization for later random draws
     table.sort(wave_set.blueprints, function(a, b) return a[1] > b[1] end)   
end
-------------------------------------------------------------------------
-- Grow Wave Set: increments base weights and then reaccumulates
-------------------------------------------------------------------------
function ganger_wave:GrowWaveSet( wave_set )

    if wave_set == nil then log("#### GrowWaveSet: nil wave_set") end

    local growth_boss     = .001
    local growth_ultra    = .008
    local growth_alpha    = .016
    local decay_standard  = .1

    local to_remove = {}
    for i,v in ipairs( wave_set.blueprints ) do
        if     string.find(v[2], "_boss") then        v[1] = v[1] + growth_boss
        elseif string.find(v[2], "canceroth") then    v[1] = v[1] + growth_boss
        elseif string.find(v[2], "_ultra") then       v[1] = v[1] + growth_ultra
        elseif string.find(v[2], "_alpha") then       v[1] = v[1] + growth_alpha
        else -- did not contain any of the above -- standard mob
            v[1] = v[1] - decay_standard
            if v[1] <= 0 then table.insert( to_remove, i ) end
        end
    end

    for i = #to_remove, 1, -1 do
        table.remove( wave_set.blueprints, to_remove[i])
    end

    self:InitWaveSet( wave_set ) -- reaccumulate

    self:LogWaveSet( wave_set )

end
function ganger_wave:GrowWaveSetToLevel( wave_set, level )

    local growth_boss     = .001 * level
    local growth_ultra    = .008 * level
    local growth_alpha    = .016 * level
    local decay_standard  = .1   * level

    local to_remove = {}
    for i,v in ipairs( wave_set.blueprints ) do
        if     string.find(v[2], "_boss") then        v[1] = v[1] + growth_boss
        elseif string.find(v[2], "canceroth") then    v[1] = v[1] + growth_boss
        elseif string.find(v[2], "_ultra") then       v[1] = v[1] + growth_ultra
        elseif string.find(v[2], "_alpha") then       v[1] = v[1] + growth_alpha
        else -- did not contain any of the above -- standard mob
            v[1] = v[1] - decay_standard
            if v[1] <= 0 then table.insert( to_remove, i ) end
        end
    end

    for i = #to_remove, 1, -1 do
        table.remove( wave_set.blueprints, to_remove[i])
    end

    self:InitWaveSet( wave_set ) -- reaccumulate

    self:LogWaveSet( wave_set )
end
-------------------------------------------------------------------------
-- Pick Enemy: picks a single enemy from table
-------------------------------------------------------------------------
function ganger_wave:PickEnemy( wave_set )
    if wave_set.total == 0 then return nil end
    
    local rand = RandFloat(0, wave_set.total)
    
    for _, blueprint in ipairs(wave_set.blueprints) do
        rand = rand - blueprint[1]
        if rand < 0 then
            return blueprint[2]  -- Return the blueprint name
        end
    end
    
    return wave_set.blueprints[1][2]  -- Fallback to most likely
end
-------------------------------------------------------------------------
-- Create Wave: creates a kvp of blueprint keys and total counts for each
-- This randomizes the inventory of enemies
-------------------------------------------------------------------------
function ganger_wave:CreateWave( wave_set, n_enemies )
    local wave = {}
    for i = 1, n_enemies do
        local bp_name = self:PickEnemy (wave_set)
        if not bp_name then
            log("#### error: no picked enemy")
        elseif GANGER_INSTANCE.level < 6 and 
            (string.find( bp_name, "boss" ) or string.find( bp_name, "canceroth" )) then
            -- nothing, just drop the boss
        else
            if not wave[bp_name] then
                wave[bp_name] = 1
            else
                wave[bp_name] = (wave[bp_name] or 0) + 1
            end
        end
    end
    return wave
end

-------------------------------------------------------------------------
-- Log Wave Set (the weighted table)
-------------------------------------------------------------------------
function ganger_wave:LogWaveSet( wave_set )
    local lines = {}
    for _,v in ipairs (wave_set.blueprints) do
        table.insert(lines,string.format("   %6.3f: %s", v[1], v[2]))
    end
    log("WAVESET: \n%s", table.concat(lines,"\n"))
end
-------------------------------------------------------------------------
-- Log Wave (a selected wave composition)
-------------------------------------------------------------------------
function ganger_wave:LogWave( wave )
    local lines = {}
    for k,v in pairs(wave) do
        table.insert(lines,string.format("    %s: %d", k, v))
    end
    log("WAVE: \n%s",table.concat(lines,"\n"))
end
-------------------------------------------------------------------------
return ganger_wave