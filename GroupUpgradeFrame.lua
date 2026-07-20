-- Group upgrade presentation.
--
-- This module owns the reverse-loot panel and coordinates its per-member comparison
-- requests. CacheHandler still owns inspection serialization, retries, and equipment
-- snapshots; completed requests feed this panel one member at a time.
--
-- Member data contract:
-- {
--     key = "party1", name = "Player", classFile = "MAGE",
--     unit = "party1", whisperTarget = "Player-Realm",
--     currentItemLevel = 670, candidateItemLevel = 684, delta = 14,
--     status = "upgrade" -- checking, upgrade, equal, no_upgrade, cannot_use, unavailable
-- }

WGLGroupUpgrade = WGLGroupUpgrade or {}
WGLGroupUpgrade.Frames = WGLGroupUpgrade.Frames or {}

WGLGroupUpgrade.Status = {
    CHECKING = "checking",
    UPGRADE = "upgrade",
    EQUAL = "equal",
    NO_UPGRADE = "no_upgrade",
    CANNOT_USE = "cannot_use",
    UNAVAILABLE = "unavailable",
}

local PANEL_WIDTH = 270
local PANEL_PADDING = 6
local HEADER_HEIGHT = 36
local ROW_HEIGHT = 20
local ROW_GAP = 0
local MAX_PARTY_MEMBERS = 4

local function ReduceFontSizeByOne(fontString)
    local fontFile, fontHeight, fontFlags = fontString:GetFont()
    if fontFile and fontHeight then
        fontString:SetFont(fontFile, math.max(1, fontHeight - 1), fontFlags)
    end
end

local STATUS_STYLE = {
    checking = {
        label = "CHECKING...",
        text = { 0.72, 0.78, 0.86, 1 },
        background = { 0.18, 0.28, 0.40, 0.55 },
        border = { 0.30, 0.48, 0.68, 0.9 },
    },
    upgrade = {
        label = "UPGRADE",
        text = { 0.48, 0.94, 0.40, 1 },
        background = { 0.10, 0.38, 0.12, 0.55 },
        border = { 0.30, 0.72, 0.28, 0.9 },
    },
    equal = {
        label = "EQUAL",
        text = { 0.94, 0.76, 0.30, 1 },
        background = { 0.38, 0.27, 0.08, 0.55 },
        border = { 0.70, 0.52, 0.16, 0.9 },
    },
    no_upgrade = {
        label = "NO UPGRADE",
        text = { 0.68, 0.70, 0.74, 1 },
        background = { 0.18, 0.18, 0.20, 0.65 },
        border = { 0.36, 0.37, 0.40, 0.9 },
    },
    cannot_use = {
        label = "CAN'T USE",
        text = { 0.90, 0.38, 0.34, 1 },
        background = { 0.38, 0.10, 0.08, 0.55 },
        border = { 0.66, 0.22, 0.18, 0.9 },
    },
    unavailable = {
        label = "UNAVAILABLE",
        text = { 0.58, 0.58, 0.60, 1 },
        background = { 0.14, 0.14, 0.15, 0.65 },
        border = { 0.30, 0.30, 0.32, 0.9 },
    },
}

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function GetMemberStatus(member)
    if member.status and STATUS_STYLE[member.status] then return member.status end
    if member.delta == nil then return WGLGroupUpgrade.Status.CHECKING end
    if member.delta > 0 then return WGLGroupUpgrade.Status.UPGRADE end
    if member.delta == 0 then return WGLGroupUpgrade.Status.EQUAL end
    return WGLGroupUpgrade.Status.NO_UPGRADE
end

local function GetStatusText(member, status, displayDelta)
    if status == WGLGroupUpgrade.Status.UPGRADE and displayDelta then
        return string.format("+%d  UPGRADE", displayDelta)
    end
    if status == WGLGroupUpgrade.Status.NO_UPGRADE and displayDelta then
        return string.format("%d  NO UPGRADE", displayDelta)
    end
    return STATUS_STYLE[status].label
end

local function RemoveFromActiveFrames(panel)
    if not WhoLootData or not WhoLootData.ActiveFrames or not panel then return end

    for index = #WhoLootData.ActiveFrames, 1, -1 do
        if WhoLootData.ActiveFrames[index] == panel then
            table.remove(WhoLootData.ActiveFrames, index)
        end
    end
end

