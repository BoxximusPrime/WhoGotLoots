WhoLootsOptionsEntries = {}

-- Create the options frame
WhoLootsOptionsFrame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
WhoLootsOptionsFrame.name = "WhoLootsOptionsFrame"
WhoLootsOptionsFrame:SetSize(200, 385)
WhoLootData.OptionsFrame = WhoLootsOptionsFrame

-- Make us a child of MainFrame, so we move with it.
WhoLootsOptionsFrame:SetParent(WhoLootData.MainFrame)
WhoLootsOptionsFrame:ClearAllPoints()
WhoLootsOptionsFrame:SetPoint("TOPLEFT", WhoLootData.MainFrame, "TOPRIGHT", 0, 0)
WhoLootsOptionsFrame:EnableMouse(true)

-- Handle Events --
function WhoLootsOptionsEntries.LoadOptions()

    -- Set the initial values of the options
    if WhoGotLootsSavedData.AutoCloseOnEmpty == nil then WhoGotLootsSavedData.AutoCloseOnEmpty = true end
    if WhoGotLootsSavedData.LockWindow == nil then WhoGotLootsSavedData.LockWindow = false end
    if WhoGotLootsSavedData.HideUnequippable == nil then WhoGotLootsSavedData.HideUnequippable = true end
    if WhoGotLootsSavedData.SavedSize == nil then WhoGotLootsSavedData.SavedSize = 1 end
    if WhoGotLootsSavedData.SoundEnabled == nil then WhoGotLootsSavedData.SoundEnabled = true end
    if WhoGotLootsSavedData.ShowOwnLoot == nil then WhoGotLootsSavedData.ShowOwnLoot = true end
    if WhoGotLootsSavedData.ShowDuringRaid == nil then WhoGotLootsSavedData.ShowDuringRaid = true end
    if WhoGotLootsSavedData.ShowDuringLFR == nil then WhoGotLootsSavedData.ShowDuringLFR = false end

    WhoLootsOptionsEntries.AutoClose:SetChecked(WhoGotLootsSavedData.AutoCloseOnEmpty)
    WhoLootsOptionsEntries.LockWindow:SetChecked(WhoGotLootsSavedData.LockWindow)
    WhoLootsOptionsEntries.HideUnequippable:SetChecked(WhoGotLootsSavedData.HideUnequippable)
    WhoLootsOptionsEntries.SoundToggle:SetChecked(WhoGotLootsSavedData.SoundEnabled)
    WhoLootsOptionsEntries.ShowOwnLoot:SetChecked(WhoGotLootsSavedData.ShowOwnLoot)
    WhoLootsOptionsEntries.ScaleSlider:SetValue(WhoGotLootsSavedData.SavedSize)
    WhoLootsOptionsEntries.ShowDuringRaid:SetChecked(WhoGotLootsSavedData.ShowDuringRaid)
    WhoLootsOptionsEntries.ShowDuringLFR:SetChecked(WhoGotLootsSavedData.ShowDuringLFR)

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
bg = CreateFrame("Frame", nil, WhoLootsOptionsFrame);
bg:SetAllPoints(true);
bg:SetFrameLevel(WhoLootsOptionsFrame:GetFrameLevel());
WGLUICreator.SetUpSlice(bg, "genericChamferedBackground", "backdrop", 0, nil)
-- WGLUICreator.ColorBGSlicedFrame(bg, "backdrop", 0.078, 0.078, 0.078, 0.95)
WGLUICreator.ColorBGSlicedFrame(bg, "backdrop", 0.06, 0.06, 0.05, 0.95)

-- Create the border
border = CreateFrame("Frame", nil, WhoLootsOptionsFrame);
border:SetAllPoints(true);
border:SetFrameLevel(WhoLootsOptionsFrame:GetFrameLevel() + 1);
WGLUICreator.SetUpSlice(border, "genericChamferedBorder", "border", 0, nil)
WGLUICreator.ColorBGSlicedFrame(border, "border", 0.4, 0.4, 0.4, 1)

-- Create a title
local title = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_Title")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Options")

