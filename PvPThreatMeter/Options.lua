------------------------------------------------------------
-- PvPThreatMeter - Options (Modern, Clean, No Redundant Controls)
-- Fully aligned with the lightweight meter visual.
------------------------------------------------------------

local PvPThreatMeter = _G.PvPThreatMeter
local Options = {}
local panel
local category

------------------------------------------------------------
-- Utility
------------------------------------------------------------
local function InitDB()
    if not PvPThreatMeterDB then
        PvPThreatMeterDB = CopyTable(PvPThreatMeter.DB_DEFAULTS)
    end
end

local function RefreshPanel()
    if panel then
        panel:Hide()
        panel:Show()
    end
end

local function GetMeter()
    return PvPThreatMeter.visuals and PvPThreatMeter.visuals["Meter"]
end


------------------------------------------------------------
-- Checkbox Factory
------------------------------------------------------------
local function CreateCheckbox(parent, label, key, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb.Text:SetText(label)
    cb.tooltipText = tooltip

    cb:SetScript("OnShow", function(self)
        self:SetChecked(PvPThreatMeterDB[key])
    end)

    cb:SetScript("OnClick", function(self)
        PvPThreatMeterDB[key] = self:GetChecked()
    end)

    return cb
end

------------------------------------------------------------
-- Slider Factory
------------------------------------------------------------
local function CreateSlider(parent, label, key, minVal, maxVal, step, tooltip)
    local sliderName = "PvPThreatMeterSlider_" .. key
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")

    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)
    slider.tooltipText = tooltip

    _G[sliderName .. "Low"]:SetText(minVal)
    _G[sliderName .. "High"]:SetText(maxVal)

    slider:SetScript("OnShow", function(self)
        local v = PvPThreatMeterDB[key] or minVal
        self:SetValue(v)
        local display = step < 1 and string.format("%.2f", v) or tostring(math.floor(v))
        _G[sliderName .. "Text"]:SetText(label .. ": " .. display)
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        PvPThreatMeterDB[key] = value
        local display = step < 1 and string.format("%.2f", value) or tostring(math.floor(value))
        _G[sliderName .. "Text"]:SetText(label .. ": " .. display)
    end)

    return slider
end

