------------------------------------------------------------
-- PvPThreatMeter - Bootstrap
-- Addon table, registration helpers, event frame, debug mode
------------------------------------------------------------

local addonName, addonTable = ...

------------------------------------------------------------
-- Root Addon Table
------------------------------------------------------------
local PvPThreatMeter = {}
_G.PvPThreatMeter = PvPThreatMeter

PvPThreatMeter.name    = addonName or "PvPThreatMeter"
PvPThreatMeter.version = "1.1.0"

PvPThreatMeter.modules = {}
PvPThreatMeter.visuals = {}
PvPThreatMeter.ui      = {}

------------------------------------------------------------
-- Global Debug Simulation Toggle
------------------------------------------------------------
-- When true:
--  • Frame always shows
--  • Detection always runs
--  • NPCs count as attackers
--  • Scope is forced ON
DEBUG_MODE = false

------------------------------------------------------------
-- Print / Debug
------------------------------------------------------------
local PREFIX = "|cff00ff96PvPThreatMeter:|r "

function PvPThreatMeter:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

-- Debug printing now uses debugEvents (clean architecture)
function PvPThreatMeter:Debug(msg)
    if PvPThreatMeterDB and PvPThreatMeterDB.debugEvents then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cff999999[DEBUG]|r " .. tostring(msg))
    end
end

------------------------------------------------------------
-- Registration Helpers
------------------------------------------------------------
function PvPThreatMeter:RegisterModule(name, module)
    self.modules[name] = module
end

function PvPThreatMeter:RegisterVisual(name, visual)
    self.visuals[name] = visual
end

function PvPThreatMeter:RegisterUI(name, ui)
    self.ui[name] = ui
end

------------------------------------------------------------
-- Debug Slash Command
------------------------------------------------------------
SLASH_PTMDEBUG1 = "/ptmdebug"
SlashCmdList["PTMDEBUG"] = function()
    DEBUG_MODE = not DEBUG_MODE
    PvPThreatMeter:Print("Debug Simulation Mode: " .. tostring(DEBUG_MODE))

    -- Force meter refresh immediately
    if PvPThreatMeter.visuals["Meter"] then
        PvPThreatMeter.SafeCall(
            PvPThreatMeter.visuals["Meter"],
            "UPDATE_THREAT_DATA",
            {},
            {}
        )
    end
end

------------------------------------------------------------
-- Event Frame
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if PvPThreatMeter.Core and PvPThreatMeter.Core.OnEvent then
        PvPThreatMeter.Core:OnEvent(event, ...)
    end
end)

------------------------------------------------------------
-- End of PvPThreatMeter.lua
------------------------------------------------------------
