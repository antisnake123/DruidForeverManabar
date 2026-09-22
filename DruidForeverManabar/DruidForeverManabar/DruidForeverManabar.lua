local MANA_POWER_TYPE = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local FIVE_SECOND_RULE = 5.0
local FSR_UPDATE_INTERVAL = 0.05

-- Bear and Dire Bear share form ID 5.
local TRACKED_FORMS = {
    [1] = true, -- Cat Form
    [3] = true, -- Travel Form
    [4] = true, -- Aquatic Form
    [5] = true, -- Bear / Dire Bear Form
}

DruidForeverManabarDB = DruidForeverManabarDB or {}

local DEFAULTS = {
    width = 124,
    height = 10,
    scale = 1.0,
    point = "CENTER",
    relativePoint = "CENTER",
    xOfs = 0,
    yOfs = -150,
    attachToPlayerFrame = true,
    unlocked = false,
    colorR = 0.0,
    colorG = 0.4,
    colorB = 0.85,
    textFormat = "both",
    showTimerText = true,
    showOutsideForms = false,
    fontKey = "arial",
    fontSize = 10,
}

local function EnsureDB()
    for key, value in pairs(DEFAULTS) do
        if DruidForeverManabarDB[key] == nil then
            DruidForeverManabarDB[key] = value
        end
    end
    return DruidForeverManabarDB
end

local db = EnsureDB()

local FONT_CHOICES = {
    arial = { label = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    friz = { label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    morpheus = { label = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    skurri = { label = "Skurri", path = "Fonts\\SKURRI.TTF" },
}

local manaFrame = CreateFrame("Frame", "DruidForeverManabarMainFrame", UIParent, "BackdropTemplate")
manaFrame:SetSize(db.width, db.height)
manaFrame:SetScale(db.scale)
manaFrame:SetMovable(true)
manaFrame:EnableMouse(true)
manaFrame:RegisterForDrag("LeftButton")
manaFrame:SetClampedToScreen(true)

manaFrame:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
})
manaFrame:SetBackdropBorderColor(0.08, 0.08, 0.10, 0.95)

local background = manaFrame:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints(manaFrame)
background:SetColorTexture(0, 0, 0, 0.6)

local manaBar = CreateFrame("StatusBar", nil, manaFrame)
manaBar:SetAllPoints(manaFrame)
manaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
manaBar:SetStatusBarColor(db.colorR, db.colorG, db.colorB, 1)
manaBar:SetMinMaxValues(0, 1)
manaBar:SetValue(0)

local manaText = manaBar:CreateFontString(nil, "OVERLAY")
manaText:SetPoint("CENTER", manaBar, "CENTER", 0, 0)

local fsrMarker = manaBar:CreateTexture(nil, "OVERLAY", nil, 7)
fsrMarker:SetColorTexture(1, 1, 1, 0.95)
fsrMarker:SetWidth(2)
fsrMarker:SetHeight(db.height + 4)
fsrMarker:Hide()

local fsrText = manaFrame:CreateFontString(nil, "OVERLAY")
fsrText:SetPoint("TOP", manaFrame, "BOTTOM", 0, -2)
fsrText:Hide()

local function ApplyFont()
    local choice = FONT_CHOICES[db.fontKey] or FONT_CHOICES.arial
    local size = db.fontSize or 10

    manaText:SetFont(choice.path, size, "")
    manaText:SetTextColor(1, 1, 1, 1)
    manaText:SetShadowColor(0, 0, 0, 0.9)
    manaText:SetShadowOffset(1, -1)

    fsrText:SetFont(choice.path, math.max(8, size - 1), "")
    fsrText:SetTextColor(1, 1, 1, 1)
    fsrText:SetShadowColor(0, 0, 0, 0.9)
    fsrText:SetShadowOffset(1, -1)
end

ApplyFont()

local isDruid = false
local fsrEndTime = 0
local pendingManaCasts = {}
local lastManaSpellID = nil
local fsrUpdateFrame = CreateFrame("Frame")
local fsrUpdateElapsed = 0

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

local function IsTrackedForm(formID)
    return formID ~= nil and TRACKED_FORMS[formID] == true
end

local function GetPlayerResourceBar()
    if PlayerFrame then
        local content = PlayerFrame.PlayerFrameContent
        local main = content and content.PlayerFrameContentMain
        local manaArea = main and main.ManaBarArea
        local resourceBar = manaArea and manaArea.ManaBar

        if resourceBar and resourceBar.GetObjectType then
            return resourceBar
        end
    end

    if PlayerFrameManaBar and PlayerFrameManaBar.GetObjectType then
        return PlayerFrameManaBar
    end
end

local function ApplyAnchor()
    manaFrame:ClearAllPoints()

    if db.attachToPlayerFrame and PlayerFrame then
        local resourceBar = GetPlayerResourceBar()

        manaFrame:SetParent(PlayerFrame)
        manaFrame:SetScale(1)
        manaFrame:SetHeight(10)

        if resourceBar then
            -- Match the real Blizzard power bar instead of relying on fixed PlayerFrame offsets.
            manaFrame:SetPoint("TOPLEFT", resourceBar, "BOTTOMLEFT", 0, 0)
            manaFrame:SetPoint("TOPRIGHT", resourceBar, "BOTTOMRIGHT", 0, 0)
        else
            -- Fallback for beta builds where the resource-bar hierarchy changes.
            manaFrame:SetWidth(124)
            manaFrame:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 85, -74)
        end
    else
        manaFrame:SetParent(UIParent)
        manaFrame:SetScale(db.scale)
        manaFrame:SetSize(db.width, db.height)
        manaFrame:SetPoint(db.point, UIParent, db.relativePoint, db.xOfs, db.yOfs)
    end

    fsrMarker:SetHeight(manaFrame:GetHeight() + 4)
