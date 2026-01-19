------------------------------------------------------------
-- PvPThreatMeter - Lightweight Visual Meter
-- Pure awareness: no targeting, no macros, no secure frames.
------------------------------------------------------------

local PvPThreatMeter = _G.PvPThreatMeter
local Meter = {}

local frame
local rows = {}
local TOTAL_ROWS = 40
Meter.initialized = false

------------------------------------------------------------
-- Refresh Helper
------------------------------------------------------------
function Meter:Refresh()
    if not Meter.initialized then return end

    -- Prevent double rebuilds
    Meter.initialized = false

    -- Rebuild once
    Meter:OnInit()

    -- Restore anchor mode state cleanly
    if PvPThreatMeter.unlockMode then
        Meter:ANCHOR_MODE(true)
    end
end

------------------------------------------------------------
-- Class Icon Paths
------------------------------------------------------------
local CLASS_ICONS = {
    WARRIOR     = "Interface\\Icons\\ClassIcon_Warrior",
    PALADIN     = "Interface\\Icons\\ClassIcon_Paladin",
    HUNTER      = "Interface\\Icons\\ClassIcon_Hunter",
    ROGUE       = "Interface\\Icons\\ClassIcon_Rogue",
    PRIEST      = "Interface\\Icons\\ClassIcon_Priest",
    DEATHKNIGHT = "Interface\\Icons\\ClassIcon_DeathKnight",
    SHAMAN      = "Interface\\Icons\\ClassIcon_Shaman",
    MAGE        = "Interface\\Icons\\ClassIcon_Mage",
    WARLOCK     = "Interface\\Icons\\ClassIcon_Warlock",
    MONK        = "Interface\\Icons\\ClassIcon_Monk",
    DRUID       = "Interface\\Icons\\ClassIcon_Druid",
    DEMONHUNTER = "Interface\\Icons\\ClassIcon_DemonHunter",
    EVOKER      = "Interface\\Icons\\ClassIcon_Evoker",
}

------------------------------------------------------------
-- Position Save/Load
------------------------------------------------------------
local function LoadPosition(f)
    if PvPThreatMeterDB and PvPThreatMeterDB.meterPos then
        local pos = PvPThreatMeterDB.meterPos
        f:ClearAllPoints()
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

local function SavePosition(f)
    local point, _, relPoint, x, y = f:GetPoint()
    PvPThreatMeterDB.meterPos = {
        point    = point,
        relPoint = relPoint,
        x        = x,
        y        = y,
    }
end

------------------------------------------------------------
-- Utility
------------------------------------------------------------
local function GetClassColorRGB(class)
    local c = class and RAID_CLASS_COLORS[class]
    return c and c.r or 1, c and c.g or 1, c and c.b or 1
end

local function HideAllRows()
    for _, row in ipairs(rows) do
        row:Hide()
    end
end

local function UpdateScrollBar()
    if not frame or not frame.scrollFrame then return end

    local scrollFrame = frame.scrollFrame
    local child = scrollFrame:GetScrollChild()
    if not child then return end

    local contentHeight = child:GetHeight()
    local frameHeight = scrollFrame:GetHeight()

    if contentHeight > frameHeight then
        scrollFrame.ScrollBar:Show()
    else
        scrollFrame.ScrollBar:Hide()
        scrollFrame:SetVerticalScroll(0)
    end

    scrollFrame.ScrollBar:SetFrameLevel(frame:GetFrameLevel() + 10)
end

local function ResizeListContent()
    if not frame or not frame.listContent then return end

    local h       = PvPThreatMeterDB.barHeight or 24
    local spacing = PvPThreatMeterDB.rowSpacing or 2

    frame.listContent:SetHeight(TOTAL_ROWS * (h + spacing))
    C_Timer.After(0, UpdateScrollBar)
end

------------------------------------------------------------
-- Empty State Message
------------------------------------------------------------
local function GetEmptyStateMessage()
    return "No Threats Detected"
end

