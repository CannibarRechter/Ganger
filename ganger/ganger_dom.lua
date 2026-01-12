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
local gchaos = require("ganger/ganger_chaos.lua")
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
    scaling            = 0.05,
    difficultyMult     = 1,
    hpEffective        = 1,
    waveStrength       = nil,
    spawnPointCount    = 2,
    attackCount        = nil,
    attackSize         = 100,
    maxSpawnPointCount = 12,
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
        "  currentSpawnPoints:  " .. tostring( self.currentSpawnPoints ) .. "\n" ..
        "  testMode:            " .. tostring( self.testMode ) .. "\n" ..
        "  chaos:               " .. tostring( self.chaos ) .. "\n" ..
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
	self.warmupTime          = DifficultyService:GetWarmupDuration()
	self.waveTime            = DifficultyService:GetWaveIntermissionTime()
    self.currentWaveSet      = gwave:GetWaveSet()
    self.currentSpawnPoints  = nil
    
    --self.buffList = {}

    local ok = pcall(function()
        local prefs = require("ganger/ganger_prefs.lua")
        self.maxAttackSize  = prefs.maxAttackSize
        self.difficultyMult = prefs.difficultyMult
        self.scaling        = prefs.scaling
        self.silence        = prefs.silence
        self.testMode       = prefs.testMode
        self.chaos          = prefs.chaos
    end)
    if not ok then log("No prefs found.")
    else log("Prefs loaded.") end

    if self.testMode then
        self.attackCount  = math.max (1,  self.attackCount)
        self.warmupTime   = math.min (2,  self.warmupTime)
        self.waveTime     = math.min (30, self.waveTime)
    end

    -- defaults: normal = 1
    if self.waveStrength == "brutal" then
        self.hpEffective = 1.2
    elseif self.waveStrength == "hard" then
        self.hpEffective = 1.1
    elseif self.waveStrength == "easy" then
        self.hpEffective = .8
    end
    self.hpEffective = self.hpEffective * self.difficultyMult

	self:LogSettings()
end
------------------------------------------------------------------------------------
-- Sanitize Settings: called on load; ensures code changes align with old savegames
------------------------------------------------------------------------------------
function ganger_dom:SanitizeSettings()
    for k, v in pairs(settings) do
        if self[k] == nil then
            self[k] = v
        end
    end
    -- FUTURE function calls here only if needed (new vars from game data)
end

