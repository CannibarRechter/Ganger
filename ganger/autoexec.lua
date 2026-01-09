local log    = require("ganger/ganger_logger.lua")
local gtools = require("ganger/ganger_tools.lua")
------------------------------------------------------------------------------------
-- Autoexec Main
------------------------------------------------------------------------------------

local function PatchGame()

    -- check this because it is at autoexec time ONLOAD
    -- also: no need to add the game rule during load anyway

    if survival_base == nil then return end

    -- hook load and add game rules

    local old_base_init = survival_base.init
    ---@diagnostic disable-next-line: duplicate-set-field
    survival_base.init = function(self)
        local ok = pcall(old_base_init, self)
        if not ok then
            log("####  Failed to invoke old init")
            return
        else
            local ok, err = pcall(function()
                MissionService:AddGameRule( "ganger/ganger_dom.lua", "unused" )
                -- MissionService:AddGameRule( "ganger/ganger_spawn.lua", "unused" )
                -- MissionService:AddGameRule( "ganger/ganger_wave.lua", "unused" )
            end)

            if not ok then
                log("#### Failed to patch Ganger with error %s", tostring(err))
            else
                log("PATCHED.")
            end
        end
    end

end

local function ganger_autoexec()
    local mission = MissionService:GetCurrentMissionName()
    local isMain = tostring(MissionService:IsMainMission())
    local biome = MissionService:GetCurrentBiomeName()
    --CampaignService:IncreaseCreaturesBaseDifficulty( 20.0 )
    --local baseDifficulty = CampaignService:GetCreaturesBaseDifficulty()
    --local wave_set = gwaves:GetWaveSet()
    --local wave = gwaves:CreateWave( wave_set, 500 )
    --local difficulty = DifficultyService:GetDifficulty()
    log("--------------------------------------------------------------------------------")
    log("GANGER AUTOEXEC")
    log("mission: %s; biom: %s; main mission: %s", mission, biome, isMain )
    log("--------------------------------------------------------------------------------")

    PatchGame()

end

local ok, err = pcall(ganger_autoexec)
if not ok then
    LogService:Log("Ganger Autoexec fail with: " .. tostring(err))
end