------------------------------------------------------------
-- Threat Bar Color Gradient
------------------------------------------------------------
local function GetThreatBarColor(percent)
    if percent > 0.66 then
        local t = (percent - 0.66) / 0.34
        return 1, 0.4 * (1 - t), 0
    elseif percent > 0.33 then
        local t = (percent - 0.33) / 0.33
        return 1, 0.4 + (0.45 * (1 - t)), 0
    else
        local t = percent / 0.33
        return 1, 0.85 + (0.15 * (1 - t)), 0.3 * (1 - t)
    end
end

------------------------------------------------------------
-- Threat Text Color Gradient
------------------------------------------------------------
local function GetThreatTextColor(percent)
    if percent >= 0.85 then
        return 1, 0.1, 0.1
    elseif percent >= 0.6 then
        local t = (percent - 0.6) / 0.25
        return 1, 0.5 - (0.3 * t), 0.1
    elseif percent >= 0.35 then
        local t = (percent - 0.35) / 0.25
        return 0.2 + (0.8 * t), 1, 0.2
    else
        return 0.2, 1, 1
    end
end

------------------------------------------------------------
-- Core Update Logic
------------------------------------------------------------
function Meter:UPDATE_THREAT_DATA(threatData, guidToUnit)
    if not Meter.initialized then return end

    if DEBUG_MODE then
        frame:Show()
    end

    if not PvPThreatMeterDB.enabled then
        frame:Hide()
        HideAllRows()
        return
    end

    local h        = PvPThreatMeterDB.barHeight or 24
    local spacing  = PvPThreatMeterDB.rowSpacing or 2
    local textSize = PvPThreatMeterDB.nameTextSize or 14
    local iconSize = PvPThreatMeterDB.iconSize or 18

    --------------------------------------------------------
    -- Anchor Mode (dummy rows)
    --------------------------------------------------------
    if PvPThreatMeter.unlockMode then
        frame:Show()
        frame.anchor:Show()

        for i = 1, PvPThreatMeterDB.maxRows do
            local row = rows[i]
            if row then
                row:SetHeight(h)
                row:SetPoint("TOPLEFT", 0, -((i - 1) * (h + spacing)))
                row.threatBar:SetHeight(h - 2)

                row.text:SetFont("Fonts\\FRIZQT__.TTF", textSize, "")
                row.value:SetFont("Fonts\\FRIZQT__.TTF", textSize, "")

                row.classIcon:SetSize(iconSize, iconSize)
                row.classIcon:SetTexture(CLASS_ICONS.WARRIOR)
                row.classIcon:Show()

                row.text:SetText("Threat Slot " .. i)
                row.text:SetTextColor(1, 1, 1)

                local dummy = 50 - ((i - 1) * 10)
                row.value:SetText(dummy)
                row.value:SetTextColor(0, 1, 1)

                row.value:ClearAllPoints()
                row.value:SetPoint("RIGHT", PvPThreatMeterDB.valueOffset or 0, 0)

                local barPercent = 1 - ((i - 1) * 0.18)
				local maxBar = PvPThreatMeterDB.maxBarWidth or 140
				local barWidth = maxBar * barPercent

                row.threatBar:SetWidth(math.max(1, barWidth))
                row.threatBar:SetColorTexture(GetThreatBarColor(barPercent))
                row.threatBar:Show()

                row:SetAlpha(1)
                row:Show()
            end
        end

        return
    end

    frame.anchor:Hide()

    --------------------------------------------------------
    -- Build sortable list
    --------------------------------------------------------
    local list = {}
    local now = GetTime()

    for guid, entry in pairs(threatData) do
        if entry.alpha and entry.alpha > 0 then
            local unit = guidToUnit[guid]
            local name = entry.name or "Unknown"

            local hpPct
            if unit and UnitExists(unit) then
                local hp = UnitHealth(unit)
                local maxHp = UnitHealthMax(unit)
                if maxHp and maxHp > 0 then
                    hpPct = (hp / maxHp) * 100
                end
            end

            table.insert(list, {
                guid        = guid,
                rawName     = name,
                class       = entry.class,
                unit        = unit,
                hpPct       = hpPct,
                range       = entry.range,
                threatScore = entry.threatScore or 0,
                damageTaken = entry.damageTaken or 0,
                alpha       = entry.alpha,
                lastSeen    = entry.lastSeen or now,
            })
        end
    end

    --------------------------------------------------------
    -- Sorting
    --------------------------------------------------------
    local mode = PvPThreatMeterDB.mode or "threat"
    local stickyTop = PvPThreatMeterDB.stickyTopThreat

    table.sort(list, function(a, b)
        local av = (mode == "damage") and a.damageTaken or a.threatScore
        local bv = (mode == "damage") and b.damageTaken or b.threatScore
        if av ~= bv then return av > bv end
        return a.lastSeen > b.lastSeen
    end)

    if stickyTop and Meter.lastTopGUID then
        for i, data in ipairs(list) do
            if data.guid == Meter.lastTopGUID and i > 1 then
                table.remove(list, i)
                table.insert(list, 1, data)
                break
            end
        end
    end

    Meter.lastTopGUID = list[1] and list[1].guid or nil

    --------------------------------------------------------
    -- Display rows
    --------------------------------------------------------
    if #list == 0 then
        HideAllRows()

        if DEBUG_MODE or PvPThreatMeter.unlockMode or PvPThreatMeter.IsScopeAllowed() then
            frame:Show()
            local row = rows[1]
            if row then
                row.classIcon:Hide()
                row.text:SetText(GetEmptyStateMessage())
                row.text:SetTextColor(0.6, 0.6, 0.6)
                row.value:SetText("")
                row.threatBar:Hide()
                row:SetAlpha(0.7)
                row:Show()
            end
        else
            frame:Hide()
        end

        return
    end

    frame:Show()

    local topValue = (mode == "damage") and list[1].damageTaken or list[1].threatScore
    if topValue == 0 then topValue = 1 end

    for i = 1, PvPThreatMeterDB.maxRows do
        local row = rows[i]
        local data = list[i]

        if row and data then
            row:SetHeight(h)
            row:SetPoint("TOPLEFT", 0, -((i - 1) * (h + spacing)))
            row.threatBar:SetHeight(h - 2)

            row.text:SetFont("Fonts\\FRIZQT__.TTF", textSize, "")
            row.value:SetFont("Fonts\\FRIZQT__.TTF", textSize, "")

            row.classIcon:SetSize(iconSize, iconSize)

            ------------------------------------------------
            -- CLASS ICON
            ------------------------------------------------
            if data.class and CLASS_ICONS[data.class] then
                row.classIcon:SetTexture(CLASS_ICONS[data.class])
                row.classIcon:Show()
            else
                row.classIcon:Hide()
            end

            ------------------------------------------------
            -- DISPLAY NAME
            ------------------------------------------------
            local displayName = data.rawName
            local extras = {}

            if data.hpPct then table.insert(extras, string.format("%.0f%%", data.hpPct)) end
            if data.range then table.insert(extras, data.range) end

            if #extras > 0 then
                displayName = displayName .. " (" .. table.concat(extras, " | ") .. ")"
            end

            row.text:SetText(displayName)

            ------------------------------------------------
            -- VALUE TEXT
            ------------------------------------------------
            row.value:ClearAllPoints()
            row.value:SetPoint("RIGHT", PvPThreatMeterDB.valueOffset or 0, 0)

            local currentValue = (mode == "damage") and data.damageTaken or data.threatScore
            local percent = currentValue / topValue

            if mode == "damage" then
                row.value:SetText(math.floor(currentValue))
                row.value:SetTextColor(1, 0.85, 0)
                local r, g, b = GetClassColorRGB(data.class)
                row.text:SetTextColor(r, g, b)
            else
                local tr, tg, tb = GetThreatTextColor(percent)
                row.value:SetText(currentValue)
                row.value:SetTextColor(tr, tg, tb)
                row.text:SetTextColor(tr, tg, tb)
            end

            ------------------------------------------------
            -- THREAT BAR
            ------------------------------------------------
			local barPercent = 1 - ((i - 1) * 0.18)
			local available  = row:GetWidth() - 30
			local maxBar     = PvPThreatMeterDB.maxBarWidth or 140
			local barWidth   = math.min(available * barPercent, maxBar)

            row.threatBar:SetWidth(math.max(1, barWidth))
            row.threatBar:SetColorTexture(GetThreatBarColor(percent))
            row.threatBar:Show()

            ------------------------------------------------
            -- FINALIZE ROW
            ------------------------------------------------
            row:SetAlpha(data.alpha or 1)
            row:Show()

        elseif row then
            row:Hide()
        end
    end