local function AddToActiveFrames(panel)
    if not WhoLootData or not WhoLootData.ActiveFrames or not panel then return end
    RemoveFromActiveFrames(panel)
    WhoLootData.ActiveFrames[#WhoLootData.ActiveFrames + 1] = panel
end

local function PauseLifetime(panel)
    panel.HoverAnimDelta = 0
    WGLUIBuilder.ColorBGSlicedFrame(panel, "border", 0.9, 0.9, 0.95, 1)
end

local function ResumeLifetimeIfOutside(panel)
    if not panel:IsMouseOver() then
        panel.HoverAnimDelta = nil
        WGLUIBuilder.ColorBGSlicedFrame(panel, "border", unpack(WhoLootFrameData.BorderColor))
    end
end

local function CloseOnRightClick(panel, button)
    if button == "RightButton" then WGLGroupUpgrade.Hide(panel) end
end

local function GetMemberUnit(member)
    local unit = member.unit
    if not unit and type(member.key) == "string" and UnitExists(member.key) then
        unit = member.key
    end

    if unit and UnitExists(unit) then
        local name, realm = UnitFullName(unit)
        if not (issecretvalue and (issecretvalue(name) or issecretvalue(realm))) and name then
            local fullName = realm and realm ~= "" and (name .. "-" .. realm:gsub("%s+", "")) or name
            if not member.fullName or member.fullName == fullName or member.name == fullName then
                return unit
            end
        end
    end

    return member.fullName and WGLU.GetPlayerUnitByName(member.fullName) or nil
end

local function GetWhisperTarget(member)
    if member.whisperTarget then return member.whisperTarget end

    local unit = GetMemberUnit(member)
    if unit then
        local name, realm = UnitFullName(unit)
        if issecretvalue and (issecretvalue(name) or issecretvalue(realm)) then return nil end
        if name and realm and realm ~= "" then return name .. "-" .. realm:gsub("%s+", "") end
        if name then return name end
    end

    return member.fullName or member.name
end

local function ResolvePanelItemLocation(panel)
    if panel.ItemGUID and C_Item.IsItemGUIDInInventory(panel.ItemGUID) then
        local itemLocation = C_Item.GetItemLocation(panel.ItemGUID)
        if itemLocation then
            local bagID, slotID = itemLocation:GetBagAndSlot()
            if bagID and slotID and C_Container.GetContainerItemLink(bagID, slotID) == panel.ItemLink then
                return bagID, slotID
            end
        end
    end

    local fallbackBag, fallbackSlot, fallbackGUID
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
    for bagID = BACKPACK_CONTAINER or 0, lastBag do
        for slotID = 1, C_Container.GetContainerNumSlots(bagID) do
            if C_Container.GetContainerItemLink(bagID, slotID) == panel.ItemLink then
                local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
                local itemGUID = C_Item.GetItemGUID(itemLocation)
                if C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bagID, slotID) then
                    panel.ItemGUID = itemGUID
                    return bagID, slotID
                end
                if not fallbackBag then
                    fallbackBag, fallbackSlot, fallbackGUID = bagID, slotID, itemGUID
                end
            end
        end
    end

    panel.ItemGUID = fallbackGUID
    return fallbackBag, fallbackSlot
end

local function TradeItemToMember(panel, member)
    if not member then return end
    if panel.Options and panel.Options.isPreview then
        print("Who Got Loots: preview rows do not start trades.")
        return
    end
    if TradeFrame and TradeFrame:IsShown() then
        print("Who Got Loots: finish or close the current trade first.")
        return
    end

    local unit = GetMemberUnit(member)
    if not unit or not UnitPlayerControlled(unit) then
        print("Who Got Loots: that player is no longer available to trade.")
        return
    end

    local inRange = CheckInteractDistance(unit, 2)
    if issecretvalue and issecretvalue(inRange) then inRange = false end
    if not inRange then
        print("Who Got Loots: move closer to " .. (member.name or "that player") .. " to trade.")
        return
    end
    if CursorHasItem() then
        print("Who Got Loots: clear the item currently on your cursor first.")
        return
    end

    local bagID, slotID = ResolvePanelItemLocation(panel)
    if not bagID or not slotID then
        print("Who Got Loots: couldn't find that exact item in your bags.")
        return
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if C_Item.IsLocked(itemLocation) then
        print("Who Got Loots: that item is currently locked; try again in a moment.")
        return
    end

    C_Container.PickupContainerItem(bagID, slotID)
    if not CursorHasItem() then
        print("Who Got Loots: couldn't pick up that item from your bags.")
        return
    end

    local ok, errorMessage = pcall(C_Item.DropItemOnUnit, unit)
    if not ok then
        ClearCursor()
        geterrorhandler()(errorMessage)
        print("Who Got Loots: WoW blocked the trade action.")
    end
