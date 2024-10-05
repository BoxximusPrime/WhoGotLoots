WGLUIBuilder = WGLUIBuilder or {}

WGLUIBuilder.WhisperMsgMaxChars = 160
WGLUIBuilder.DefaultWhisperMessage = "Greetings, %n! I sense you hold %i. If it does not align with your destiny, would you consider trading it? Many thanks!"
WGLUIBuilder.TempWhisperMesage = ""

function WGLUIBuilder.CreateMainFrame()

    -- Create the main frame.
    local mainFrame = CreateFrame("Frame", nil, UIParent)
    mainFrame:SetSize(130, 50)
    mainFrame:SetPoint("CENTER", 0, 0)

    -- Create the background texture
    local bgTexture = mainFrame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetSize(250, 125)
    bgTexture:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
    bgTexture:SetTexture("Interface\\AddOns\\WhoGotLoots\\Art\\MainWindowBG.tga")

    -- Create the options btn.
    local optionsBtn = CreateFrame("Button", nil, mainFrame, "WGLOptionsBtn")
    optionsBtn:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 9, -27)
    optionsBtn:SetSize(12, 12)
    optionsBtn:SetScript("OnClick", function()
        WhoLootsOptionsEntries.OpenOptions()
    end)
    optionsBtn:SetFrameLevel(3)

    -- Create the close button.
    local closeBtn = CreateFrame("Button", nil, mainFrame, "WGLCloseBtn")
    closeBtn:SetPoint("TOP", optionsBtn, "BOTTOM", 0, 30)
    closeBtn:SetSize(12, 12)
    closeBtn:SetScript("OnClick", function(self)
        WhoLootData.MainFrame:Close()
    end)
    closeBtn:SetFrameLevel(3)

    -- Create the info button. Align it to the left of the main frame.
    mainFrame.infoBtn = CreateFrame("Button", nil, mainFrame, "WGLInfoBtn")
    mainFrame.infoBtn:SetPoint("TOPRIGHT", mainFrame, "TOPLEFT", -9, -27)
    mainFrame.infoBtn:SetSize(12, 12)
    mainFrame.infoBtn:SetFrameLevel(3)
    mainFrame.infoBtn:SetScript("OnEnter", function()
        mainFrame.infoBtn.Btn:SetVertexColor(1, 1, 1, 1);
        -- Fade the tooltip in over 0.2 seconds.
        mainFrame.infoTooltip:Show()
        mainFrame.infoTooltip:SetAlpha(0)
        mainFrame.infoTooltip:SetScript("OnUpdate", function(self, elapsed)
            self:SetAlpha(WGLU.Clamp(self:GetAlpha() + elapsed * 5, 0, 1))
        end)
    end)
    mainFrame.infoBtn:SetScript("OnLeave", function()
        mainFrame.infoBtn.Btn:SetVertexColor(0.7, 0.7, 0.7, 1);
        -- Fade the tooltip out over 1 seconds.
        mainFrame.infoTooltip:SetScript("OnUpdate", function(self, elapsed)
            self:SetAlpha(WGLU.Clamp(self:GetAlpha() - elapsed * 2, 0, 1))
            if self:GetAlpha() == 0 then
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end)

    -- Create an information tooltip to show when the info button is hovered.
    local tipWidth = 295
    local tooltipText = "|cFFFFFFFFKey Bindings|r\n   - Double left click to equip the item (if it's your loot).\n   - Shift + left click to link the item in chat.\n   - Right click to dismiss the item.\n   - Alt + left click to try and inspect the player.\n   - Ctrl + left click to open trade with the person.\n   - Middle click to whisper them with the set whissper messsage in options.\n|CFFFFFFFFTips|r\n   - Rings and Trinket will compare to your lowest item level one."
    mainFrame.infoTooltip = CreateFrame("Frame", nil, UIParent)
    mainFrame.infoTooltip:SetSize(tipWidth, 900)
    mainFrame.infoTooltip:SetPoint("TOP", mainFrame, "TOP", 0, -mainFrame:GetHeight() + 16)
    mainFrame.infoTooltip:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    mainFrame.infoTooltip.Text = mainFrame.infoTooltip:CreateFontString(nil, "OVERLAY", "WGLFont_Tooltip")
    mainFrame.infoTooltip.Text:SetSize(tipWidth, 999)
    mainFrame.infoTooltip.Text:SetJustifyH("LEFT")
    mainFrame.infoTooltip.Text:SetJustifyV("TOP")
    mainFrame.infoTooltip.Text:SetSpacing(3)
    mainFrame.infoTooltip.Text:SetText(tooltipText)
    --mainFrame.infoTooltip.Text:SetHeight(mainFrame.infoTooltip.Text:GetStringHeight() + 35)
    mainFrame.infoTooltip.Text:SetHeight(127)
    mainFrame.infoTooltip:SetHeight(mainFrame.infoTooltip.Text:GetHeight())
    mainFrame.infoTooltip:SetWidth(mainFrame.infoTooltip.Text:GetWidth() + 10)
    mainFrame.infoTooltip:Hide()

    -- Now rescale the tooltip to fit the text.
    mainFrame.infoTooltip.Text:SetPoint("TOPLEFT", mainFrame.infoTooltip, "TOPLEFT", 15, -15)
    mainFrame.infoTooltip.Text:SetPoint("BOTTOMRIGHT", mainFrame.infoTooltip, "BOTTOMRIGHT", -15, 15)

    -- Draw background and border
    WGLUIBuilder.DrawSlicedBG(mainFrame.infoTooltip, "OptionsWindowBG", "backdrop", 6)
    WGLUIBuilder.ColorBGSlicedFrame(mainFrame.infoTooltip, "backdrop", 1, 1, 1, 0.95)
    mainFrame.infoTooltip.Border = CreateFrame("Frame", nil, mainFrame.infoTooltip)
    mainFrame.infoTooltip.Border:SetAllPoints()
    WGLUIBuilder.DrawSlicedBG(mainFrame.infoTooltip.Border, "EdgedBorder", "border", 6)
    WGLUIBuilder.ColorBGSlicedFrame(mainFrame.infoTooltip.Border, "border", 0.5, 0.5, 0.5, 1)

    -- Create a frame that captures the cursor's onEnter and onLeave events.
    -- This'll be useed to show the options and close buttons.
    mainFrame.cursorFrame = CreateFrame("Frame", nil, UIParent)
    mainFrame.cursorFrame:SetSize(200, 40)
    mainFrame.cursorFrame:SetPoint("CENTER", 0, 0)

    -- Extend the frame to the edges of the screen.
    mainFrame.cursorFrame:SetFrameLevel(2)
    mainFrame.cursorFrame:EnableMouse(true)

    mainFrame.cursorFrame.CursorOver = false
    mainFrame.cursorFrame.HoverAnimDelta = 1
    mainFrame.cursorFrame.MoveAmount = -60
    mainFrame.cursorFrame.LastElapsed = -1
    mainFrame.cursorFrame.BeingDragged = false

    -- Make the main frame movable.
    mainFrame.cursorFrame:SetMovable(true)
    mainFrame.cursorFrame:EnableMouse(true)
    mainFrame.cursorFrame.isLocked = false
    mainFrame.cursorFrame:RegisterForDrag("LeftButton")
    mainFrame.cursorFrame:SetScript("OnDragStart", function(self)
        self.BeingDragged = true
        self:StartMoving()
    end)
    mainFrame.cursorFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.BeingDragged = false
        local point, relativeTo, relativePoint, xOfs, yOfs = mainFrame.cursorFrame:GetPoint()
        WhoGotLootsSavedData.SavedPos = { point, relativeTo, relativePoint, xOfs, yOfs }
    end)

    -- Animations And Events
    mainFrame.cursorFrame:SetScript("OnUpdate", function(self, elapsed)

        -- If the frame is not visible, don't bother with the rest of the code.
        if not WhoLootData.MainFrame:IsVisible() then return end

        -- Keep the main frame stuck to the cursor frame.
        if self.BeingDragged then
            mainFrame:SetPoint("CENTER", mainFrame.cursorFrame, "CENTER", 0, 0)
        end
        self.CursorOver = self:IsMouseOver()

        if self.CursorOver and not WhoGotLootsSavedData.LockWindow then
            self:SetAlpha(1)
        end
        if not self.CursorOver and not WhoGotLootsSavedData.LockWindow then
            self:SetAlpha(0)
        end

        if self.CursorOver then
            self.HoverAnimDelta = WGLU.Clamp(self.HoverAnimDelta + elapsed * 8, 0, 1)
        else
            self.HoverAnimDelta = WGLU.Clamp(self.HoverAnimDelta - elapsed * 4, 0, 1)
        end

        -- Save on CPU cycles by only updating whenever the cursor enters or leaves the frame.
        if self.LastElapsed == self.HoverAnimDelta then return end
        self.LastElapsed = self.HoverAnimDelta

        -- Make the options and close button swoop in from the right.
        local moveAmount = mainFrame.cursorFrame.MoveAmount * self.HoverAnimDelta
        moveAmount = math.sin(self.HoverAnimDelta * (math.pi * 0.5)) * moveAmount
        optionsBtn:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", moveAmount + (self.MoveAmount * -1), -27)
        closeBtn:SetPoint("TOP", optionsBtn, "BOTTOM", 0, 30)
        optionsBtn:SetAlpha(self.HoverAnimDelta)
        closeBtn:SetAlpha(self.HoverAnimDelta)

        -- Also move the info button to swoop in from the left.
        moveAmount = mainFrame.cursorFrame.MoveAmount * self.HoverAnimDelta
        moveAmount = math.sin(self.HoverAnimDelta * (math.pi * 0.5)) * -moveAmount
        mainFrame.infoBtn:SetPoint("TOPRIGHT", mainFrame, "TOPLEFT", moveAmount - (self.MoveAmount * -1), -20)
        mainFrame.infoBtn:SetAlpha(self.HoverAnimDelta)
    end)

    function mainFrame:Move(point)
        self.cursorFrame:ClearAllPoints()
        self.cursorFrame:SetPoint(unpack(point))
        self:SetPoint("CENTER", self.cursorFrame, "CENTER")
    end

    function mainFrame:Close()
        mainFrame.cursorFrame:EnableMouse(false)
        mainFrame.cursorFrame.HoverAnimDelta = 0
        mainFrame.cursorFrame:SetAlpha(0)
        WhoLootData.MainFrame:Hide()
    end

    function mainFrame:Open()
        if not mainFrame.cursorFrame.isLocked then mainFrame.cursorFrame:EnableMouse(true) end
        WhoLootData.MainFrame:Show()
    end

    function mainFrame:LockWindow(toState)
        mainFrame.cursorFrame.isLocked = toState
        mainFrame.cursorFrame:SetAlpha(toState and 0 or 1)
        mainFrame.cursorFrame:SetMovable(not toState)
        mainFrame.cursorFrame:EnableMouse(not toState)
    end

    WGLUIBuilder.DrawSlicedBG(mainFrame.cursorFrame, "SelectionBox", "backdrop", 0)
    WGLUIBuilder.ColorBGSlicedFrame(mainFrame.cursorFrame, "backdrop", 1, 1, 1, 0.25)

    -- Create a pop up window to show the Whisper text entry.
    mainFrame.WhisperWindow = CreateFrame("Frame", nil, UIParent)
    mainFrame.WhisperWindow:SetSize(360, 140)
    mainFrame.WhisperWindow:SetPoint("CENTER", 0, 0)
    mainFrame.WhisperWindow:SetFrameLevel(10)
    mainFrame.WhisperWindow:EnableMouse(true)
    mainFrame.WhisperWindow:Hide()

    -- Draw background and border
    WGLUIBuilder.DrawSlicedBG(mainFrame.WhisperWindow, "OptionsWindowBG", "backdrop", 6)
    WGLUIBuilder.ColorBGSlicedFrame(mainFrame.WhisperWindow, "backdrop", 1, 1, 1, 1)
    mainFrame.WhisperWindow.Border = CreateFrame("Frame", nil, mainFrame.WhisperWindow)
    mainFrame.WhisperWindow.Border:SetAllPoints()
    WGLUIBuilder.DrawSlicedBG(mainFrame.WhisperWindow.Border, "EdgedBorder", "border", 6)
    WGLUIBuilder.ColorBGSlicedFrame(mainFrame.WhisperWindow.Border, "border", 0.7, 0.7, 0.7, 1)

    -- Title text
    mainFrame.WhisperWindow.Title = mainFrame.WhisperWindow:CreateFontString(nil, "OVERLAY", "WGLFont_Title")
    mainFrame.WhisperWindow.Title:SetText("Whisper Player Message")
    mainFrame.WhisperWindow.Title:SetPoint("TOP", mainFrame.WhisperWindow, "TOP", 0, -15)

    -- Set tip text
    mainFrame.WhisperWindow.Tip = mainFrame.WhisperWindow:CreateFontString(nil, "OVERLAY", "WGLFont_Tooltip")
    mainFrame.WhisperWindow.Tip:SetText("Set your custom message here. Use %n for the player's name, and %i for the item name.")
    mainFrame.WhisperWindow.Tip:SetPoint("TOP", mainFrame.WhisperWindow.Title, "BOTTOM", 0, -10)

    -- Create a "Set to default" button
    mainFrame.WhisperWindow.DefaultBtn = CreateFrame("Button", nil, mainFrame.WhisperWindow, "WGLGeneralButton")
    mainFrame.WhisperWindow.DefaultBtn:SetPoint("BOTTOMLEFT", mainFrame.WhisperWindow, "BOTTOMLEFT", 18, 18)
    mainFrame.WhisperWindow.DefaultBtn:SetSize(70, 14)
    mainFrame.WhisperWindow.DefaultBtn:SetText("Set to Default")
    mainFrame.WhisperWindow.DefaultBtn:SetScript("OnClick", function(self)
        mainFrame.WhisperWindow.EditBox:SetText(WGLUIBuilder.DefaultWhisperMessage)
        PlaySound(856)
    end)

    -- Create edit box
    mainFrame.WhisperWindow.EditBox = CreateFrame("EditBox", nil, mainFrame.WhisperWindow, "InputBoxTemplate")
    mainFrame.WhisperWindow.EditBox:SetWidth(mainFrame.WhisperWindow:GetWidth() - 50)
    mainFrame.WhisperWindow.EditBox:SetMultiLine(true)
    mainFrame.WhisperWindow.EditBox:SetMaxLetters(WGLUIBuilder.WhisperMsgMaxChars)
    mainFrame.WhisperWindow.EditBox:SetAutoFocus(false)
    mainFrame.WhisperWindow.EditBox:SetPoint("TOP", mainFrame.WhisperWindow.Tip, "BOTTOM", 0, -15)
    mainFrame.WhisperWindow.EditBox:SetPoint("BOTTOM", mainFrame.WhisperWindow.DefaultBtn, "TOP", 0, 18)
    mainFrame.WhisperWindow.EditBox:SetFontObject("WGLFont_Item_StatBottomText")
    mainFrame.WhisperWindow.EditBox:SetText("Message here")
    mainFrame.WhisperWindow.EditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    mainFrame.WhisperWindow.EditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Hide the background and border of the edit box.
    mainFrame.WhisperWindow.EditBox.Left:Hide()
    mainFrame.WhisperWindow.EditBox.Middle:Hide()
    mainFrame.WhisperWindow.EditBox.Right:Hide()

    WGLUIBuilder.DrawSlicedBG(mainFrame.WhisperWindow.EditBox, "OptionsWindowBG", "backdrop", -8)
    WGLUIBuilder.ColorBGSlicedFrame(mainFrame.WhisperWindow.EditBox, "backdrop", 1, 1, 1, 0.95)
    WGLUIBuilder.DrawSlicedBG(mainFrame.WhisperWindow.EditBox, "EdgedBorder", "border", -9)
    WGLUIBuilder.ColorBGSlicedFrame(mainFrame.WhisperWindow.EditBox, "border", 0.3, 0.3, 0.3, 1)

    -- Create some text below the input box showing the number of available characters.
    local charCount = mainFrame.WhisperWindow.EditBox:CreateFontString(nil, "OVERLAY", "WGLFont_Tooltip")
    charCount:SetPoint("BOTTOMRIGHT", mainFrame.WhisperWindow.EditBox, "BOTTOMRIGHT",  0, 0)
    charCount:SetText(WGLUIBuilder.WhisperMsgMaxChars .. " characters remaining")

    -- Update the character count whenever the text changes.
    mainFrame.WhisperWindow.EditBox:SetScript("OnTextChanged", function(self)
        WGLUIBuilder.TempWhisperMesage = self:GetText()
        local remaining = WGLUIBuilder.WhisperMsgMaxChars - self:GetNumLetters()
        charCount:SetText(remaining .. " characters remaining")

        -- If the remaining is less than 40, color the text a dark red.
        if remaining < 40 then
            charCount:SetTextColor(0.7098, 0.2588, 0.2588, 1)
        else
            charCount:SetTextColor(0.65, 0.65, 0.65, 1)
        end

        -- If the text is different than the saved text, change the text color of the ssave button.
        mainFrame.WhisperWindow.SaveBtn:SetEnabled(WGLUIBuilder.TempWhisperMesage ~= WhoGotLootsSavedData.WhisperMessage)
    end)
    WGLUIBuilder.WhisperEditor = mainFrame.WhisperWindow

    -- Create a "Save" button
    mainFrame.WhisperWindow.SaveBtn = CreateFrame("Button", nil, mainFrame.WhisperWindow.EditBox, "WGLGeneralButton")
    mainFrame.WhisperWindow.SaveBtn:SetPoint("BOTTOMRIGHT", mainFrame.WhisperWindow, "BOTTOMRIGHT", -18, 18)
    mainFrame.WhisperWindow.SaveBtn:SetSize(70, 14)
    mainFrame.WhisperWindow.SaveBtn:SetText("Save")
    mainFrame.WhisperWindow.SaveBtn:SetScript("OnClick", function(self)
        if mainFrame.WhisperWindow.SaveBtn:IsEnabled() == false then return end
        WhoGotLootsSavedData.WhisperMessage = WGLUIBuilder.TempWhisperMesage
        mainFrame.WhisperWindow:ShowSavedText()
        mainFrame.WhisperWindow.SaveBtn:SetEnabled(false)
        WhoLootsOptionsFrame.whisperPreview:SetText(WGLUIBuilder.TempWhisperMesage)
        PlaySound(856)
    end)
    mainFrame.WhisperWindow.SaveBtn:SetEnabled(false)

    -- Create a frame for the saved message text, so we can move it around.
    mainFrame.WhisperWindow.SavedTextFrame = CreateFrame("Frame", nil, mainFrame.WhisperWindow)
    mainFrame.WhisperWindow.SavedTextFrame:SetSize(200, 20)
    mainFrame.WhisperWindow.SavedTextFrame:SetPoint("RIGHT", mainFrame.WhisperWindow.SaveBtn, "LEFT", -4, 0)
    mainFrame.WhisperWindow.SavedTextFrame:Hide()

    -- Create some text that says "saved" when the message is saved.
    mainFrame.WhisperWindow.savedText = mainFrame.WhisperWindow:CreateFontString(nil, "OVERLAY", "WGLFont_Checkbox")
    mainFrame.WhisperWindow.savedText:SetPoint("RIGHT", mainFrame.WhisperWindow.SavedTextFrame, "RIGHT", -9, 0)
    mainFrame.WhisperWindow.savedText:SetText("Message saved")
    mainFrame.WhisperWindow.savedText:SetParent(mainFrame.WhisperWindow.SavedTextFrame)
    mainFrame.WhisperWindow.savedText:SetVertexColor(0.6196, 0.8627, 0.549, 1)
    mainFrame.WhisperWindow.SavedTextFrame.AnimDelta = 0
    mainFrame.WhisperWindow.SavedTextFrame.AnimTimer = nil
    
    function mainFrame.WhisperWindow:ShowSavedText()
        -- Make the SavedTextFrame slide from behind the save button, and fade in.
        self.SavedTextFrame:Show()
        self.SavedTextFrame.AnimDelta = 0
    
        -- Cancel any onupdate scripts that are running.
        if WhoLootData.MainFrame.WhisperWindow.SavedTextFrame.AnimTimer then
            self.SavedTextFrame.AnimTimer:Cancel()
            self.SavedTextFrame.AnimTimer = nil
        end
    
        self.SavedTextFrame:SetScript("OnUpdate", function(self, elapsed)
            self.AnimDelta = WGLU.Clamp(self.AnimDelta + elapsed * 5, 0, 1)
            self:SetPoint("RIGHT", WhoLootData.MainFrame.WhisperWindow.SaveBtn, "LEFT", WGLU.LerpFloat(60, -4, math.sin(self.AnimDelta * 1.57)), 0)
            self:SetAlpha(self.AnimDelta)
            if self.AnimDelta == 1 then
                self:SetScript("OnUpdate", nil) -- Stop the slide-in animation
                -- Delay the fade out by 1 second.
                WhoLootData.MainFrame.WhisperWindow.SavedTextFrame.AnimTimer = C_Timer.NewTimer(1, function()
                    self:SetScript("OnUpdate", function(self, elapsed)
                        self.AnimDelta = WGLU.Clamp(self.AnimDelta - elapsed * 2, 0, 1)
                        self:SetAlpha(math.sin(self.AnimDelta * 1.57))
                        if self.AnimDelta == 0 then
                            self:Hide()
                            self:SetScript("OnUpdate", nil)
                            WhoLootData.MainFrame.WhisperWindow.SavedTextFrame.AnimTimer = nil
                        end
                    end)
                end)
            end
        end)
    end
    

    -- Close Button
    local tipCloseBtn = CreateFrame("Button", nil, WGLUIBuilder.WhisperEditor, "WGLCloseBtn")
    tipCloseBtn:SetPoint("TOPRIGHT", WGLUIBuilder.WhisperEditor, "TOPRIGHT", -12, -12)
    tipCloseBtn:SetSize(12, 12)
    tipCloseBtn:SetScript("OnClick", function(self)
        PlaySound(856)
        WGLUIBuilder.WhisperEditor:Hide()
    end)

    return mainFrame