end

local function HideFiveSecondRuleVisual()
    fsrMarker:Hide()
    fsrText:Hide()
    fsrUpdateFrame:SetScript("OnUpdate", nil)
    fsrUpdateElapsed = 0
end

local function StopFiveSecondRule()
    fsrEndTime = 0
    HideFiveSecondRuleVisual()
end

local function UpdateFiveSecondRuleVisual()
    if fsrEndTime <= 0 then
        StopFiveSecondRule()
        return
    end

    local remaining = fsrEndTime - GetTime()
    if remaining <= 0 then
        StopFiveSecondRule()
        return
    end

    if not manaFrame:IsShown() then
        HideFiveSecondRuleVisual()
        return
    end

    local elapsed = FIVE_SECOND_RULE - remaining
    local progress = elapsed / FIVE_SECOND_RULE
    if progress < 0 then progress = 0 end
    if progress > 1 then progress = 1 end

    local markerWidth = fsrMarker:GetWidth() or 2
    local usableWidth = math.max(0, manaBar:GetWidth() - markerWidth)
    local x = (markerWidth / 2) + (progress * usableWidth)

    fsrMarker:ClearAllPoints()
    fsrMarker:SetPoint("CENTER", manaBar, "LEFT", x, 0)
    fsrMarker:Show()

    if db.showTimerText then
        fsrText:SetText(string.format("%.1f", remaining))
        fsrText:Show()
    else
        fsrText:Hide()
    end
end

local function OnFiveSecondRuleUpdate(_, elapsed)
    fsrUpdateElapsed = fsrUpdateElapsed + elapsed
    if fsrUpdateElapsed < FSR_UPDATE_INTERVAL then
        return
    end

    fsrUpdateElapsed = 0
    UpdateFiveSecondRuleVisual()
end

local function ResumeFiveSecondRuleVisual()
    if fsrEndTime > GetTime() and manaFrame:IsShown() then
        fsrUpdateElapsed = 0
        UpdateFiveSecondRuleVisual()
        fsrUpdateFrame:SetScript("OnUpdate", OnFiveSecondRuleUpdate)
    elseif fsrEndTime > 0 and fsrEndTime <= GetTime() then
        StopFiveSecondRule()
    end