end

local function WhisperOfferToMember(panel, member)
    if not member then return end
    if panel.Options and panel.Options.isPreview then
        print("Who Got Loots: preview rows do not send whispers.")
        return
    end

    local itemLink = panel.ItemLink
    local target = GetWhisperTarget(member)
    if not itemLink or not target then
        print("Who Got Loots: couldn't resolve that player or item for the whisper.")
        return
    end

    local message = WhoGotLootsSavedData.OfferWhisperMessage or WGLUIBuilder.DefaultOfferWhisperMessage
    message = message:gsub("%%n", member.name or target)
    message = message:gsub("%%i", itemLink)
    SendChatMessage(message, "WHISPER", nil, target)
end

local function AnnounceUnneededItem(panel)
    if panel.Options and panel.Options.isPreview then
        print("Who Got Loots: preview frames do not send group messages.")
        return
    end

    if not panel.ItemLink then return end

    local message = WhoGotLootsSavedData.IDontNeedMessage
    if not message then return end
    message = message:gsub("%%i", panel.ItemLink)

    local chatType = "SAY"
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        chatType = "INSTANCE_CHAT"
    elseif IsInRaid() then
        chatType = "RAID"
    elseif IsInGroup() then
        chatType = "PARTY"
    end

    SendChatMessage(message, chatType)
end

local function HandlePanelMouseDown(panel, button)
    if button == "MiddleButton" then
        AnnounceUnneededItem(panel)
    else
        CloseOnRightClick(panel, button)
    end
end

