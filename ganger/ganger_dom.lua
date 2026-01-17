------------------------------------------------------------------------------------
-- GAME SAFETY IN THIS FILE
-- This file can be called from Riftbreaker in Init(), OnLoad, the various state
-- functions, and the event handlers. The GANGSAFE wrapper is a catchall to prevent
-- the game from crashing and should not be removed. It is only mandatory where
-- presently coded
------------------------------------------------------------------------------------require("lua/utils/table_utils.lua")
require("ganger/ganger_safe.lua")
local gtools = require("ganger/ganger_tools.lua")
local gspawn = require("ganger/ganger_spawn.lua")
local gwave = require("ganger/ganger_wave.lua")
local log = require("ganger/ganger_logger.lua")
------------------------------------------------------------------------------------
-- CLASS PLUMBING
------------------------------------------------------------------------------------
class 'ganger_dom' ( LuaGraphNode )
function ganger_dom:__init()
    LuaGraphNode.__init(self, self)
end
GANGER_INSTANCE = nil -- inited in Init/OnLoad
------------------------------------------------------------------------------------
local settings = {
    level              = 0,
    scaling            = 0.1, -- additive percent
    hpEffective        = 1,
    waveStrength       = nil,
    spawnPointCount    = 2,
    attackCount        = nil,
    attackSize         = 100,
    maxSpawnPointCount = 10,
    maxAttackSize      = 300,

    warmupTime         = nil,
    waveTime           = nil,
    multiAttackTime    = 10,
    ambientDelay       = 4,
    buffDelay          = 1,
    politeTime         = 10,
    recentRuntime      = 0,
    priorRuntime       = 0,
    lastChaosTime      = 0,
    totalWaves         = 0,

    testMode           = false,
    ambience           = true,
    silence            = false,
    chaos              = true
}
------------------------------------------------------------------------------------
function ganger_dom:LogSettings()
	log(
		"Settings: \n" ..

		"  level:               " .. self.level .. "\n" ..
		"  scaling:             " .. self.scaling .. "\n" ..
		"  hp(Effective)        " .. self.hpEffective .. "\n" ..
		"  waveStr:             " .. self.waveStrength .. "\n" ..
		"  spawnPointCount:     " .. self.spawnPointCount .. "\n" ..
		"  attackCount:         " .. self.attackCount .. "\n" ..
		"  attackSize:          " .. self.attackSize .. "\n" ..
		"  maxSpawnPointCount:  " .. self.maxSpawnPointCount .. "\n" ..
		"  maxAttackSize:       " .. self.maxAttackSize .. "\n" ..

		"  warmupTime:          " .. self.warmupTime .. "\n" ..
		"  waveTime:            " .. self.waveTime .. "\n" ..
		"  multiAttackTime:     " .. self.multiAttackTime .. "\n" ..
		"  ambientDelay:        " .. self.ambientDelay .. "\n" ..
		"  buffDelay:           " .. self.buffDelay .. "\n" ..
		"  politeTime:          " .. self.politeTime .. "\n" ..
		"  recentRuntime:       " .. self.recentRuntime .. "\n" ..
		"  priorRuntime:        " .. self.priorRuntime .. "\n" ..
		"  lastChaosTime:       " .. self.lastChaosTime .. "\n" ..
		"  totalWaves:          " .. self.totalWaves .. "\n" ..

        "  currentWaveSet:      " .. tostring( self.currentWaveSet ) .. "\n" ..
        "  currentSpawnPoints:  #" .. tostring( #self.currentSpawnPoints ) .. "\n" ..
        "  admissibleBorders :  #" .. tostring( #self.admissibleBorderSpawnPoints ) .. "\n" ..
        "  admissibleInteriors: #" .. tostring( #self.admissibleInteriorSpawnPoints ) .. "\n" ..
        "  testMode:            " .. tostring( self.testMode ) .. "\n" ..
        "  chaos:               " .. tostring( self.chaos ) .. "\n" ..
        "  ambience:            " .. tostring( self.ambience ) .. "\n" ..
        "  silence:             " .. tostring( self.silence )
		)

    --log("waveset:")
    --gwave:LogWaveSet( self.currentWaveSet )

end
------------------------------------------------------------------------------------
-- InitSettings; called only once at game start (with Init)
-- Note: data in dom is automatically persistent
------------------------------------------------------------------------------------
function ganger_dom:InitSettings( )

    -- makes them persistent
    for k,v in pairs(settings) do
        self[k] = v
    end

	self.waveStrength        = DifficultyService:GetWaveStrength()
	self.attackCount         = DifficultyService:GetAttacksCountMultiplier()
	self.warmupTime          = math.max( DifficultyService:GetWarmupDuration(), 300)
	self.waveTime            = math.max( DifficultyService:GetWaveIntermissionTime(), 120)
    self.currentWaveSet      = gwave:GetWaveSet()
    self.currentSpawnPoints  = {}
    self.admissibleInteriorSpawnPoints = gtools:FindAllInteriorSpawnPoints( )
    self.admissibleBorderSpawnPoints   = gtools:FindAllBorderSpawnPoints( )

    self:LoadPrefs()
    self:MaybeApplyTestMode()

    -- defaults: normal = 1
    if self.waveStrength == "brutal" then
        self.hpEffective = 1.2
    elseif self.waveStrength == "hard" then
        self.hpEffective = 1.1
    end

	self:LogSettings()
    gwave:LogWaveSet( self.currentWaveSet )
end
------------------------------------------------------------------------------------
-- Sanitize Settings: called on load; ensures code changes align with old savegames
------------------------------------------------------------------------------------
function ganger_dom:SanitizeSettings()
    -- ensures that older save games without current settings havfe the value
    -- push from the local table to the dom table ensures persistence
    for k, v in pairs(settings) do
        if self[k] == nil then
            self[k] = v
        end
    end
    -- FUTURE function calls here only if needed (new vars from game data
    -- or settings that are determined dynamically
end

------------------------------------------------------------------------------------
-- Init dom; runs only once
------------------------------------------------------------------------------------
function ganger_dom:init()
GANGSAFE(function()

    log("--------------------------------------------------------------------------------")
    log("ganger_dom:INIT() self: %s", tostring(self))
    log("--------------------------------------------------------------------------------")
	-- self.marked_enemies = setmetatable({}, { __mode = "k" }) -- mode k makes the table weak; if objects in it are gc'd the entry is erased

	self:InitSettings()

    GANGER_INSTANCE = self

    if pcall(function() 
        -- used to track range of buildings to interior spawn points
        RegisterGlobalEventHandler("BuildingBuildEvent", function(event)
            self:OnBuildingBuild(event)
        end)
    end) then
        log("BuildingBuildEvent handler registered")
    else
        log("BuildingBuildEvent handler failed registration")
    end

    --state machines; each loop independently

    self.actionm    = self:CreateStateMachine() -- main spawner
    self.chaosm     = self:CreateStateMachine() -- choatic events
    self.ambientm   = self:CreateStateMachine() -- ambient sounds
    self.susm       = self:CreateStateMachine() -- occasional sussurus
    self.alarmm     = self:CreateStateMachine() -- occasional alarm
    self.endm       = self:CreateStateMachine() -- endgame sequence

    -- main spawning engine
    self.actionm:AddState("prep",     { enter=  "PrepStart",    exit="PrepEnd"   	}) -- breather without display on screen
    self.actionm:AddState("wait",     { enter=  "WaitStart",    exit="WaitEnd"   	}) -- display on screen with countdown
    self.actionm:AddState("action",   { enter=  "ActionStart", 
                                        -- main action here; loop is a loop over the game-provided attack count
                                        execute="ActionLoop",   interval=self.multiAttackTime,
                                        exit="ActionEnd" 	}) 

    -- chaos engine (random events)
    self.chaosm:AddState("chaos",     { enter=  "ChaosStart",   exit="ChaosEnd"   	})

    -- sound related: ambient is continuous, all others are conditional

    self.ambientm:AddState("ambient", { enter=  "AmbientStart", exit="AmbientEnd"   })
    self.susm:AddState("sus",         { enter=  "SusStart",     exit="SusEnd" 	    }) 
    self.alarmm:AddState("alarm",     { enter=  "AlarmStart",   exit="AlarmEnd" 	}) 
    self.endm:AddState("endgame",     { enter=  "EndgameStart", exit="EndgameEnd" 	}) 

	-- start your engines!
	self.actionm:ChangeState("prep")
    if self.ambience then self.ambientm:ChangeState("ambient") end
    self.chaosm:ChangeState("chaos")

    self:PatchEndGame()

end)
end
------------------------------------------------------------------------------------
-- Load dom; runs once when loading game; needs to reregister event handler
------------------------------------------------------------------------------------
function ganger_dom:OnLoad()
GANGSAFE(function()

    log("--------------------------------------------------------------------------------")
    log("ganger_dom:ON_LOAD() data:" .. tostring(self.data))
    log("--------------------------------------------------------------------------------")

    if pcall(function() 
        -- used to track range of buildings to interior spawn points
        RegisterGlobalEventHandler("BuildingBuildEvent", function(event)
            self:OnBuildingBuild(event)
        end)
    end) then
        log("BuildingBuildEvent handler registered")
    else
        log("BuildingBuildEvent handler failed registration")
    end

    GANGER_INSTANCE = self

    self:SanitizeSettings()
    self:LogSettings()
    self:PatchEndGame()

    -- enable changing preferences on game reload
    self:LoadPrefs()
    self:MaybeApplyTestMode()

    gwave:LogWaveSet( self.currentWaveSet )

end)
end
------------------------------------------------------------------------------------
--  Load Prefs
------------------------------------------------------------------------------------
function ganger_dom:LoadPrefs()
    local ok = pcall(function()
        local prefs = require("ganger/ganger_prefs.lua")
        self.maxAttackSize  = prefs.maxAttackSize
        self.scaling        = prefs.scaling
        self.ambience       = prefs.ambience
        self.silence        = prefs.silence
        self.chaos          = prefs.chaos
        self.testMode       = prefs.testMode
    end)
    if not ok then log("No prefs found.")
    else log("Prefs loaded.") end
end
------------------------------------------------------------------------------------
--  Test Mode
------------------------------------------------------------------------------------
function ganger_dom:MaybeApplyTestMode()
    if self.testMode then
        self.level          = 8
        self.maxAttackSize  = 400
        self.attackCount    = 5
        self.warmupTime     = 5
        self.waveTime       = 60
    end
end
------------------------------------------------------------------------------------
-- Patch Game: runtime patches
------------------------------------------------------------------------------------
function ganger_dom:PatchEndGame()
GANGSAFE(function()

    self.oldMissionFail = dom_mananger.OnRespawnFailedEvent

    dom_mananger.OnRespawnFailedEvent = function(oldDomInstance, evt)

        -- must save both so they can be passed back to the game asynchronously
        self.oldMissionFailEvt = evt
        --self.oldDomInstance = oldDomInstance
        self.endm:ChangeState("endgame")

    end

end)
end
------------------------------------------------------------------------
-- PREP; just waits a few seconds each time to be "polite" --
-- (takes GUI notification down, but does not change wave interval)
------------------------------------------------------------------------
function ganger_dom:PrepStart(state)
GANGSAFE(function()

    --log("PrepStart(): politeTime: " .. self.politeTime)
    state:SetDurationLimit( self.politeTime )

end)
end
------------------------------------------------------------------------
function ganger_dom:PrepEnd(state)
GANGSAFE(function()

    --log("PrepEnd")
    self.actionm:ChangeState("wait")

end)
end
------------------------------------------------------------------------
-- WAIT: exists solely to control activation time for the RUN MACHINE
------------------------------------------------------------------------
function ganger_dom:WaitStart(state)
GANGSAFE(function()

    local time_delay = 0
    
    if self.priorRuntime ~= 0 then
        -- standard condition
        time_delay = self.waveTime - self.politeTime
    else
        -- warmup condition
        time_delay = self.waveTime + self.warmupTime - self.politeTime		
    end

    --log("WaitStart(): time_delay: " .. tostring(time_delay) .. " at level: " .. tostring(self.level))
    
    local label = string.format("Galatea's Wrath (Level %d):", self.level)
    self:DisplayTimer(time_delay, label)

    state:SetDurationLimit(time_delay)

end)
end
------------------------------------------------------------------------
function ganger_dom:WaitEnd(state)
GANGSAFE(function()

    --log("WaitEnd")
    self.actionm:ChangeState("action")

end)
end
------------------------------------------------------------------------
-- ACTION: Handles all spawning, aggro, and what not
------------------------------------------------------------------------
function ganger_dom:ActionStart(state)
GANGSAFE(function()

    log("ActionStart")
    self.actionCount = 0
    self.susm:ChangeState("sus")
    self.currentSpawnPoints = gspawn:PickSpawnPoints( self.spawnPointCount)
    table.insert( self.currentSpawnPoints, gtools:GetPlayer() )

    for _,sp in ipairs( self.currentSpawnPoints ) do

        local indicator = EntityService:SpawnEntity( "effects/messages_and_markers/wave_marker", sp, "no_team" )
	    local indicatorDuration = 45
	    EntityService:CreateLifeTime( indicator, indicatorDuration, "normal" )

    end

    local label = string.format("Horde incoming:")
    self:DisplayTimer(10, label)

    state:SetDurationLimit(10)

end)
end
------------------------------------------------------------------------
-- ActionLoop: loops over the attack count parameter as given by player
------------------------------------------------------------------------
function ganger_dom:ActionLoop(state)
GANGSAFE(function()

    self.priorRuntime = self.recentRuntime
    self.recentRuntime = GetLogicTime()

    self.actionCount = self.actionCount + 1
    log("ActionLoop() ACTION#: %d", self.actionCount)
    gtools:PlaySoundOnPlayer( "ganger/effects/big_roar" )
    self.alarmm:ChangeState("alarm")
    gspawn:SpawnWaves( self.currentSpawnPoints, self.currentWaveSet, self.attackSize )

    if self.actionCount > self.attackCount then 
        state:Exit()
    end

end)
end
------------------------------------------------------------------------
function ganger_dom:ActionEnd(state)
GANGSAFE(function()

    self:ProcessDifficultyIncrease()
    local text = string.format("WRATH LEVEL %d", self.level)
    self:DisplayText( text, 0.5 )
    self.actionm:ChangeState("prep")
    --log("ActionEnd() ### TERMINATED")

end)
end
------------------------------------------------------------------------
-- Chaos machine; spawns little events without warning
------------------------------------------------------------------------
function ganger_dom:ChaosStart(state)
GANGSAFE(function()

    local time_delay = 0

    if self.lastChaosTime then
        time_delay = self.chaosInterval or 10
        -- they mostly come out at night, mostly
        if EnvironmentService:GetLightIntensity() < .3 then
            time_delay = time_delay / 2
        end
    else
        -- don't start until full warmup of waves /2 to to align out of wave cycle
        time_delay = self.waveTime/2 + self.warmupTime
    end

    --log("ChaosStart()")
    state:SetDurationLimit( time_delay )

end)
end
------------------------------------------------------------------------
function ganger_dom:ChaosEnd(state)
GANGSAFE(function()

    --GANGER_CHAOS:ChaosAggro() 
    -- if not self.chaosCount then self.chaosCount = 0
    -- else self.chaosCount = self.chaosCount + 1 end
    --log("MaybeCauseChaos(): admissibleInteriorSpawnPoints = %d", #GANGER_INSTANCE.admissibleInteriorSpawnPoints)

    local chaos_caused = GANGER_CHAOS:MaybeCauseChaos( 1 )

    if (chaos_caused) then
        self.lastChaosTime = GetLogicTime()
    end

    self.chaosm:ChangeState("chaos")

end)
end
------------------------------------------------------------------------
-- AMBIENT; gives this mod a distinct flavor with background roars
------------------------------------------------------------------------
function ganger_dom:AmbientStart(state)
GANGSAFE(function()

    -- more lively at night
    local lightLevel = EnvironmentService:GetLightIntensity()
    local daylightFactor = lightLevel*10 -- 0-1 becomes 0-10

    local offset = RandFloat( 0, 5 ) + daylightFactor -- up to ~15 seconds longer during day
    state:SetDurationLimit( self.ambientDelay + offset )

end)
end
------------------------------------------------------------------------
function ganger_dom:AmbientEnd(state)
GANGSAFE(function()

    if RandInt( 1, 3) == 1 then
        if EnvironmentService:GetLightIntensity() < 0.3 then
            -- they mostly come out at night... mostly
            gtools:PlaySoundOnPlayer( "ganger/effects/ambient_xenos" )
        else
            gtools:PlaySoundOnPlayer( "ganger/effects/ambient_roars" )
        end
    else
        gtools:PlaySoundOnPlayer( "ganger/effects/ambient_herbivores" )  
    end
    self.ambientm:ChangeState("ambient")

end)
end
------------------------------------------------------------------------
-- SUSSURUS; rumble with bunches of overlapping roars
------------------------------------------------------------------------
function ganger_dom:SusStart(state)
GANGSAFE(function()

    --log("SusStart()")
    local susCount = self.susCount or 0
    self.susCount = susCount
    local wait = RandFloat( 0.3, 0.9 )
    state:SetDurationLimit( wait )

end)
end
------------------------------------------------------------------------
function ganger_dom:SusEnd(state)
GANGSAFE(function()

	--log("SusEnd: %d", self.susCount)
    if self.susCount == 1 then 
        gtools:PlaySoundOnPlayer( "ganger/effects/long_rumble" )
    else
        if EnvironmentService:GetLightIntensity() < 0.3 then
            -- they mostly come out at night... mostly
            gtools:PlaySoundOnPlayer( "ganger/effects/ambient_xenos" )
        else
            gtools:PlaySoundOnPlayer( "ganger/effects/ambient_roars" )
        end
    end

    if self.susCount < 8 then
        self.susCount = self.susCount + 1
        self.susm:ChangeState("sus")
    else
        self.susCount = 0
        -- stop the sussurus
    end

end)
end
------------------------------------------------------------------------
-- ALARM; plays the alarm once
------------------------------------------------------------------------
function ganger_dom:AlarmStart(state)
GANGSAFE(function()

    --log("AlarmStart()")
    state:SetDurationLimit( 5 )

end)
end
------------------------------------------------------------------------
function ganger_dom:AlarmEnd(state)
GANGSAFE(function()

	--log("AlarmEnd")
    gtools:PlaySoundOnPlayer( "ganger/effects/redalert" )

end)
end
------------------------------------------------------------------------
-- Endgame; displays banner and ends game
------------------------------------------------------------------------
function ganger_dom:EndgameStart(state)
GANGSAFE(function()

    local text = string.format("ASHLEY REACHED WRATH LEVEL %d", self.level)
    self:DisplayText( text )
    SoundService:Play("ganger/sound/endgame") -- can't play on player: they're dead
    --GuiService:FadeOut( 5 )
    --LogService:DebugText( 600, 350, text, "debug_white_size_38" )
    self:DisplayTimer(8, text)
    state:SetDurationLimit( 8 )

end)
end
------------------------------------------------------------------------
function ganger_dom:EndgameEnd(state)
GANGSAFE(function()

    LampService:ReportGameFailed()
	MissionService:ShowEndGameHud( 0.0, false )

	local failedAction = MissionService:GetCurrentMissionFailedAction();
	if ( failedAction ~= MFA_REMAIN ) then
		MissionService:DeactivateAllFlows()
	end

    -- local ok, err = pcall(self.oldMissionFail, self.oldDomInstance, self.oldMissionFailEvt)
    -- if not ok then log("failed to invoke old mission fail: %s", tostring(err)) end

end)
end
------------------------------------------------------------------------
-- Insert waveName into the buff list
------------------------------------------------------------------------
-- function ganger_dom:InsertBuffList( waveName )
--     table.insert( self.buffList, waveName )
-- end
------------------------------------------------------------------------
-- Increase difficulty each full waveset
------------------------------------------------------------------------
function ganger_dom:ProcessDifficultyIncrease(state)

    -- no upper limit on scaling; just go until the player fails

    self.level = self.level + 1

    self.hpEffective = 1 + self.scaling * self.level

    -- limit these to prevent wrecking CPU

    if (self.attackSize < self.maxAttackSize) then
        self.attackSize = self.attackSize * (1 + self.scaling * 2)
    end
    if (self.attackSize > self.maxAttackSize) then
        self.attackSize = self.maxAttackSize
    end

    if (self.spawnPointCount < self.maxSpawnPointCount) then
        self.spawnPointCount = self.spawnPointCount * (1 + self.scaling)
    end
    if (self.spawnPointCount > self.maxSpawnPointCount) then
        self.spawnPointCount = self.maxSpawnPointCount
    end

    log("DifficultyIncrease(): lvl=%d; hp=%.1f; #sps=%.1f; #attacks=%.1f; attacksz=%.1f",
        self.level, self.hpEffective, self.spawnPointCount, self.attackCount, self.attackSize
        )
    gwave:GrowWaveSet( self.currentWaveSet )

end
------------------------------------------------------------------------------------
-- Observe all builds; we're doing this because it's the most efficient way to 
-- keep a curated list of spawn points at least 128 away from a building
------------------------------------------------------------------------------------
function ganger_dom:OnBuildingBuild( event )
GANGSAFE(function()

    local building = event:GetEntity()
    gtools:MaybeRemoveSpawnPoints( self.admissibleInteriorSpawnPoints, building )

end)
end
------------------------------------------------------------------------
-- Display Timer
------------------------------------------------------------------------
function ganger_dom:DisplayTimer(seconds, text)
    local logic = "logic/ganger_timer.logic"

    --log("DisplayTimer(): trying timer with: " .. string.format("t: %d; value: %s; data: %s", seconds, text, tostring(self.data)))

    if not self.data then return end

    local ok, err = pcall(function()
            self.data:SetFloat("ganger_timer_time", seconds or 0)
            self.data:SetString("ganger_timer_text", text or "")
            MissionService:ActivateMissionFlow("", logic, "default", self.data)
        end)
    if not ok then
        log("#### DisplayTimer(): ActivateMissionFlow failed with err: " .. tostring(err))
    end
end
------------------------------------------------------------------------
-- Display Endgame
------------------------------------------------------------------------
function ganger_dom:DisplayText( text, time )
    time = time or 5
    local logic = "logic/ganger_text.logic"

    if not self.data then return end

    local ok, err = pcall(function()
            self.data:SetString("ganger_text_text", text)
            self.data:SetFloat("ganger_text_time", time)
            MissionService:ActivateMissionFlow("", logic, "default", self.data)
        end)
    if not ok then
        log("#### DisplayText(): ActivateMissionFlow failed with err: " .. tostring(err))
    end
end
------------------------------------------------------------------------
-- Display Text
------------------------------------------------------------------------
function ganger_dom:DisplayDialog( sound, text )
    local logic = "logic/ganger_dialog.logic"

    if not self.data then return end

    local ok, err = pcall(function()
            self.data:SetString("ganger_dialog_sound", sound)
            self.data:SetString("ganger_dialog_text", text)
            MissionService:ActivateMissionFlow("", logic, "default", self.data)
        end)
    if not ok then
        local trace = debug.traceback(err, 2)
        log("#### DisplayDialog(): ActivateMissionFlow failed with err: %s", trace)
    end
end
------------------------------------------------------------------------
return ganger_dom