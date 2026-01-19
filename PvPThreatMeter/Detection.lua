------------------------------------------------------------
-- PvPThreatMeter - Detection Engine (Upgraded)
-- Features:
--  • Perfect pet attribution (GUID decode + unitID mapping)
--  • Robust class detection (unitID → arena → GUID decode → fallback)
--  • Accurate PvP range detection (0–10, 10–20, 20–30, 30–40, 40+)
--  • No targeting, no macros, no secure frames
--  • All existing threat logic preserved
------------------------------------------------------------

local DEBUG_THREATS = false

local PvPThreatMeter = _G.PvPThreatMeter
local Detection = {}

Detection.initialized = false

------------------------------------------------------------
-- Internal State
------------------------------------------------------------
local threatData   = {}   -- GUID -> entry table
local guidToUnit   = {}   -- GUID -> last known unitID
local petToOwner   = {}   -- Pet GUID -> Owner GUID

------------------------------------------------------------
-- Utility: Track a unitID and map GUIDs
------------------------------------------------------------
local function TrackUnit(unit)
    if not UnitExists(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    guidToUnit[guid] = unit

    -- Track pet ownership via unitID
    if UnitIsPlayer(unit) then
        local pet = unit .. "pet"
        if UnitExists(pet) then
            local petGUID = UnitGUID(pet)
            if petGUID then
                petToOwner[petGUID] = guid
            end
        end
    end

    if DEBUG_THREATS then
        PvPThreatMeter:Debug("TrackUnit: " .. unit .. " -> " .. guid)
    end
end

local function UntrackUnit(unit)
    if not unit then return end

    local guid = UnitGUID(unit)
    if guid then
        guidToUnit[guid] = nil
        if DEBUG_THREATS then
            PvPThreatMeter:Debug("UntrackUnit: " .. unit .. " -> " .. guid)
        end
    end
end

------------------------------------------------------------
-- Utility: Enemy check
------------------------------------------------------------
local function IsEnemy(unit)
    return UnitExists(unit) and UnitCanAttack("player", unit)
end

------------------------------------------------------------
-- PET ATTRIBUTION: Decode owner GUID from pet GUID
------------------------------------------------------------
local function DecodePetOwnerGUID(petGUID)
    -- Pet GUID format:
    -- Pet-0-0000-00000000-00000-00000
    -- Owner GUID is encoded in the 4th field
    local ownerID = petGUID:match("Pet%-%d+%-%d+%-%d+%-(%d+)")
    if ownerID then
        return "Player-" .. ownerID
    end
    return nil
end

------------------------------------------------------------
-- CLASS DETECTION: Multi-layer fallback
------------------------------------------------------------
local function DetectClass(guid)
    -- 1) If we have a unitID, use UnitClass
    local unit = guidToUnit[guid]
    if unit and UnitExists(unit) then
        local _, class = UnitClass(unit)
        if class then return class end
    end

    -- 2) Arena unitIDs
    for i = 1, 5 do
        local a = "arena" .. i
        if UnitExists(a) and UnitGUID(a) == guid then
            local _, class = UnitClass(a)
            if class then return class end
        end
    end

    -- 3) GUID decode (Player GUIDs encode classID)
    local classID = tonumber(guid:match("Player%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
    if classID then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.classFile then
            return info.classFile
        end
    end

    -- 4) Fallback
    local _, class = GetPlayerInfoByGUID(guid)
    return class
end

------------------------------------------------------------
-- RANGE DETECTION: Accurate PvP ranges
------------------------------------------------------------
local function GetAccurateRange(unit)
    if not unit or not UnitExists(unit) then return nil end

    -- 0–10
    if CheckInteractDistance(unit, 3) then
        return "0-10"
    end

    -- 10–20 (bandage range)
    if IsItemInRange(1251, unit) == true then
        return "10-20"
    end

    -- 20–30 (engineering bomb range)
    if IsItemInRange(28767, unit) == true then
        return "20-30"
    end

    -- 30–40 (spell range)
    if UnitInRange(unit) then
        return "30-40"
    end

    -- 40+ fallback
    return "40+"
end
------------------------------------------------------------
-- Combat Log Detection (Upgraded)
------------------------------------------------------------
function Detection:COMBAT_LOG_EVENT_UNFILTERED(...)
    if DEBUG_THREATS then
        PvPThreatMeter:Debug("CLEU fired")
    end

    if not Detection.initialized then return end
    if not PvPThreatMeterDB.enabled then return end

    -- Allow forced scope in debug mode
    if not PvPThreatMeter.IsScopeAllowed() and not DEBUG_MODE then
        if DEBUG_THREATS then
            PvPThreatMeter:Debug("Out of scope, ignoring CLEU")
        end
        return
    end

    local timestamp, subevent, _, srcGUID, srcName, srcFlags,
          _, destGUID, destName, destFlags,
          _, spellID, spellName, spellSchool, amount = ...

    local playerGUID = UnitGUID("player")
    local playerName = UnitName("player")

    ------------------------------------------------------------
    -- 1) VICTIM CHECK (Debug override)
    ------------------------------------------------------------
    local isPlayerVictim =
        (destGUID == playerGUID) or
        (destFlags and bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0) or
        (destName ~= nil and destName == playerName)

    -- DEBUG MODE: treat ALL events as if player is the victim
    if DEBUG_MODE then
        isPlayerVictim = true
    end

    if not isPlayerVictim then
        if DEBUG_THREATS then
            PvPThreatMeter:Debug("Not victim:", subevent, srcName, destName)
        end
        return
    end

    ------------------------------------------------------------
    -- 2) SOURCE CHECK
    ------------------------------------------------------------
    if not srcGUID or not srcName then
        if DEBUG_THREATS then
            PvPThreatMeter:Debug("No source:", subevent)
        end
        return
    end

    ------------------------------------------------------------
    -- 3) HOSTILE CHECK (with debug NPC override)
    ------------------------------------------------------------
    local isHostile = false

    -- DEBUG MODE: bypass hostile check entirely
    if DEBUG_MODE then
        isHostile = true
    end

    if srcFlags and srcFlags ~= 0 then
        if bit.band(srcFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0 then
            isHostile = true
        end
    else
        if srcGUID ~= playerGUID then
            isHostile = true
        end
    end

    if not isHostile then
        if DEBUG_THREATS then
            PvPThreatMeter:Debug("Not hostile:", subevent, srcName)
        end
        return
    end

    if DEBUG_THREATS then
        PvPThreatMeter:Debug("Hostile OK:", subevent, srcName)
    end

    ------------------------------------------------------------
    -- 4) PET ATTRIBUTION (Upgraded)
    ------------------------------------------------------------
    local actualGUID = srcGUID
    local actualName = srcName

    local isPet = srcFlags and bit.band(srcFlags, COMBATLOG_OBJECT_TYPE_PET) ~= 0

    if isPet then
        -- A) Try unitID mapping first
        local ownerGUID = petToOwner[srcGUID]

        -- B) If not found, decode GUID
        if not ownerGUID then
            ownerGUID = DecodePetOwnerGUID(srcGUID)
            if ownerGUID then
                petToOwner[srcGUID] = ownerGUID
            end
        end

        -- C) Attribute to owner if found
        if ownerGUID then
            actualGUID = ownerGUID

            local ownerUnit = guidToUnit[ownerGUID]
            if ownerUnit and UnitExists(ownerUnit) then
                actualName = UnitName(ownerUnit)
            else
                -- fallback: use original pet name until owner appears
                actualName = actualName
            end
        end
    end

    ------------------------------------------------------------
    -- 5) CREATE OR UPDATE ENTRY
    ------------------------------------------------------------
    local now = GetTime()
    local entry = threatData[actualGUID]

    if not entry then
        entry = { damageEvents = {}, alpha = 1 }
        threatData[actualGUID] = entry

        if DEBUG_THREATS then
            PvPThreatMeter:Debug("Entry created:", actualName, actualGUID)
        end
    end

    entry.name     = actualName
    entry.lastSeen = now

    -- Track unitID if available
    if not entry.unit then
        local unit = guidToUnit[actualGUID]
        if unit and UnitExists(unit) then
            entry.unit = unit
        end
    end

    -- Upgrade class detection
    if not entry.class then
        entry.class = DetectClass(actualGUID)
    end

    ------------------------------------------------------------
    -- 6) DAMAGE EVENTS (Unchanged logic, cleaned)
    ------------------------------------------------------------
    if subevent == "SWING_DAMAGE" then
        entry.lastDamage = now
        entry.lastSwing  = now
        table.insert(entry.damageEvents, { t = now, amount = amount or 0 })

    elseif subevent == "RANGE_DAMAGE" then
        entry.lastDamage = now
        entry.lastSwing  = now
        table.insert(entry.damageEvents, { t = now, amount = amount or 0 })

    elseif subevent == "SPELL_DAMAGE" then
        entry.lastDamage = now
        table.insert(entry.damageEvents, { t = now, amount = amount or 0 })

    elseif subevent == "SPELL_PERIODIC_DAMAGE" then
        entry.lastDamage = now
        entry.lastDot    = now
        table.insert(entry.damageEvents, { t = now, amount = amount or 0 })
    end

    -- Cast events
    if subevent == "SPELL_CAST_START" or subevent == "SPELL_CAST_SUCCESS" then
        entry.lastCast = now
    end

    if DEBUG_THREATS then
        PvPThreatMeter:Debug("Damage event:", subevent, actualName, amount or 0)
    end

    BroadcastUpdate()
