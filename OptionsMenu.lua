WhoLootsOptionsEntries = {}

-- Create the options frame
WhoLootsOptionsFrame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
WhoLootsOptionsFrame.name = "WhoLootsOptionsFrame"
WhoLootsOptionsFrame:SetSize(220, 395)
WhoLootData.OptionsFrame = WhoLootsOptionsFrame

-- Make us a child of MainFrame, so we move with it.
WhoLootsOptionsFrame:SetParent(WhoLootData.MainFrame)
WhoLootsOptionsFrame:ClearAllPoints()
WhoLootsOptionsFrame:SetPoint("TOPLEFT", WhoLootData.MainFrame, "TOPRIGHT", 0, 0)
WhoLootsOptionsFrame:EnableMouse(true)

WGLUIBuilder = WGLUIBuilder or {}

-- Handle Events --
function WhoLootsOptionsEntries.LoadOptions()

    -- Set the initial values of the options
    if WhoGotLootsSavedData.AutoCloseOnEmpty == nil then WhoGotLootsSavedData.AutoCloseOnEmpty = true end
    if WhoGotLootsSavedData.LockWindow == nil then WhoGotLootsSavedData.LockWindow = false end
    if WhoGotLootsSavedData.HideUnequippable == nil then WhoGotLootsSavedData.HideUnequippable = false end
    if WhoGotLootsSavedData.SavedSize == nil then WhoGotLootsSavedData.SavedSize = 1 end
    if WhoGotLootsSavedData.SoundEnabled == nil then WhoGotLootsSavedData.SoundEnabled = true end
    if WhoGotLootsSavedData.ShowOwnLoot == nil then WhoGotLootsSavedData.ShowOwnLoot = true end
    if WhoGotLootsSavedData.ShowDuringRaid == nil then WhoGotLootsSavedData.ShowDuringRaid = true end
    if WhoGotLootsSavedData.ShowDuringLFR == nil then WhoGotLootsSavedData.ShowDuringLFR = false end
    if WhoGotLootsSavedData.MinQuality == nil then WhoGotLootsSavedData.MinQuality = 3 end

    WhoLootsOptionsEntries.AutoClose:SetChecked(WhoGotLootsSavedData.AutoCloseOnEmpty)
    WhoLootsOptionsEntries.LockWindow:SetChecked(WhoGotLootsSavedData.LockWindow)
    WhoLootsOptionsEntries.HideUnequippable:SetChecked(WhoGotLootsSavedData.HideUnequippable)
    WhoLootsOptionsEntries.SoundToggle:SetChecked(WhoGotLootsSavedData.SoundEnabled)
    WhoLootsOptionsEntries.ShowOwnLoot:SetChecked(WhoGotLootsSavedData.ShowOwnLoot)
    WhoLootsOptionsEntries.ScaleSlider:SetValue(WhoGotLootsSavedData.SavedSize)
    WhoLootsOptionsEntries.ShowDuringRaid:SetChecked(WhoGotLootsSavedData.ShowDuringRaid)
    WhoLootsOptionsEntries.ShowDuringLFR:SetChecked(WhoGotLootsSavedData.ShowDuringLFR)
    WhoLootsOptionsEntries.MinQualitySlider:SetValue(WhoGotLootsSavedData.MinQuality)

    if WhoGotLootsSavedData.WhisperMessage ~= nil then
        WhoLootsOptionsFrame.whisperPreview:SetText(WhoGotLootsSavedData.WhisperMessage)
        WGLUIBuilder.WhisperEditor.EditBox:SetText(WhoGotLootsSavedData.WhisperMessage)
    else
        WhoGotLootsSavedData.WhisperMessage = WGLUIBuilder.DefaultWhisperMessage
        WGLUIBuilder.WhisperEditor.EditBox:SetText(WGLUIBuilder.DefaultWhisperMessage)
    end

    -- Set the minimum item quality text color
    local r, g, b, hex = C_Item.GetItemQualityColor(WhoGotLootsSavedData.MinQuality)
    WhoLootsOptionsEntries.MinQualitySlider.KeyLabel:SetText(WGLU.ItemQualityToText(WhoGotLootsSavedData.MinQuality))

    -- Set the moveable state of the main frame
    WhoLootData.MainFrame:LockWindow(WhoGotLootsSavedData.LockWindow)
end

