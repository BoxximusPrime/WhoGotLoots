-- Define a table to store global variables
WhoLootData = WhoLootData or {}
WhoLootDataVers = "1.4.2"
WGLU.DebugMode = false

WhoLootData.ActiveFrames = {} -- A table to store all active frames.

WhoLootData.MainFrame = WGLUIBuilder.CreateMainFrame()
WhoLootData.MainFrame:SetParent(UIParent)
WhoLootData.MainFrame:SetDontSavePosition(true)

-- Register Events --
WhoLootData.MainFrame:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
WhoLootData.MainFrame:RegisterEvent("CHAT_MSG_LOOT")

WhoLootFrameData = WhoLootFrameData or {}

-- Handle Events --
function HandleEvents(self, event, ...)
    local args = {...}
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

        -- Parent all the item boxes to the main window.
        for i, frame in ipairs(WhoGotLootsFrames) do
            frame:SetParent(WhoLootData.MainFrame)
        end

        -- Set window position (we do this after loading the options, because the saved position is loaded in LoadOptions)
        if WhoGotLootsSavedData.SavedPos then
            WhoLootData.MainFrame:Move(WhoGotLootsSavedData.SavedPos)
        else
            WhoLootData.MainFrame:Move({"CENTER", nil, "CENTER"})
        end
    elseif event == "CHAT_MSG_LOOT" then 

        -- Does the message have the words "receive loot" or "receives loot" in it?
        --if not string.find(args[1], "receives? loot") then return end
        if not string.find(args[1], "receives? loot") and not string.find(args[1], "You receive item") then return end

        -- Scrape the message for the item link. Item links look like "|cffffffff|Hitem:2589::::::::20:257::::::|h[Linen Cloth]|h|rx2.",
        -- and we can use a pattern to extract it.
        local message = args[1]
        local itemLink = message:match("|c.-|Hitem:.-|h.-|h|r")
        if itemLink then
            AddLootFrame(args[2], itemLink)
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

local function GetLowestItemBetween(compareItemID, compareItemLVL, slot1, slot2)
    local item1 = GetInventoryItemLink("player", slot1)
    local item2 = GetInventoryItemLink("player", slot2)
    local item1id = item1 and select(1, C_Item.GetItemInfoInstant(item1)) or nil
    local item2id = item2 and select(1, C_Item.GetItemInfoInstant(item2)) or nil
    local item1Ilvl = item1 and C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot1)) or 0
    local item2Ilvl = item2 and C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot2)) or 0

    local itemSlot = item1Ilvl < item2Ilvl and slot1 or slot2

    if compareItemID == item1id or compareItemID == item2id then
        itemSlot = (item1id == compareItemID) and slot1 or slot2
        if C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(itemSlot)) < compareItemLVL then
            IsUnique = false
        else
            IsUnique = true
        end
    end

    local CurrentItemIlvl = math.min(item1Ilvl, item2Ilvl)
    local CurrentItemLink = (item1Ilvl < item2Ilvl) and item1 or item2
    local CurrentSlotID = itemSlot
    return CurrentItemLink, CurrentItemIlvl, CurrentSlotID
end

-- ======================================================================= --
-- ======================================================================= --

