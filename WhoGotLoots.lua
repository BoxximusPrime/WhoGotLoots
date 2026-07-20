-- Define a table to store global variables
WhoLootData = WhoLootData or {}
WhoLootDataVers = C_AddOns.GetAddOnMetadata("WhoGotLoots", "Version")
WGLU.DebugMode = false

WhoLootData.ActiveFrames = {} -- A table to store all active frames.

WhoLootData.MainFrame = WGLUIBuilder.CreateMainFrame()
WhoLootData.MainFrame:SetParent(UIParent)
WhoLootData.MainFrame:SetDontSavePosition(true)
WGLGroupUpgrade.Initialize(WhoLootData.MainFrame)

-- Register Events --
WhoLootData.MainFrame:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
WhoLootData.MainFrame:RegisterEvent("CHAT_MSG_LOOT")

WhoLootFrameData = WhoLootFrameData or {}

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function UsableItemLevel(value)
    if IsSecret(value) or type(value) ~= "number" then return nil end
    return value
end

local function IsOwnItemUpgradeMessage(message, itemLinks)
    -- Item upgrades are delivered through CHAT_MSG_LOOT, but this is a
    -- replacement, not newly received loot.  Use Blizzard's localized format
    -- string so this also works on non-English clients.
    return #itemLinks == 2 and CHANGED_OWN_ITEM and
        message == string.format(CHANGED_OWN_ITEM, itemLinks[1], itemLinks[2])
end

local function EscapeLuaPattern(text)
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function MatchesOtherPlayerBonusFormat(message, formatString, itemLink)
    if type(formatString) ~= "string" then return false end

    -- The raw chat message can decorate the player's displayed name differently
    -- from CHAT_MSG_LOOT's plain playerName argument. Build the localized
    -- Blizzard message with markers, allow only the player field to vary, and
    -- require the exact hyperlink that WhoGotLoots will put on the frame.
    local playerMarker = "__WGL_BONUS_PLAYER__"
    local itemMarker = "__WGL_BONUS_ITEM__"
    local ok, template = pcall(string.format, formatString, playerMarker, itemMarker)
    if not ok then return false end

    local pattern = EscapeLuaPattern(template)
    pattern = pattern:gsub(EscapeLuaPattern(playerMarker), function() return ".-" end)
    pattern = pattern:gsub(EscapeLuaPattern(itemMarker), function() return EscapeLuaPattern(itemLink) end)
    return message:match("^" .. pattern .. "$") ~= nil
end

local function IsBonusLootMessage(message, itemLinks)
    if #itemLinks ~= 1 then return false end

    local itemLink = itemLinks[1]
    if MatchesOtherPlayerBonusFormat(message, LOOT_ITEM_BONUS_ROLL, itemLink) then return true end

    if type(LOOT_ITEM_BONUS_ROLL_SELF) == "string" then
        local ok, selfMessage = pcall(string.format, LOOT_ITEM_BONUS_ROLL_SELF, itemLink)
        if ok and message == selfMessage then return true end
    end

    -- Keep current English clients working if Blizzard renames or temporarily
    -- omits the non-self global while retaining the chat wording. The exact
    -- hyperlink requirement prevents an unrelated chat line from tagging a
    -- different loot frame.
    local locale = GetLocale()
    if (locale == "enUS" or locale == "enGB") and
        message:find(" receives bonus loot: ", 1, true) and
        message:find(itemLink, 1, true) then
        return true
    end

    return false
end