function WhoLootsOptionsEntries.OpenOptions()
    if WhoLootsOptionsFrame:IsVisible() then
        WhoLootsOptionsFrame:Hide()
    else
        -- Fade in the options frame, and make it slide into view.
        WhoLootsOptionsFrame:Show()
        WhoLootsOptionsFrame:SetAlpha(0)
        WhoLootsOptionsFrame:ClearAllPoints()

        -- Determine if we have enough space on the right side of the main frame.
        local WhichPoint = "TOPLEFT"
        local frameWidth = WhoLootData.MainFrame:GetWidth()
        local optionsFrameWidth = WhoLootsOptionsFrame:GetWidth()
        local screenWidth = GetScreenWidth()
        local MainFrameX, MainFrameY = WhoLootData.MainFrame:GetCenter()

        local estimatedX = MainFrameX + optionsFrameWidth

        -- Do we have enough room on the right?
        if estimatedX < screenWidth then
            WhoLootsOptionsFrame:SetPoint("TOPLEFT", WhoLootData.MainFrame, "TOPRIGHT", 0, 0)
            WhichPoint = "TOPLEFT"
        else
            WhoLootsOptionsFrame:SetPoint("TOPRIGHT", WhoLootData.MainFrame, "TOPLEFT", 0, 0)
            WhichPoint = "TOPRIGHT"
        end

        WhoLootsOptionsFrame:SetFrameStrata("HIGH")
        WhoLootsOptionsFrame:SetScript("OnUpdate", function(self, elapsed)
            local alpha = self:GetAlpha()
            if alpha < 1 then
                local clamped = math.min(1, alpha + elapsed * 4)
                self:SetAlpha(clamped)
                if WhichPoint == "TOPRIGHT" then
                    self:SetPoint(WhichPoint, WhoLootData.MainFrame, "TOPLEFT", (1 - clamped) * -26 - 40, 0)
                else
                    self:SetPoint(WhichPoint, WhoLootData.MainFrame, "TOPRIGHT", (1 - clamped) * 26 + 40, 0)
                end
            else
                self:SetScript("OnUpdate", nil)
            end
        end)

        PlaySound(170827)
    end
end

-- Create the background
local bg = CreateFrame("Frame", nil, WhoLootsOptionsFrame);
bg:SetAllPoints();
bg:SetFrameLevel(WhoLootsOptionsFrame:GetFrameLevel());
WGLUIBuilder.DrawSlicedBG(bg, "OptionsWindowBG", "backdrop", 0)
WGLUIBuilder.ColorBGSlicedFrame(bg, "backdrop", 1, 1, 1, 0.95)

-- Create the border
local border = CreateFrame("Frame", nil, WhoLootsOptionsFrame);
border:SetAllPoints();
border:SetFrameLevel(WhoLootsOptionsFrame:GetFrameLevel() + 1);
WGLUIBuilder.DrawSlicedBG(border, "EdgedBorder", "border", 0)
WGLUIBuilder.ColorBGSlicedFrame(border, "border", 0.4, 0.4, 0.4, 1)

-- Create a title
local title = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_Title")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Options")

-- Create the scroll frame
local scrollFrame = CreateFrame("ScrollFrame", "ScrollFrame", WhoLootsOptionsFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -50)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

-- Create the content frame
local contentFrame = CreateFrame("Frame", "ContentFrame", scrollFrame)

-- Set the scroll child
scrollFrame:SetScrollChild(contentFrame)

-- Create a title for the whisper message
local whisperTitle = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_Checkbox")
whisperTitle:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -6)
whisperTitle:SetText("Whisper Message")

-- Create a preview of the whisper message
WhoLootsOptionsFrame.whisperPreview = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
WhoLootsOptionsFrame.whisperPreview:SetPoint("TOPLEFT", whisperTitle, "BOTTOMLEFT", 0, -6)
WhoLootsOptionsFrame.whisperPreview:SetText("loading")
WhoLootsOptionsFrame.whisperPreview:SetJustifyH("LEFT")
WhoLootsOptionsFrame.whisperPreview:SetWidth(scrollFrame:GetWidth() - 20)

-- Set Whisper Message Button
local whisperMessageBtn = CreateFrame("Button", nil, contentFrame, "WGLGeneralButton")
whisperMessageBtn:SetText("Set Whisper Message")
whisperMessageBtn:SetPoint("TOPLEFT", WhoLootsOptionsFrame.whisperPreview, "BOTTOMLEFT", 0, -6)
whisperMessageBtn:SetSize(110, 16)
whisperMessageBtn:SetScript("OnClick", function(self)
    WGLUIBuilder.WhisperEditor:Show()
    PlaySound(170827)
end)


-- Checkbox: Auto Close Window
local autoClose = CreateFrame("Button", nil, contentFrame, "WGLCheckBoxTemplate")
WGLUIBuilder.AddOnClick(autoClose, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.AutoCloseOnEmpty = tick; end)
autoClose:SetText("Auto Close")
autoClose:SetParent(contentFrame)
autoClose:SetPoint("TOPLEFT", whisperMessageBtn, "BOTTOMLEFT", 0, -16)
WhoLootsOptionsEntries.AutoClose = autoClose
-- Option text
local autoClose_Desc = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
autoClose_Desc:SetPoint("TOPLEFT", autoClose, "BOTTOMLEFT", 15, -8)
autoClose_Desc:SetText("Closes the header frame when empty.")
autoClose_Desc:SetParent(contentFrame)