-- Chekcbox: Auto Close Window
local autoClose = CreateFrame("Button", nil, WhoLootsOptionsFrame, "WGLCheckBoxTemplate")
WGLUICreator.AddOnClick(autoClose, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.AutoCloseOnEmpty = tick; end)
autoClose:SetText("Auto Close")
autoClose:SetParent(WhoLootsOptionsFrame)
autoClose:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -16)
WhoLootsOptionsEntries.AutoClose = autoClose
-- Option text
local autoClose_Desc = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
autoClose_Desc:SetPoint("TOPLEFT", autoClose, "BOTTOMLEFT", 15, -8)
autoClose_Desc:SetText("Closes the header frame when empty.")
autoClose_Desc:SetParent(WhoLootsOptionsFrame)


-- Checkbox: Lock Window
local lockWindow = CreateFrame("Button", nil, WhoLootsOptionsFrame, "WGLCheckBoxTemplate")
WGLUICreator.AddOnClick(lockWindow, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.LockWindow = tick; WhoLootData.MainFrame:LockWindow(tick); end)
lockWindow.Label:SetText("Lock Window")
lockWindow:SetPoint("TOPLEFT", autoClose_Desc, "BOTTOMLEFT", -15, -16)
lockWindow:SetParent(WhoLootsOptionsFrame)
WhoLootsOptionsEntries.LockWindow = lockWindow
-- Option text
local lockWindow_Desc = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
lockWindow_Desc:SetPoint("TOPLEFT", lockWindow, "BOTTOMLEFT", 15, -8)
lockWindow_Desc:SetText("Locks the window in place.")
lockWindow_Desc:SetParent(WhoLootsOptionsFrame)

-- Checkbox: Show Own Loot
local ShowOwnLoot = CreateFrame("Button", nil, WhoLootsOptionsFrame, "WGLCheckBoxTemplate")
WGLUICreator.AddOnClick(ShowOwnLoot, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.ShowOwnLoot = tick; end)
ShowOwnLoot.Label:SetText("Show Own Loot")
ShowOwnLoot:SetPoint("TOPLEFT", lockWindow_Desc, "BOTTOMLEFT", -15, -16)
ShowOwnLoot:SetParent(WhoLootsOptionsFrame)
WhoLootsOptionsEntries.ShowOwnLoot = ShowOwnLoot
-- Option text
local showOwnLoot_Desc = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
showOwnLoot_Desc:SetPoint("TOPLEFT", ShowOwnLoot, "BOTTOMLEFT", 15, -8)
showOwnLoot_Desc:SetText("Show your own loot in the window.")
showOwnLoot_Desc:SetParent(WhoLootsOptionsFrame)


-- Checkbox: Hide Unequippable Items
local HideUnequippable = CreateFrame("Button", nil, WhoLootsOptionsFrame, "WGLCheckBoxTemplate")
WGLUICreator.AddOnClick(HideUnequippable, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.HideUnequippable = tick; end)
HideUnequippable.Label:SetText("Hide Unequippable")
HideUnequippable:SetPoint("TOPLEFT", showOwnLoot_Desc, "BOTTOMLEFT", -15, -16)
HideUnequippable:SetParent(WhoLootsOptionsFrame)
WhoLootsOptionsEntries.HideUnequippable = HideUnequippable
-- Option text
local hideUnequippable_Desc = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
hideUnequippable_Desc:SetPoint("TOPLEFT", HideUnequippable, "BOTTOMLEFT", 15, -8)
hideUnequippable_Desc:SetText("Hides items that cannot be equipped.")
hideUnequippable_Desc:SetParent(WhoLootsOptionsFrame)