-- Function to add a loot frame to the main window.
function AddLootFrame(player, CompareItemLink)

    -- Does the player name have their realm? Check for a -
    if string.find(player, "-") then player = string.match(player, "(.*)-") end

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

    -- Are we in a raid, and should we show raid loot?
    local isInRaid = IsPlayerInRaidInstance()
    if (WhoGotLootsSavedData.ShowDuringRaid ~= true and isInRaid) or
        (isInRaid and WhoGotLootsSavedData.ShowDuringRaid == true and WhoGotLootsSavedData.ShowDuringLFR ~= true and IsRaidLFR()) then
        return
    end

    -- If we've ran out of frames, remove the oldest one.
    if #WhoLootData.ActiveFrames >= WGL_NumPooledFrames then
        local frame = WhoLootData.ActiveFrames
        frame.InUse = false
        frame.Frame:Hide()
        table.remove(WhoLootData.ActiveFrames, 1)
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
        local itemName, linkedItem, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent = C_Item.GetItemInfo(CompareItemLink)

        if type(CompareItemLink) == "number" then CompareItemLink = linkedItem end

        if itemQuality < WhoGotLootsSavedData.MinQuality then return end

        -- We only worry about armor and weapons.
        if itemType ~= "Armor" and itemType ~= "Weapon" then return end

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
        
        -- Get currently equipped item information
        local CurrentSlotID = -1
        
        -- Necks don't have a transmog slot, rings and trinkets will be handled below.
        if itemEquipLoc == "INVTYPE_NECK" then CurrentSlotID = 2
        else CurrentSlotID = C_Transmog.GetSlotForInventoryType(C_Item.GetItemInventoryTypeByID(CompareItemID) + 1) end
        
        -- Prepare comparison data
        local CurrentItemLink = GetInventoryItemLink("player", CurrentSlotID)
        local CurrentItemIlvl = CurrentItemLink and C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(CurrentSlotID)) or 0
        
        local IsBoP = false
        local IsUnique = false
        local NoCompare = false
        local CacheRequest = nil
        local IsClassRestricted = false
        local IsDowngradeForOtherPlayer = UnitIsUnit('player', player) -- Logic is handled differnetly for the player, so we need to know if it's the player or not.

        local BottomText = {}
        local BottomText2 = {}

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
            CurrentItemLink, CurrentItemIlvl, CurrentSlotID = GetLowestItemBetween(CompareItemID, CompareItemIlvl, 13, 14)
        elseif itemEquipLoc == "INVTYPE_FINGER" then
            CurrentItemLink, CurrentItemIlvl, CurrentSlotID = GetLowestItemBetween(CompareItemID, CompareItemIlvl, 11, 12)
        end

        -- Check the tooltip to see if it's class restricted.
        local tooltipData = C_TooltipInfo.GetHyperlink(CompareItemLink)
        for i = 1, #tooltipData.lines do
            if tooltipData.lines[i].type == 21 then
                -- if the restricted class is not the player's class, return.
                local foundClass = string.match(tooltipData.lines[i].leftText, "Class[es]*: (.*)")
                if foundClass and string.lower(foundClass) ~= string.lower(select(2, UnitClass("player"))) then
                    IsClassRestricted = true
                    if WhoGotLootsSavedData.HideUnequippable then return else
                        table.insert(BottomText, "|cFFFF0000Restricted to " .. foundClass .. "|r")
                    end
                end
            end
        end

        -- If the item was looted by another player check to see if it was an item level upgrade for them.
        -- This is kind of tricky, because the item may not be cached, so we need to asynchronously get the item, then update it later using the cache.
        if not UnitIsUnit('player', player) then
            local otherItemLink = GetInventoryItemLink(player, CurrentSlotID)
            if otherItemLink then
                local otherPlayerItemIlvl = otherItemLink and C_Item.GetDetailedItemLevelInfo(otherItemLink) or 0
                if otherPlayerItemIlvl > CompareItemIlvl then
                    IsDowngradeForOtherPlayer = true
                    table.insert(BottomText2, "|cFFFFFFFFThem:|r |cFFb7d672|r " .. (otherPlayerItemIlvl - CompareItemIlvl) .. " ilvl downgrade")
                else
                    table.insert(BottomText2, "|cFFFFFFFFThem:|r |cFFe28743" .. (otherPlayerItemIlvl - CompareItemIlvl) .. " ilvl upgrade|r")
                end
            else
                CacheRequest = { ["ItemLocation"] = CurrentSlotID, ["ItemLevel"] = CompareItemIlvl, ["ItemID"] = CompareItemID }
            end
        end

        WGLU.DebugPrint("CanEquip = " .. tostring(CanEquip) .. ", IsAppropriate = " .. tostring(IsAppropriate) .. ", ItemHasMainStat = " .. tostring(ItemHasMainStat))

        -- If we can equip this item, check if it's an upgrade.
        if CanEquip == true and IsAppropriate == true and ItemHasMainStat == true and IsClassRestricted ~= true then

            -- First, check if we're at the minimum character level.
            if UnitLevel("player") < itemMinLevel then table.insert(BottomText, "|cFFFF0000Level " .. itemMinLevel .. "|r") end

            -- If we have a unique equipped, then we don't want to show it.
            if IsUnique then table.insert(BottomText, "|cFFFF0000Unique Equipped|r") end

            -- Give a stat breakdown.
            if not IsUnique then

                -- Show the ilvl diff if any
                local ilvlDiff = not NoCompare and CompareItemIlvl - CurrentItemIlvl or CompareItemIlvl
                local color = not NoCompare and (ilvlDiff > 0 and "|cFF00FF00" or ilvlDiff < 0 and "|cFFFF0000") or ""
                local sign = not NoCompare and ilvlDiff > 0 and "+" or ""
                local text = ilvlDiff ~= 0 and color .. sign .. ilvlDiff .. "|r ilvl" or (NoCompare and CompareItemIlvl .. " ilvl" or "+0 ilvl")
                table.insert(BottomText, text)

                -- Get the compare item's stats.
                local CompareItemStats = C_Item.GetItemStats(CompareItemLink)
                
                -- If we have an item equipped in the same slot, compare the main stats.
                local CompareItemMainStat = CompareItemStats and WGLU.GetItemMainStat(CompareItemStats, PlayerTopStat) or -1
                local diffStat = 0
                local ourItemMainStat = CurrentItemLink and WGLU.GetItemMainStat(C_Item.GetItemStats(CurrentItemLink), PlayerTopStat) or 0

                if CompareItemMainStat ~= -1 then
                    diffStat = CompareItemMainStat - ourItemMainStat
                else
                    diffStat = 0
                end

                -- Create a text showing the difference in main stat.
                local diffStatText = ""
                if diffStat ~= 0 and CompareItemMainStat ~= -1 then
                    if diffStat > 0 then
                        diffStatText = "|cFF00FF00" .. (not NoCompare and "+" or "") .. diffStat .. "|r"
                    elseif diffStat < 0 then
                        diffStatText = "|cFFFF0000" .. diffStat .. "|r"
                    end
                    table.insert(BottomText, diffStatText .. " " .. PlayerTopStat)
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

                local preferredOrder = { "Armor", "Haste", "Mastery", "Versatility", "Crit", "Vers", "Avoidance", "Leech", "Speed", "Indestructible" }

                -- Get the stats of the item we're comparing to.
                for stat, value in pairs(CompareItemStats) do
                    if stat == "ITEM_MOD_HASTE_RATING_SHORT" then stats.Haste.theirs = value
                    elseif stat == "ITEM_MOD_MASTERY_RATING_SHORT" then stats.Mastery.theirs = value
                    elseif stat == "ITEM_MOD_VERSATILITY" then stats.Versatility.theirs = value
                    elseif stat == "ITEM_MOD_CRIT_RATING_SHORT" then stats.Crit.theirs = value
                    elseif stat == "ITEM_MOD_VERSATILITY" then stats.Vers.theirs = value
                    elseif stat == "ITEM_MOD_CR_AVOIDANCE_SHORT" then stats.Avoidance.theirs = value
                    elseif stat == "ITEM_MOD_CR_LIFESTEAL_SHORT" then stats.Leech.theirs = value
                    elseif stat == "ITEM_MOD_CR_SPEED_SHORT" then stats.Speed.theirs = value
                    elseif stat == "ITEM_MOD_CR_STURDINESS_SHORT" then stats.Indestructible.theirs = value
                    elseif stat == "RESISTANCE0_NAME" then stats.Armor.theirs = value
                    end
                end

                -- Get the stats of our currently equipped item.
                if CurrentItemLink and not NoCompare then 
                    local ourItemStats = C_Item.GetItemStats(CurrentItemLink)
                    for stat, value in pairs(ourItemStats) do
                        if stat == "ITEM_MOD_HASTE_RATING_SHORT" then stats.Haste.ours = value
                        elseif stat == "ITEM_MOD_MASTERY_RATING_SHORT" then stats.Mastery.ours = value
                        elseif stat == "ITEM_MOD_VERSATILITY" then stats.Versatility.ours = value
                        elseif stat == "ITEM_MOD_CRIT_RATING_SHORT" then stats.Crit.ours = value
                        elseif stat == "ITEM_MOD_VERSATILITY" then stats.Vers.ours = value
                        elseif stat == "ITEM_MOD_CR_AVOIDANCE_SHORT" then stats.Avoidance.ours = value
                        elseif stat == "ITEM_MOD_CR_LIFESTEAL_SHORT" then stats.Leech.ours = value
                        elseif stat == "ITEM_MOD_CR_SPEED_SHORT" then stats.Speed.ours = value
                        elseif stat == "ITEM_MOD_CR_STURDINESS_SHORT" then stats.Indestructible.ours = value
                        elseif stat == "RESISTANCE0_NAME" then stats.Armor.ours = value
                        end
                    end
                end

                local StatString = {}
                
                -- Compare the stats.
                for _, stat in ipairs(preferredOrder) do
                    local value = stats[stat]
                    local diff = value.theirs - value.ours
                    local statName = WGLU.SimplifyStatName(stat)

                    if statName ~= nil then
                        -- Overrides for some stats.
                        if(statName == "Indest") then
                            if diff > 0 then
                                table.insert(StatString, "|cFF00FF00+Indestructible|r")
                            elseif diff < 0 then
                                table.insert(StatString, "|cFFFF0000-Indestructible|r")
                            end
                        -- Normal stat display
                        else
                            if diff > 0 then
                                table.insert(StatString, "|cFF00FF00" .. (not NoCompare and "+" or "") .. diff .. "|r " .. statName)
                            elseif diff < 0 then
                                table.insert(StatString, "|cFFFF0000" .. diff .. "|r " .. statName .. ",")
                            end
                        end
                    end
                end

                -- Sort the BottomText stat breakdown. We want upgraded things to be first.
                table.sort(StatString, function(a, b)
                    local aStat = a:match("|c.-|r%s*(.-)$")
                    local bStat = b:match("|c.-|r%s*(.-)$")
                    local aIndex = #preferredOrder + 1
                    local bIndex = #preferredOrder + 1
                
                    for i, stat in ipairs(preferredOrder) do
                        if stat == aStat then
                            aIndex = i
                        end
                        if stat == bStat then
                            bIndex = i
                        end
                    end
                
                    if a:find("+") and not b:find("+") then
                        return true
                    elseif not a:find("+") and b:find("+") then
                        return false
                    elseif aIndex ~= bIndex then
                        return aIndex < bIndex
                    else
                        return a < b
                    end
                end)

                -- Remove the last entry's comma.
                if #StatString > 0 then
                    StatString[#StatString] = StatString[#StatString]:gsub(",$", "")
                end

                -- Add it to our BottomText.
                for i, stat in ipairs(StatString) do
                    table.insert(BottomText, stat)
                end
            end
        end

        WGLU.DebugPrint("CanEquip: " .. tostring(CanEquip) .. ", IsAppropriate: " .. tostring(IsAppropriate) .. ", ItemHasMainStat: " .. tostring(ItemHasMainStat))

        -- Display why we can't equip the item.
        if CanEquip == false then
            table.insert(BottomText, "|cFFFF0000Can't equip " .. C_Item.GetItemSubClassInfo(classID, subclassID) .. "|r")
        elseif IsAppropriate == false then
            table.insert(BottomText, "|cFFe28743" .. string.lower(C_Item.GetItemSubClassInfo(classID, subclassID)) .. " - Undesired Type|r")
        elseif ItemHasMainStat == false then
            table.insert(BottomText, "|cFFFF0000No " .. PlayerTopStat .. "|r")
        end

        -- Look into the Frame Manager and find an available frame.
        local frame = nil
        for i, f in ipairs(WhoGotLootsFrames) do
            if not f.InUse then
                frame = f
                break
            end
        end

        if frame then

            -- Unhide the main window
            WhoLootData.MainFrame:Open()

            frame:HideUpgradeGlow()

            -- Create cache request
            if CacheRequest and not IsBoP then
                CacheRequest.Frame = frame
                CacheRequest.CompareIlvl = CompareItemIlvl
                CacheRequest.GoodForPlayer = CanEquip and IsAppropriate and not IsClassRestricted
                CacheRequest.IsUpgrade =  CompareItemIlvl > CurrentItemIlvl
                CacheRequest.TextString = table.concat(BottomText2, " ")
                frame.QueuedRequest = WGLCache.CreateRequest(player, CacheRequest)
                frame.LoadingIcon:Unhide()
            else
                frame.LoadingIcon:Hide()
            end

            -- Do we need to show the upgrade glow right now?
            if not CacheRequest and not IsBoP and CanEquip and IsAppropriate and IsDowngradeForOtherPlayer and CompareItemIlvl > CurrentItemIlvl then
                frame:ShowUpgradeGlow()
            end

            -- Make sure that the entry with "ilvl" is always first.
            for i, text in ipairs(BottomText) do
                if text:find("ilvl") then
                    table.insert(BottomText, 1, text)
                    table.remove(BottomText, i + 1)
                    break
                end
            end

            local playerClass = select(2, UnitClass(player))
            frame.Player = player
            frame.PlayerText:SetText("|c" .. RAID_CLASS_COLORS[playerClass].colorStr .. UnitName(player) .. "|r")
            frame.PlayerText:Show()

            -- Dynamically set the width of PlayerText based on its content
            local textWidth = frame.PlayerText:GetStringWidth()
            frame.PlayerText:SetWidth(textWidth)  -- Adding 10 pixels as padding

            frame.PlayerArrow:ClearAllPoints()
            frame.PlayerArrow:SetPoint("LEFT", frame.PlayerText, "RIGHT", 4, 1)

            frame.ItemText:SetText("|c" .. select(4, C_Item.GetItemQualityColor(itemQuality)) .. "[" .. itemName  .. "]" .. "|r")
            frame.ItemText:ClearAllPoints()
            frame.ItemText:SetPoint("LEFT", frame.PlayerArrow, "RIGHT", 4, -1)
            
            frame.BottomText2:SetText("")

            -- If we're comparing items against someone else, and we have the data, show the comparison.
            local CompareItemAppend = ""
            if not NoCompare then
                CompareItemAppend = not UnitIsUnit('player', player) and "|cFFFFFFFFYou:|r " or ""
            end

            if IsBoP then CompareItemAppend = CompareItemAppend .. "|cFF6fcbe3Is BoP|r " end

            -- If we don't have anything in the BottomText2 string, then use BottomText and BottomText2 to split the text.
            if #BottomText2 == 0 and #BottomText > 3 and not CacheRequest and UnitIsUnit('player', player) then
                -- Move the last half of the BottomText to BottomText2.
                local half = math.ceil(#BottomText / 2) + 1
                for i = half, #BottomText do
                    table.insert(BottomText2, BottomText[i])
                    BottomText[i] = nil
                end
            
                -- Insert some blank space at the beginning of BottomText2
                local bottomTextCombined = table.concat(BottomText2, " ") -- "         " is 9 spaces.
            
                frame.BottomText:SetText(CompareItemAppend .. table.concat(BottomText, " "))
                frame.BottomText2:SetText(bottomTextCombined)
            else
                frame.BottomText:SetText(CompareItemAppend .. table.concat(BottomText, " "))
            
                if not IsBoP then
                    if CacheRequest then
                        frame.BottomText2:SetText("Inspecting ...")
                    else
                        frame.BottomText2:SetText(table.concat(BottomText2, " "))
                    end
                end
            end
            
            frame.Icon:SetTexture(itemTexture)
            frame.Item = CompareItemLink
            frame:DropIn(1.0, 0.2)
            frame.lastClickTime = 0

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
            print("Who Got Loots ERROR: Couldn't find an available frame from pool. This shouldn't happen.")
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
                if not UnitIsUnit('player', player) and UnitPlayerControlled(player) and not InCombatLockdown() and CheckInteractDistance(player, 1) and CanInspect(player) then
                    WGLU.DebugPrint("Inspecting " .. player)
                    InspectUnit(player)
                end
                if InCombatLockdown() then
                    print("Who Got Loots - Can't inspect while in combat.")
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
            local message = WhoGotLootsSavedData.WhisperMessage
            local playerName = select(1, UnitName(player))
            message = message:gsub("%%n", playerName)
            message = message:gsub("%%i", itemLink)

            SendChatMessage(message, "WHISPER", nil, UnitName(player))
        end
        if button == "RightButton" then
            WGLCache.RemoveRequest(frame.QueuedRequest)
            self.Close:CloseFrame()
        end
    end)
end

function WhoLootData.HoverFrame(fromFrame, toState)

    if fromFrame == nil or fromFrame.Animating then return end
    if fromFrame == nil then
        print("ERROR: Couldn't find the frame in the ActiveFrames table.")
        return
    end

    local function HandleHoverAnimation(fromFrame, toState)
        local function UpdateAnimation(self, elapsed)
            fromFrame.HoverAnimDelta = (fromFrame.HoverAnimDelta or 0) + (toState and elapsed * 3 or -elapsed)
            local progress = WGLU.Clamp(fromFrame.HoverAnimDelta / WhoLootFrameData.HoverAnimTime, 0, 1)
            progress = math.sin(progress * math.pi / 2)
            WGLU.LerpBackdropColor(fromFrame.background, WhoLootFrameData.HoverColor, WhoLootFrameData.ExitColor, 1 - progress)
    
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
    
    -- Loop through the in-use frames, and set their position starting at the top of the mainwindowbg.
    local numFrames = #WhoLootData.ActiveFrames
    for i, frame in ipairs(WhoLootData.ActiveFrames) do
        frame:ClearAllPoints()
        frame:SetPoint("TOP", WhoLootData.MainFrame, "BOTTOM", 0, (i - 1) * -(frame:GetHeight() - 0) + 8 )
    end

    -- If there are no frames to show, and the option is enabled, hide the main window.
    if numFrames == 0 and WhoGotLootsSavedData.AutoCloseOnEmpty == true then
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
    elseif cmd == "debug" then
        WGLU.DebugMode = not WGLU.DebugMode
        print("Debug mode is now " .. (WGLU.DebugMode and "enabled" or "disabled"))
    end
end