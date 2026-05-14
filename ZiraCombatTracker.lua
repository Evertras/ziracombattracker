local addonName = ...

local defaults = {
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 180,
    },
    enterText = "ENTERING COMBAT",
    leaveText = "Leaving Combat",
    enterColor = { r = 1, g = 0.15, b = 0.15 },
    leaveColor = { r = 0.25, g = 1, b = 0.25 },
    font = "Friz Quadrata TT",
    fontSize = 36,
    preview = false,
}

local state = {
    frame = nil,
    text = nil,
    background = nil,
    optionsPanel = nil,
    optionsCategory = nil,
    optionsCategoryID = nil,
    previewCheckbox = nil,
    hideToken = 0,
    isDragging = false,
}

local eventFrame = CreateFrame("Frame")

local function CopyDefaults(source, target)
    if type(source) ~= "table" then
        return target
    end

    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local function GetLSM()
    if not LibStub then
        return nil
    end

    return LibStub("LibSharedMedia-3.0", true)
end

local function GetFontPath(fontName)
    local lsm = GetLSM()
    if lsm and fontName then
        return lsm:Fetch("font", fontName, true) or STANDARD_TEXT_FONT
    end

    return STANDARD_TEXT_FONT
end

local function IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

local function SavePosition()
    if not state.frame then
        return
    end

    local point, _, relativePoint, x, y = state.frame:GetPoint(1)
    ZiraCombatTrackerDB.position.point = point
    ZiraCombatTrackerDB.position.relativePoint = relativePoint
    ZiraCombatTrackerDB.position.x = x
    ZiraCombatTrackerDB.position.y = y
end

local function ApplyPosition()
    if not state.frame then
        return
    end

    local position = ZiraCombatTrackerDB.position
    state.frame:ClearAllPoints()
    state.frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

local function RefreshFont()
    if not state.text then
        return
    end

    local fontPath = GetFontPath(ZiraCombatTrackerDB.font)
    local fontSize = ZiraCombatTrackerDB.fontSize or defaults.fontSize
    local applied = state.text:SetFont(fontPath, fontSize, "OUTLINE")

    if not applied then
        state.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    end
end

local function UpdateMovableState()
    if not state.frame then
        return
    end

    local canMove = IsEditModeActive()
    state.frame:SetMovable(canMove)
    state.frame:EnableMouse(canMove)

    if state.background then
        state.background:SetShown(canMove or ZiraCombatTrackerDB.preview)
    end

    if state.text then
        if canMove and (ZiraCombatTrackerDB.preview or not state.frame:IsShown()) then
            state.frame:Show()
            state.text:SetText(ZiraCombatTrackerDB.enterText)
            state.text:SetTextColor(1, 1, 1)
            state.frame:SetAlpha(0.5)
        elseif not ZiraCombatTrackerDB.preview then
            state.frame:SetAlpha(1)
            state.frame:Hide()
        else
            state.frame:SetAlpha(1)
        end
    end
end

local function ShowBanner(message, color)
    if not state.frame or not state.text then
        return
    end

    state.hideToken = state.hideToken + 1
    local token = state.hideToken

    state.text:SetText(message)
    state.text:SetTextColor(color.r, color.g, color.b)
    state.frame:SetAlpha(1)
    state.frame:Show()

    C_Timer.After(2, function()
        if token ~= state.hideToken then
            return
        end

        if ZiraCombatTrackerDB.preview or IsEditModeActive() then
            UpdateMovableState()
            return
        end

        state.frame:Hide()
    end)
end

local function RefreshPreview()
    if not state.frame or not state.text then
        return
    end

    if state.background then
        state.background:SetShown(ZiraCombatTrackerDB.preview or IsEditModeActive())
    end

    if ZiraCombatTrackerDB.preview then
        state.hideToken = state.hideToken + 1
        state.text:SetText(ZiraCombatTrackerDB.enterText)
        state.text:SetTextColor(
            ZiraCombatTrackerDB.enterColor.r,
            ZiraCombatTrackerDB.enterColor.g,
            ZiraCombatTrackerDB.enterColor.b
        )
        state.frame:SetAlpha(1)
        state.frame:Show()
        return
    end

    if not IsEditModeActive() then
        state.frame:Hide()
    else
        UpdateMovableState()
    end
