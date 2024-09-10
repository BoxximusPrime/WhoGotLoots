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

    -- Create a frame that captures the cursor's onEnter and onLeave events.
    -- This'll be useed to show the options and close buttons.
    mainFrame.cursorFrame = CreateFrame("Frame", nil, UIParent)
    mainFrame.cursorFrame:SetSize(180, 40)
    mainFrame.cursorFrame:SetPoint("CENTER", 0, 0)

    -- Extend the frame to the edges of the screen.
    mainFrame.cursorFrame:SetFrameLevel(2)
    mainFrame.cursorFrame:EnableMouse(true)

    mainFrame.cursorFrame.CursorOver = false
    mainFrame.cursorFrame.HoverAnimDelta = 1
    mainFrame.cursorFrame.MoveAmount = -60
    mainFrame.cursorFrame.LastElapsed = -1
    mainFrame.cursorFrame.IsDragging = false

    -- Make the main frame movable.
    mainFrame.cursorFrame:SetMovable(true)
    mainFrame.cursorFrame:EnableMouse(true)
    mainFrame.cursorFrame:RegisterForDrag("LeftButton")
    mainFrame.cursorFrame:SetScript("OnDragStart", function(self)
        IsDragging = true
        self:StartMoving()
    end)
    mainFrame.cursorFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IsDragging = false
        local point, relativeTo, relativePoint, xOfs, yOfs = mainFrame.cursorFrame:GetPoint()
        WhoGotLootsSavedData.SavedPos = { point, relativeTo, relativePoint, xOfs, yOfs }
    end)

    -- Animations And Events
    mainFrame.cursorFrame:SetScript("OnUpdate", function(self, elapsed)

        -- If the frame is not visible, don't bother with the rest of the code.
        if not WhoLootData.MainFrame:IsVisible() then return end

        -- Keep the main frame stuck to the cursor frame.
        if self.IsDragging then
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
            self.HoverAnimDelta = WGLUtil.Clamp(self.HoverAnimDelta + elapsed * 8, 0, 1)
        else
            self.HoverAnimDelta = WGLUtil.Clamp(self.HoverAnimDelta - elapsed * 4, 0, 1)
        end

        -- Save on CPU cycles by only updating whenever the cursor enters or leaves the frame.
        if self.LastElapsed == self.HoverAnimDelta then return end
        self.LastElapsed = self.HoverAnimDelta

        -- Make the options and close button swoop in from the right.
        local moveAmount = mainFrame.cursorFrame.MoveAmount * self.HoverAnimDelta
        moveAmount = math.sin(self.HoverAnimDelta * (math.pi * 0.5)) * moveAmount
        optionsBtn:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", moveAmount + (self.MoveAmount * -1), -27)
        closeBtn:SetPoint("TOP", optionsBtn, "BOTTOM", 0, 30)

        -- Also make them fade in/out.
        optionsBtn:SetAlpha(self.HoverAnimDelta)
        closeBtn:SetAlpha(self.HoverAnimDelta)
    end)

    function mainFrame:Move(point)
        self.cursorFrame:ClearAllPoints()
        self.cursorFrame:SetPoint(unpack(point))
        self:SetPoint("CENTER", self.cursorFrame, "CENTER")
    end

    function mainFrame:Close()
        mainFrame.cursorFrame:EnableMouse(false)
        mainFrame.cursorFrame:SetMovable(false)
        mainFrame.cursorFrame.HoverAnimDelta = 0
        mainFrame.cursorFrame:SetAlpha(0)
        WhoLootData.MainFrame:Hide()
    end

    function mainFrame:Open()
        mainFrame.cursorFrame:EnableMouse(true)
        mainFrame.cursorFrame:SetMovable(true)
        WhoLootData.MainFrame:Show()
    end

    function mainFrame:LockWindow(toState)
        self.cursorFrame:SetAlpha(toState and 0 or 1)
        self.cursorFrame:EnableMouse(not toState)
        self.cursorFrame:SetMovable(not toState)
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
        cornerSize = 12,
        cornerCoord = 0.25,
    },

    ItemEntryBorder = {
        file = "EdgedBorder",
        cornerSize = 12,
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
    local offset = cornerSize * (data.offsetRatio or 0);
    local buildOrder = {1, 3, 7, 9, 2, 4, 6, 8, 5};
    local tex, key;
    local isNewTexture;

    for i = 1, 9 do
        key = buildOrder[i];
        if not group[key] then
            group[key] = frame:CreateTexture(nil, "BACKGROUND", nil, subLevel);
            isNewTexture = true;
        else
            isNewTexture = false;
        end
        tex = group[key];
        tex:SetTexture(file, nil, nil, "LINEAR");
        if data.disableSharpening then
            DisableSharpening(tex)
        end
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