-- Handle Events --
function HandleEvents(self, event, ...)
    local args = { ... }

    if event == "ADDON_LOADED" and args[1] == "WhoGotLoots" then
        WhoGotLootsSavedData = WhoGotLootsSavedData or {}
        WhoLootsOptionsEntries.LoadOptions()

        if WhoGotLootsSavedData.FirstBoot == false then
            WhoLootData.MainFrame:Close()
        else
            WhoLootData.MainFrame:LockWindow(false)
        end
        WhoGotLootsSavedData.FirstBoot = false

        -- Set window scale.
        WhoLootData.MainFrame:SetScale(WhoGotLootsSavedData.SavedSize)
        WhoLootData.MainFrame.infoTooltip:SetScale(WhoGotLootsSavedData.SavedSize)
        WhoLootData.MainFrame.cursorFrame:SetScale(WhoGotLootsSavedData.SavedSize)
        WGLUIBuilder.WhisperEditor:SetScale(WhoGotLootsSavedData.SavedSize)
        WGLUIBuilder.IDontNeedEditor:SetScale(WhoGotLootsSavedData.SavedSize)
        WGLUIBuilder.OfferWhisperEditor:SetScale(WhoGotLootsSavedData.SavedSize)

        -- Parent all the item boxes to the main window.
        for i, frame in ipairs(WhoGotLootsFrames) do
            frame:SetParent(WhoLootData.MainFrame)
        end

        -- Set window position (we do this after loading the options, because the saved position is loaded in LoadOptions)
        if WhoGotLootsSavedData.SavedPos then
            WhoLootData.MainFrame:Move(WhoGotLootsSavedData.SavedPos)
        else
            WhoLootData.MainFrame:Move({ "CENTER", nil, "CENTER" })
        end
    elseif event == "CHAT_MSG_LOOT" then
        -- Debug: Print all event arguments to understand the structure
        WGLU.DebugPrint("CHAT_MSG_LOOT Debug - Total args: " .. #args)
        for i = 1, #args do
            WGLU.DebugPrint("  args[" .. i .. "] = " .. tostring(args[i]))
        end

        -- Make sure we have an assosciated player.
        if args[2] == nil or args[2] == "" then
            WGLU.DebugPrint("ERROR: No player name found in loot message. args[2] is nil or empty.")
            return
        end

        -- Scrape the message for item links. Item links look like "|cffffffff|Hitem:2589::::::::20:257::::::|h[Linen Cloth]|h|rx2.",
        local itemLinks = {}
        for itemLink in args[1]:gmatch("|c.-|H.-:.-|h.-|h|r") do
            table.insert(itemLinks, itemLink)
        end

        if IsOwnItemUpgradeMessage(args[1], itemLinks) then
            WGLU.DebugPrint("Ignoring item-upgrade replacement message.")
            return
        end

        local isBonusLoot = IsBonusLootMessage(args[1], itemLinks)
        if isBonusLoot then WGLU.DebugPrint("Detected bonus loot message for " .. tostring(args[2])) end

        -- Only call AddLootFrame if exactly one item was detected
        local playerGUID = args[12]
        local playerUnit
        if issecretvalue and issecretvalue(playerGUID) then
            playerUnit = UnitTokenFromGUID(playerGUID)
        elseif playerGUID then
            playerUnit = UnitTokenFromGUID(playerGUID)
        end
        if issecretvalue and issecretvalue(playerUnit) then playerUnit = nil end
        playerUnit = playerUnit or WGLU.GetPlayerUnitByName(args[2]) or args[2]

        if #itemLinks == 1 then
            AddLootFrame(playerUnit, itemLinks[1], playerGUID, args[2], isBonusLoot)
        elseif #itemLinks > 1 then
            WGLU.DebugPrint("WARNING: Multiple item links found in loot message. Only the first will be processed.")
            AddLootFrame(playerUnit, itemLinks[1], playerGUID, args[2], false)
        else
            WGLU.DebugPrint("No item links found in loot message.")
        end
    end
end

WhoLootData.MainFrame:SetScript("OnEvent", HandleEvents)

-- Create a frame that acts as a timer, which iterates through all active frames and hides them when their time is up.
local TimerFrame = CreateFrame("Frame")
TimerFrame:SetScript("OnUpdate", function(self, elapsed)
    -- If the options window is open, don't hide the frames.
    if WhoLootsOptionsFrame:IsVisible() then return end

    for i, frame in ipairs(WhoLootData.ActiveFrames) do
        if frame.HoverAnimDelta == nil then
            frame.Lifetime = frame.Lifetime - elapsed
            frame.ProgressBar:SetValue(frame.Lifetime / WhoLootFrameData.FrameLifetime)
            if frame.Lifetime <= 0 then
                frame:FadeOut()
            end
        end
    end
end)

-- Function to check if the player is in a raid instance
local function IsPlayerInRaidInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

local function IsRaidLFR()
    local _, _, difficultyID = GetInstanceInfo()
    return difficultyID == 17
end

local ComparisonSlotByEquipLocation = {
    INVTYPE_HEAD = INVSLOT_HEAD,
    INVTYPE_NECK = INVSLOT_NECK,
    INVTYPE_SHOULDER = INVSLOT_SHOULDER,
    INVTYPE_BODY = INVSLOT_BODY,
    INVTYPE_CHEST = INVSLOT_CHEST,
    INVTYPE_ROBE = INVSLOT_CHEST,
    INVTYPE_WAIST = INVSLOT_WAIST,
    INVTYPE_LEGS = INVSLOT_LEGS,
    INVTYPE_FEET = INVSLOT_FEET,
    INVTYPE_WRIST = INVSLOT_WRIST,
    INVTYPE_HAND = INVSLOT_HAND,
    INVTYPE_FINGER = INVSLOT_FINGER1,
    INVTYPE_TRINKET = INVSLOT_TRINKET1,
    INVTYPE_CLOAK = INVSLOT_BACK,
    INVTYPE_WEAPON = INVSLOT_MAINHAND,
    INVTYPE_2HWEAPON = INVSLOT_MAINHAND,
    INVTYPE_WEAPONMAINHAND = INVSLOT_MAINHAND,
    INVTYPE_WEAPONOFFHAND = INVSLOT_OFFHAND,
    INVTYPE_SHIELD = INVSLOT_OFFHAND,
    INVTYPE_HOLDABLE = INVSLOT_OFFHAND,
    INVTYPE_RANGED = INVSLOT_MAINHAND,
    INVTYPE_RANGEDRIGHT = INVSLOT_MAINHAND,
    INVTYPE_THROWN = INVSLOT_MAINHAND,
    INVTYPE_TABARD = INVSLOT_TABARD,
}

local DualWieldSpecializations = {
    [72] = true,  -- Fury Warrior
    [251] = true, -- Frost Death Knight
    [259] = true, -- Assassination Rogue
    [260] = true, -- Outlaw Rogue
    [261] = true, -- Subtlety Rogue
    [263] = true, -- Enhancement Shaman
    [268] = true, -- Brewmaster Monk
    [269] = true, -- Windwalker Monk
    [577] = true, -- Havoc Demon Hunter
    [581] = true, -- Vengeance Demon Hunter
}

local function ShouldCompareBothLocalWeaponSlots(itemEquipLoc)
    if itemEquipLoc ~= "INVTYPE_WEAPON" and itemEquipLoc ~= "INVTYPE_2HWEAPON" then return false end

    local specialization = GetSpecialization()
    local specID = specialization and GetSpecializationInfo(specialization) or nil
    if not specID or not DualWieldSpecializations[specID] then return false end

    return itemEquipLoc == "INVTYPE_WEAPON" or specID == 72
end

local function GetLowestItemBetween(compareItemID, compareItemLVL, slot1, slot2)
    local item1 = GetInventoryItemLink("player", slot1)
    local item2 = GetInventoryItemLink("player", slot2)
    local item1id = item1 and select(1, C_Item.GetItemInfoInstant(item1)) or nil
    local item2id = item2 and select(1, C_Item.GetItemInfoInstant(item2)) or nil
    local item1Ilvl = item1 and UsableItemLevel(C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot1))) or nil
    local item2Ilvl = item2 and UsableItemLevel(C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot2))) or nil
    if not item1 then item1Ilvl = 0 end
    if not item2 then item2Ilvl = 0 end

    -- Retail 12 can protect equipped and dropped item levels during combat.
    -- Keep enough slot information to render the loot row, but do not compare
    -- protected values; a later unrestricted loot event can provide the delta.
    if not compareItemLVL or item1Ilvl == nil or item2Ilvl == nil then
        if item1 then return item1, nil, slot1, false end
        if item2 then return item2, nil, slot2, false end
        return nil, nil, slot1, false
    end

    local itemSlot = item1Ilvl < item2Ilvl and slot1 or slot2
    local isUnique = false

    if compareItemID == item1id or compareItemID == item2id then
        itemSlot = (item1id == compareItemID) and slot1 or slot2
        local equippedItemLevel = itemSlot == slot1 and item1Ilvl or item2Ilvl
        if equippedItemLevel < compareItemLVL then
            isUnique = false
        else
            isUnique = true
        end
    end

    local CurrentItemIlvl = math.min(item1Ilvl, item2Ilvl)
    local CurrentItemLink = (item1Ilvl < item2Ilvl) and item1 or item2
    local CurrentSlotID = itemSlot
    return CurrentItemLink, CurrentItemIlvl, CurrentSlotID, isUnique
