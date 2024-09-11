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
    ItemFrame.background:SetAllPoints(true);
    ItemFrame.background:SetFrameLevel(ItemFrame:GetFrameLevel());
    WGLUIBuilder.DrawSlicedBG(ItemFrame.background, "ItemEntryBG", "backdrop", 0, nil)
    WGLUIBuilder.ColorBGSlicedFrame(ItemFrame.background, "backdrop", 0.12, 0.1, 0.1, 0.85)

    -- Create the border
    ItemFrame.border = CreateFrame("Frame", nil, ItemFrame);
    ItemFrame.border:SetAllPoints(true);
    ItemFrame.border:SetFrameLevel(ItemFrame:GetFrameLevel() + 1);
    WGLUIBuilder.DrawSlicedBG(ItemFrame.border, "ItemEntryBorder", "border", 0, nil)
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

    -- Show the item's name.
    ItemFrame.ItemText = ItemFrame:CreateFontString(nil, "OVERLAY", "WGLFont_ItemName")
    ItemFrame.ItemText:SetPoint("TOPLEFT", 85, -8)
    ItemFrame.ItemText:SetText("item name")
    ItemFrame.ItemText:SetParent(ItemFrame)

    ItemFrame.BottomText = ItemFrame:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    ItemFrame.BottomText:SetPoint("TOPLEFT", itemText, "BOTTOMLEFT", 0, -2)
    ItemFrame.BottomText:SetParent(ItemFrame)
    ItemFrame.BottomText:SetText("Bottom Text")

    -- Create a close button to remove the frame.
    local close = CreateFrame("Button", nil, ItemFrame, "WGLCloseBtn")
    close:SetSize(12, 12)
    close:SetPoint("TOPRIGHT", -6, -6)
    close.ParentFrame = ItemFrame

    -- Add the frame to the list of frames.
    WhoGotLootsFrames[#WhoGotLootsFrames + 1] = ItemFrame

    -- Register user interaction.
    ItemFrame:SetScript("OnEnter", function(self) WhoLootData.HoverFrame(self, true) end)
    ItemFrame:SetScript("OnLeave", function(self) WhoLootData.HoverFrame(self, false) end)

    close:SetScript("OnClick", function(self)
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
    end)
    close:SetScript("OnEnter", function(self) self.Btn:SetVertexColor(1, 1, 1, 1); WhoLootData.HoverFrame(ItemFrame, true) end)
    close:SetScript("OnLeave", function(self) self.Btn:SetVertexColor(0.7, 0.7, 0.7, 1); WhoLootData.HoverFrame(ItemFrame, false) end)

    -- Animation/visual controls
    function ItemFrame:Reset()
        self:SetAlpha(1)
        self.Icon:ClearAllPoints()
        self.Icon:SetPoint("TOPLEFT", WhoLootFrameData.IconStartLeftPos, WhoLootFrameData.IconTopPos)
        self.Icon:SetAlpha(1)
        self.ItemText:ClearAllPoints()
        self.ItemText:SetPoint("TOPLEFT", WhoLootFrameData.ItemNameStartLeftPos, WhoLootFrameData.ItemNameTopPos)
        self.BottomText:ClearAllPoints()
        self.BottomText:SetPoint("TOPLEFT", ItemFrame.ItemText, "BOTTOMLEFT", 0, -2)
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
            self:SetAlpha(WGLUtil.Clamp(self:GetAlpha() - elapsed * 2, 0, 1))
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

