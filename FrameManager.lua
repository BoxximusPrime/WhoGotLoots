WhoGotLootsFrames = {}
WhoGotLootsNumFrames = 10

WhoLootData = WhoLootData or {}

function WhoGotLootsFrames:CreateFrame()

    -- Create a new frame to display the player and item.
    local newframe =  CreateFrame("Frame", nil, nil, "BackdropTemplate")
    newframe:SetWidth(240)
    newframe:SetHeight(35)

    -- Create a text showing which player it was.
    local playerText = newframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerText:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
    playerText:SetPoint("LEFT", 10, 0)
    playerText:SetParent(newframe)
    playerText:SetText("PlayerName")

    -- Create UI
    -- Create a progress bar that will show the timer's progress.
    local progressBar = CreateFrame("StatusBar", nil, newframe)
    progressBar:SetSize(100, 2)
    progressBar:SetPoint("BOTTOMLEFT",  1, 1)
    progressBar:SetPoint("BOTTOMRIGHT", -1, 1)
    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(0)
    progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    progressBar:SetStatusBarColor(1, 1, 1, 0.6)
    progressBar:SetParent(newframe)

    -- Show the item's icon.
    local itemTexture = newframe:CreateTexture(nil, "OVERLAY")
    itemTexture:SetSize(22, 22)
    itemTexture:SetPoint("TOPLEFT", 55, -5)
    itemTexture:SetParent(newframe)
    itemTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- Show the item's name.
    local itemText = newframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemText:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
    itemText:SetPoint("TOPLEFT", 85, -8)
    itemText:SetText("item name")
    itemText:SetParent(newframe)

    BottomTextFrame = newframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    BottomTextFrame:SetFont("Fonts\\FRIZQT__.TTF", 7, "")
    BottomTextFrame:SetPoint("TOPLEFT", itemText, "BOTTOMLEFT", 0, -2)
    BottomTextFrame:SetParent(newframe)
    BottomTextFrame:SetText("Bottom Text")

    -- Register a mouseover to show the item tooltip.
    newframe:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:Show()
        self:SetBackdropColor(0.4, 0.4, 0.4, 1)
    end)

    newframe:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
    end)

    -- Create a close button to remove the frame.
    local close = CreateFrame("Button", nil, newframe, "UIPanelCloseButton")
    close:SetSize(15, 15)
    close:SetPoint("RIGHT", -3, 0)

    newframe:SetBackdrop(WhoGotLootUtil.Backdrop)
    newframe:SetBackdropBorderColor(0, 0, 0, 1) -- Set the border color (RGBA)

    -- Add the frame to the list of frames.
    WhoGotLootsFrames[#WhoGotLootsFrames + 1] = {
        Frame = newframe,
        Player = playerText,
        ItemName = itemText,
        Icon = itemTexture,
        BottomText = BottomTextFrame,
        ProgBar = progressBar,
        InUse = false
    }

    close:SetScript("OnClick", function(self)
        for i, frame in ipairs(WhoGotLootsFrames) do
            if frame.Frame == newframe then
                frame.Frame:Hide()
                frame.InUse = false

                -- Find this frame in WhoLootData.ActiveFrames and remove it.
                for i, activeFrame in ipairs(WhoLootData.ActiveFrames) do
                    if activeFrame[1] == frame then
                        table.remove(WhoLootData.ActiveFrames, i)
                        break
                    end
                end

                WhoLootData.ResortFrames()
                break
            end
        end
    end)
end

-- Create an initial pool.
for i = 1, WhoGotLootsNumFrames do
    WhoGotLootsFrames:CreateFrame()
end