end

local function StartFiveSecondRule()
    fsrEndTime = GetTime() + FIVE_SECOND_RULE

    if manaFrame:IsShown() then
        fsrUpdateElapsed = 0
        UpdateFiveSecondRuleVisual()
        fsrUpdateFrame:SetScript("OnUpdate", OnFiveSecondRuleUpdate)
    else
        HideFiveSecondRuleVisual()
    end
end

local function GetManaPercent(currentMana, maxMana)
    -- Avoid direct arithmetic when power values are restricted.
    if UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local ok, manaPercent = pcall(UnitPowerPercent, "player", MANA_POWER_TYPE, false, CurveConstants.ScaleTo100)
        if ok then
            return true, manaPercent
        end
    end

    if not IsSecretValue(currentMana) and not IsSecretValue(maxMana) and maxMana and maxMana > 0 then
        return true, (currentMana / maxMana) * 100
    end

    return false, nil
end

local function SetManaText(currentMana, maxMana)
    local format = db.textFormat

    if format == "numeric" then
        manaText:SetFormattedText("%s / %s", currentMana, maxMana)
        return
    end

    local hasPercent, manaPercent = GetManaPercent(currentMana, maxMana)
    if hasPercent then
        if format == "percent" then
            manaText:SetFormattedText("%.0f%%", manaPercent)
        else
            manaText:SetFormattedText("%s / %s (%.0f%%)", currentMana, maxMana, manaPercent)
        end
    else
        manaText:SetText("Mana")
    end
end

local function UpdateManaBar()
    if not isDruid then
        return
    end

    local maxMana = UnitPowerMax("player", MANA_POWER_TYPE)
    local currentMana = UnitPower("player", MANA_POWER_TYPE)

    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(currentMana)
    SetManaText(currentMana, maxMana)
end

local function HasPositiveReadableValue(value)
    return value ~= nil and not IsSecretValue(value) and value > 0
end

local function SpellSpendsMana(spellID)
    if spellID == nil or IsSecretValue(spellID) then
        return false
    end

    if not (C_Spell and C_Spell.GetSpellPowerCost) then
        return false
    end

    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or type(costs) ~= "table" then
        return false
    end

    for _, costInfo in ipairs(costs) do
        local powerType = costInfo.type
        local powerName = costInfo.name

        local isMana = false
        if powerType ~= nil and not IsSecretValue(powerType) then
            isMana = (powerType == MANA_POWER_TYPE)
        end
        if not isMana and powerName ~= nil and not IsSecretValue(powerName) then
            isMana = (powerName == "MANA")
        end

        if isMana then
            if HasPositiveReadableValue(costInfo.cost)
                or HasPositiveReadableValue(costInfo.minCost)
                or HasPositiveReadableValue(costInfo.costPercent)
                or HasPositiveReadableValue(costInfo.costPerSec) then
                return true
            end
        end
    end

    return false
end

local function UpdateFormState()
    local formID = GetShapeshiftFormID()
    local tracked = isDruid and IsTrackedForm(formID)
    local shouldShow = isDruid and (tracked or db.showOutsideForms)

    if shouldShow then
        manaFrame:Show()
        ApplyAnchor()
        UpdateManaBar()

        ResumeFiveSecondRuleVisual()
    else
        manaFrame:Hide()
        HideFiveSecondRuleVisual()
        manaText:ClearText()
    end
end

local OpenOptions

manaFrame:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" and OpenOptions then
        OpenOptions()
    end
end)

manaFrame:SetScript("OnDragStart", function(self)
    if db.unlocked and not db.attachToPlayerFrame then
        self:StartMoving()
    end
end)

manaFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    db.point = point
    db.relativePoint = relativePoint
    db.xOfs = xOfs
    db.yOfs = yOfs
end)

