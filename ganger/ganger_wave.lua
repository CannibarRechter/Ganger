require("lua/utils/table_utils.lua")
local gtools = require("ganger/ganger_tools.lua")
local log = require("ganger/ganger_logger.lua")
-------------------------------------------------------------------------
-- CLASS PLUMBING
-------------------------------------------------------------------------
local ganger_wave = { }
-- class 'ganger_wave' ( LuaGraphNode )
-- function ganger_wave:__init()
--     LuaGraphNode.__init(self, self)
-- end
-------------------------------------------------------------------------
-- function ganger_wave:init()
-- GANGSAFE(function()
--     log("ganger_wave:INIT()")
--     -- local selfStr = gtools.PrettyPrint( self.waveSets )
--     -- log("waveSets:\n%s", selfStr)
-- end)
-- end
-------------------------------------------------------------------------
-- function ganger_wave:OnLoad()
-- GANGSAFE(function()
--     log("ganger_wave:LOAD()")
--     -- local selfStr = gtools.PrettyPrint( self.waveSets )
--     -- log("waveSets:\n%s", selfStr)
-- end)
-- end
-------------------------------------------------------------------------
-- Ganger wave sets (weighted compositions by biome)
-------------------------------------------------------------------------
local wave_sets = { -- do not modify at runtime, results will be discarded
-------------------------------------------------------------------------
-- DESERT
-------------------------------------------------------------------------
    ["desert"] = {
        ["total"] = 0,
        ["blueprints"] = {
            --{ 0.30,  0, "units/ground/gnerot_desert", }, -- bugged
            -- v1:   v2: v3:

            { 0.03,  0, "units/ground/gnerot_alpha", },
            { 0.015, 0, "units/ground/gnerot_ultra", },
            { 0.003, 0, "units/ground/gnerot_boss_random", },

            { 0.50,  0, "units/ground/kermon", },
            { 0.05,  0, "units/ground/kermon_alpha", },
            { 0.025, 0, "units/ground/kermon_ultra", },

            { 0.75,  0, "units/ground/lesigian", },
            { 0.075, 0, "units/ground/lesigian_alpha", },
            { 0.038, 0, "units/ground/lesigian_ultra", },
            { 0.007, 0, "units/ground/lesigian_boss", },

            { 3.00, 0, "units/ground/mushbit", },
            { 0.30, 0, "units/ground/mushbit_alpha", },
            { 0.15, 0, "units/ground/mushbit_ultra", },

            { 2.00, 0, "units/ground/stregaros", },
            { 0.20, 0, "units/ground/stregaros_alpha", },
            { 0.10, 0, "units/ground/stregaros_ultra", },
            { 0.02, 0, "units/ground/stregaros_boss_random", },

            { 1.50, 0, "units/ground/zorant", },
            { 0.15, 0, "units/ground/zorant_alpha", },
            { 0.08, 0, "units/ground/zorant_ultra", },
        }
    }
}
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
    local total = 0
    for _,v in ipairs (wave_set.blueprints) do
        total = total + v[1]
        v[2] = total
        wave_set.total = total
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
        if     string.find(v[3], "_boss") then        v[1] = v[1] + growth_boss
        elseif string.find(v[3], "canceroth") then    v[1] = v[1] + growth_boss
        elseif string.find(v[3], "_ultra") then       v[1] = v[1] + growth_ultra
        elseif string.find(v[3], "_alpha") then       v[1] = v[1] + growth_alpha
        else -- did not contain any of the above -- standard mob
            v[1] = v[1] - decay_standard
            if v[1] <= 0 then table.insert( to_remove, i ) end
        end
    end

    for i = #to_remove, 1, -1 do
        table.remove( wave_set.blueprints, to_remove[i])
    end

    self:InitWaveSet( wave_set ) -- reaccumulate

    --self:LogWaveSet( wave_set )

end
-------------------------------------------------------------------------
-- Pick Enemy: picks a single enemy from table
-------------------------------------------------------------------------
function ganger_wave:PickEnemy ( wave_set )
    local rand = RandFloat(0, wave_set.total)
    for _,v in ipairs (wave_set.blueprints) do
        if rand <= v[2] then
            return v[3]
        end
    end
end
-------------------------------------------------------------------------
-- Create Wave: creates a kvp of blueprint keys and total counts for each
-- This randomizes the inventory of enemies
-------------------------------------------------------------------------
function ganger_wave:CreateWave( wave_set, n_enemies )
    local wave = {}
    for i = 1, n_enemies do
        local bp_name = ganger_wave:PickEnemy (wave_set)
        if not wave[bp_name] then
            wave[bp_name] = 1
        else
            wave[bp_name] = (wave[bp_name] or 0) + 1
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
        table.insert(lines,string.format("   %6.3f: %6.3f: %s", v[1], v[2], v[3]))
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