end

------------------------------------------------------------
-- Anchor Mode Handler
------------------------------------------------------------
function Meter:ANCHOR_MODE(mode)
    if not Meter.initialized then return end

    local h        = PvPThreatMeterDB.barHeight or 24
    local spacing  = PvPThreatMeterDB.rowSpacing or 2
    local textSize = PvPThreatMeterDB.nameTextSize or 14
    local iconSize = PvPThreatMeterDB.iconSize or 18

    if mode then
        frame:Show()
        frame.anchor:Show()
        frame.resizeGrip:Show()

        frame.anchor:SetBackdropColor(
            0, 0.4, 1,
            PvPThreatMeterDB.backgroundAlpha or 0.85
        )

        ----------------------------------------------------
        -- Dummy rows for anchor mode
        ----------------------------------------------------
        for i = 1, PvPThreatMeterDB.maxRows do
            local row = rows[i]
            if row then
                row:SetHeight(h)
                row:SetPoint("TOPLEFT", 0, -((i - 1) * (h + spacing)))
                row.threatBar:SetHeight(h - 2)

                row.text:SetFont("Fonts\\FRIZQT__.TTF", textSize, "")
                row.value:SetFont("Fonts\\FRIZQT__.TTF", textSize, "")

                row.classIcon:SetSize(iconSize, iconSize)
                row.classIcon:SetTexture(CLASS_ICONS.WARRIOR)
                row.classIcon:Show()

                row.text:SetText("Threat Slot " .. i)
                row.text:SetTextColor(1, 1, 1)

                local dummy = 50 - ((i - 1) * 10)
                row.value:SetText(dummy)
                row.value:SetTextColor(0, 1, 1)

                row.value:ClearAllPoints()
                row.value:SetPoint("RIGHT", PvPThreatMeterDB.valueOffset or 0, 0)

                local barPercent = 1 - ((i - 1) * 0.18)
                local available  = row:GetWidth() - 30
                local maxBar     = PvPThreatMeterDB.maxBarWidth or 140
                local barWidth   = math.min(available * barPercent, maxBar)

                row.threatBar:SetWidth(math.max(1, barWidth))
                row.threatBar:SetColorTexture(GetThreatBarColor(barPercent))
                row.threatBar:Show()

                row:SetAlpha(1)
                row:Show()
            end
        end

    else
        frame.anchor:Hide()
        frame.resizeGrip:Hide()
        frame:Hide()
        HideAllRows()
    end
