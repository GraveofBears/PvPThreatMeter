------------------------------------------------------------
-- PvPThreatMeter - Core (Debug-Clean Architecture)
-- Database defaults, scope logic, initialization, dispatch
------------------------------------------------------------

local PvPThreatMeter = _G.PvPThreatMeter

------------------------------------------------------------
-- Core Object
------------------------------------------------------------
PvPThreatMeter.Core = PvPThreatMeter.Core or {}
local Core = PvPThreatMeter.Core

------------------------------------------------------------
-- Database Defaults
------------------------------------------------------------
local DB_DEFAULTS = {
    enabled        = true,

    --------------------------------------------------------
    -- Debug Flags
    --------------------------------------------------------
    debugEvents    = false,

    --------------------------------------------------------
    -- PvP Scope
    --------------------------------------------------------
    scopeBG        = true,
    scopeArena     = true,
    scopeWorld     = false,

    --------------------------------------------------------
    -- Meter Mode
    --------------------------------------------------------
    mode           = "threat",

    --------------------------------------------------------
    -- Visual Settings (modern defaults)
    --------------------------------------------------------
    maxRows           = 5,      -- more useful default for PvP
    maxBarWidth       = 500,    -- wider bars for modern UI scaling
    valueOffset       = -35,    -- better alignment with larger fonts
    backgroundAlpha   = 0.90,   -- slightly more solid, still elegant

    barHeight         = 26,     -- ideal row height for readability
    nameTextSize      = 15,     -- perfect balance for PvP readability
    rowSpacing        = 3,      -- slightly more breathing room
    iconSize          = 20,     -- matches 26px bar height nicely

    --------------------------------------------------------
    -- Damage Mode
    --------------------------------------------------------
    damageWindow   = 5,

    --------------------------------------------------------
    -- Threat Weights
    --------------------------------------------------------
    weightTarget   = 3,
    weightDamage   = 5,
    weightCast     = 4,
    weightSwing    = 2,
    weightDot      = 1,

    --------------------------------------------------------
    -- Linger System
    --------------------------------------------------------
    lingerTime        = 8,
    minVisibility     = 2,
    fadeDuration      = 1.0,
    showLastAttackers = 3,
    stickyTopThreat   = false,

    --------------------------------------------------------
    -- Meter Position
    --------------------------------------------------------
    meterPos       = nil,
}

PvPThreatMeter.DB_DEFAULTS = DB_DEFAULTS

------------------------------------------------------------
-- Initialize Database (Graceful Merge)
------------------------------------------------------------
local function InitializeDatabase()
    if not PvPThreatMeterDB then
        PvPThreatMeterDB = {}
    end

    for key, defaultValue in pairs(DB_DEFAULTS) do
        if PvPThreatMeterDB[key] == nil then
            PvPThreatMeterDB[key] = defaultValue
        end
    end
end

------------------------------------------------------------
-- Debug Printing (clean)
------------------------------------------------------------
function PvPThreatMeter:Debug(msg)
    if PvPThreatMeterDB and PvPThreatMeterDB.debugEvents then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96PvPThreatMeter:|r |cff999999[DEBUG]|r " .. tostring(msg))
    end
end

function PvPThreatMeter:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96PvPThreatMeter:|r " .. tostring(msg))
end

------------------------------------------------------------
-- PvP Scope Logic
------------------------------------------------------------
local function IsScopeAllowed()
    local inInstance, instanceType = IsInInstance()

    if instanceType == "pvp"   and PvPThreatMeterDB.scopeBG    then return true end
    if instanceType == "arena" and PvPThreatMeterDB.scopeArena then return true end
    if not inInstance          and PvPThreatMeterDB.scopeWorld then return true end

    return false
end

PvPThreatMeter.IsScopeAllowed = IsScopeAllowed

------------------------------------------------------------
-- SafeCall Wrapper
------------------------------------------------------------
local function SafeCall(target, methodName, ...)
    local fn = target[methodName]
    if type(fn) ~= "function" then return end

    if PvPThreatMeterDB.debugEvents then
        PvPThreatMeter:Debug("Event -> " .. methodName)
    end

    local ok, err = pcall(fn, target, ...)
    if not ok then
        PvPThreatMeter:Print("Error in " .. methodName .. ": " .. tostring(err))
    end
end

PvPThreatMeter.SafeCall = SafeCall

------------------------------------------------------------
-- Event Dispatch
------------------------------------------------------------
local modules  = PvPThreatMeter.modules
local visuals  = PvPThreatMeter.visuals
local uiPanels = PvPThreatMeter.ui

local function DispatchEvent(event, ...)
    for _, module in pairs(modules) do
        SafeCall(module, event, ...)
    end
    for _, visual in pairs(visuals) do
        SafeCall(visual, event, ...)
    end
    for _, ui in pairs(uiPanels) do
        SafeCall(ui, event, ...)
    end
end

------------------------------------------------------------
-- Initialization Fan-Out
------------------------------------------------------------
local function InitAll()
    PvPThreatMeter:Debug("InitAll starting")

    for name, module in pairs(modules) do
        if type(module.OnInit) == "function" then
            SafeCall(module, "OnInit")
        end
    end

    for name, visual in pairs(visuals) do
        if type(visual.OnInit) == "function" then
            SafeCall(visual, "OnInit")
        end
    end

    for name, ui in pairs(uiPanels) do
        if type(ui.OnInit) == "function" then
            SafeCall(ui, "OnInit")
        end
    end

    PvPThreatMeter:Debug("InitAll complete")
end

------------------------------------------------------------
-- ADDON_LOADED Entry Point
------------------------------------------------------------
function Core:ADDON_LOADED(addonName)
    if addonName ~= PvPThreatMeter.name then return end

    InitializeDatabase()
    InitAll()

    -- Force meter to update immediately on load
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
-- Central Event Router
------------------------------------------------------------
function Core:OnEvent(event, ...)
    --------------------------------------------------------
    -- ADDON_LOADED
    --------------------------------------------------------
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == PvPThreatMeter.name then
            Core:ADDON_LOADED(addonName)
        end
        return
    end

    --------------------------------------------------------
    -- Zone / World Events
    -- These require a forced meter refresh so the UI updates
    -- even when no threat data exists (debug mode, empty state)
    --------------------------------------------------------
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        DispatchEvent(event, ...)

        -- Force meter to update visibility
        if PvPThreatMeter.visuals["Meter"] then
            PvPThreatMeter.SafeCall(
                PvPThreatMeter.visuals["Meter"],
                "UPDATE_THREAT_DATA",
                {},
                {}
            )
        end

        return
    end

    --------------------------------------------------------
    -- Combat Log
    --------------------------------------------------------
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		DispatchEvent("COMBAT_LOG_EVENT_UNFILTERED", CombatLogGetCurrentEventInfo())
		return
	end

    --------------------------------------------------------
    -- All Other Events
    --------------------------------------------------------
    DispatchEvent(event, ...)
end

------------------------------------------------------------
-- End of Core.lua
------------------------------------------------------------