manaFrame:RegisterEvent("PLAYER_LOGIN")
manaFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
manaFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
manaFrame:RegisterEvent("UNIT_DISPLAYPOWER")
manaFrame:RegisterEvent("UNIT_POWER_UPDATE")
manaFrame:RegisterEvent("UNIT_POWER_FREQUENT")
manaFrame:RegisterEvent("UNIT_MAXPOWER")
manaFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
manaFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
manaFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
manaFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
manaFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

manaFrame:SetScript("OnEvent", function(_, event, unit, arg2, arg3, arg4)
    if event == "PLAYER_LOGIN" then
        local _, classFile = UnitClass("player")
        isDruid = (classFile == "DRUID")

        manaBar:SetStatusBarColor(db.colorR, db.colorG, db.colorB, 1)
        ApplyFont()
        ApplyAnchor()

        UpdateFormState()

        if isDruid then
            print("|cff00ff00DruidForeverManabar loaded.|r Right-click the mana bar or type |cffffffff/dfm|r for options.")
        end
        return
    end

    if not isDruid then
        manaFrame:Hide()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        wipe(pendingManaCasts)
        ApplyAnchor()
        UpdateFormState()
        return
    end

    if event == "UPDATE_SHAPESHIFT_FORM" or (event == "UNIT_DISPLAYPOWER" and unit == "player") then
        UpdateFormState()
        return
    end

    if unit ~= "player" then
        return
    end

    if event == "UNIT_SPELLCAST_SENT" then
        local castGUID = arg3
        local spellID = arg4
        if castGUID ~= nil and not IsSecretValue(castGUID) then
            pendingManaCasts[castGUID] = SpellSpendsMana(spellID)
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local castGUID = arg2
        local spellID = arg3
        local spendsMana = nil

        if castGUID ~= nil and not IsSecretValue(castGUID) then
            spendsMana = pendingManaCasts[castGUID]
            pendingManaCasts[castGUID] = nil
        end

        if spendsMana == nil then
            spendsMana = SpellSpendsMana(spellID)
        end

        if spendsMana then
            lastManaSpellID = spellID
            StartFiveSecondRule()
        end
        return
    end

    if event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_FAILED_QUIET"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local castGUID = arg2
        if castGUID ~= nil and not IsSecretValue(castGUID) then
            pendingManaCasts[castGUID] = nil
        end
        return
    end

    local powerType = arg2
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        if powerType == "MANA" then
            UpdateManaBar()
        end
    elseif event == "UNIT_MAXPOWER" then
        if powerType == nil or powerType == "MANA" then
            UpdateManaBar()
        end
    end
end)

manaFrame:Hide()

local panel = CreateFrame("Frame", "DruidForeverManabarOptionsPanel", UIParent)
panel.name = "Druid Forever Manabar"
panel:SetSize(460, 570)

local settingsCategory

OpenOptions = function()
    if Settings and Settings.OpenToCategory and settingsCategory then
        local ok = pcall(Settings.OpenToCategory, settingsCategory:GetID())
        if not ok then
            pcall(Settings.OpenToCategory, settingsCategory)
        end
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Druid Forever Manabar Settings")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Right-click the mana bar in-game anytime to open this menu.")

local attachCheckbox = CreateFrame("CheckButton", "DFMAttachCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
attachCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -15)
_G[attachCheckbox:GetName() .. "Text"]:SetText("Snap directly below Player Frame resource bar")
attachCheckbox:SetChecked(db.attachToPlayerFrame)
attachCheckbox:SetScript("OnClick", function(self)
    db.attachToPlayerFrame = self:GetChecked()
    ApplyAnchor()
end)