end

local function BuildFontList()
    local fonts = {}
    local seen = {}
    local lsm = GetLSM()

    local function AddFont(name)
        if not name or seen[name] then
            return
        end

        seen[name] = true
        table.insert(fonts, name)
    end

    AddFont(defaults.font)

    if lsm then
        for name in pairs(lsm:HashTable("font")) do
            AddFont(name)
        end
    end

    table.sort(fonts)
    return fonts
end

local function CreateLabel(parent, text, anchor, offsetY)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    label:SetText(text)
    return label
end

local function CreateColorButton(parent, labelText, initialColor, anchor)
    local label = CreateLabel(parent, labelText, anchor, -16)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(120, 22)
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    button:SetText("Choose color")

    local swatch = parent:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(18, 18)
    swatch:SetPoint("LEFT", button, "RIGHT", 10, 0)

    local function RefreshSwatch()
        swatch:SetColorTexture(initialColor.r, initialColor.g, initialColor.b, 1)
    end

    button:SetScript("OnClick", function()
        local info = {}
        info.r = initialColor.r
        info.g = initialColor.g
        info.b = initialColor.b
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            initialColor.r = r
            initialColor.g = g
            initialColor.b = b
            RefreshSwatch()
            RefreshPreview()
        end
        info.cancelFunc = function(previousValues)
            if not previousValues then
                return
            end

            initialColor.r = previousValues.r
            initialColor.g = previousValues.g
            initialColor.b = previousValues.b
            RefreshSwatch()
            RefreshPreview()
        end
        info.opacityFunc = nil
        info.hasOpacity = false
        info.previousValues = {
            r = initialColor.r,
            g = initialColor.g,
            b = initialColor.b,
        }

        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    RefreshSwatch()
    return button
end

local function CreateFontDropdown(parent, anchor)
    local label = CreateLabel(parent, "Font", anchor, -24)
    local dropdown = CreateFrame("Frame", addonName .. "FontDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -6)

    local function SetSelected(fontName)
        ZiraCombatTrackerDB.font = fontName
        UIDropDownMenu_SetText(dropdown, fontName)
        RefreshFont()
        RefreshPreview()
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, fontName in ipairs(BuildFontList()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = fontName
            info.func = function()
                SetSelected(fontName)
            end
            info.checked = fontName == ZiraCombatTrackerDB.font
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetWidth(dropdown, 220)
    UIDropDownMenu_SetText(dropdown, ZiraCombatTrackerDB.font)
    return dropdown
end

local function CreateFontSizeSlider(parent, anchor)
    local slider = CreateFrame("Slider", addonName .. "FontSizeSlider", parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -44)
    slider:SetMinMaxValues(12, 72)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(240)
    slider:SetValue(ZiraCombatTrackerDB.fontSize)
    _G[slider:GetName() .. "Low"]:SetText("12")
    _G[slider:GetName() .. "High"]:SetText("72")
    _G[slider:GetName() .. "Text"]:SetText("Font size")

    slider:SetScript("OnValueChanged", function(self, value)
        ZiraCombatTrackerDB.fontSize = math.floor(value + 0.5)
        RefreshFont()
        RefreshPreview()
    end)

    return slider
end

local function CreateTextInput(parent, labelText, initialValue, anchor, onApply)
    local label = CreateLabel(parent, labelText, anchor, -24)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    local currentValue = initialValue
    editBox:SetSize(240, 30)
    editBox:SetAutoFocus(false)
    editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    editBox:SetText(currentValue)
    editBox:SetCursorPosition(0)

    local function ApplyText()
        local value = editBox:GetText()
        if value == "" then
            value = currentValue
            editBox:SetText(value)
        end

        currentValue = value
        onApply(value)
        RefreshPreview()
        UpdateMovableState()
    end

    editBox.RefreshValue = function(self, value)
        currentValue = value
        self:SetText(value)
    end

    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ApplyText()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(currentValue)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", ApplyText)

    return editBox
end

local function CreatePreviewCheckbox(parent, anchor)
    local checkbox = CreateFrame("CheckButton", addonName .. "PreviewCheckbox", parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -24)
    checkbox.Text:SetText("Preview text")
    checkbox:SetChecked(ZiraCombatTrackerDB.preview)
    checkbox:SetScript("OnClick", function(self)
        ZiraCombatTrackerDB.preview = self:GetChecked() and true or false
        RefreshPreview()
        UpdateMovableState()
    end)
    state.previewCheckbox = checkbox
    return checkbox
end

local function OpenOptionsPanel()
    if not state.optionsPanel then
        return
    end

    if Settings and Settings.OpenToCategory then
        local categoryID = state.optionsCategoryID

        if not categoryID and state.optionsCategory and state.optionsCategory.GetID then
            categoryID = state.optionsCategory:GetID()
            state.optionsCategoryID = categoryID
        end

        if categoryID then
            Settings.OpenToCategory(categoryID)
            return
        end
    end

    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(state.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(state.optionsPanel)
    end
end

local function CreateOptionsPanel()
    if state.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", addonName .. "OptionsPanel", UIParent)
    panel.name = "Zira Combat Tracker"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Zira Combat Tracker")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Shows a short combat banner and supports Edit Mode dragging.")

    local enterTextBox = CreateTextInput(panel, "Enter combat text", ZiraCombatTrackerDB.enterText, subtitle, function(value)
        ZiraCombatTrackerDB.enterText = value
    end)
    local leaveTextBox = CreateTextInput(panel, "Leave combat text", ZiraCombatTrackerDB.leaveText, enterTextBox, function(value)
        ZiraCombatTrackerDB.leaveText = value
    end)
    local enterButton = CreateColorButton(panel, "Enter combat color", ZiraCombatTrackerDB.enterColor, leaveTextBox)
    local leaveButton = CreateColorButton(panel, "Leave combat color", ZiraCombatTrackerDB.leaveColor, enterButton)
    local fontDropdown = CreateFontDropdown(panel, leaveButton)
    local slider = CreateFontSizeSlider(panel, fontDropdown)
    local previewCheckbox = CreatePreviewCheckbox(panel, slider)

    panel.refresh = function()
        enterTextBox:RefreshValue(ZiraCombatTrackerDB.enterText)
        leaveTextBox:RefreshValue(ZiraCombatTrackerDB.leaveText)
        UIDropDownMenu_SetText(fontDropdown, ZiraCombatTrackerDB.font)
        slider:SetValue(ZiraCombatTrackerDB.fontSize)
        previewCheckbox:SetChecked(ZiraCombatTrackerDB.preview)
    end

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        state.optionsCategory = category
        if category and category.GetID then
            state.optionsCategoryID = category:GetID()
        end
    else
        InterfaceOptions_AddCategory(panel)
    end

    state.optionsPanel = panel
end

SLASH_ZIRACOMBATTRACKER1 = "/ziracombat"
SlashCmdList.ZIRACOMBATTRACKER = function()
    OpenOptionsPanel()
end

local function CreateDisplayFrame()
    if state.frame then
        return
    end

    local frame = CreateFrame("Frame", addonName .. "DisplayFrame", UIParent, "BackdropTemplate")
    frame:SetSize(420, 72)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not IsEditModeActive() then
            return
        end

        state.isDragging = true
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        if not state.isDragging then
            return
        end

        state.isDragging = false
        self:StopMovingOrSizing()
        SavePosition()
        UpdateMovableState()
    end)
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.35)
    background:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetAllPoints()
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")

    state.frame = frame
    state.text = text
    state.background = background

    RefreshFont()
    text:SetText(ZiraCombatTrackerDB.enterText)
    ApplyPosition()
    RefreshPreview()
    UpdateMovableState()
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then
            return
        end

        ZiraCombatTrackerDB = CopyDefaults(defaults, ZiraCombatTrackerDB)

        CreateDisplayFrame()
        CreateOptionsPanel()

        eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        ShowBanner(ZiraCombatTrackerDB.enterText, ZiraCombatTrackerDB.enterColor)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        ShowBanner(ZiraCombatTrackerDB.leaveText, ZiraCombatTrackerDB.leaveColor)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        ApplyPosition()
        UpdateMovableState()
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")