local function CreateMemberRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANEL_WIDTH - PANEL_PADDING * 2, ROW_HEIGHT)
    row:EnableMouse(true)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(0.32, 0.48, 0.68, 0.20)
    row.highlight:Hide()

    row.classStripe = row:CreateTexture(nil, "ARTWORK")
    row.classStripe:SetPoint("TOPLEFT", 0, -4)
    row.classStripe:SetPoint("BOTTOMLEFT", 0, 4)
    row.classStripe:SetWidth(2)
    row.classStripe:SetColorTexture(0.55, 0.55, 0.55, 1)

    row.name = row:CreateFontString(nil, "OVERLAY", "WGLFont_ItemName")
    row.name:SetPoint("LEFT", 6, 1)
    row.name:SetWidth(72)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    ReduceFontSizeByOne(row.name)

    row.comparison = row:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    row.comparison:SetPoint("LEFT", row.name, "RIGHT", 1, 0)
    row.comparison:SetWidth(60)
    row.comparison:SetJustifyH("CENTER")
    row.comparison:SetTextColor(0.72, 0.72, 0.74, 1)
    ReduceFontSizeByOne(row.comparison)

    row.tradeButton = CreateFrame("Button", nil, row)
    row.tradeButton:SetPoint("RIGHT", -2, 0)
    row.tradeButton:SetSize(16, 16)
    WGLUIBuilder.DrawSlicedBG(row.tradeButton, "ItemStatBG", "backdrop", 0)
    WGLUIBuilder.DrawSlicedBG(row.tradeButton, "ItemStatBorder", "border", 0)
    WGLUIBuilder.ColorBGSlicedFrame(row.tradeButton, "backdrop", 0.16, 0.17, 0.19, 0.92)
    WGLUIBuilder.ColorBGSlicedFrame(row.tradeButton, "border", 0.40, 0.42, 0.46, 0.95)
    row.tradeButton.icon = row.tradeButton:CreateTexture(nil, "ARTWORK")
    row.tradeButton.icon:SetPoint("TOPLEFT", 2, -2)
    row.tradeButton.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    row.tradeButton.icon:SetColorTexture(0.78, 0.80, 0.84, 1)
    row.tradeButton.iconMask = row.tradeButton:CreateMaskTexture(nil, "ARTWORK")
    row.tradeButton.iconMask:SetAllPoints(row.tradeButton.icon)
    row.tradeButton.iconMask:SetTexture(
        "Interface\\AddOns\\WhoGotLoots\\Art\\trade.png",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )
    row.tradeButton.icon:AddMaskTexture(row.tradeButton.iconMask)
    row.tradeButton:SetScript("OnEnter", function(self)
        row.highlight:Show()
        self.icon:SetColorTexture(1, 1, 1, 1)
        WGLUIBuilder.ColorBGSlicedFrame(self, "backdrop", 0.28, 0.30, 0.34, 1)
        WGLUIBuilder.ColorBGSlicedFrame(self, "border", 0.78, 0.82, 0.90, 1)
        PauseLifetime(parent)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Trade item", 1, 1, 1)
        GameTooltip:AddLine("Opens a trade and places this item in it.", 0.72, 0.74, 0.78, true)
        GameTooltip:Show()
    end)
    row.tradeButton:SetScript("OnLeave", function(self)
        self.icon:SetColorTexture(0.78, 0.80, 0.84, 1)
        WGLUIBuilder.ColorBGSlicedFrame(self, "backdrop", 0.16, 0.17, 0.19, 0.92)
        WGLUIBuilder.ColorBGSlicedFrame(self, "border", 0.40, 0.42, 0.46, 0.95)
        row.highlight:SetShown(row:IsMouseOver())
        GameTooltip:Hide()
        ResumeLifetimeIfOutside(parent)
    end)
    row.tradeButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            WGLUIBuilder.ColorBGSlicedFrame(self, "backdrop", 0.40, 0.42, 0.48, 1)
        elseif button == "MiddleButton" then
            WhisperOfferToMember(parent, row.member)
        else
            CloseOnRightClick(parent, button)
        end
    end)
    row.tradeButton:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            WGLUIBuilder.ColorBGSlicedFrame(self, "backdrop", 0.28, 0.30, 0.34, 1)
        end
    end)
    row.tradeButton:SetScript("OnClick", function()
        TradeItemToMember(parent, row.member)
    end)

    row.status = CreateFrame("Frame", nil, row)
    row.status:SetPoint("RIGHT", row.tradeButton, "LEFT", -2, 0)
    row.status:SetSize(96, 14)
    WGLUIBuilder.DrawSlicedBG(row.status, "ItemStatBG", "backdrop", 0)
    WGLUIBuilder.DrawSlicedBG(row.status, "ItemStatBorder", "border", 0)

    row.status.text = row.status:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    row.status.text:SetPoint("CENTER", 0, 0)
    ReduceFontSizeByOne(row.status.text)

    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        PauseLifetime(parent)
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        ResumeLifetimeIfOutside(parent)
    end)
    row:SetScript("OnMouseDown", function(self, button)
        if button == "MiddleButton" then
            WhisperOfferToMember(parent, self.member)
        else
            CloseOnRightClick(parent, button)
        end
    end)

    row:Hide()
    return row
end