end

------------------------------------------------------------
-- Init
------------------------------------------------------------
function Meter:OnInit()
    -- 🔹 Clean up any existing frame/rows so we don't duplicate
    if frame then
        frame:Hide()
        frame:SetParent(nil)
        frame = nil
    end

    -- wipe rows table so we don't keep references to old row frames
    for i = 1, #rows do
        rows[i] = nil
    end

    local width = math.max(PvPThreatMeterDB.frameWidth or 220, (PvPThreatMeterDB.maxBarWidth or 140) + 60)
    local scale    = 1.0
    local maxRows  = PvPThreatMeterDB.maxRows

    local h        = PvPThreatMeterDB.barHeight or 24
    local spacing  = PvPThreatMeterDB.rowSpacing or 2
    local textSize = PvPThreatMeterDB.nameTextSize or 14
    local iconSize = PvPThreatMeterDB.iconSize or 18

    --------------------------------------------------------
    -- Main Frame
    --------------------------------------------------------
    frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(width, maxRows * (h + spacing) + 40)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetScale(scale)
    frame:Hide()

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    frame:SetBackdropColor(1, 1, 1, PvPThreatMeterDB.backgroundAlpha or 0.85)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetResizable(true)
    frame:SetResizeBounds(150, 80, 500, 600)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    frame:SetScript("OnSizeChanged", function(self, width, height)
        PvPThreatMeterDB.frameWidth  = width
        PvPThreatMeterDB.frameHeight = height
    end)

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and PvPThreatMeter.unlockMode then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    --------------------------------------------------------
    -- Scroll Container
    --------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 12)
    scrollFrame:EnableMouseWheel(true)

    frame.scrollFrame = scrollFrame

    local listContent = CreateFrame("Frame", nil, scrollFrame)
    listContent:SetPoint("TOPLEFT")
    listContent:SetSize(width - 20, maxRows * (h + spacing))

    scrollFrame:SetScrollChild(listContent)
    frame.listContent = listContent

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local step = h + spacing
        local newOffset = self:GetVerticalScroll() - (delta * step)
        newOffset = math.max(0, math.min(newOffset, self:GetVerticalScrollRange()))
        self:SetVerticalScroll(newOffset)
    end)

    scrollFrame:EnableMouse(true)
    scrollFrame:RegisterForDrag("LeftButton")
    scrollFrame:SetScript("OnDragStart", function()
        if PvPThreatMeter.unlockMode then
            frame:StartMoving()
        end
    end)
    scrollFrame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)

    --------------------------------------------------------
    -- Anchor Overlay
    --------------------------------------------------------
    local anchor = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    anchor:SetAllPoints()
    anchor:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    anchor:SetBackdropColor(0, 0.4, 1, PvPThreatMeterDB.backgroundAlpha or 0.85)
    anchor:Hide()
    frame.anchor = anchor

    --------------------------------------------------------
    -- Resize Grip
    --------------------------------------------------------
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", 0, 0)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:Hide()

    resizeGrip:SetScript("OnMouseDown", function(self)
        if PvPThreatMeter.unlockMode then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)

    resizeGrip:SetScript("OnMouseUp", function(self)
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)

    frame.resizeGrip = resizeGrip
    resizeGrip:SetFrameStrata("HIGH")
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 20)

    --------------------------------------------------------
    -- Rows
    --------------------------------------------------------
    for i = 1, TOTAL_ROWS do
        local row = CreateFrame("Button", nil, frame.listContent)
        row:SetSize(width - 20, h)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * (h + spacing)))

        ------------------------------------------------
        -- Background highlight
        ------------------------------------------------
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0, 0, 0, 0.3)
        row.bg:Hide()

        ------------------------------------------------
        -- Threat bar
        ------------------------------------------------
        row.threatBar = row:CreateTexture(nil, "ARTWORK")
        row.threatBar:SetPoint("LEFT", 22, 0)
        row.threatBar:SetHeight(h - 2)
        row.threatBar:SetColorTexture(1, 0, 0, 0.4)
        row.threatBar:Hide()

        ------------------------------------------------
        -- Class icon
        ------------------------------------------------
        row.classIcon = row:CreateTexture(nil, "OVERLAY")
        row.classIcon:SetSize(iconSize, iconSize)
        row.classIcon:SetPoint("LEFT", 2, 0)
        row.classIcon:Hide()

        ------------------------------------------------
        -- Name text
        ------------------------------------------------
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 22, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetFont("Fonts\\FRIZQT__.TTF", textSize, "")

        ------------------------------------------------
        -- Value text
        ------------------------------------------------
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.value:SetWidth(50)
        row.value:SetWordWrap(false)
        row.value:ClearAllPoints()
        row.value:SetPoint("RIGHT", PvPThreatMeterDB.valueOffset or 0, 0)
        row.value:SetJustifyH("RIGHT")
        row.value:SetFont("Fonts\\FRIZQT__.TTF", textSize, "")

        ------------------------------------------------
        -- Hover highlight
        ------------------------------------------------
        row:SetScript("OnEnter", function(self)
            self.bg:Show()
        end)

        row:SetScript("OnLeave", function(self)
            self.bg:Hide()
        end)

        row:Hide()
        rows[i] = row
    end

    ResizeListContent()

    --------------------------------------------------------
    -- Finalize
    --------------------------------------------------------
    LoadPosition(frame)

    Meter.initialized = true
    PvPThreatMeter:Debug("Meter visual initialized (lightweight, no targeting)")
    UpdateScrollBar()
end

------------------------------------------------------------
-- Register Visual
------------------------------------------------------------
PvPThreatMeter:RegisterVisual("Meter", Meter)
