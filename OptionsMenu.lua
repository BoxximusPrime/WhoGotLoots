WhoLootsOptionsEntries = {}

-- Handle Events --
function WhoLootsOptionsEntries.LoadOptions(asdf)

    -- Make us a child of MainFrame, so we move with it.
    WhoLootsOptionsFrame:SetParent(WhoLootData.MainFrame)
    WhoLootsOptionsFrame:SetPoint("TOPLEFT", WhoLootData.MainFrame, "TOPRIGHT", 0, 0)

    WhoLootsOptionsEntries.AutoClose:SetChecked(WhoGotLootsSavedData.AutoCloseOnEmpty)
    WhoLootsOptionsEntries.LockWindow:SetChecked(WhoGotLootsSavedData.LockWindow)
    WhoLootsOptionsEntries.HideUnequippable:SetChecked(WhoGotLootsSavedData.HideUnequippable)
    WhoLootsOptionsEntries.ScaleSlider:SetValue(WhoGotLootsSavedData.SavedSize)

    -- Set the moveable state of the main frame
    if WhoGotLootsSavedData.LockWindow then
        WhoLootData.MainFrame:EnableMouse(false)
        WhoLootData.MainFrame:SetMovable(false)
    else
        WhoLootData.MainFrame:EnableMouse(true)
        WhoLootData.MainFrame:SetMovable(true)
    end
end

WhoLootsOptionsFrame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
WhoLootsOptionsFrame.name = "WhoLoots"
WhoLootsOptionsFrame:SetPoint("CENTER")
WhoLootsOptionsFrame:SetSize(200, 210)
WhoLootData.OptionsFrame = WhoLootsOptionsFrame

local backdrop = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 4,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Apply the backdrop to the frame
WhoLootsOptionsFrame:SetBackdrop(backdrop)
WhoLootsOptionsFrame:SetBackdropColor(0.2, 0.2, 0.2, 1) -- Set the background color (RGBA)
WhoLootsOptionsFrame:SetBackdropBorderColor(0, 0, 0, 1) -- Set the border color (RGBA)

-- Create a background image
local bg = WhoLootsOptionsFrame:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\EncounterJournal\\UI-EJ-Background")
bg:SetTexCoord(0, 1, 0, 0.643)
bg:SetAllPoints(WhoLootsOptionsFrame)

-- Create a title
local title = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
title:SetText("Who Got Loots - Options")

-- Create a frame holder for the options
local optionsFrameHolder = CreateFrame("Frame", nil, WhoLootsOptionsFrame)
optionsFrameHolder:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
optionsFrameHolder:SetSize(WhoLootsOptionsFrame:GetWidth() - 32, WhoLootsOptionsFrame:GetHeight() - 32)
optionsFrameHolder:SetScale(0.6)

-- Chekcbox: Auto Close Window
local autoPopup = CreateFrame("CheckButton", "WhoLootsAutoPopup", WhoLootsOptionsFrame, "InterfaceOptionsCheckButtonTemplate")
autoPopup:SetScript("OnClick", function(self)
    local tick = self:GetChecked()
    WhoGotLootsSavedData.AutoCloseOnEmpty = tick
    if tick then
        PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    else
        PlaySound(857) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
    end
end)
autoPopup.label = _G[autoPopup:GetName() .. "Text"]
autoPopup.label:SetText("Auto Close Window")
autoPopup.tooltipText = "Automatically closes the window when there are no items to display"
autoPopup.tooltipRequirement = "Auto popup"
autoPopup:SetParent(optionsFrameHolder)
autoPopup:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -16)
WhoLootsOptionsEntries.AutoClose = autoPopup

-- Option text
local autoPopup_Desc = optionsFrameHolder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
autoPopup_Desc:SetPoint("TOPLEFT", autoPopup, "BOTTOMLEFT", 15, -8)
autoPopup_Desc:SetText("Closes the header frame when empty.")
autoPopup_Desc:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
autoPopup_Desc:SetTextColor(0.7, 0.7, 0.7)
autoPopup_Desc:SetParent(optionsFrameHolder)