local function CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetPoint("TOP", parent, "BOTTOM", 0, 8)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel.InUse = false
    panel.Animating = false
    panel.Generation = 0
    panel.Members = {}
    panel.Options = {}
    panel.ItemLink = nil
    panel.ItemLevel = nil
    panel.HoverAnimDelta = nil
    panel.Lifetime = WhoLootFrameData.FrameLifetime

    WGLUIBuilder.DrawSlicedBG(panel, "ItemEntryBG", "backdrop", 0)
    WGLUIBuilder.ColorBGSlicedFrame(panel, "backdrop", 0.09, 0.09, 0.10, 0.96)
    WGLUIBuilder.DrawSlicedBG(panel, "ItemEntryBorder", "border", 0)
    WGLUIBuilder.ColorBGSlicedFrame(panel, "border", unpack(WhoLootFrameData.BorderColor))

    panel.title = panel:CreateFontString(nil, "OVERLAY", "WGLFont_ItemName")
    panel.title:SetPoint("TOPLEFT", PANEL_PADDING, -5)
    panel.title:SetText("WHO COULD USE THIS?")
    panel.title:SetTextColor(0.76, 0.84, 0.94, 1)

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    panel.subtitle:SetPoint("LEFT", panel.title, "RIGHT", 6, 0)
    panel.subtitle:SetText("YOUR DROP")
    panel.subtitle:SetTextColor(0.46, 0.48, 0.52, 1)

    panel.close = CreateFrame("Button", nil, panel, "WGLCloseBtn")
    panel.close:SetSize(12, 12)
    panel.close:SetPoint("TOPRIGHT", -4, -4)
    panel.close:SetScript("OnClick", function() WGLGroupUpgrade.Hide(panel) end)
    panel.close:HookScript("OnMouseDown", function(_, button) CloseOnRightClick(panel, button) end)
    panel.close:HookScript("OnEnter", function() PauseLifetime(panel) end)
    panel.close:HookScript("OnLeave", function() ResumeLifetimeIfOutside(panel) end)

    panel.itemHeader = CreateFrame("Frame", nil, panel)
    panel.itemHeader:SetPoint("TOPLEFT", PANEL_PADDING, -21)
    panel.itemHeader:SetPoint("TOPRIGHT", -PANEL_PADDING, -21)
    panel.itemHeader:SetHeight(HEADER_HEIGHT)
    panel.itemHeader:EnableMouse(true)
    WGLUIBuilder.DrawSlicedBG(panel.itemHeader, "ItemEntryBG", "backdrop", 0)
    WGLUIBuilder.ColorBGSlicedFrame(panel.itemHeader, "backdrop", 0.16, 0.14, 0.14, 0.92)
    WGLUIBuilder.DrawSlicedBG(panel.itemHeader, "ItemEntryBorder", "border", 0)
    WGLUIBuilder.ColorBGSlicedFrame(panel.itemHeader, "border", 0.42, 0.42, 0.44, 0.9)

    panel.icon = panel.itemHeader:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(28, 28)
    panel.icon:SetPoint("LEFT", 4, 0)
    panel.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    panel.itemName = panel.itemHeader:CreateFontString(nil, "OVERLAY", "WGLFont_ItemName")
    panel.itemName:SetPoint("TOPLEFT", panel.icon, "TOPRIGHT", 6, -2)
    panel.itemName:SetPoint("RIGHT", -6, 0)
    panel.itemName:SetJustifyH("LEFT")
    panel.itemName:SetWordWrap(false)
    panel.itemName:SetText("Loading item...")

    panel.itemDetails = panel.itemHeader:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    panel.itemDetails:SetPoint("BOTTOMLEFT", panel.icon, "BOTTOMRIGHT", 6, 2)
    panel.itemDetails:SetTextColor(0.66, 0.68, 0.72, 1)

    panel.itemHeader:SetScript("OnEnter", function(self)
        PauseLifetime(panel)
        if not panel.ItemLink then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(panel.ItemLink)
        GameTooltip:Show()
    end)
    panel.itemHeader:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ResumeLifetimeIfOutside(panel)
    end)
    panel.itemHeader:SetScript("OnMouseDown", function(_, button) HandlePanelMouseDown(panel, button) end)

    panel:SetScript("OnEnter", function() PauseLifetime(panel) end)
    panel:SetScript("OnLeave", function() ResumeLifetimeIfOutside(panel) end)
    panel:SetScript("OnMouseDown", function(_, button) HandlePanelMouseDown(panel, button) end)

    panel.rows = {}
    for index = 1, MAX_PARTY_MEMBERS do
        local row = CreateMemberRow(panel)
        row:SetPoint("TOPLEFT", panel.itemHeader, "BOTTOMLEFT", 0, -PANEL_PADDING - (index - 1) * (ROW_HEIGHT + ROW_GAP))
        panel.rows[index] = row
    end

    panel.emptyText = panel:CreateFontString(nil, "OVERLAY", "WGLFont_Item_StatBottomText")
    panel.emptyText:SetPoint("TOP", panel.itemHeader, "BOTTOM", 0, -18)
    panel.emptyText:SetText("No party members to compare.")
    panel.emptyText:SetTextColor(0.55, 0.55, 0.58, 1)
    panel.emptyText:Hide()

    panel.ProgressBar = CreateFrame("StatusBar", nil, panel)
    panel.ProgressBar:SetPoint("BOTTOMLEFT", 1, 2)
    panel.ProgressBar:SetPoint("BOTTOMRIGHT", -1, 2)
    panel.ProgressBar:SetHeight(2)
    panel.ProgressBar:SetMinMaxValues(0, 1)
    panel.ProgressBar:SetValue(1)
    panel.ProgressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    panel.ProgressBar:SetStatusBarColor(0.5, 0.5, 0.5, 0.6)
    panel.RequestIDs = {}

    function panel:CancelQueuedRequest()
        if WGLCache then
            for _, requestID in ipairs(self.RequestIDs or {}) do
                WGLCache.CancelRequest(requestID)
            end
        end
        self.RequestIDs = {}
        self:SetScript("OnUpdate", nil)
        self.Animating = false
    end

    function panel:FadeOut()
        self:CancelQueuedRequest()
        self.Animating = true
        self:SetScript("OnUpdate", function(self, elapsed)
            self:SetAlpha(WGLU.Clamp(self:GetAlpha() - elapsed * 2, 0, 1))
            if self:GetAlpha() <= 0 then
                self:SetScript("OnUpdate", nil)
                self:SetAlpha(1)
                self:Hide()
                self.InUse = false
                self.Animating = false
                self.ItemLink = nil
                self.ItemGUID = nil
                RemoveFromActiveFrames(self)
                WhoLootData.ResortFrames()
            end
        end)
    end

    panel:Hide()
    return panel