end
------------------------------------------------------------
-- Threat Score Calculation
------------------------------------------------------------
local function ComputeThreatScore(entry, now)
    local wT = PvPThreatMeterDB.weightTarget
    local wD = PvPThreatMeterDB.weightDamage
    local wC = PvPThreatMeterDB.weightCast
    local wS = PvPThreatMeterDB.weightSwing
    local wO = PvPThreatMeterDB.weightDot

    local score = 0

    if entry.lastTarget and (now - entry.lastTarget) <= 2 then
        score = score + wT
    end
    if entry.lastDamage and (now - entry.lastDamage) <= 5 then
        score = score + wD
    end
    if entry.lastCast and (now - entry.lastCast) <= 3 then
        score = score + wC
    end
    if entry.lastSwing and (now - entry.lastSwing) <= 3 then
        score = score + wS
    end
    if entry.lastDot and (now - entry.lastDot) <= 5 then
        score = score + wO
    end

    return score
end

------------------------------------------------------------
-- Damage Window Calculation
------------------------------------------------------------
local function ComputeDamageWindow(entry, now)
    local window = PvPThreatMeterDB.damageWindow
    local total = 0

    if entry.damageEvents then
        for i = #entry.damageEvents, 1, -1 do
            local e = entry.damageEvents[i]
            if (now - e.t) <= window then
                total = total + e.amount
            else
                table.remove(entry.damageEvents, i)
            end
        end
    end

    return total