local unlockCheckbox = CreateFrame("CheckButton", "DFMUnlockCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
unlockCheckbox:SetPoint("TOPLEFT", attachCheckbox, "BOTTOMLEFT", 0, -10)
_G[unlockCheckbox:GetName() .. "Text"]:SetText("Unlock bar for dragging (disable anchoring first)")
unlockCheckbox:SetChecked(db.unlocked)
unlockCheckbox:SetScript("OnClick", function(self)
    db.unlocked = self:GetChecked()
end)

local timerTextCheckbox = CreateFrame("CheckButton", "DFMTimerTextCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
timerTextCheckbox:SetPoint("TOPLEFT", unlockCheckbox, "BOTTOMLEFT", 0, -10)
_G[timerTextCheckbox:GetName() .. "Text"]:SetText("Show 5-second-rule countdown text below the mana bar")
timerTextCheckbox:SetChecked(db.showTimerText)
timerTextCheckbox:SetScript("OnClick", function(self)
    db.showTimerText = self:GetChecked()
    UpdateFiveSecondRuleVisual()
end)

local outsideFormsCheckbox = CreateFrame("CheckButton", "DFMOutsideFormsCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
outsideFormsCheckbox:SetPoint("TOPLEFT", timerTextCheckbox, "BOTTOMLEFT", 0, -10)
_G[outsideFormsCheckbox:GetName() .. "Text"]:SetText("Show mana bar in Caster Form (outside shapeshift forms)")
outsideFormsCheckbox:SetChecked(db.showOutsideForms)
outsideFormsCheckbox:SetScript("OnClick", function(self)
    db.showOutsideForms = self:GetChecked()
    UpdateFormState()
end)

local function CreateSlider(name, parent, minVal, maxVal, step, labelText, valueKey, callback)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValue(db[valueKey])
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    _G[slider:GetName() .. "Low"]:SetText(tostring(minVal))
    _G[slider:GetName() .. "High"]:SetText(tostring(maxVal))
    local label = _G[slider:GetName() .. "Text"]

    local function DisplayValue(value)
        if step < 1 then
            return string.format("%.1f", value)
        end
        return tostring(math.floor(value + 0.5))
    end

    label:SetText(labelText .. ": " .. DisplayValue(db[valueKey]))

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        db[valueKey] = value
        label:SetText(labelText .. ": " .. DisplayValue(value))
        if callback then callback(value) end
    end)

    return slider
end

local widthSlider = CreateSlider("DFMWidthSlider", panel, 50, 400, 10, "Bar Width (Manual)", "width", function(val)
    if not db.attachToPlayerFrame then
        manaFrame:SetSize(val, db.height)
        fsrMarker:SetHeight(manaFrame:GetHeight() + 4)
    end
end)
widthSlider:SetPoint("TOPLEFT", outsideFormsCheckbox, "BOTTOMLEFT", 0, -35)

local heightSlider = CreateSlider("DFMHeightSlider", panel, 6, 30, 2, "Bar Height (Manual)", "height", function(val)
    if not db.attachToPlayerFrame then
        manaFrame:SetSize(manaFrame:GetWidth(), val)
        fsrMarker:SetHeight(manaFrame:GetHeight() + 4)
    end
end)
heightSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -35)

local scaleSlider = CreateSlider("DFMScaleSlider", panel, 0.5, 2.0, 0.1, "UI Scale (Manual)", "scale", function(val)
    if not db.attachToPlayerFrame then
        manaFrame:SetScale(val)
    end
end)
scaleSlider:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -35)

local formatLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
formatLabel:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -35)
formatLabel:SetText("Mana text format:")

local formatButtons = {}

local function RefreshFormatButtons()
    for mode, btn in pairs(formatButtons) do
        if mode == db.textFormat then
            btn:SetText("[" .. btn.label .. "]")
        else
            btn:SetText(btn.label)
        end
    end
end

local function CreateFormatButton(mode, label, xOffset)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(80, 22)
    btn:SetPoint("TOPLEFT", formatLabel, "BOTTOMLEFT", xOffset, -8)
    btn.label = label
    btn:SetText(label)
    btn:SetScript("OnClick", function()
        db.textFormat = mode
        RefreshFormatButtons()
        UpdateManaBar()
    end)
    formatButtons[mode] = btn
    return btn
end