end

local function RenderMemberRow(row, member, candidateItemLevel)
    local classColor = member.classFile and RAID_CLASS_COLORS[member.classFile]
    local red, green, blue = 0.72, 0.72, 0.74
    if classColor then red, green, blue = classColor.r, classColor.g, classColor.b end

    row.name:SetText(member.name or member.key or "Unknown")
    row.member = member
    row.highlight:Hide()
    row.name:SetTextColor(red, green, blue, 1)
    row.classStripe:SetColorTexture(red, green, blue, 1)

    local itemLevel = member.candidateItemLevel or candidateItemLevel
    local equippedItemLevel = member.currentItemLevel
    local displayDelta = member.delta
    if not equippedItemLevel and itemLevel and member.delta then
        equippedItemLevel = math.max(0, itemLevel - member.delta)
        displayDelta = itemLevel - equippedItemLevel
    end

    if equippedItemLevel and itemLevel then
        row.comparison:SetText(string.format("%d  >  %d", equippedItemLevel, itemLevel))
    else
        row.comparison:SetText("--  >  --")
    end

    local status = GetMemberStatus(member)
    local style = STATUS_STYLE[status]
    row.status.text:SetText(GetStatusText(member, status, displayDelta))
    row.status.text:SetTextColor(unpack(style.text))
    WGLUIBuilder.ColorBGSlicedFrame(row.status, "backdrop", unpack(style.background))
    WGLUIBuilder.ColorBGSlicedFrame(row.status, "border", unpack(style.border))
    row:Show()
end

local function RenderMembers(panel)
    if not panel then return end

    local memberCount = math.min(#panel.Members, MAX_PARTY_MEMBERS)
    for index, row in ipairs(panel.rows) do
        local member = panel.Members[index]
        if member then
            RenderMemberRow(row, member, panel.ItemLevel)
        else
            row.member = nil
            row.highlight:Hide()
            row:Hide()
        end
    end

    panel.emptyText:SetShown(memberCount == 0)
    local bodyHeight = memberCount > 0 and
        (memberCount * ROW_HEIGHT + math.max(0, memberCount - 1) * ROW_GAP) or 38
    panel:SetHeight(21 + HEADER_HEIGHT + PANEL_PADDING * 2 + bodyHeight + 2)

    local playerDelta = panel.Options.playerDelta
    local playerDeltaText = "You: comparison pending"
    if playerDelta then
        if playerDelta > 0 then
            playerDeltaText = string.format("You: +%d ilvl", playerDelta)
        elseif playerDelta < 0 then
            playerDeltaText = string.format("You: %d ilvl", playerDelta)
        else
            playerDeltaText = "You: equal ilvl"
        end
    end

    panel.itemDetails:SetText(string.format(
        "%s  |  %s  |  %d party member%s",
        playerDeltaText,
        panel.ItemLevel and (panel.ItemLevel .. " ilvl") or "item level pending",
        memberCount,
        memberCount == 1 and "" or "s"
    ))

    if panel.InUse and WhoLootData and WhoLootData.ResortFrames then
        WhoLootData.ResortFrames()
    end
end

local function ApplyLoadedItem(panel, itemReference, generation)
    if not panel.InUse or generation ~= panel.Generation then return end

    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemReference)
    if not itemLink and type(itemReference) == "string" and itemReference:find("|Hitem:", 1, true) then
        itemLink = itemReference
    end

    panel.ItemLink = itemLink
    panel.ItemLevel = panel.Options.itemLevel or C_Item.GetDetailedItemLevelInfo(itemLink or itemReference)

    panel.icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if itemName and itemQuality then
        panel.itemName:SetText("|c" .. select(4, C_Item.GetItemQualityColor(itemQuality)) .. "[" .. itemName .. "]|r")
    else
        panel.itemName:SetText(itemName or "Unknown item")
    end

    RenderMembers(panel)