-- Checkbox: Lock Window
local lockWindow = CreateFrame("CheckButton", "WhoLootsLockWindow", WhoLootsOptionsFrame, "InterfaceOptionsCheckButtonTemplate")
lockWindow:SetScript("OnClick", function(self)
    local tick = self:GetChecked()
    WhoGotLootsSavedData.LockWindow = tick
    if tick then
        PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    else
        PlaySound(857) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
    end

    if tick then
        WhoLootData.MainFrame:EnableMouse(false)
        WhoLootData.MainFrame:SetMovable(false)
    else
        WhoLootData.MainFrame:EnableMouse(true)
        WhoLootData.MainFrame:SetMovable(true)
    end
end)
lockWindow.label = _G[lockWindow:GetName() .. "Text"]
lockWindow.label:SetText("Lock Window")
lockWindow.tooltipText = "Locks the window in place"
lockWindow.tooltipRequirement = "Lock Window"
lockWindow:SetPoint("TOPLEFT", autoPopup_Desc, "BOTTOMLEFT", -15, -16)
lockWindow:SetParent(optionsFrameHolder)
WhoLootsOptionsEntries.LockWindow = lockWindow

-- Option text
local lockWindow_Desc = optionsFrameHolder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
lockWindow_Desc:SetPoint("TOPLEFT", lockWindow, "BOTTOMLEFT", 15, -8)
lockWindow_Desc:SetText("Locks the window in place.")
lockWindow_Desc:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
lockWindow_Desc:SetTextColor(0.7, 0.7, 0.7)
lockWindow_Desc:SetParent(optionsFrameHolder)

-- Checkbox: Hide Unequippable Items
local hideUnequippable = CreateFrame("CheckButton", "WhoLootsHideUnequippable", WhoLootsOptionsFrame, "InterfaceOptionsCheckButtonTemplate")
hideUnequippable:SetScript("OnClick", function(self)
    local tick = self:GetChecked()
    WhoGotLootsSavedData.HideUnequippable = tick
    if tick then
        PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    else
        PlaySound(857) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
    end
end)
hideUnequippable.label = _G[hideUnequippable:GetName() .. "Text"]
hideUnequippable.label:SetText("Hide Unequippable Items")
hideUnequippable.tooltipText = "Hides items that cannot be equipped"
hideUnequippable.tooltipRequirement = "Hide Unequippable Items"
hideUnequippable:SetPoint("TOPLEFT", lockWindow_Desc, "BOTTOMLEFT", -15, -16)
hideUnequippable:SetParent(optionsFrameHolder)
WhoLootsOptionsEntries.HideUnequippable = hideUnequippable

-- Option text
local hideUnequippable_Desc = optionsFrameHolder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
hideUnequippable_Desc:SetPoint("TOPLEFT", hideUnequippable, "BOTTOMLEFT", 15, -8)
hideUnequippable_Desc:SetText("Hides items that cannot be equipped.")
hideUnequippable_Desc:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
hideUnequippable_Desc:SetTextColor(0.7, 0.7, 0.7)
hideUnequippable_Desc:SetParent(optionsFrameHolder)

-- Scale Slider Title
local scaleSlider_Desc = optionsFrameHolder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
scaleSlider_Desc:SetPoint("TOPLEFT", hideUnequippable_Desc, "BOTTOMLEFT", 0, -26)
scaleSlider_Desc:SetText("Adjust the scale of the window.")
scaleSlider_Desc:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
scaleSlider_Desc:SetParent(optionsFrameHolder)

-- Scale Slider
local scaleSlider = CreateFrame("Slider", "WhoLootsScaleSlider", WhoLootsOptionsFrame, "OptionsSliderTemplate")
scaleSlider:SetWidth(WhoLootsOptionsFrame:GetWidth() - 32)
scaleSlider:SetHeight(10)
scaleSlider:SetOrientation("HORIZONTAL")
scaleSlider:SetPoint("TOPLEFT", scaleSlider_Desc, "BOTTOMLEFT", -5, -12)
scaleSlider:SetMinMaxValues(0.5, 2)
scaleSlider:SetValueStep(0.1)   
scaleSlider:SetObeyStepOnDrag(true)

scaleSlider:SetScript("OnMouseUp", function(self, button)
    local value = self:GetValue()
    WhoGotLootsSavedData.SavedSize = value
    WhoLootData.MainFrame:SetScale(value)
end)
WhoLootsOptionsEntries.ScaleSlider = scaleSlider


WhoLootsOptionsFrame:Hide()