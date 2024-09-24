WGLUIBuilder = WGLUIBuilder or {}

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

        -- Would the top of the tooltip go off the screen? If so, move the anchor to the top right of the tooltip, and the left side of the info button
        local top =  mainFrame.infoTooltip:GetTop()
        top = top + mainFrame.infoTooltip:GetHeight()

        -- Take the scale into account
        top = top * mainFrame.infoTooltip:GetScale()

        if top > GetScreenHeight() then
            mainFrame.infoTooltip:ClearAllPoints()
            mainFrame.infoTooltip:SetPoint("TOPRIGHT", mainFrame.infoBtn, "TOPLEFT", -9, 0)
        else
            mainFrame.infoTooltip:ClearAllPoints()
            mainFrame.infoTooltip:SetPoint("BOTTOMLEFT", mainFrame.infoBtn, "TOPLEFT", -15, 0)
        end

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
    mainFrame.infoTooltip = CreateFrame("Frame", nil, UIParent)
    mainFrame.infoTooltip:SetSize(270, 135)
    mainFrame.infoTooltip:SetPoint("BOTTOMLEFT", mainFrame.infoBtn, "TOPLEFT", -15, 0)
    mainFrame.infoTooltip:SetFrameLevel(4)
    mainFrame.infoTooltip.Text = mainFrame.infoTooltip:CreateFontString(nil, "OVERLAY", "WGLFont_Tooltip")
    mainFrame.infoTooltip.Text:SetAllPoints()
    mainFrame.infoTooltip.Text:SetPoint("TOPLEFT", mainFrame.infoTooltip, "TOPLEFT", 15, -0)
    mainFrame.infoTooltip.Text:SetText("|cFFFFFFFFKey Bindings|r\n- Double left click to equip the item (if it's your loot).\n- Shift + left click to link the item in chat.\n- Right click to dismiss the item.\n- Alt + left click to try and inspect the player.\n- Ctrl + left click to open trade with the person.\n|CFFFFFFFFTips|r\n- Rings and Trinket will compare to your lowest item level one.")
    mainFrame.infoTooltip.Text:SetJustifyH("LEFT")
    mainFrame.infoTooltip.Text:SetSpacing(4)
    mainFrame.infoTooltip:SetScale(1.4)
    mainFrame.infoTooltip:Hide()

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
        cornerSize = 8,
        cornerCoord = 0.25,
    },

    ItemEntryBorder = {
        file = "EdgedBorder",
        cornerSize = 8,
        cornerCoord = 0.25,
    },

    SelectionBox = {
        file = "SelectionBox",
        cornerSize = 14,
        cornerCoord = 0.25,
    }
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
        if not frame.backdropTextures then
            return
        end
        for _, tex in pairs(frame.backdropTextures) do
            tex:SetVertexColor(r, g, b, a);
        end
    elseif layer == "border" then
        if not frame.borderTextures then
            return
        end
        for _, tex in pairs(frame.borderTextures) do
            tex:SetVertexColor(r, g, b, a);
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