end

function WGLGroupUpgrade.Initialize(parent)
    if parent then WGLGroupUpgrade.Parent = parent end
    return WGLGroupUpgrade.Parent
end

function WGLGroupUpgrade.Show(itemReference, members, options)
    if not WGLGroupUpgrade.Parent then
        WGLGroupUpgrade.Initialize(WhoLootData and WhoLootData.MainFrame)
    end
    if not WGLGroupUpgrade.Parent or not itemReference then return nil end

    local panel
    for _, pooledPanel in ipairs(WGLGroupUpgrade.Frames) do
        if not pooledPanel.InUse then
            panel = pooledPanel
            break
        end
    end
    if not panel then
        panel = CreatePanel(WGLGroupUpgrade.Parent)
        WGLGroupUpgrade.Frames[#WGLGroupUpgrade.Frames + 1] = panel
    end

    panel.Generation = panel.Generation + 1
    local generation = panel.Generation
    panel.Members = {}
    panel.Options = options or {}
    panel.ItemLink = type(itemReference) == "string" and
        itemReference:find("|Hitem:", 1, true) and itemReference or nil
    panel.ItemGUID = nil
    panel.ItemLevel = panel.Options.itemLevel
    if panel.ItemLink and not panel.Options.isPreview then ResolvePanelItemLocation(panel) end

    for index, member in ipairs(members or {}) do
        if index > MAX_PARTY_MEMBERS then break end
        panel.Members[index] = CopyTable(member)
    end

    panel:CancelQueuedRequest()
    panel:SetAlpha(1)
    WGLUIBuilder.ColorBGSlicedFrame(panel, "border", unpack(WhoLootFrameData.BorderColor))
    panel.Lifetime = WhoLootFrameData.FrameLifetime
    panel.HoverAnimDelta = nil
    panel.ProgressBar:SetValue(1)
    panel.InUse = true
    panel.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    panel.itemName:SetText("Loading item...")
    panel:Show()
    AddToActiveFrames(panel)
    RenderMembers(panel)
    if WhoLootData and WhoLootData.MainFrame then WhoLootData.MainFrame:Open() end

    local numericID = tonumber(itemReference)
    local item = numericID and Item:CreateFromItemID(numericID) or Item:CreateFromItemLink(itemReference)
    item:ContinueOnItemLoad(function() ApplyLoadedItem(panel, numericID or itemReference, generation) end)
    return panel
end

function WGLGroupUpgrade.UpdateMember(panel, memberKey, result)
    if not panel or not panel.InUse then return false end
    for index, member in ipairs(panel.Members or {}) do
        if index == memberKey or member.key == memberKey or member.unit == memberKey then
            for key, value in pairs(result or {}) do member[key] = value end
            RenderMembers(panel)
            return true
        end
    end
    return false
end

function WGLGroupUpgrade.BeginPartyCheck(itemLink, itemLevel, itemLocation, itemID, playerDelta)
    if not IsInGroup() or IsInRaid() then return false end

    local members = {}
    for index = 1, GetNumSubgroupMembers() do
        local unit = "party" .. index
        if UnitExists(unit) then
            local name, realm = UnitFullName(unit)
            local _, classFile = UnitClass(unit)
            local hasSecretIdentity = issecretvalue and (issecretvalue(name) or issecretvalue(realm))
            if not hasSecretIdentity and name then
                members[#members + 1] = {
                    key = unit,
                    unit = unit,
                    name = name,
                    fullName = realm and realm ~= "" and (name .. "-" .. realm:gsub("%s+", "")) or name,
                    classFile = classFile,
                    status = WGLGroupUpgrade.Status.CHECKING,
                }
            end
        end
    end

    if #members == 0 then return false end

    local panel = WGLGroupUpgrade.Show(itemLink, members, {
        itemLevel = itemLevel,
        itemID = itemID,
        itemLocation = itemLocation,
        playerDelta = playerDelta,
    })
    if not panel then return false end

    local generation = panel.Generation
    local itemEquipLoc, _, itemClassID = select(4, C_Item.GetItemInfoInstant(itemID))
    for _, member in ipairs(panel.Members) do
        local memberForRequest = member
        local request = {
            ItemLocation = itemLocation,
            ItemLevel = itemLevel,
            ItemID = itemID,
            ItemEquipLoc = itemEquipLoc,
            RequireSpec = itemClassID == Enum.ItemClass.Weapon,
            IsActive = function()
                return panel.InUse and generation == panel.Generation
            end,
            OnComplete = function(_, equippedItemLevel, cachedSpecID)
                local specID = cachedSpecID or memberForRequest.specID
                if not specID and GetInspectSpecialization then
                    local inspectedSpecID = GetInspectSpecialization(memberForRequest.unit)
                    if inspectedSpecID and inspectedSpecID > 0 then specID = inspectedSpecID end
                end

                local isAppropriate = WGLItemsDB.IsAppropriate(itemID, memberForRequest.classFile, specID) == true
                local delta = WGLUIBuilder.GetItemLevelDelta(itemLevel, equippedItemLevel)
                if delta == nil then
                    WGLGroupUpgrade.UpdateMember(panel, memberForRequest.key, {
                        status = WGLGroupUpgrade.Status.UNAVAILABLE,
                        failureReason = "Comparison unavailable",
                    })
                    return
                end
                local status
                if not isAppropriate then
                    status = WGLGroupUpgrade.Status.CANNOT_USE
                elseif delta > 0 then
                    status = WGLGroupUpgrade.Status.UPGRADE
                elseif delta == 0 then
                    status = WGLGroupUpgrade.Status.EQUAL
                else
                    status = WGLGroupUpgrade.Status.NO_UPGRADE
                end

                WGLGroupUpgrade.UpdateMember(panel, memberForRequest.key, {
                    currentItemLevel = equippedItemLevel,
                    candidateItemLevel = itemLevel,
                    delta = delta,
                    status = status,
                    specID = specID,
                })
            end,
            OnFailure = function(_, reason)
                WGLGroupUpgrade.UpdateMember(panel, memberForRequest.key, {
                    status = WGLGroupUpgrade.Status.UNAVAILABLE,
                    failureReason = reason,
                })
            end,
        }

        local requestID = WGLCache.CreateRequest(
            memberForRequest.unit,
            request,
            UnitGUID(memberForRequest.unit),
            memberForRequest.fullName
        )
        panel.RequestIDs[#panel.RequestIDs + 1] = requestID
    end

    return true
end

function WGLGroupUpgrade.Hide(panel)
    if not panel then
        for index = #WGLGroupUpgrade.Frames, 1, -1 do
            if WGLGroupUpgrade.Frames[index].InUse then
                panel = WGLGroupUpgrade.Frames[index]
                break
            end
        end
    end
    if not panel then return end

    panel.Generation = panel.Generation + 1
    panel.ItemLink = nil
    panel.ItemGUID = nil
    panel:CancelQueuedRequest()
    panel:SetAlpha(1)
    WGLUIBuilder.ColorBGSlicedFrame(panel, "border", unpack(WhoLootFrameData.BorderColor))
    panel.InUse = false
    panel:Hide()
    RemoveFromActiveFrames(panel)
    if WhoLootData and WhoLootData.ResortFrames then WhoLootData.ResortFrames() end
    GameTooltip:Hide()
end

function WGLGroupUpgrade.ShowTest(itemReference)
    itemReference = itemReference or GetInventoryItemLink("player", INVSLOT_CHEST) or 19019

    local members = {
        { key = "party1", name = "Arcweaver", classFile = "MAGE", delta = 18 },
        { key = "party2", name = "Ironroot", classFile = "WARRIOR", delta = 7 },
        { key = "party3", name = "Moonsong", classFile = "DRUID", delta = 0 },
        { key = "party4", name = "Veilstep", classFile = "ROGUE", delta = -12 },
    }

    WGLGroupUpgrade.Show(itemReference, members, { isPreview = true, playerDelta = -5 })
end
