
local log    = require("scripts/ganger_logger.lua")
local gtools = require("scripts/ganger_tools.lua")
local gwaves = require("scripts/ganger_wave.lua")
------------------------------------------------------------------------------------
-- Autoexec Main
------------------------------------------------------------------------------------
local function ganger_autoexec()
    local player = gtools:GetPlayer()
    local team = EntityService:GetTeam( player )
    local mission = MissionService:GetCurrentMissionName()
    local isMain = tostring(MissionService:IsMainMission())
    --CampaignService:IncreaseCreaturesBaseDifficulty( 20.0 )
    --local baseDifficulty = CampaignService:GetCreaturesBaseDifficulty()
    local wave_set = gwaves:GetWaveSet()
    --local wave = gwaves:CreateWave( wave_set, 500 )
    --local difficulty = DifficultyService:GetDifficulty()
    log("--------------------------------------------------------------------------------")
    log("GANGER AUTOEXEC")
    log("mission: %s; main mission: %s", mission, isMain )
    log("--------------------------------------------------------------------------------")
	
    -- local serpent = require("scripts/serpent.lua")
    -- LogService:Log("\n _G:\n" .. serpent.block(_G))
    -- LogService:Log("\n _G metatable:\n" .. serpent.block(getmetatable(_G)))
    -- LogService:Log("\n: package.loaded\n" .. serpent.block(package.loaded))
    --revisit
    --local ok = pcall(function() MissionService:AddGameRule("scripts/ganger_dom.lua", "unused") end)
    --if not ok then log("ganger failed mission registration; if you are loading a savegame, ignore this") end
end

local ok, err = pcall(ganger_autoexec)

if not ok then
    LogService:Log("Ganger Autoexec fail with: " .. tostring(err))
end

-- FAILED ATTEMPT TO MONKEY PATCH; probably was called prior to my DOM
-- local old_desert = survival_desert.__init
-- log("old_desert: " .. tostring(old_desert))
-- survival_desert.init = function(self)
    -- local ok, result = pcall(old_desert, self)
    -- if not ok then
        -- log("orig desert init failed: " .. tostring(result))
        -- return
    -- end
    -- log("post-init hook")
    -- return result
-- end