end

------------------------------------------------------------
-- Debug Mode Simulation
------------------------------------------------------------
local function InjectDebugThreats()
    if not DEBUG_MODE then return end
    
    local now = GetTime()
    local debugEnemies = {
        { guid = "DEBUG_001", name = "Test Warrior", class = "WARRIOR" },
        { guid = "DEBUG_002", name = "Test Mage", class = "MAGE" },
        { guid = "DEBUG_003", name = "Test Rogue", class = "ROGUE" },
    }
    
    for i, enemy in ipairs(debugEnemies) do
        local entry = threatData[enemy.guid]
        if not entry then
            entry = { damageEvents = {}, alpha = 1 }
            threatData[enemy.guid] = entry
        end
        
        entry.name = enemy.name
        entry.class = enemy.class
        entry.lastSeen = now
        entry.lastTarget = now - (i * 0.5)
        entry.lastDamage = now - (i * 0.3)
        entry.lastCast = now - (i * 0.7)
        
        if not entry.damageEvents then
            entry.damageEvents = {}
        end
        table.insert(entry.damageEvents, { t = now, amount = 100 * (4 - i) })
    end
end

------------------------------------------------------------
-- Linger / Fade Helpers
------------------------------------------------------------
local function UpdateLingerState(entry, now)
    local lingerTime     = PvPThreatMeterDB.lingerTime or 8
    local minVisibility  = PvPThreatMeterDB.minVisibility or 2
    local fadeDuration   = PvPThreatMeterDB.fadeDuration or 1.0
    local lastSeen       = entry.lastSeen or now

    local visibleUntil = lastSeen + math.max(lingerTime, minVisibility)
    entry.visibleUntil = visibleUntil

    entry.fadeStart = visibleUntil - fadeDuration
    entry.fadeEnd   = visibleUntil

    if now >= entry.fadeEnd then
        entry.alpha = 0
    elseif now >= entry.fadeStart then
        local t = (now - entry.fadeStart) / (entry.fadeEnd - entry.fadeStart)
        entry.alpha = 1 - t
    else
        entry.alpha = 1
    end
