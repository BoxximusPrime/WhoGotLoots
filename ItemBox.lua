WhoGotLootsFrames = {}
WGL_FrameManager = {}
WhoLootFrameData = {}

WGL_NumPooledFrames = 10

-- Animation Values
WhoLootFrameData.HoverAnimTime = 0.3
WhoLootFrameData.IconStartLeftPos = 55
WhoLootFrameData.ItemNameStartLeftPos = 85
WhoLootFrameData.BottomTextStartLeftPos = 85

WhoLootFrameData.IconEndLeftPos = -30
WhoLootFrameData.ItemNameEndLeftPos = 5
WhoLootFrameData.BottomTextEndLeftPos = 5

WhoLootFrameData.IconTopPos = -5
WhoLootFrameData.ItemNameTopPos = -8
WhoLootFrameData.BottomTextTopPos = -8

WhoLootFrameData.FrameLifetime = 60

WhoLootFrameData.HoverColor = { 0.3, 0.3, 0.3, 1 }
WhoLootFrameData.ExitColor = { 0.1, 0.1, 0.1, 1 }


function WGL_FrameManager:CreateFrame()

    -- Create a new frame to display the player and item.
    local ItemFrame = CreateFrame("Frame", nil, nil)
    ItemFrame:SetWidth(240)
    ItemFrame:SetHeight(35)
    ItemFrame:SetClipsChildren(true)
    ItemFrame:SetFrameLevel(5)
    WhoGotLootsFrames[#WhoGotLootsFrames + 1] = ItemFrame

    -- Create a few variables we'll need later.
    ItemFrame.Item = nil
    ItemFrame.InUse = false
    ItemFrame.Animating = false
    ItemFrame.HoverAnimDelta = nil
    ItemFrame.Lifetime = WhoLootFrameData.FrameLifetime

    -- Create the background
    ItemFrame.background = CreateFrame("Frame", nil, ItemFrame);
    ItemFrame.background:SetAllPoints();
    ItemFrame.background:SetFrameLevel(ItemFrame:GetFrameLevel());
    WGLUIBuilder.DrawSlicedBG(ItemFrame.background, "ItemEntryBG", "backdrop", 0)
    WGLUIBuilder.ColorBGSlicedFrame(ItemFrame.background, "backdrop", 0.12, 0.1, 0.1, 0.85)

    -- Create the border
    ItemFrame.border = CreateFrame("Frame", nil, ItemFrame);
    ItemFrame.border:SetAllPoints();
    ItemFrame.border:SetFrameLevel(ItemFrame:GetFrameLevel() + 1);
    WGLUIBuilder.DrawSlicedBG(ItemFrame.border, "ItemEntryBorder", "border", 0)
    WGLUIBuilder.ColorBGSlicedFrame(ItemFrame.border, "border", 0.4, 0.4, 0.4, 1)

    -- Create a text showing which player it was.
    ItemFrame.PlayerText = ItemFrame:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    ItemFrame.PlayerText:SetPoint("LEFT", 10, 0)
    ItemFrame.PlayerText:SetParent(ItemFrame)
    ItemFrame.PlayerText:SetText("PlayerName")

    -- Create a progress bar that will show the timer's progress.
    ItemFrame.ProgressBar = CreateFrame("StatusBar", nil, ItemFrame)
    ItemFrame.ProgressBar:SetSize(100, 2)
    ItemFrame.ProgressBar:SetPoint("BOTTOMLEFT",  1, 1)
    ItemFrame.ProgressBar:SetPoint("BOTTOMRIGHT", -1, 1)
    ItemFrame.ProgressBar:SetMinMaxValues(0, 1)
    ItemFrame.ProgressBar:SetValue(0)
    ItemFrame.ProgressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    ItemFrame.ProgressBar:SetStatusBarColor(0.5, 0.5, 0.5, 0.6)
    ItemFrame.ProgressBar:SetParent(ItemFrame)

    -- Show the item's icon.
    ItemFrame.Icon = ItemFrame:CreateTexture(nil, "OVERLAY")
    ItemFrame.Icon:SetSize(22, 22)
    ItemFrame.Icon:SetPoint("TOPLEFT", 55, -5)
    ItemFrame.Icon:SetParent(ItemFrame)
    ItemFrame.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- Create a loading icon over the item icon.
    ItemFrame.LoadingIcon = CreateFrame("Frame", nil, ItemFrame, "LoadingIcon")
    ItemFrame.LoadingIcon:SetParent(ItemFrame)
    ItemFrame.LoadingIcon:SetAllPoints(ItemFrame.Icon, true)
    ItemFrame.LoadingIcon:Hide()

    -- Show the item's name.
    ItemFrame.ItemText = ItemFrame:CreateFontString(nil, "OVERLAY", "WGLFont_ItemName")
    ItemFrame.ItemText:SetPoint("TOPLEFT", 85, -8)
    ItemFrame.ItemText:SetText("item name")
    ItemFrame.ItemText:SetParent(ItemFrame)

    ItemFrame.BottomText = ItemFrame:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    ItemFrame.BottomText:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", 0, -4)
    ItemFrame.BottomText:SetParent(ItemFrame)
    ItemFrame.BottomText:SetText("Bottom Text")

    -- Create a close button to remove the frame.
    ItemFrame.Close = CreateFrame("Button", nil, ItemFrame, "WGLCloseBtn")
    ItemFrame.Close:SetSize(12, 12)
    ItemFrame.Close:SetPoint("TOPRIGHT", -6, -6)
    ItemFrame.Close.ParentFrame = ItemFrame

    ItemFrame.HintContainer = CreateFrame("Frame", nil, ItemFrame)
    ItemFrame.HintContainer:SetSize(100, 12)
    ItemFrame.HintContainer:SetPoint("TOPRIGHT", ItemFrame.Close, "LEFT", -4, 0)
    ItemFrame.HintContainer:SetFrameLevel(ItemFrame:GetFrameLevel() + 1)
    ItemFrame.HintContainer:SetAlpha(0)

    -- Show the left and right click icons to the left of the close button
    ItemFrame.RightClickIcon = ItemFrame:CreateTexture(nil, "OVERLAY")
    ItemFrame.RightClickIcon:SetSize(8, 8)
    ItemFrame.RightClickIcon:SetPoint("RIGHT", ItemFrame.Close, "LEFT", -4, 0)
    ItemFrame.RightClickIcon:SetTexture("Interface\\Addons\\WhoGotLoots\\Art\\RightClick")
    ItemFrame.RightClickIcon:SetVertexColor(1, 1, 1, 1)
    ItemFrame.RightClickIcon:SetParent(ItemFrame.HintContainer)

    -- Show "shift" text and left click icon to the left of the right click icon
    ItemFrame.LeftClickIcon = ItemFrame:CreateTexture(nil, "OVERLAY")
    ItemFrame.LeftClickIcon:SetSize(8, 8)
    ItemFrame.LeftClickIcon:SetPoint("RIGHT", ItemFrame.RightClickIcon, "LEFT", -4, 0)
    ItemFrame.LeftClickIcon:SetTexture("Interface\\Addons\\WhoGotLoots\\Art\\LeftClick")
    -- ItemFrame.LeftClickIcon:SetVertexColor(0.2, 0.1, 0.8, 1)
    ItemFrame.LeftClickIcon:SetParent(ItemFrame.HintContainer)

    ItemFrame.ShiftText = ItemFrame:CreateFontString(nil, "OVERLAY", "WGLFont_VersNum")
    ItemFrame.ShiftText:SetPoint("RIGHT", ItemFrame.LeftClickIcon, "LEFT", 0, 0)
    ItemFrame.ShiftText:SetText("Shift + ")
    ItemFrame.ShiftText:SetParent(ItemFrame.HintContainer)
    ItemFrame.ShiftText:SetTextColor(0.8, 0.8, 0.8, 1)


    -- Add the frame to the list of frames.
    WhoGotLootsFrames[#WhoGotLootsFrames + 1] = ItemFrame

    -- Register user interaction.
    ItemFrame:SetScript("OnEnter", function(self) WhoLootData.HoverFrame(self, true); self:HoverOver(); end)
    ItemFrame:SetScript("OnLeave", function(self) WhoLootData.HoverFrame(self, false); self:HoverOut(); end)

    function  ItemFrame.Close:CloseFrame()
        PlaySound(856)
        self.ParentFrame:Hide()
        self.ParentFrame.InUse = false

        -- Find this frame in WhoLootData.ActiveFrames and remove it.
        for i, activeFrame in ipairs(WhoLootData.ActiveFrames) do
            if activeFrame == self.ParentFrame then
                table.remove(WhoLootData.ActiveFrames, i)
                break
            end
        end

        WhoLootData.ResortFrames()
    end

    ItemFrame.Close:SetScript("OnClick", function(self) self:CloseFrame() end)
    ItemFrame.Close:SetScript("OnEnter", function(self) self.Btn:SetVertexColor(1, 1, 1, 1); WhoLootData.HoverFrame(ItemFrame, true); end)
    ItemFrame.Close:SetScript("OnLeave", function(self) self.Btn:SetVertexColor(0.7, 0.7, 0.7, 1); WhoLootData.HoverFrame(ItemFrame, false); end)

    function ItemFrame:HoverOver()
        if WhoGotLootsSavedData.ShowControlHints then
            -- Fade the ItemFrame.HintContainer in over 0.2 seconds
            self.HintContainer:SetAlpha(0)
            self.HintContainer:Show()
            self.HintContainer:SetScript("OnUpdate", function(self, elapsed)
                self:SetAlpha(WGLU.Clamp(self:GetAlpha() + elapsed * 5, 0, 1))
                if self:GetAlpha() >= 1 then
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    end

    function ItemFrame.LoadingIcon:FadeOut()
        self:SetScript("OnUpdate", function(self, elapsed)
            local newAlpha = self:GetAlpha() - elapsed
            if newAlpha <= 0 then
                self:SetAlpha(0)
                self:SetScript("OnUpdate", nil)
                self:Hide()
            else
                self:SetAlpha(newAlpha)
            end
        end)
    end

    function ItemFrame:HoverOut()
        -- Fade the ItemFrame.HintContainer out over 0.2 seconds
        self.HintContainer:SetScript("OnUpdate", function(self, elapsed)
            self:SetAlpha(WGLU.Clamp(self:GetAlpha() - elapsed * 5, 0, 1))
            if self:GetAlpha() <= 0 then
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    -- Animation/visual controls
    function ItemFrame:Reset()
        self:SetAlpha(1)
        self.Icon:ClearAllPoints()
        self.Icon:SetPoint("TOPLEFT", WhoLootFrameData.IconStartLeftPos, WhoLootFrameData.IconTopPos)
        self.Icon:SetAlpha(1)
        self.ItemText:ClearAllPoints()
        self.ItemText:SetPoint("TOPLEFT", WhoLootFrameData.ItemNameStartLeftPos, WhoLootFrameData.ItemNameTopPos)
        self.BottomText:ClearAllPoints()
        self.BottomText:SetPoint("TOPLEFT", ItemFrame.ItemText, "BOTTOMLEFT", 0, -4)
        self.Animating = false
        self.HoverAnimDelta = nil
        self.Lifetime = WhoLootFrameData.FrameLifetime
        self.InUse = false
    end

    function ItemFrame:DropIn(targetScale, duration)
        self:Reset()
        self.Animating = true
        self.InUse = true
        local startTime = GetTime()
        local initialScale = 1.5
        local scaleChange = targetScale - initialScale
        self:Show()
        self:SetAlpha(1)
        self.PlayerText:SetAlpha(1)
        self.PlayerText:Show()
    
        self:SetScript("OnUpdate", function(self, elapsed)
            local currentTime = GetTime()
            local progress = (currentTime - startTime) / duration
            local startColor = { 1, 1, 1 }
            local endColor = WhoLootFrameData.ExitColor
    
            if progress >= 1 then
                self:SetScale(targetScale)
                WGLUIBuilder.ColorBGSlicedFrame(self.background, "backdrop", endColor[1], endColor[2], endColor[3], 1)
                self:SetScript("OnUpdate", nil) -- Stop the animation
                self.Animating = false
    
            else
                local newScale = initialScale + (scaleChange * progress)
                self:SetScale(newScale)
                WGLUIBuilder.ColorBGSlicedFrame(self.background, "backdrop",startColor[1] + (endColor[1] - startColor[1]) * progress, startColor[2] + (endColor[2] - startColor[2]) * progress, startColor[3] + (endColor[3] - startColor[3]) * progress, 1)
            end
        end)
    end

    function ItemFrame:FadeOut()
        self.Animating = true
        self:SetScript("OnUpdate", function(self, elapsed)
            self:SetAlpha(WGLU.Clamp(self:GetAlpha() - elapsed * 2, 0, 1))
            if self:GetAlpha() <= 0 then
                self:Hide()
                self.InUse = false
                self.Animating = false
                self:SetScript("OnUpdate", nil)

                -- Remove this frame from WhoLootData.ActiveFrames
                for i, activeFrame in ipairs(WhoLootData.ActiveFrames) do
                    if activeFrame == self then
                        table.remove(WhoLootData.ActiveFrames, i)
                        break
                    end
                end

                WhoLootData.ResortFrames()
            end
        end)
    end
end

-- Create an initial pool.
for i = 1, WGL_NumPooledFrames do
    WGL_FrameManager:CreateFrame()
end

