WhoGotLootsFrames = {}
WGL_FrameManager = {}
WhoLootFrameData = {}
WhoLootData = WhoLootData or {}

WGL_NumPooledFrames = 10

-- Animation Values
WhoLootFrameData.HoverAnimTime = 0.3

-- Animation values { start, end }
WhoLootFrameData.ItemNameAnimPosLeft = { 35, 5 }
WhoLootFrameData.BottomTextAnimPosLeft = { 35, 5 }
WhoLootFrameData.IconAnimPosLeft = { 8, 7 }
WhoLootFrameData.PlayerNameLeft = { 8, 5 }

WhoLootFrameData.ItemNameAnimPosTop = { -5, -5 }
WhoLootFrameData.BottomTextAnimPosTop = { -17, -17 }
WhoLootFrameData.IconAnimPosTop = { -15, -15 }
WhoLootFrameData.PlayerNameTop = { -5.5, -5.5    }

WhoLootFrameData.FrameLifetime = 60

WhoLootFrameData.HoverColor = { 0.3, 0.3, 0.3, 1 }
WhoLootFrameData.ExitColor = { 0.1, 0.1, 0.1, 1 }


function WGL_FrameManager:CreateFrame()

    -- Create a new frame to display the player and item.
    local ItemFrame = CreateFrame("Frame", nil, WhoLootData.MainFrame)
    ItemFrame:SetWidth(250)
    ItemFrame:SetHeight(48)
    ItemFrame:SetClipsChildren(true)
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
    WGLUIBuilder.ColorBGSlicedFrame(ItemFrame.border, "border", 0.5, 0.5, 0.5, 1)

    -- Show the item's icon.
    ItemFrame.Icon = ItemFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    ItemFrame.Icon:SetSize(22, 22)
    ItemFrame.Icon:SetPoint("TOPLEFT", 5, -ItemFrame:GetHeight() / 2 + ItemFrame.Icon:GetHeight() / 2)
    ItemFrame.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- Create a text showing which player it was.
    -- First, create a new frame to hold the text.
    ItemFrame.PlayerTextFrame = CreateFrame("Frame", nil, ItemFrame)
    ItemFrame.PlayerTextFrame:SetSize(100, 12)
    ItemFrame.PlayerTextFrame:SetPoint("TOPLEFT", ItemFrame, "TOPLEFT", WhoLootFrameData.PlayerNameLeft[1], WhoLootFrameData.PlayerNameTop[1])
    ItemFrame.PlayerTextFrame:SetFrameLevel(ItemFrame:GetFrameLevel() + 1)

    ItemFrame.PlayerText = ItemFrame:CreateFontString(nil, "OVERLAY", "WGLFont_ItemName")
    ItemFrame.PlayerText:SetParent(ItemFrame.PlayerTextFrame)
    ItemFrame.PlayerText:SetPoint("TOPLEFT", 0, 0)
    ItemFrame.PlayerText:SetText("PlayerName")
    ItemFrame.PlayerText:SetWordWrap(false)
    ItemFrame.PlayerText:SetJustifyH("LEFT")

    -- Create a little texture that'll sit to the right of the player name (will be an arrow pointing right)
    ItemFrame.PlayerArrow = ItemFrame:CreateTexture(nil, "OVERLAY")
    ItemFrame.PlayerArrow:SetSize(8, 8)
    ItemFrame.PlayerArrow:SetPoint("LEFT", ItemFrame.PlayerText, "RIGHT", 2, 0)
    ItemFrame.PlayerArrow:SetTexture("Interface\\Addons\\WhoGotLoots\\Art\\RightArrow")
    ItemFrame.PlayerArrow:SetVertexColor(0.6, 0.6, 0.6, 1)

    -- Create a progress bar that will show the timer's progress.
    ItemFrame.ProgressBar = CreateFrame("StatusBar", nil, ItemFrame)
    ItemFrame.ProgressBar:SetSize(100, 3)
    ItemFrame.ProgressBar:SetPoint("BOTTOMLEFT",  1, 2)
    ItemFrame.ProgressBar:SetPoint("BOTTOMRIGHT", -1, 2)
    ItemFrame.ProgressBar:SetMinMaxValues(0, 1)
    ItemFrame.ProgressBar:SetValue(0)
    ItemFrame.ProgressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    ItemFrame.ProgressBar:SetStatusBarColor(0.5, 0.5, 0.5, 0.6)
    ItemFrame.ProgressBar:SetParent(ItemFrame)

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
    ItemFrame.BottomText:SetJustifyH("LEFT")
    ItemFrame.BottomText:SetJustifyV("TOP")
    ItemFrame.BottomText:SetWordWrap(true)
    ItemFrame.BottomText:SetNonSpaceWrap(false)
    ItemFrame.BottomText:SetWidth(ItemFrame:GetWidth() - WhoLootFrameData.BottomTextAnimPosLeft[1] - 8)

    ItemFrame.BottomText2 = ItemFrame:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    ItemFrame.BottomText2:SetPoint("TOPLEFT", ItemFrame.BottomText, "BOTTOMLEFT", 0, 0)
    ItemFrame.BottomText2:SetParent(ItemFrame)
    ItemFrame.BottomText2:SetText("Bottom Text")

    -- Create a close button to remove the frame.
    ItemFrame.Close = CreateFrame("Button", nil, ItemFrame, "WGLCloseBtn")
    ItemFrame.Close:SetSize(12, 12)
    ItemFrame.Close:SetPoint("TOPRIGHT", -4, -4)
    ItemFrame.Close.ParentFrame = ItemFrame

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

    end

    function ItemFrame:HoverOut()

    end

    function ItemFrame.LoadingIcon:Unhide()
        self:SetAlpha(1)
        self:Show()
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

    -- Animation/visual controls
    function ItemFrame:Reset()
        self:SetAlpha(1)
        self.Icon:ClearAllPoints()
        self.Icon:SetPoint("TOPLEFT", WhoLootFrameData.IconAnimPosLeft[1], WhoLootFrameData.IconAnimPosTop[1])
        self.Icon:SetAlpha(1)
        self.BottomText:ClearAllPoints()
        self.BottomText:SetPoint("TOPLEFT", WhoLootFrameData.BottomTextAnimPosLeft[1], WhoLootFrameData.BottomTextAnimPosTop[1])
        self.BottomText2:ClearAllPoints()
        self.BottomText2:SetPoint("TOPLEFT", ItemFrame.BottomText, "BOTTOMLEFT", 0, -2)
        self.Animating = false
        self.HoverAnimDelta = nil
        self.Lifetime = WhoLootFrameData.FrameLifetime
        self.InUse = false
        self.QueuedRequest = nil
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