CreateFormatButton("numeric", "Numeric", 0)
CreateFormatButton("percent", "Percent", 85)
CreateFormatButton("both", "Both", 170)
RefreshFormatButtons()

local fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
fontLabel:SetPoint("TOPLEFT", formatLabel, "BOTTOMLEFT", 0, -42)
fontLabel:SetText("Mana bar font:")

local fontButtons = {}

local function RefreshFontButtons()
    for key, btn in pairs(fontButtons) do
        if key == db.fontKey then
            btn:SetText("[" .. btn.label .. "]")
        else
            btn:SetText(btn.label)
        end
    end
end

local function CreateFontButton(key, xOffset, width)
    local choice = FONT_CHOICES[key]
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(width or 95, 22)
    btn:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", xOffset, -8)
    btn.label = choice.label
    btn:SetText(choice.label)
    btn:SetScript("OnClick", function()
        db.fontKey = key
        ApplyFont()
        RefreshFontButtons()
        UpdateManaBar()
        UpdateFiveSecondRuleVisual()
    end)
    fontButtons[key] = btn
    return btn
end

CreateFontButton("arial", 0, 95)
CreateFontButton("friz", 100, 95)
CreateFontButton("morpheus", 200, 95)
CreateFontButton("skurri", 300, 80)
RefreshFontButtons()

local fontSizeSlider = CreateSlider("DFMFontSizeSlider", panel, 8, 16, 1, "Font Size", "fontSize", function()
    ApplyFont()
    UpdateManaBar()
    UpdateFiveSecondRuleVisual()
end)
fontSizeSlider:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -55)

if Settings and Settings.RegisterCanvasLayoutCategory then
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(settingsCategory)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

local function PrintDebugInfo()
    local version, build, _, tocVersion = GetBuildInfo()
    local formID = GetShapeshiftFormID()
    local powerID, powerToken = UnitPowerType("player")
    local currentMana = UnitPower("player", MANA_POWER_TYPE)
    local maxMana = UnitPowerMax("player", MANA_POWER_TYPE)
    local manaIsSecret = IsSecretValue(currentMana)
    local remaining = math.max(0, fsrEndTime - GetTime())

    print("|cff55ff55DruidForeverManabar debug|r")
    print("Client:", tostring(version), "build", tostring(build), "TOC", tostring(tocVersion))
    print("Form ID:", tostring(formID), "tracked:", tostring(IsTrackedForm(formID)))
    print("Primary power:", tostring(powerID), tostring(powerToken))
    local resourceBar = GetPlayerResourceBar()
    print("Snap target:", resourceBar and (resourceBar.GetDebugName and resourceBar:GetDebugName() or tostring(resourceBar)) or "fallback PlayerFrame offset")
    print("Mana secret:", tostring(manaIsSecret), "max mana:", tostring(maxMana))
    if not manaIsSecret then
        print("Current mana:", tostring(currentMana))
    end
    print("5SR remaining:", string.format("%.2f", remaining))
    local fontChoice = FONT_CHOICES[db.fontKey] or FONT_CHOICES.arial
    print("Font:", fontChoice.label, "size", tostring(db.fontSize), "show outside forms:", tostring(db.showOutsideForms))
    if lastManaSpellID and not IsSecretValue(lastManaSpellID) then
        local spellName = nil
        if C_Spell and C_Spell.GetSpellName then
            local ok, name = pcall(C_Spell.GetSpellName, lastManaSpellID)
            if ok then spellName = name end
        end
        print("Last mana spell:", tostring(spellName or "?"), "ID", tostring(lastManaSpellID))
    end
end

SLASH_DRUIDFOREVERMANABAR1 = "/dfm"
SlashCmdList["DRUIDFOREVERMANABAR"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "debug" then
        PrintDebugInfo()
    elseif msg == "test" or msg == "testtimer" then
        manaFrame:Show()
        StartFiveSecondRule()
        print("|cff55ff55DFM:|r started a 5-second visual test timer.")
    else
        OpenOptions()
    end
end