-- Checkbox: Lock Window
local lockWindow = CreateFrame("Button", nil, contentFrame, "WGLCheckBoxTemplate")
WGLUIBuilder.AddOnClick(lockWindow, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.LockWindow = tick; WhoLootData.MainFrame:LockWindow(tick); end)
lockWindow.Label:SetText("Lock Window")
lockWindow:SetPoint("TOPLEFT", autoClose_Desc, "BOTTOMLEFT", -15, -16)
lockWindow:SetParent(contentFrame)
WhoLootsOptionsEntries.LockWindow = lockWindow
-- Option text
local lockWindow_Desc = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
lockWindow_Desc:SetPoint("TOPLEFT", lockWindow, "BOTTOMLEFT", 15, -8)
lockWindow_Desc:SetText("Locks the window in place.")
lockWindow_Desc:SetParent(contentFrame)

-- Checkbox: Show Own Loot
local ShowOwnLoot = CreateFrame("Button", nil, contentFrame, "WGLCheckBoxTemplate")
WGLUIBuilder.AddOnClick(ShowOwnLoot, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.ShowOwnLoot = tick; end)
ShowOwnLoot.Label:SetText("Show Own Loot")
ShowOwnLoot:SetPoint("TOPLEFT", lockWindow_Desc, "BOTTOMLEFT", -15, -16)
ShowOwnLoot:SetParent(contentFrame)
WhoLootsOptionsEntries.ShowOwnLoot = ShowOwnLoot
-- Option text
local showOwnLoot_Desc = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
showOwnLoot_Desc:SetPoint("TOPLEFT", ShowOwnLoot, "BOTTOMLEFT", 15, -8)
showOwnLoot_Desc:SetText("Show your own loot in the window.")
showOwnLoot_Desc:SetParent(contentFrame)


-- Checkbox: Hide Unequippable Items
local HideUnequippable = CreateFrame("Button", nil, contentFrame, "WGLCheckBoxTemplate")
WGLUIBuilder.AddOnClick(HideUnequippable, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.HideUnequippable = tick; end)
HideUnequippable.Label:SetText("Hide Unequippable")
HideUnequippable:SetPoint("TOPLEFT", showOwnLoot_Desc, "BOTTOMLEFT", -15, -16)
HideUnequippable:SetParent(contentFrame)
WhoLootsOptionsEntries.HideUnequippable = HideUnequippable
-- Option text
local hideUnequippable_Desc = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
hideUnequippable_Desc:SetPoint("TOPLEFT", HideUnequippable, "BOTTOMLEFT", 15, -8)
hideUnequippable_Desc:SetText("Hides items that cannot be equipped.")
hideUnequippable_Desc:SetParent(contentFrame)

-- Slider: Set the minimum item quality (between 1, and 5)
-- Create the label text.
local minQualityLabel = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_Checkbox")
minQualityLabel:SetPoint("TOPLEFT", hideUnequippable_Desc, "BOTTOMLEFT", -10, -20)
minQualityLabel:SetText("Minimum Item Quality")
minQualityLabel:SetParent(contentFrame)

local minQualitySlider = CreateFrame("Slider", nil, contentFrame, "WGLSlider")
minQualitySlider:SetWidth(150)
minQualitySlider:SetHeight(5)
minQualitySlider:SetPoint("TOPLEFT", minQualityLabel, "BOTTOMLEFT", 0, -20)
minQualitySlider:SetMinMaxValues(1, 4)
minQualitySlider:SetValueStep(1)
minQualitySlider:SetObeyStepOnDrag(true)

-- Create a function to handle the slider's value change
minQualitySlider:SetScript("OnMouseUp", function(self, button)
    local value = self:GetValue()
    WhoGotLootsSavedData.MinQuality = value

    -- set the thumb text color to match the quality of the item.
    self.KeyLabel:SetText(WGLU.ItemQualityToText(value))

end)
WGLU.OverrideEvent(minQualitySlider, "OnValueChanged", function(self, value)
    self.KeyLabel:SetText(WGLU.ItemQualityToText(value))
end)


WhoLootsOptionsEntries.MinQualitySlider = minQualitySlider