end

FrameTextures =
{
    OptionsWindowBG = {
        file = "OptionsWindowBG",
        cornerSize = 12,
        cornerCoord = 0.25,
    },

    EdgedBorder = {
        file = "EdgedBorder",
        cornerSize = 12,
        cornerCoord = 0.25,
    },

    ItemEntryBG = {
        file = "ItemBG",
        cornerSize = 10,
        cornerCoord = 0.2,
    },

    ItemEntryBorder = {
        file = "EdgedBorder_Sharp",
        cornerSize = 10,
        cornerCoord = 0.2,
    },

    SelectionBox = {
        file = "SelectionBox",
        cornerSize = 14,
        cornerCoord = 0.25,
    },

    ItemEntryGlow = {
        file = "ItemBox_Upgrade",
        cornerSize = 8,
        cornerCoord = 0.2,
    },
    BtnBG = {
        file = "ItemBG",
        cornerSize = 4,
        cornerCoord = 0.2,
    },
    BtnBorder = {
        file = "EdgedBorder_Sharp_Thick",
        cornerSize = 4,
        cornerCoord = 0.2,
    },
}


function WGLUIBuilder.DrawSlicedBG(frame, textureKey, layer, shrink)
    shrink = shrink or 0;
    local group, subLevel;

    if layer == "backdrop" then
        if not frame.backdropTextures then
            frame.backdropTextures = {};
        end
        group = frame.backdropTextures;
        subLevel = 0;
    elseif layer == "border" then
        if not frame.borderTextures then
            frame.borderTextures = {};
        end
        group = frame.borderTextures;
        subLevel = -1;
    else
        return
    end

    local data = FrameTextures[textureKey];

    local file = "Interface\\AddOns\\WhoGotLoots\\Art\\" .. data.file;
    local cornerSize = data.cornerSize;
    local coord = data.cornerCoord;
    local buildOrder = {1, 3, 7, 9, 2, 4, 6, 8, 5};
    local tex, key;

    for i = 1, 9 do
        key = buildOrder[i];
        if not group[key] then
            group[key] = frame:CreateTexture(nil, "BACKGROUND", nil, subLevel);
        else
        end
        tex = group[key];
        tex:SetTexture(file, nil, nil, "LINEAR");
        if key == 2 or key == 8 then
            if key == 2 then
                tex:SetPoint("TOPLEFT", group[1], "TOPRIGHT", 0, 0);
                tex:SetPoint("BOTTOMRIGHT", group[3], "BOTTOMLEFT", 0, 0);
                tex:SetTexCoord(coord, 1-coord, 0, coord);
            else
                tex:SetPoint("TOPLEFT", group[7], "TOPRIGHT", 0, 0);
                tex:SetPoint("BOTTOMRIGHT", group[9], "BOTTOMLEFT", 0, 0);
                tex:SetTexCoord(coord, 1-coord, 1-coord, 1);
            end
        elseif key == 4 or key == 6 then
            if key == 4 then
                tex:SetPoint("TOPLEFT", group[1], "BOTTOMLEFT", 0, 0);
                tex:SetPoint("BOTTOMRIGHT", group[7], "TOPRIGHT", 0, 0);
                tex:SetTexCoord(0, coord, coord, 1-coord);
            else
                tex:SetPoint("TOPLEFT", group[3], "BOTTOMLEFT", 0, 0);
                tex:SetPoint("BOTTOMRIGHT", group[9], "TOPRIGHT", 0, 0);
                tex:SetTexCoord(1-coord, 1, coord, 1-coord);
            end
        elseif key == 5 then
            tex:SetPoint("TOPLEFT", group[1], "BOTTOMRIGHT", 0, 0);
            tex:SetPoint("BOTTOMRIGHT", group[9], "TOPLEFT", 0, 0);
            tex:SetTexCoord(coord, 1-coord, coord, 1-coord);

        else
            tex:SetSize(cornerSize, cornerSize);
            if key == 1 then
                tex:SetPoint("CENTER", frame, "TOPLEFT", shrink, -shrink);
                tex:SetTexCoord(0, coord, 0, coord);
            elseif key == 3 then
                tex:SetPoint("CENTER", frame, "TOPRIGHT", -shrink, -shrink);
                tex:SetTexCoord(1-coord, 1, 0, coord);
            elseif key == 7 then
                tex:SetPoint("CENTER", frame, "BOTTOMLEFT", shrink, shrink);
                tex:SetTexCoord(0, coord, 1-coord, 1);
            elseif key == 9 then
                tex:SetPoint("CENTER", frame, "BOTTOMRIGHT", -shrink, shrink);
                tex:SetTexCoord(1-coord, 1, 1-coord, 1);
            end
        end
    end
end

function WGLUIBuilder.ColorBGSlicedFrame(frame, layer, r, g, b, a)

    if layer == "backdrop" then
        if frame.backdropTextures then
            for _, tex in pairs(frame.backdropTextures) do
                tex:SetVertexColor(r, g, b, a);
            end
        end
    elseif layer == "border" then
        if frame.borderTextures then
            for _, tex in pairs(frame.borderTextures) do
                tex:SetVertexColor(r, g, b, a);
            end
        end
    end
end

-- Utility function to add an OnClick handler while preserving the original
function WGLUIBuilder.AddOnClick(button, newOnClick)
    local originalOnClick = button:GetScript("OnClick")
    button:SetScript("OnClick", function(self, ...)
        -- Call the original OnClick script
        if originalOnClick then
            originalOnClick(self, ...)
        end

        -- Call the new OnClick script
        newOnClick(self, ...)
    end)
end