end

local function GetActiveHeirloomMaxLevel(itemLink)
    if not itemLink or WhoGotLootsSavedData.ProtectActiveHeirlooms ~= true then return nil end

    local itemID = C_Item.GetItemIDForItemInfo(itemLink)
    if not itemID or not C_Heirloom.IsItemHeirloom(itemID) then return nil end

    local maxLevel = select(10, C_Heirloom.GetHeirloomInfo(itemID))
    if maxLevel and UnitLevel("player") <= maxLevel then
        return maxLevel
    end

    return nil
end

-- ======================================================================= --
-- ======================================================================= --

-- Function to add a loot frame to the main window.
function AddLootFrame(player, CompareItemLink, playerGUID, playerDisplayName, isBonusLoot)
    -- Safety check for required variables
    if not WGL_NumPooledFrames or not WhoGotLootsFrames then
        WGLU.DebugPrint("ERROR: Frame pool not initialized. WGL_NumPooledFrames=" ..
            tostring(WGL_NumPooledFrames) .. ", WhoGotLootsFrames=" .. tostring(WhoGotLootsFrames ~= nil))
        return
    end

    WGLU.DebugPrint("Processing loot for player: " .. tostring(player) .. ", item: " .. tostring(CompareItemLink))
    WGLU.DebugPrint("Frame pool status: Active=" ..
        #WhoLootData.ActiveFrames ..
        ", Pool size=" ..
        WGL_NumPooledFrames .. ", Total frames=" .. (WhoGotLootsFrames and #WhoGotLootsFrames or "undefined"))

    -- If it was our loot, don't show the frame.
    if UnitIsUnit('player', player) and WhoGotLootsSavedData.ShowOwnLoot ~= true then return end

    -- If the player was "target" (this should only be for debugging) resolve it to a party member number.
    if player == "target" then
        for i = 1, 4 do
            if UnitName("party" .. i) == UnitName("target") then
                player = "party" .. i
                break
            end
        end
    end

    -- Could we not find the player?
    if player == "" then return end

    -- Are we in a raid, and should we show raid loot?
    local isInRaid = IsPlayerInRaidInstance()
    if (WhoGotLootsSavedData.ShowDuringRaid ~= true and isInRaid) or
        (isInRaid and WhoGotLootsSavedData.ShowDuringRaid == true and WhoGotLootsSavedData.ShowDuringLFR ~= true and IsRaidLFR()) then
        return
    end

    -- If we've ran out of frames, remove the oldest one.
    if #WhoLootData.ActiveFrames >= WGL_NumPooledFrames then
        local oldestFrame = WhoLootData.ActiveFrames[1]
        if oldestFrame then
            oldestFrame:CancelQueuedRequest()
            oldestFrame.InUse = false
            oldestFrame:Hide()
            table.remove(WhoLootData.ActiveFrames, 1)
            WGLU.DebugPrint("Removed oldest frame to make room. Active frames: " .. #WhoLootData.ActiveFrames)
        end
    end

    -- Additional safety check - if we still don't have available frames, force cleanup more frames
    local availableFrames = 0
    if WhoGotLootsFrames then
        for i, f in ipairs(WhoGotLootsFrames) do
            if f and not f.InUse then
                availableFrames = availableFrames + 1
            end
        end
    end

    -- If no frames available, force cleanup of multiple oldest frames
    if availableFrames == 0 and #WhoLootData.ActiveFrames > 0 then
        local framesToRemove = math.min(3, #WhoLootData.ActiveFrames) -- Remove up to 3 oldest frames
        for i = 1, framesToRemove do
            local oldFrame = WhoLootData.ActiveFrames[1]
            if oldFrame then
                oldFrame:CancelQueuedRequest()
                oldFrame.InUse = false
                oldFrame:Hide()
                table.remove(WhoLootData.ActiveFrames, 1)
            end
        end
        WGLU.DebugPrint("Force removed " .. framesToRemove .. " frames. Active frames now: " .. #WhoLootData
            .ActiveFrames)

        -- Recount available frames
        availableFrames = 0
        if WhoGotLootsFrames then
            for i, f in ipairs(WhoGotLootsFrames) do
                if f and not f.InUse then
                    availableFrames = availableFrames + 1
                end
            end
        end
    end

    if availableFrames == 0 then
        WGLU.DebugPrint("No available frames in pool after cleanup, skipping item")
        return
    end

    if type(player) ~= "string" then player = tostring(player) end

    -- Try to see if the Item is actually an integer ID, and not a proper item link. If so, cast it to an actual integer.
    if type(CompareItemLink) == "string" then
        if tonumber(CompareItemLink) then CompareItemLink = tonumber(CompareItemLink) end
    end

    -- If itemLink is just an ID, then it came from a debug command, and we need to convert it to a proper item link.
    -- We need to create an Item object to get the item level.
    local CompareItem
    if type(CompareItemLink) == "number" then CompareItem = Item:CreateFromItemID(CompareItemLink) end
    if type(CompareItemLink) == "string" then CompareItem = Item:CreateFromItemLink(CompareItemLink) end

    CompareItem:ContinueOnItemLoad(function()
        local CompareItemID = C_Item.GetItemIDForItemInfo(CompareItemLink)
        local CompareItemIlvl, isPreview, baseIlvl = C_Item.GetDetailedItemLevelInfo(CompareItemLink)
        CompareItemIlvl = UsableItemLevel(CompareItemIlvl)
        local itemName, linkedItem, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent =
            C_Item.GetItemInfo(CompareItemLink)

        if type(CompareItemLink) == "number" then CompareItemLink = linkedItem end

        local IsBelowMinQuality = itemQuality < WhoGotLootsSavedData.MinQuality
        if IsBelowMinQuality and WhoGotLootsSavedData.ShowUpgradesBelowMinQuality ~= true then return end

        -- We only worry about armor and weapons.
        if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then return end

        -- Is it a cosmetic item?
        if C_Item.IsCosmeticItem(CompareItemID) then return end

        -- Grab the player's main stat.
        local PlayerTopStat = WGLU.GetPlayerMainStat()

        -- Check if the item is appropriate for the player's class.
        local CanEquip = WGLItemsDB.CanEquip(CompareItemID, select(2, UnitClass("player")))
        local IsAppropriate = WGLItemsDB.IsAppropriate(CompareItemID, select(2, UnitClass("player")))
        local ItemHasMainStat = WGLU.ItemHasMainStat(CompareItemLink, PlayerTopStat)

        -- If we don't want to show unequippable items, and this item is not equippable, return.
        if WhoGotLootsSavedData.HideUnequippable == true and not UnitIsUnit('player', player) and (CanEquip == false or IsAppropriate == false or ItemHasMainStat == false) then return end

        -- Resolve the actual equipment slot directly. Transmog inventory-type
        -- conversion has its own offset convention and is not a comparison API.
        local CurrentSlotID = ComparisonSlotByEquipLocation[itemEquipLoc]
        if not CurrentSlotID then
            WGLU.DebugPrint("No comparison slot for " .. tostring(itemEquipLoc))
            return
        end

        -- Prepare comparison data
        local CurrentItemLink = GetInventoryItemLink("player", CurrentSlotID)
        local CurrentItemIlvl
        if CurrentItemLink then
            CurrentItemIlvl = UsableItemLevel(C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(CurrentSlotID)))
        else
            CurrentItemIlvl = 0
        end

        local IsBoP = false
        local IsUnique = false
        local NoCompare = false
        local CacheRequest = nil
        local IsClassRestricted = false
        local IsOwnLoot = UnitIsUnit('player', player)
        local IsDowngradeForOtherPlayer = IsOwnLoot -- Logic is handled differnetly for the player, so we need to know if it's the player or not.

        local SecondaryStatsLine = {}
        local PriorityStatsLine = {}

        if isBonusLoot then
            table.insert(PriorityStatsLine, "|cFFe28743Bonus Roll - Not Tradeable|r")
        end

        -- If this is a ring, or neck we dont need to worry about the main stat.
        if itemEquipLoc == "INVTYPE_FINGER" or itemEquipLoc == "INVTYPE_NECK" or itemEquipLoc == "INVTYPE_TRINKET" then
            ItemHasMainStat = true
        end

        -- We can't trade BoP items, so just show the item and stats.
        if C_Item.IsItemBindToAccountUntilEquip(CompareItemLink) then
            IsBoP = true
            NoCompare = not UnitIsUnit('player', player)
        end

        -- -----------------------------------------------------------------------------------------------------------
        -- Convert the Item if we're comparing rings, or trinkets, or offhands.

        if itemEquipLoc == "INVTYPE_TRINKET" then
            CurrentItemLink, CurrentItemIlvl, CurrentSlotID, IsUnique =
                GetLowestItemBetween(CompareItemID, CompareItemIlvl, INVSLOT_TRINKET1, INVSLOT_TRINKET2)
        elseif itemEquipLoc == "INVTYPE_FINGER" then
            CurrentItemLink, CurrentItemIlvl, CurrentSlotID, IsUnique =
                GetLowestItemBetween(CompareItemID, CompareItemIlvl, INVSLOT_FINGER1, INVSLOT_FINGER2)
        elseif ShouldCompareBothLocalWeaponSlots(itemEquipLoc) then
            CurrentItemLink, CurrentItemIlvl, CurrentSlotID, IsUnique =
                GetLowestItemBetween(CompareItemID, CompareItemIlvl, INVSLOT_MAINHAND, INVSLOT_OFFHAND)
        end

        local ActiveHeirloomMaxLevel = GetActiveHeirloomMaxLevel(CurrentItemLink)

        -- Check the tooltip to see if it's class restricted.
        local tooltipData = C_TooltipInfo.GetHyperlink(CompareItemLink)
        for i = 1, #tooltipData.lines do
            if tooltipData.lines[i].type == 21 then
                -- if the restricted class is not the player's class, return.
                local foundClass = string.match(tooltipData.lines[i].leftText, "Class[es]*: (.*)")
                if foundClass and string.lower(foundClass) ~= string.lower(select(2, UnitClass("player"))) then
                    IsClassRestricted = true
                    if WhoGotLootsSavedData.HideUnequippable then
                        return
                    else
                        table.insert(SecondaryStatsLine, "|cFFFF0000Restricted to " .. foundClass .. "|r")
                    end
                end
            end
        end

        -- An own drop is only eligible for the reverse "who could use this?"
        -- flow when it does not beat the item that controls loot tradeability.
        -- Rings and trinkets already resolve CurrentItemIlvl to the lower of the
        -- two equipped slots above, so either weaker slot correctly blocks an
        -- item-level upgrade from being offered to the group.
        local PlayerItemLevelDelta = WGLUIBuilder.GetItemLevelDelta(CompareItemIlvl, CurrentItemIlvl)
        local IsUpgradeForPlayer = CanEquip == true and
            IsAppropriate == true and
            ItemHasMainStat == true and
            IsClassRestricted ~= true and
            not ActiveHeirloomMaxLevel and
            PlayerItemLevelDelta ~= nil and
            PlayerItemLevelDelta > 0

        -- Below-threshold items only bypass the quality filter when they are a
        -- genuine upgrade for the player. All other filters continue to apply.
        if IsBelowMinQuality and not IsUpgradeForPlayer then return end

        local CanOfferOwnDrop = IsOwnLoot and
            not isBonusLoot and
            not IsBoP and
            CurrentSlotID and CurrentSlotID > 0 and
            CanEquip == true and
            IsAppropriate == true and
            ItemHasMainStat == true and
            IsClassRestricted ~= true and
            PlayerItemLevelDelta ~= nil and
            PlayerItemLevelDelta <= 0

        if IsOwnLoot then
            WGLU.DebugPrint("Own drop item-level delta: " .. tostring(PlayerItemLevelDelta) ..
                ", eligible to offer: " .. tostring(CanOfferOwnDrop))
        end

        if CanOfferOwnDrop and WGLGroupUpgrade.BeginPartyCheck(
                CompareItemLink,
                CompareItemIlvl,
                CurrentSlotID,
                CompareItemID,
                PlayerItemLevelDelta
            ) then
            if WhoGotLootsSavedData.SoundEnabled == true or WhoGotLootsSavedData.SoundEnabled == nil then
                PlaySound(145739)
            end
            return
        end

        -- Queue an equipment comparison for the player who received the item. The
        -- inspection broker uses cached equipment immediately when possible and
        -- performs one coalesced inspection otherwise.
        if not UnitIsUnit('player', player) and CompareItemIlvl and CurrentItemIlvl then
            CacheRequest = {
                ["ItemLocation"] = CurrentSlotID,
                ["ItemLevel"] = CompareItemIlvl,
                ["ItemID"] = CompareItemID,
                ["ItemEquipLoc"] = itemEquipLoc,
                ["RequireSpec"] = classID == Enum.ItemClass.Weapon,
            }
        end

        WGLU.DebugPrint("CanEquip = " ..
            tostring(CanEquip) ..
            ", IsAppropriate = " .. tostring(IsAppropriate) .. ", ItemHasMainStat = " .. tostring(ItemHasMainStat))
        WGLU.DebugPrint("Bonus loot = " .. tostring(isBonusLoot))

        -- If we can equip this item, check if it's an upgrade.
        if CanEquip == true and IsAppropriate == true and ItemHasMainStat == true and IsClassRestricted ~= true then
            -- First, check if we're at the minimum character level.
            if UnitLevel("player") < itemMinLevel then
                table.insert(SecondaryStatsLine,
                    "|cFFFF0000Level " .. itemMinLevel .. "|r")
            end

            -- If we have a unique equipped, then we don't want to show it.
            if IsUnique then table.insert(SecondaryStatsLine, "|cFFFF0000Unique Equipped|r") end

            -- Give a stat breakdown.
            if not IsUnique then
                -- Show the ilvl diff if any
                local ilvlDiff
                if not NoCompare then
                    ilvlDiff = WGLUIBuilder.GetItemLevelDelta(CompareItemIlvl, CurrentItemIlvl)
                else
                    ilvlDiff = CompareItemIlvl
                end
                local ilvlText
                if ActiveHeirloomMaxLevel then
                    ilvlText = "|cFFFFFFFFYou:|r " ..
                        string.format(WGLUIBuilder.UpgradeStatuses.HEIRLOOM, ActiveHeirloomMaxLevel)
                elseif not CompareItemIlvl or (not NoCompare and not CurrentItemIlvl) then
                    ilvlText = "|cFFFFFFFFYou:|r comparison unavailable during combat"
                elseif not NoCompare then
                    if ilvlDiff > 0 then
                        ilvlText = "|cFFFFFFFFYou:|r " .. string.format(WGLUIBuilder.UpgradeStatuses.UPGRADE, ilvlDiff)
                    elseif ilvlDiff < 0 then
                        ilvlText = "|cFFFFFFFFYou:|r " ..
                            string.format(WGLUIBuilder.UpgradeStatuses.DOWNGRADE, math.abs(ilvlDiff))
                    else
                        ilvlText = WGLUIBuilder.UpgradeStatuses.EQUAL
                    end
                else
                    ilvlText = CompareItemIlvl .. " ilvl"
                end

                table.insert(PriorityStatsLine, 1, ilvlText)

                -- Get the compare item's stats.
                local CompareItemStats = C_Item.GetItemStats(CompareItemLink) or {}

                -- If we have an item equipped in the same slot, compare the main stats.
                local CompareItemMainStat = CompareItemStats and WGLU.GetItemMainStat(CompareItemStats, PlayerTopStat) or
                    -1
                local diffStat = 0
                local ourItemMainStat = CurrentItemLink and
                    WGLU.GetItemMainStat(C_Item.GetItemStats(CurrentItemLink), PlayerTopStat) or 0

                if CompareItemMainStat ~= -1 then
                    diffStat = CompareItemMainStat - ourItemMainStat
                else
                    diffStat = 0
                end

                -- Create a text showing the difference in main stat.
                local diffStatText = ""
                if diffStat ~= 0 and CompareItemMainStat ~= -1 then
                    if diffStat > 0 then
                        diffStatText = (not NoCompare and "+" or "") .. diffStat
                    elseif diffStat < 0 then
                        diffStatText = diffStat .. "|r"
                    end
                    table.insert(SecondaryStatsLine, diffStatText .. " " .. PlayerTopStat)
                end

                local stats = {
                    Armor = { ours = 0, theirs = 0 },
                    Haste = { ours = 0, theirs = 0 },
                    Mastery = { ours = 0, theirs = 0 },
                    Versatility = { ours = 0, theirs = 0 },
                    Crit = { ours = 0, theirs = 0 },
                    Vers = { ours = 0, theirs = 0 },
                    Avoidance = { ours = 0, theirs = 0 },
                    Leech = { ours = 0, theirs = 0 },
                    Speed = { ours = 0, theirs = 0 },
                    Indestructible = { ours = 0, theirs = 0 }
                }

                local preferredOrder = { "Armor", "Haste", "Mastery", "Versatility", "Crit", "Vers", "Avoidance", "Leech",
                    "Speed", "Indestructible" }

                -- Get the stats of the item we're comparing to.
                for stat, value in pairs(CompareItemStats) do
                    if stat == "ITEM_MOD_HASTE_RATING_SHORT" then
                        stats.Haste.theirs = value
                    elseif stat == "ITEM_MOD_MASTERY_RATING_SHORT" then
                        stats.Mastery.theirs = value
                    elseif stat == "ITEM_MOD_VERSATILITY" then
                        stats.Versatility.theirs = value
                    elseif stat == "ITEM_MOD_CRIT_RATING_SHORT" then
                        stats.Crit.theirs = value
                    elseif stat == "ITEM_MOD_VERSATILITY" then
                        stats.Vers.theirs = value
                    elseif stat == "ITEM_MOD_CR_AVOIDANCE_SHORT" then
                        stats.Avoidance.theirs = value
                    elseif stat == "ITEM_MOD_CR_LIFESTEAL_SHORT" then
                        stats.Leech.theirs = value
                    elseif stat == "ITEM_MOD_CR_SPEED_SHORT" then
                        stats.Speed.theirs = value
                    elseif stat == "ITEM_MOD_CR_STURDINESS_SHORT" then
                        stats.Indestructible.theirs = value
                    elseif stat == "RESISTANCE0_NAME" then
                        stats.Armor.theirs = value
                    end
                end

                -- Get the stats of our currently equipped item.
                if CurrentItemLink and not NoCompare then
                    local ourItemStats = C_Item.GetItemStats(CurrentItemLink) or {}
                    for stat, value in pairs(ourItemStats) do
                        if stat == "ITEM_MOD_HASTE_RATING_SHORT" then
                            stats.Haste.ours = value
                        elseif stat == "ITEM_MOD_MASTERY_RATING_SHORT" then
                            stats.Mastery.ours = value
                        elseif stat == "ITEM_MOD_VERSATILITY" then
                            stats.Versatility.ours = value
                        elseif stat == "ITEM_MOD_CRIT_RATING_SHORT" then
                            stats.Crit.ours = value
                        elseif stat == "ITEM_MOD_VERSATILITY" then
                            stats.Vers.ours = value
                        elseif stat == "ITEM_MOD_CR_AVOIDANCE_SHORT" then
                            stats.Avoidance.ours = value
                        elseif stat == "ITEM_MOD_CR_LIFESTEAL_SHORT" then
                            stats.Leech.ours = value
                        elseif stat == "ITEM_MOD_CR_SPEED_SHORT" then
                            stats.Speed.ours = value
                        elseif stat == "ITEM_MOD_CR_STURDINESS_SHORT" then
                            stats.Indestructible.ours = value
                        elseif stat == "RESISTANCE0_NAME" then
                            stats.Armor.ours = value
                        end
                    end
                end

                -- Separate positive and negative stats
                local positiveStats = {}
                local negativeStats = {}

                -- Compare the stats and separate them
                for _, stat in ipairs(preferredOrder) do
                    local value = stats[stat]
                    local diff = value.theirs - value.ours
                    local statName = WGLU.SimplifyStatName(stat)

                    if statName ~= nil then
                        -- Overrides for some stats
                        if statName == "Indest" then
                            if diff > 0 then
                                table.insert(positiveStats, "|cFF00FF00+Indestructible|r")
                            elseif diff < 0 then
                                table.insert(negativeStats, "|cFFFF0000-Indestructible|r")
                            end
                            -- Normal stat display
                        else
                            if diff > 0 then
                                table.insert(positiveStats, (not NoCompare and "+" or "") .. diff .. " " .. statName)
                            elseif diff < 0 then
                                table.insert(negativeStats, diff .. " " .. statName)
                            end
                        end
                    end
                end

                -- Add positive stats first
                for _, statText in ipairs(positiveStats) do
                    table.insert(SecondaryStatsLine, statText)
                end

                -- Then add negative stats
                for _, statText in ipairs(negativeStats) do
                    table.insert(SecondaryStatsLine, statText)
                end
            end
        end

        WGLU.DebugPrint("CanEquip: " ..
            tostring(CanEquip) ..
            ", IsAppropriate: " .. tostring(IsAppropriate) .. ", ItemHasMainStat: " .. tostring(ItemHasMainStat))

        -- Display why we can't equip the item.
        if CanEquip == false then
            table.insert(SecondaryStatsLine,
                "|cFFFF0000Can't equip " .. C_Item.GetItemSubClassInfo(classID, subclassID) .. "|r")
        elseif IsAppropriate == false then
            -- Capitalize first letter of item type using gsub
            local itemTypeStringed = C_Item.GetItemSubClassInfo(classID, subclassID)
            itemTypeStringed = itemTypeStringed:gsub("^%l", string.upper)
            table.insert(SecondaryStatsLine, "|cFFe28743" .. itemTypeStringed .. " - Undesired Type|r")
        elseif ItemHasMainStat == false then
            table.insert(SecondaryStatsLine, "|cFFFF0000No " .. PlayerTopStat .. "|r")
        end

        -- Look into the Frame Manager and find an available frame.
        local frame = nil
        if WhoGotLootsFrames then
            for i, f in ipairs(WhoGotLootsFrames) do
                if f and not f.InUse then
                    frame = f
                    frame.InUse = true -- Mark as in use immediately
                    WGLU.DebugPrint("Found available frame #" .. i .. " for item")
                    break
                end
            end
        end

        -- If we found a frame, then we can use it.
        if frame then
            -- Unhide the main window
            WhoLootData.MainFrame:Open()

            frame:HideUpgradeGlow()

            -- Do we need to show the upgrade glow right now?
            if not CacheRequest and not IsBoP and CanEquip and IsAppropriate and IsDowngradeForOtherPlayer and
                not ActiveHeirloomMaxLevel and PlayerItemLevelDelta and PlayerItemLevelDelta > 0 then
                frame:ShowUpgradeGlow()
            end

            local playerClass = select(2, UnitClass(player))
            local playerColor = playerClass and RAID_CLASS_COLORS[playerClass]
            local displayedPlayerName = UnitName(player)
            if (issecretvalue and issecretvalue(displayedPlayerName)) or not displayedPlayerName then
                displayedPlayerName = playerDisplayName or "Unknown"
            end

            frame.Player = player
            frame.PlayerText:SetText(
                playerColor and
                ("|c" .. playerColor.colorStr .. displayedPlayerName .. "|r") or
                displayedPlayerName
            )
            frame.PlayerText:Show()

            -- Dynamically set the width of PlayerText based on its content
            local textWidth = frame.PlayerText:GetStringWidth()
            frame.PlayerText:SetWidth(textWidth) -- Adding 10 pixels as padding

            frame.PlayerArrow:ClearAllPoints()
            frame.PlayerArrow:SetPoint("LEFT", frame.PlayerText, "RIGHT", 4, 1)

            frame.ItemText:SetText("|c" ..
                select(4, C_Item.GetItemQualityColor(itemQuality)) .. "[" .. itemName .. "]" .. "|r")
            frame.ItemText:ClearAllPoints()
            frame.ItemText:SetPoint("LEFT", frame.PlayerArrow, "RIGHT", 4, -1)

            if IsBoP then table.insert(PriorityStatsLine, 1, "|cFF6fcbe3Is BoP|r ") end

            -- Create stat breakdown frames with processed stats
            WGLUIBuilder.CreateStatBreakdownFrames(frame, SecondaryStatsLine)

            for _, stat in ipairs(PriorityStatsLine) do
                WGLUIBuilder.AddStatToBreakdown(frame, stat, "append", nil, 0, "primary")
            end

            frame.Icon:SetTexture(itemTexture)
            frame.Item = CompareItemLink
            frame:DropIn(1.0, 0.2)
            -- DropIn resets recycled frame state. Restore this item's upgrade
            -- status afterward so upgrades override the user's hidden-stat and
            -- hidden-comparison preferences as intended.
            frame.IsUpgrade = IsUpgradeForPlayer
            frame:UpdateStatBreakdownVisibility()
            frame.lastClickTime = 0

            -- Create the inspection request after DropIn resets the recycled frame,
            -- otherwise Reset() would immediately detach the new request.
            if CacheRequest and not IsBoP then
                CacheRequest.Frame = frame
                CacheRequest.CompareIlvl = CompareItemIlvl
                CacheRequest.OurItemLevel = CurrentItemIlvl
                CacheRequest.GoodForPlayer = CanEquip and IsAppropriate and not IsClassRestricted
                CacheRequest.IsBonusLoot = isBonusLoot
                CacheRequest.IsUpgrade = not ActiveHeirloomMaxLevel and not isBonusLoot and
                    PlayerItemLevelDelta ~= nil and PlayerItemLevelDelta > 0
                CacheRequest.TextString = table.concat(PriorityStatsLine, " | ")
                frame.QueuedRequest =
                    WGLCache.CreateRequest(player, CacheRequest, playerGUID, playerDisplayName)
                frame.LoadingIcon:Unhide()
            else
                frame.LoadingIcon:Hide()
            end

            -- Store the frame in the ChildFrames table.
            WhoLootData.ActiveFrames[#WhoLootData.ActiveFrames + 1] = frame
            WhoLootData.ResortFrames()

            -- Setup hover/click functions
            WhoLootData.SetupItemBoxFunctions(frame, CompareItemLink, player)

            -- Play a sound
            if WhoGotLootsSavedData.SoundEnabled == true or WhoGotLootsSavedData.SoundEnabled == nil then
                PlaySound(145739)
            end
        else
            WGLU.DebugPrint("ERROR: Couldn't find an available frame from pool. Active: " ..
                #WhoLootData.ActiveFrames ..
                ", Pool size: " .. (WGL_NumPooledFrames or "undefined") .. ", Available: " .. availableFrames)
        end
    end)
end

function WhoLootData.SetupItemBoxFunctions(frame, itemLink, player)
    -- Right click to close it.
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if IsShiftKeyDown() then
                ChatEdit_InsertLink(itemLink)
                -- Inspect
            elseif IsAltKeyDown() then
                if not UnitIsUnit('player', player) then
                    if UnitPlayerControlled(player) then
                        if not InCombatLockdown() then
                            if CanInspect(player) then
                                WGLU.DebugPrint("Inspecting " .. player)
                                InspectUnit(player)
                            else
                                print("Who Got Loots - Can't inspect " .. player .. ".")
                            end
                        else
                            print("Who Got Loots - Addons can't inspect while in combat.")
                        end
                    else
                        print("Who Got Loots - Can only inspect players.")
                    end
                end
                -- Open Trade
            elseif IsControlKeyDown() then
                if not UnitIsUnit('player', player) and UnitPlayerControlled(player) and CheckInteractDistance(player, 2) then
                    WGLU.DebugPrint("Who Got Loots - Initiating trade with " .. player)
                    InitiateTrade(player)
                end
                -- Double clicked to equip
            else
                if UnitIsUnit('player', player) or player == "player" then
                    local currentTime = GetTime()
                    WGLU.DebugPrint(currentTime - self.lastClickTime)
                    if currentTime - self.lastClickTime < 0.4 then
                        WGLU.DebugPrint("Equipping " .. itemLink)
                        C_Item.EquipItemByName(itemLink)
                        self.Close:CloseFrame()
                    end
                    self.lastClickTime = currentTime
                end
            end
        end
        if button == "MiddleButton" then
            -- Check if this is the player's own loot
            if UnitIsUnit('player', player) or player == "player" then
                -- This is our own loot - send "I don't need this" message to appropriate chat
                local message = WhoGotLootsSavedData.IDontNeedMessage
                message = message:gsub("%%i", itemLink)

                -- Determine which chat channel to use
                local chatType = "SAY" -- Default to local chat

                -- Check if we're in an instance group (dungeons, raids, etc.)
                if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
                    chatType = "INSTANCE_CHAT"
                    -- Check if we're in a regular party or raid
                elseif IsInRaid() then
                    chatType = "RAID"
                elseif IsInGroup() then
                    chatType = "PARTY"
                end

                -- Send to the determined chat channel
                SendChatMessage(message, chatType)
            else
                -- This is someone else's loot - send whisper message
                local message = WhoGotLootsSavedData.WhisperMessage
                local playerName = select(1, UnitName(player))
                message = message:gsub("%%n", playerName)
                message = message:gsub("%%i", itemLink)

                SendChatMessage(message, "WHISPER", nil, UnitName(player))
            end
        end
        if button == "RightButton" then
            WGLCache.RemoveRequest(frame.QueuedRequest)
            self.Close:CloseFrame()
        end
    end)
end

function WhoLootData.HoverFrame(fromFrame, toState)
    if fromFrame == nil then
        print("ERROR: Couldn't find the frame in the ActiveFrames table.")
        return
    end

    if fromFrame.border then
        if toState then
            WGLUIBuilder.ColorBGSlicedFrame(fromFrame.border, "border", 0.9, 0.9, 0.95, 1)
        else
            WGLUIBuilder.ColorBGSlicedFrame(fromFrame.border, "border", unpack(WhoLootFrameData.BorderColor))
        end
    end

    if fromFrame.Animating then return end

    local function HandleHoverAnimation(fromFrame, toState)
        local function UpdateAnimation(self, elapsed)
            fromFrame.HoverAnimDelta = (fromFrame.HoverAnimDelta or 0) + (toState and elapsed * 3 or -elapsed)
            local progress = WGLU.Clamp(fromFrame.HoverAnimDelta / WhoLootFrameData.HoverAnimTime, 0, 1)
            progress = math.sin(progress * math.pi / 2)
            WGLU.LerpBackdropColor(fromFrame.background, WhoLootFrameData.HoverColor, WhoLootFrameData.ExitColor,
                1 - progress)

            if toState then
                if progress >= 1 then
                    fromFrame:SetScript("OnUpdate", nil)
                end
            else
                if progress <= 0 then
                    fromFrame:SetScript("OnUpdate", nil)
                    fromFrame.HoverAnimDelta = nil
                end
            end
        end

        if toState then
            GameTooltip:SetOwner(fromFrame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(fromFrame.Item)
            GameTooltip:Show()
            fromFrame:SetScript("OnUpdate", UpdateAnimation)
        else
            GameTooltip:Hide()
            fromFrame.HoverAnimDelta = fromFrame.HoverAnimDelta or WhoLootFrameData.HoverAnimTime
            fromFrame:SetScript("OnUpdate", UpdateAnimation)
        end
    end


    if toState then
        HandleHoverAnimation(fromFrame, toState)
    else
        HandleHoverAnimation(fromFrame, toState)
    end
end

-- Function to resort the frames, if we remove one.
function WhoLootData.ResortFrames()
    local topOffset = 8
    local frameGap = 2

    for _, frame in ipairs(WhoLootData.ActiveFrames) do
        frame:ClearAllPoints()
        frame:SetPoint("TOP", WhoLootData.MainFrame, "BOTTOM", 0, topOffset)
        topOffset = topOffset - frame:GetHeight() - frameGap
    end

    -- Rest of your existing code...
    local numFrames = #WhoLootData.ActiveFrames
    if numFrames == 0 and WhoGotLootsSavedData.AutoCloseOnEmpty == true then
        for _, frame in ipairs(WhoGotLootsFrames) do
            WGLUIBuilder.ClearStatContainer(frame)
        end
        WhoLootData.MainFrame:Close()
    end
end

-- Define the slash commands
SLASH_WHOLOOT1 = "/whogotloots"
SLASH_WHOLOOT2 = "/wgl"

-- Split the command into parts using spaces.
-- We need to ignore the spaces though when it's inbetween the tags |c and |r so we don't split item links apart.
local function SplitCommands(msg)
    local args = {}
    local currentArg = ""
    local ignoreSpaces = false
    for i = 1, #msg do
        local char = msg:sub(i, i)
        if char == " " and not ignoreSpaces then
            if currentArg ~= "" then
                table.insert(args, currentArg)
                currentArg = ""
            end
        else
            currentArg = currentArg .. char
            if char == "|" then
                ignoreSpaces = true
            elseif char == "|r" then
                ignoreSpaces = false
            end
        end
    end
    if currentArg ~= "" then
        table.insert(args, currentArg)
    end
    return args
end

-- Register the command handler
SlashCmdList["WHOLOOT"] = function(msg)
    local args = SplitCommands(msg)
    if #args == 0 then
        if WhoLootData.MainFrame:IsVisible() then
            WhoLootData.MainFrame:Close()
        else
            WhoLootData.MainFrame:Open()
        end
        return
    end

    local cmd = args[1]
    table.remove(args, 1)

    if cmd == "add" then
        -- Are we targeting someone right now?
        if UnitExists("target") then
            AddLootFrame("target", args[1])
        else
            -- If not, add it to the player.
            AddLootFrame("player", args[1])
        end
    elseif cmd == "groupcheck" or cmd == "testgroup" then
        local itemReference = #args > 0 and table.concat(args, " ") or nil
        WGLGroupUpgrade.ShowTest(itemReference)
        print("Who Got Loots: showing the four-player group upgrade preview.")
    elseif cmd == "debug" then
        WGLU.DebugMode = not WGLU.DebugMode
        print("Debug mode is now " .. (WGLU.DebugMode and "enabled" or "disabled"))
    end
end