-- Checkbox: Show During Raid
local ShowDuringRaid = CreateFrame("Button", nil, WhoLootsOptionsFrame, "WGLCheckBoxTemplate")
WGLUICreator.AddOnClick(ShowDuringRaid, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.ShowDuringRaid = tick; end)
ShowDuringRaid.Label:SetText("Show During Raid")
ShowDuringRaid:SetPoint("TOPLEFT", hideUnequippable_Desc, "BOTTOMLEFT", -15, -16)
ShowDuringRaid:SetParent(WhoLootsOptionsFrame)
WhoLootsOptionsEntries.ShowDuringRaid = ShowDuringRaid
-- Option text
local showDuringRaid_Desc = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
showDuringRaid_Desc:SetPoint("TOPLEFT", ShowDuringRaid, "BOTTOMLEFT", 15, -8)
showDuringRaid_Desc:SetText("Show loot while in a raid.")

-- CheckBox: Also show for LFR
local ShowDuringLFR = CreateFrame("Button", nil, WhoLootsOptionsFrame, "WGLCheckBoxTemplate")
WGLUICreator.AddOnClick(ShowDuringLFR, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.ShowDuringLFR = tick; end)
ShowDuringLFR.Label:SetText("Show During LFR")
ShowDuringLFR:SetPoint("TOPLEFT", showDuringRaid_Desc, "BOTTOMLEFT", 0, -10)
ShowDuringLFR:SetParent(WhoLootsOptionsFrame)
WhoLootsOptionsEntries.ShowDuringLFR = ShowDuringLFR
-- Option text
local showDuringLFR_Desc = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
showDuringLFR_Desc:SetPoint("TOPLEFT", ShowDuringLFR, "BOTTOMLEFT", 15, -8)
showDuringLFR_Desc:SetText("Show loot while in LFR.")


-- Sound Toggle
local SoundToggle = CreateFrame("Button", nil, WhoLootsOptionsFrame, "WGLCheckBoxTemplate")
WGLUICreator.AddOnClick(SoundToggle, function(self) local tick = self:GetChecked(); WhoGotLootsSavedData.SoundEnabled = tick; end)
SoundToggle.Label:SetText("Enable Sound")
SoundToggle:SetPoint("TOPLEFT", showDuringLFR_Desc, "BOTTOMLEFT", -30, -16)
SoundToggle:SetParent(WhoLootsOptionsFrame)
WhoLootsOptionsEntries.SoundToggle = SoundToggle

-- Option text
local soundToggle_Desc = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_General")
soundToggle_Desc:SetPoint("TOPLEFT", SoundToggle, "BOTTOMLEFT", 15, -8)
soundToggle_Desc:SetText("Enable the looting sound effect.")
soundToggle_Desc:SetParent(WhoLootsOptionsFrame)


-- Scale Slider Title
local scaleSlider_Desc = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_Checkbox")
scaleSlider_Desc:SetPoint("TOPLEFT", soundToggle_Desc, "BOTTOMLEFT", -10, -20)
scaleSlider_Desc:SetText("Adjust the scale of the window.")
scaleSlider_Desc:SetParent(WhoLootsOptionsFrame)

-- Scale Slider
local scaleSlider = CreateFrame("Slider", nil, WhoLootsOptionsFrame, "WGLSlider")
scaleSlider:SetWidth(WhoLootsOptionsFrame:GetWidth() - 32)
scaleSlider:SetHeight(5)
scaleSlider:SetPoint("TOPLEFT", scaleSlider_Desc, "BOTTOMLEFT", 0, -12)
scaleSlider:SetMinMaxValues(0.5, 2)
scaleSlider:SetValueStep(0.1)
scaleSlider:SetObeyStepOnDrag(true)
scaleSlider.KeyLabel:SetText("0.5")
scaleSlider.KeyLabel2:SetText("2.0")

-- Show the version number at the bottom right of the options frame.
local version = WhoLootsOptionsFrame:CreateFontString(nil, "ARTWORK", "WGLFont_VersNum")
version:SetPoint("BOTTOMRIGHT", -6, 6)
version:SetText("v" .. WhoLootData.Version)


scaleSlider:SetScript("OnMouseUp", function(self, button)
    local value = self:GetValue()
    WhoGotLootsSavedData.SavedSize = value
    WhoLootData.MainFrame:SetScale(value)
    WhoLootData.MainFrame.cursorFrame:SetScale(value)
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

--WhoLootsOptionsFrame:Hide()