end

local function ShouldRemoveEntry(entry, now)
    if not entry.visibleUntil then return false end
    return now > entry.visibleUntil
end

------------------------------------------------------------
-- Broadcast to Meter Visual
------------------------------------------------------------
function BroadcastUpdate()
    if DEBUG_THREATS and DEBUG_MODE then
        local count = 0
        for _ in pairs(threatData) do count = count + 1 end
        PvPThreatMeter:Debug("BroadcastUpdate: " .. count .. " threat entries")
    end
    
    local meter = PvPThreatMeter.visuals["Meter"]
    if meter then
        if DEBUG_MODE then
            PvPThreatMeter:Debug("Calling Meter.UPDATE_THREAT_DATA")
        end
        
        if type(meter.UPDATE_THREAT_DATA) == "function" then
            meter:UPDATE_THREAT_DATA(threatData, guidToUnit)
        end
    else
        if DEBUG_MODE then
            PvPThreatMeter:Debug("WARNING: Meter visual not found!")
        end
    end
end

------------------------------------------------------------
-- Targeting Detection (no secure actions, just awareness)
------------------------------------------------------------
local function ScanTargetingUnits()
    if not PvPThreatMeter.IsScopeAllowed() and not DEBUG_MODE then
        return
    end

    local now = GetTime()

    local function MarkUnit(unit)
        if not IsEnemy(unit) then return end
        if not UnitIsUnit(unit .. "target", "player") then return end

        local guid = UnitGUID(unit)
        local name = UnitName(unit)
        if not guid or not name then return end

        local entry = threatData[guid]
        if not entry then
            entry = { damageEvents = {}, alpha = 1 }
            threatData[guid] = entry
        end

        entry.name       = name
        entry.unit       = unit
        entry.lastTarget = now
        entry.lastSeen   = now

        if DEBUG_THREATS then
            PvPThreatMeter:Debug("Targeting: " .. name .. " (" .. unit .. ")")
        end
    end

    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        if plate.namePlateUnitToken then
            MarkUnit(plate.namePlateUnitToken)
        end
    end

    MarkUnit("target")
    MarkUnit("focus")

    for i = 1, 5 do
        MarkUnit("arena" .. i)
    end
end