-- Checkbox: Show During Raid
local ShowDuringRaid = CreateFrame("Button", nil, contentFrame, "WGLCheckBoxTemplate")
WGLUIBuilder.AddOnClick(ShowDuringRaid, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.ShowDuringRaid = tick; end)
ShowDuringRaid.Label:SetText("Show During Raid")
ShowDuringRaid:SetPoint("TOPLEFT", minQualitySlider, "BOTTOMLEFT", 0, -28)
ShowDuringRaid:SetParent(contentFrame)
WhoLootsOptionsEntries.ShowDuringRaid = ShowDuringRaid
-- Option text
local showDuringRaid_Desc = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
showDuringRaid_Desc:SetPoint("TOPLEFT", ShowDuringRaid, "BOTTOMLEFT", 15, -8)
showDuringRaid_Desc:SetText("Show loot while in a raid.")

-- CheckBox: Also show for LFR
local ShowDuringLFR = CreateFrame("Button", nil, contentFrame, "WGLCheckBoxTemplate")
WGLUIBuilder.AddOnClick(ShowDuringLFR, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.ShowDuringLFR = tick; end)
ShowDuringLFR.Label:SetText("Show During LFR")
ShowDuringLFR:SetPoint("TOPLEFT", showDuringRaid_Desc, "BOTTOMLEFT", 0, -10)
ShowDuringLFR:SetParent(contentFrame)
WhoLootsOptionsEntries.ShowDuringLFR = ShowDuringLFR
-- Option text
local showDuringLFR_Desc = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
showDuringLFR_Desc:SetPoint("TOPLEFT", ShowDuringLFR, "BOTTOMLEFT", 15, -8)
showDuringLFR_Desc:SetText("Show loot while in LFR.")


-- Sound Toggle
local SoundToggle = CreateFrame("Button", nil, contentFrame, "WGLCheckBoxTemplate")
WGLUIBuilder.AddOnClick(SoundToggle, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.SoundEnabled = tick; end)
SoundToggle.Label:SetText("Enable Sound")
SoundToggle:SetPoint("TOPLEFT", showDuringLFR_Desc, "BOTTOMLEFT", -30, -16)
SoundToggle:SetParent(contentFrame)
WhoLootsOptionsEntries.SoundToggle = SoundToggle
-- Option text
local soundToggle_Desc = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
soundToggle_Desc:SetPoint("TOPLEFT", SoundToggle, "BOTTOMLEFT", 15, -8)
soundToggle_Desc:SetText("Enable the looting sound effect.")
soundToggle_Desc:SetParent(contentFrame)

-- Scale Slider Title
local scaleSlider_Desc = contentFrame:CreateFontString(nil, "ARTWORK", "WGLFont_Checkbox")
scaleSlider_Desc:SetPoint("TOPLEFT", soundToggle_Desc, "BOTTOMLEFT", -10, -20)
scaleSlider_Desc:SetText("Adjust the scale of the window.")
scaleSlider_Desc:SetParent(contentFrame)

-- Scale Slider
local scaleSlider = CreateFrame("Slider", nil, contentFrame, "WGLSlider")
scaleSlider:SetWidth(150)
scaleSlider:SetHeight(5)
scaleSlider:SetPoint("TOPLEFT", scaleSlider_Desc, "BOTTOMLEFT", 0, -12)
scaleSlider:SetMinMaxValues(0.5, 2)
scaleSlider:SetValueStep(0.1)
scaleSlider:SetObeyStepOnDrag(true)
scaleSlider.KeyLabel:SetText("0.5")
scaleSlider.KeyLabel2:SetText("2.0")



-- Now, set the content frame size
contentFrame:SetSize(260, 430)

-- Show the version number at the bottom right of the options frame.
local version = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_VersNum")
version:SetPoint("BOTTOMLEFT", 6, 6)
version:SetText("v" .. WhoLootDataVers)


scaleSlider:SetScript("OnMouseUp", function(self, button)
    local value = self:GetValue()
    WhoGotLootsSavedData.SavedSize = value
    WhoLootData.MainFrame:SetScale(value)
    WhoLootData.MainFrame.infoTooltip:SetScale(value)
    WhoLootData.MainFrame.cursorFrame:SetScale(value)
    WGLUIBuilder.WhisperEditor:SetScale(value)
end)
WhoLootsOptionsEntries.ScaleSlider = scaleSlider


-- Close Button
local closeBtn = CreateFrame("Button", nil, WhoLootData.OptionsFrame, "WGLCloseBtn")
closeBtn:SetPoint("TOPRIGHT", WhoLootData.OptionsFrame, "TOPRIGHT", -6, -6)
closeBtn:SetSize(12, 12)
closeBtn:SetScript("OnClick", function(self)
    PlaySound(856)
    WhoLootsOptionsFrame:Hide()
end)

WhoLootsOptionsFrame:Hide()