------------------------------------------------------------
-- Dropdown Factory
------------------------------------------------------------
local function CreateDropdown(parent, label, key, items, tooltip)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(200, 40)
    container.tooltipText = tooltip

    local text = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetText(label)

    local dropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(dropdown, 160)

    dropdown.initialize = function(self, level)
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.func = function()
                PvPThreatMeterDB[key] = item.value
                UIDropDownMenu_SetSelectedValue(dropdown, item.value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    dropdown:SetScript("OnShow", function()
        UIDropDownMenu_SetSelectedValue(dropdown, PvPThreatMeterDB[key])
    end)

    return container
end

------------------------------------------------------------
-- Build Panel
------------------------------------------------------------
local function BuildPanel()
    if panel then return end
    InitDB()

    panel = CreateFrame("Frame")
    panel.name = "PvPThreatMeter"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PvPThreatMeter")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Lightweight PvP threat meter with clean visuals and smart threat scoring.")

    ------------------------------------------------------------
    -- Scrollable content
    ------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 3, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -27, 20)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(580, 2600)
    scrollFrame:SetScrollChild(content)

    local y = -10

    local function AddCheckbox(text, key, tooltip)
        local cb = CreateCheckbox(content, text, key, tooltip)
        cb:SetPoint("TOPLEFT", 16, y)
        y = y - 30
    end

    ------------------------------------------------------------
    -- Master Enable
    ------------------------------------------------------------
    AddCheckbox(
        "Enable PvPThreatMeter",
        "enabled",
        "Turns the entire addon on or off."
    )
    y = y - 10

    ------------------------------------------------------------
    -- Mode Selection
    ------------------------------------------------------------
    local modeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    modeLabel:SetPoint("TOPLEFT", 16, y)
    modeLabel:SetText("Meter Mode:")
    modeLabel:SetTextColor(1, 0.82, 0)
    y = y - 25

    local modeDropdown = CreateDropdown(
        content,
        "Mode:",
        "mode",
        {
            { text = "Threat Mode", value = "threat" },
            { text = "Damage Mode", value = "damage" },
        },
        "Threat Mode ranks enemies by threat score.\nDamage Mode ranks enemies by recent damage taken."
    )
    modeDropdown:SetPoint("TOPLEFT", 16, y)
    y = y - 70

    ------------------------------------------------------------
    -- PvP Scope
    ------------------------------------------------------------
    local scopeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scopeLabel:SetPoint("TOPLEFT", 16, y)
    scopeLabel:SetText("Detection Scope:")
    scopeLabel:SetTextColor(1, 0.82, 0)
    y = y - 25

    AddCheckbox("  Enable in Battlegrounds", "scopeBG", "Show the meter in battlegrounds.")
    AddCheckbox("  Enable in Arenas", "scopeArena", "Show the meter in arenas.")
    AddCheckbox("  Enable in World PvP", "scopeWorld", "Show the meter in world PvP zones.")
    y = y - 20

    ------------------------------------------------------------
    -- Visual Settings
    ------------------------------------------------------------

	local maxRowsSlider = CreateSlider(
		content,
		"Max Rows",
		"maxRows",
		1, 40, 1,
		"Controls how many rows the meter displays (1–40)."
	)
	maxRowsSlider:SetPoint("TOPLEFT", 32, y)

	maxRowsSlider:SetScript("OnValueChanged", function(self, value)
		PvPThreatMeterDB.maxRows = value

		local display = tostring(math.floor(value))
		_G["PvPThreatMeterSlider_maxRowsText"]:SetText("Max Rows: " .. display)

		local meter = GetMeter()
		if meter and meter.Refresh then
			meter:Refresh()
		end
	end)

	y = y - 80

    local nameSizeSlider = CreateSlider(
        content,
        "Name / Value Text Size",
        "nameTextSize",
        8, 24, 1,
        "Controls the font size of both the name and the value text."
    )
    nameSizeSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local barHeightSlider = CreateSlider(
        content,
        "Bar Height",
        "barHeight",
        12, 40, 1,
        "Controls the height of each row and its threat bar."
    )
    barHeightSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local spacingSlider = CreateSlider(
        content,
        "Row Spacing",
        "rowSpacing",
        0, 10, 1,
        "Controls the vertical space between rows."
    )
    spacingSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local iconSizeSlider = CreateSlider(
        content,
        "Icon Size",
        "iconSize",
        10, 40, 1,
        "Controls the size of the class icon on each row."
    )
    iconSizeSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

	local barWidthSlider = CreateSlider(
		content,
		"Max Bar Width",
		"maxBarWidth",
		50, 800, 5,
		"Limits how wide the threat bar can grow."
	)
	barWidthSlider:SetPoint("TOPLEFT", 32, y)

	barWidthSlider:SetScript("OnValueChanged", function(self, value)
		PvPThreatMeterDB.maxBarWidth = value

		local display = tostring(math.floor(value))
		_G["PvPThreatMeterSlider_maxBarWidthText"]:SetText("Max Bar Width: " .. display)

		local meter = GetMeter()
		if meter and meter.Refresh then
			meter:Refresh()
		end
	end)

	y = y - 80

    local valueOffsetSlider = CreateSlider(
        content,
        "Value Text Offset",
        "valueOffset",
        -100, 100, 1,
        "Moves the value text left or right for alignment."
    )
    valueOffsetSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local bgAlphaSlider = CreateSlider(
        content,
        "Background Transparency",
        "backgroundAlpha",
        0.1, 1.0, 0.05,
        "Controls how transparent the meter background is."
    )
    bgAlphaSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    ------------------------------------------------------------
    -- Damage Mode Settings
    ------------------------------------------------------------
    local dmgLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dmgLabel:SetPoint("TOPLEFT", 16, y)
    dmgLabel:SetText("Damage Mode Settings:")
    dmgLabel:SetTextColor(1, 0.82, 0)
    y = y - 25

    local dmgWindow = CreateSlider(
        content,
        "Damage Window (sec)",
        "damageWindow",
        2, 10, 1,
        "How many seconds of recent damage are counted."
    )
    dmgWindow:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    ------------------------------------------------------------
    -- Threat Mode Weights
    ------------------------------------------------------------
    local weightLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    weightLabel:SetPoint("TOPLEFT", 16, y)
    weightLabel:SetText("Threat Mode Weights:")
    weightLabel:SetTextColor(1, 0.82, 0)
    y = y - 25

    local wTarget = CreateSlider(
        content,
        "Target Weight",
        "weightTarget",
        0, 10, 1,
        "Threat added when an enemy targets you."
    )
    wTarget:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local wDamage = CreateSlider(
        content,
        "Damage Weight",
        "weightDamage",
        0, 10, 1,
        "Threat added based on damage dealt to you."
    )
    wDamage:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local wCast = CreateSlider(
        content,
        "Cast Weight",
        "weightCast",
        0, 10, 1,
        "Threat added when an enemy casts a spell on you."
    )
    wCast:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local wSwing = CreateSlider(
        content,
        "Swing Weight",
        "weightSwing",
        0, 10, 1,
        "Threat added when an enemy swings at you."
    )
    wSwing:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local wDot = CreateSlider(
        content,
        "DoT Weight",
        "weightDot",
        0, 10, 1,
        "Threat added from damage-over-time effects."
    )
    wDot:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    ------------------------------------------------------------
    -- Linger System Settings
    ------------------------------------------------------------
    local lingerLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lingerLabel:SetPoint("TOPLEFT", 16, y)
    lingerLabel:SetText("Linger System:")
    lingerLabel:SetTextColor(1, 0.82, 0)
    y = y - 25

    local lingerSlider = CreateSlider(
        content,
        "Linger Time (sec)",
        "lingerTime",
        3, 15, 1,
        "How long an enemy remains visible after losing threat."
    )
    lingerSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local minVisSlider = CreateSlider(
        content,
        "Minimum Visibility (sec)",
        "minVisibility",
        0, 5, 1,
        "Minimum time an enemy stays visible after appearing."
    )
    minVisSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local fadeSlider = CreateSlider(
        content,
        "Fade Duration (sec)",
        "fadeDuration",
        0, 3, 0.1,
        "How long the fade-out animation lasts."
    )
    fadeSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    local lastAtkSlider = CreateSlider(
        content,
        "Show Last Attackers",
        "showLastAttackers",
        0, 10, 1,
        "Shows the last X attackers even if they are no longer active."
    )
    lastAtkSlider:SetPoint("TOPLEFT", 32, y)
    y = y - 80

    AddCheckbox(
        "Sticky Top Threat",
        "stickyTopThreat",
        "Keeps the highest-threat enemy locked at the top of the list."
    )
    y = y - 40

    ------------------------------------------------------------
    -- Buttons
    ------------------------------------------------------------
    local btnAnchor = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnAnchor:SetSize(160, 24)
    btnAnchor:SetText("Toggle Anchor Mode")
    btnAnchor:SetPoint("TOPLEFT", 16, y)

    btnAnchor:SetScript("OnClick", function()
		PvPThreatMeter.unlockMode = not PvPThreatMeter.unlockMode
		PvPThreatMeter:Print(PvPThreatMeter.unlockMode and "Anchor mode enabled" or "Anchor mode disabled")

		local meter = PvPThreatMeter.visuals["Meter"]

		if meter and meter.ANCHOR_MODE then
			meter:ANCHOR_MODE(PvPThreatMeter.unlockMode)
		end
    end)

    y = y - 40

    local btnReset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnReset:SetSize(160, 24)
    btnReset:SetText("Reset to Defaults")
    btnReset:SetPoint("TOPLEFT", 16, y)

	btnReset:SetScript("OnClick", function()
		wipe(PvPThreatMeterDB)

		for k, v in pairs(PvPThreatMeter.DB_DEFAULTS) do
			PvPThreatMeterDB[k] = v
		end

		PvPThreatMeter:Print("Settings reset to defaults")

		-- ⭐ NEW: Force meter to refresh
		local meter = PvPThreatMeter.visuals["Meter"]

		if meter then
			PvPThreatMeter.unlockMode = false
			meter:ANCHOR_MODE(false)

			if meter and meter.initialized then
				meter:ANCHOR_MODE(false) -- ensure clean state
				meter:OnInit()           -- rebuild once
				meter:ANCHOR_MODE(PvPThreatMeter.unlockMode)
			end

			meter:UPDATE_THREAT_DATA({}, {})
		end

		RefreshPanel()
	end)
end

------------------------------------------------------------
-- Register Panel
------------------------------------------------------------
local function RegisterPanel()
    if not panel then BuildPanel() end

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        return
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        return
    end
end

------------------------------------------------------------
-- Init
------------------------------------------------------------
function Options:OnInit()
    C_Timer.After(0.5, RegisterPanel)
end

PvPThreatMeter:RegisterUI("Options", Options)