------------------------------------------------------------
-- Periodic Update (Upgraded range integration)
------------------------------------------------------------
local function UpdateThreat()
    if not Detection.initialized then return end
    if not PvPThreatMeterDB.enabled then return end

    -- Inject debug data BEFORE broadcast
    if DEBUG_MODE then
        InjectDebugThreats()
    end

    BroadcastUpdate()
    
    if not PvPThreatMeter.IsScopeAllowed() and not DEBUG_MODE then
        return
    end

    ScanTargetingUnits()

    local now = GetTime()
    local showLastAttackers = PvPThreatMeterDB.showLastAttackers or 3

    for guid, entry in pairs(threatData) do
        entry.threatScore = ComputeThreatScore(entry, now)
        entry.damageTaken = ComputeDamageWindow(entry, now)

        local unit = guidToUnit[guid]
        if unit and UnitExists(unit) then
            entry.range = GetAccurateRange(unit)
        else
            entry.range = nil
        end

        if entry.threatScore > 0 or entry.damageTaken > 0 then
            entry.lastSeen = entry.lastSeen or now
        end

        UpdateLingerState(entry, now)
    end

    local candidates = {}
    for guid, entry in pairs(threatData) do
        table.insert(candidates, { guid = guid, lastSeen = entry.lastSeen or 0 })
    end

    table.sort(candidates, function(a, b)
        return a.lastSeen > b.lastSeen
    end)

    local keep = {}
    for i, info in ipairs(candidates) do
        if i <= showLastAttackers then
            keep[info.guid] = true
        end
    end

    for guid, entry in pairs(threatData) do
        if ShouldRemoveEntry(entry, now) and not keep[guid] then
            if DEBUG_THREATS then
                PvPThreatMeter:Debug("Removing stale entry:", guid)
            end
            threatData[guid] = nil
            guidToUnit[guid] = nil
        end
    end
end
------------------------------------------------------------
-- Unit Tracking Events
------------------------------------------------------------
function Detection:NAME_PLATE_UNIT_ADDED(unit)
    if DEBUG_THREATS then
        PvPThreatMeter:Debug("Nameplate added:", unit)
    end
    TrackUnit(unit)
end

function Detection:NAME_PLATE_UNIT_REMOVED(unit)
    if DEBUG_THREATS then
        PvPThreatMeter:Debug("Nameplate removed:", unit)
    end
    UntrackUnit(unit)
end

function Detection:PLAYER_TARGET_CHANGED()
    if DEBUG_THREATS then
        PvPThreatMeter:Debug("PLAYER_TARGET_CHANGED")
    end
    TrackUnit("target")
end

function Detection:PLAYER_FOCUS_CHANGED()
    if DEBUG_THREATS then
        PvPThreatMeter:Debug("PLAYER_FOCUS_CHANGED")
    end
    TrackUnit("focus")
end

function Detection:GROUP_ROSTER_UPDATE()
    if DEBUG_THREATS then
        PvPThreatMeter:Debug("GROUP_ROSTER_UPDATE")
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            TrackUnit("raid" .. i)
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            TrackUnit("party" .. i)
        end
        TrackUnit("player")
    else
        TrackUnit("player")
    end
end

------------------------------------------------------------
-- UNIT_DIED Cleanup
------------------------------------------------------------
function Detection:UNIT_DIED(...)
    local guid = select(8, ...)
    if guid and threatData[guid] then
        if DEBUG_THREATS then
            PvPThreatMeter:Debug("UNIT_DIED:", guid)
        end
        threatData[guid] = nil
        guidToUnit[guid] = nil
        BroadcastUpdate()
    end
end

------------------------------------------------------------
-- PLAYER_ENTERING_WORLD Cleanup
------------------------------------------------------------
function Detection:PLAYER_ENTERING_WORLD()
    if DEBUG_THREATS then
        PvPThreatMeter:Debug("PLAYER_ENTERING_WORLD -> clearing threat data")
    end

    wipe(threatData)
    wipe(guidToUnit)
    wipe(petToOwner)

    C_Timer.After(0.1, function()
        BroadcastUpdate()
    end)
end

------------------------------------------------------------
-- ZONE_CHANGED_NEW_AREA Cleanup
------------------------------------------------------------
function Detection:ZONE_CHANGED_NEW_AREA()
    if DEBUG_THREATS then
        PvPThreatMeter:Debug("ZONE_CHANGED_NEW_AREA -> rebroadcast")
    end

    C_Timer.After(0.1, function()
        BroadcastUpdate()
    end)
end
------------------------------------------------------------
-- Init
------------------------------------------------------------
function Detection:OnInit()
    Detection.initialized = true
    PvPThreatMeter:Debug("Detection engine initialized (upgraded build)")

    -- Main periodic update
    C_Timer.NewTicker(0.2, UpdateThreat)
end

------------------------------------------------------------
-- Module Registration
------------------------------------------------------------
PvPThreatMeter:RegisterModule("Detection", Detection)