------------------------------------------------------------------------------------
-- Init dom; runs only once
------------------------------------------------------------------------------------
function ganger_dom:init()
GANGSAFE(function()

    log("--------------------------------------------------------------------------------")
    log("ganger_dom:INIT() self: %s self.data: %s", tostring(self), tostring(self.data))
    log("--------------------------------------------------------------------------------")
	-- self.marked_enemies = setmetatable({}, { __mode = "k" }) -- mode k makes the table weak; if objects in it are gc'd the entry is erased

	self:InitSettings()
    self:PatchGame()

    GANGER_INSTANCE = self

    -- if pcall(function() 
    --     RegisterGlobalEventHandler("EntityKilledEvent", function(event)
    --         self:OnEntityKilled(event)
    --     end)
    -- end) then
    --     log("OnKilledEvent handler registered")
    -- else
    --     log("OnKilledEvent handler failed registration")
    -- end

    --state machines; each loop independently

    self.actionm    = self:CreateStateMachine() -- main spawner
    self.chaosm     = self:CreateStateMachine() -- choatic events
    self.ambientm   = self:CreateStateMachine() -- ambient sounds
    self.susm       = self:CreateStateMachine() -- occasional sussurus
    self.alarmm     = self:CreateStateMachine() -- occasional alarm

    self.actionm:AddState("prep",     { enter=  "PrepStart",    exit="PrepEnd"   	}) -- breather without display on screen
    self.actionm:AddState("wait",     { enter=  "WaitStart",    exit="WaitEnd"   	}) -- display on screen with countdown
    self.actionm:AddState("action",   { enter=  "ActionStart", 
                                        -- main action here; loop is a loop over the game-provided attack count
                                        execute="ActionLoop",   interval=self.multiAttackTime,
                                        exit="ActionEnd" 	}) 

    self.chaosm:AddState("chaos",     { enter=  "ChaosStart",   exit="ChaosEnd"   	})

    self.ambientm:AddState("ambient", { enter=  "AmbientStart", exit="AmbientEnd"   }) 
    self.susm:AddState("sus",         { enter=  "SusStart",     exit="SusEnd" 	    }) 
    self.alarmm:AddState("alarm",     { enter=  "AlarmStart",   exit="AlarmEnd" 	}) 

	-- start your engines!

	--self.actionm:ChangeState("prep")
    self.ambientm:ChangeState("ambient")
    self.chaosm:ChangeState("chaos")

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
    -- RegisterGlobalEventHandler("EntityKilledEvent", function(event)
    --     self:OnEntityKilled(event) end)
    -- log("OnKilledEvent handler registered")

    GANGER_INSTANCE = self

    self:SanitizeSettings()
    self:LogSettings()
    self:PatchGame()

    -- enable changing preferences on game reload
    local ok = pcall(function()
        local prefs = require("ganger/ganger_prefs.lua")
        self.maxAttackSize  = prefs.maxAttackSize
        self.silence        = prefs.silence
        self.chaos          = prefs.chaos
    end)
    if not ok then log("No prefs found.")
    else log("Prefs loaded.") end

    -- gwave:LogWaveSet( self.currentWaveSet )

end)
end
------------------------------------------------------------------------------------
-- Patch Game: runtime patches
------------------------------------------------------------------------------------
function ganger_dom:PatchGame()
GANGSAFE(function()

    local old_mission_fail = dom_mananger.OnRespawnFailedEvent

    dom_mananger.OnRespawnFailedEvent = function(self, evt)
        log("mission fail preexecute test")
        local ok = pcall(old_mission_fail, self, evt)
        if not ok then log("failed to invoke old mission fail")
        else log("invoked old mission")
        end
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
    self.susm:ChangeState("sus")
    self.currentSpawnPoints = gspawn:PickSpawnPoints( self.spawnPointCount)

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
function ganger_dom:ActionLoop(state)
GANGSAFE(function()

    self.priorRuntime = self.recentRuntime
    self.recentRuntime = GetLogicTime()
    if not self.actionCount then self.actionCount = 1 end
    log("ActionLoop() ACTION#: %d", self.actionCount)
    gtools:PlaySoundOnPlayer( "ganger/effects/big_roar" )
    self.alarmm:ChangeState("alarm")
    gspawn:SpawnWaves( self.currentSpawnPoints, self.currentWaveSet, self.attackSize )
    self.actionCount = self.actionCount + 1
    if self.actionCount > self.attackCount then 
        state:Exit()
    end

end)
end
------------------------------------------------------------------------
function ganger_dom:ActionEnd(state)
GANGSAFE(function()

    self.actionCount = 0
    self:ProcessDifficultyIncrease()
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

    --gchaos:ChaosAggro() -- unreliable
    -- if not self.chaosCount then self.chaosCount = 0
    -- else self.chaosCount = self.chaosCount + 1 end

    local chaos_caused = gchaos:MaybeCauseChaos( 0 )

    if (chaos_caused) then
        self.lastChaosTime = GetLogicTime()
    end

    self.chaosm:ChangeState("chaos")

end)
end
------------------------------------------------------------------------
-- BUFF: Buffs various mobs based on current difficulty
-- buff won't buff the same mobs twice; this is mainly so that we
-- don't multiplicatively expload the health of static map mobs
------------------------------------------------------------------------
-- function ganger_dom:BuffStart(state)
-- GANGSAFE(function()

--     --log("BuffStart()")
--     state:SetDurationLimit( self.buffDelay )

-- end)
-- end
-- ------------------------------------------------------------------------
-- function ganger_dom:BuffEnd(state)
-- GANGSAFE(function()

--     --log("BuffEnd()")
--     -- if (self.buffList) then
--     --     while #self.buffList > 0 do
--     --         local waveName = table.remove(self.buffList, 1)
--     --         gspawn:BuffEnemiesByWaveName( waveName, self.hpEffective )
--     --     end
--     -- end

-- 	--self:BuffAllMapEnemies()
--     --self:AggroAllMapEnemies()
--     self.buffm:ChangeState("buff")

-- end)
-- end
------------------------------------------------------------------------
-- AMBIENT; gives this mod a distinct flavor with background roars
------------------------------------------------------------------------
function ganger_dom:AmbientStart(state)
GANGSAFE(function()

    --log("AmbientStart()")

    -- more lively at night
    local lightLevel = EnvironmentService:GetLightIntensity()
    local daylightFactor = math.floor( lightLevel*10 + 0.5 )

    local offset = RandInt( 1, 3 ) + daylightFactor
    state:SetDurationLimit( self.ambientDelay + offset )

end)
end
------------------------------------------------------------------------
function ganger_dom:AmbientEnd(state)
GANGSAFE(function()

	--log("AmbientEnd()")

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
    self.hpEffective = self.hpEffective * (1 + self.scaling)

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

    gwave:GrowWaveSet( self.currentWaveSet )
    log("DifficultyIncrease(): lvl=%d; hp=%.1f; #sps=%.1f; #attacks=%.1f; attacksz=%.1f",
        self.level, self.hpEffective, self.spawnPointCount, self.attackCount, self.attackSize
        )

end
------------------------------------------------------------------------------------
-- Observe all kills
------------------------------------------------------------------------------------
-- function ganger_dom:OnEntityKilled( event )
-- GANGSAFE(function()

--     local entity = nil

--     local ok, err = pcall( function() entity = event:GetEntity() end)

--     -- if not ganger_dom then
--     --     log("MaybeDelete: self NIL")
--     --     return
--     -- end
--     if not self.buffed_enemies then
--         log("OnEntityKilled: buffed enemies NIL")
--         return
--     end

--     if ok then
--         local teamStr = tostring( EntityService:GetTeam(entity))
--         --log("Entity killed:" .. string.format("entity: %d; team: %s", entity, teamStr))
--         self:MaybeDelete( entity )
--     else
--         log("event check failed:" .. tostring(err))
--     end

-- end)
-- end
------------------------------------------------------------------------------------
-- Dump count in buffed list; for debugging
------------------------------------------------------------------------------------

-- function ganger_dom:LogBuffedEnemies()
-- 	log("LogBuffedEnemies(): buffed enemies count#: " .. tostring(Size(self.buffed_enemies)) )
-- end

------------------------------------------------------------------------
-- Display Timer
------------------------------------------------------------------------

function ganger_dom:DisplayTimer(seconds, text)
    local logic = "logic/ga_timer.logic"

    --log("DisplayTimer(): trying timer with: " .. string.format("t: %d; value: %s; data: %s", seconds, text, tostring(self.data)))

    if not self.data then return end

    local ok, err = pcall(function()
            self.data:SetFloat("ga_time", seconds or 0)
            self.data:SetString("ga_text", text or "")
            MissionService:ActivateMissionFlow("", logic, "default", self.data)
        end)
    if not ok then
        log("DisplayTimer(): ActivateMissionFlow failed with err: " .. tostring(err))
    end
end

return ganger_dom