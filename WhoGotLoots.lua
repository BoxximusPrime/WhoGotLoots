-- Define a table to store global variables
WhoLootData = WhoLootData or {}

WhoLootData.Version = "1.0.0"

WhoLootData.ActiveFrames = {} -- A table to store all active frames.

WhoLootData.MainFrame = WGLUIBuilder.CreateMainFrame()
WhoLootData.MainFrame:SetParent(UIParent)
WhoLootData.MainFrame:SetDontSavePosition(true)

-- Create a frame that acts as a timer, which iterates through all active frames and hides them when their time is up.
local TimerFrame = CreateFrame("Frame")
TimerFrame:SetScript("OnUpdate", function(self, elapsed)
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

-- Register Events --
WhoLootData.MainFrame:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
WhoLootData.MainFrame:RegisterEvent("CHAT_MSG_LOOT")

-- Handle Events --
function WhoLootData.MainFrame:OnEvent(event, ...)
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
        WhoLootData.MainFrame.cursorFrame:SetScale(WhoGotLootsSavedData.SavedSize)

        -- Set window position (we do this after loading the options, because the saved position is loaded in LoadOptions)
        if WhoGotLootsSavedData.SavedPos then
            WhoLootData.MainFrame:Move(WhoGotLootsSavedData.SavedPos)
        else
            WhoLootData.MainFrame:Move({"CENTER", nil, "CENTER"})
        end
    elseif event == "CHAT_MSG_LOOT" then 

        -- Scrape the message for the item link. Item links look like "|cffffffff|Hitem:2589::::::::20:257::::::|h[Linen Cloth]|h|rx2.",
        -- and we can use a pattern to extract it.
        local message = args[1]
        local itemLink = message:match("|c.-|Hitem:.-|h.-|h|r")
        if itemLink then
            AddLootFrame(args[2], itemLink)
        end
    end
end
WhoLootData.MainFrame:SetScript("OnEvent", WhoLootData.MainFrame.OnEvent)

local function getGearItemLvl(slotName)
    local lvl = 0
    if (slotName ~= nil) then
        local slotID, texture, checkRelic = GetInventorySlotInfo(slotName)
        if (slotID ~= nil) then
            local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
            if C_Item.DoesItemExist(itemLocation) then
                lvl = C_Item.GetCurrentItemLevel(itemLocation)
            end
        end
    end
    return format("%s", lvl)
end

local function GetItemSlotName(itemLink)
    local equipLoc = select(9, GetItemInfo(itemLink))
    local equipLocToSlotName = {
        INVTYPE_HEAD = "HeadSlot",
        INVTYPE_NECK = "NeckSlot",
        INVTYPE_SHOULDER = "ShoulderSlot",
        INVTYPE_CHEST = "ChestSlot",
        INVTYPE_WAIST = "WaistSlot",
        INVTYPE_LEGS = "LegsSlot",
        INVTYPE_FEET = "FeetSlot",
        INVTYPE_WRIST = "WristSlot",
        INVTYPE_HAND = "HandsSlot",
        INVTYPE_FINGER = "Finger0Slot", -- Finger0Slot and Finger1Slot are used for rings
        INVTYPE_TRINKET = "Trinket0Slot", -- Trinket0Slot and Trinket1Slot are used for trinkets
        INVTYPE_CLOAK = "BackSlot",
        INVTYPE_WEAPON = "MainHandSlot",
        INVTYPE_SHIELD = "SecondaryHandSlot",
        INVTYPE_2HWEAPON = "MainHandSlot",
        INVTYPE_WEAPONMAINHAND = "MainHandSlot",
        INVTYPE_WEAPONOFFHAND = "SecondaryHandSlot",
        INVTYPE_HOLDABLE = "SecondaryHandSlot",
        INVTYPE_RANGED = "RangedSlot",
        INVTYPE_THROWN = "RangedSlot",
        INVTYPE_RANGEDRIGHT = "MainHandSlot",
        INVTYPE_RELIC = "RangedSlot",
        INVTYPE_TABARD = "TabardSlot",
        INVTYPE_BODY = "ShirtSlot"
    }
    return equipLocToSlotName[equipLoc]
end

-- Function to check if the player is in a raid instance
local function IsPlayerInRaidInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

local function IsRaidLFR()
    local _, _, difficultyID = GetInstanceInfo()
    return difficultyID == 17
end

-- ======================================================================= --
-- ======================================================================= --

-- Function to add a loot frame to the main window.
function AddLootFrame(player, itemLink)

    -- Is the item at least rare qualty?
    local itemQuality = select(3, GetItemInfo(itemLink))

    -- Does the player name have their realm? Check for a -
    if string.find(player, "-") then
        player = string.match(player, "(.*)-")
    end

    -- If it was our loot, don't show the frame.
    if player == UnitName("player") and WhoGotLootsSavedData.ShowOwnLoot ~= true then
        return
    end

    -- Are we in a raid, and should we show raid loot?
    local isInRaid = IsPlayerInRaidInstance()
    if (WhoGotLootsSavedData.ShowDuringRaid ~= true and isInRaid) or 
        (isInRaid and WhoGotLootsSavedData.ShowDuringRaid == true and WhoGotLootsSavedData.ShowDuringLFR ~= true and IsRaidLFR()) then
        return
    end

    -- If the player is nil, set it to the player.
    if UnitClass(player) == nil then player = "player" end

    -- If we've ran out of frames, remove the oldest one.
    if #WhoLootData.ActiveFrames >= WGL_NumPooledFrames then
        local frame = WhoLootData.ActiveFrames
        frame.InUse = false
        frame.Frame:Hide()
        table.remove(WhoLootData.ActiveFrames, 1)
    end

    if type(player) ~= "string" then player = tostring(player) end

    -- If itemLink is just an ID, it doesn't have upgrade levels.
    -- We need to create an Item object to get the item level.
    local CompareItem
    if type(itemLink) == "number" then
        CompareItem = Item:CreateFromItemID(itemLink)
    end

    if type(itemLink) == "string" then
        CompareItem = Item:CreateFromItemLink(itemLink)
    end

    CompareItem:ContinueOnItemLoad(function()
        local CompareItemID = C_Item.GetItemIDForItemInfo(itemLink)
        local efectiveIlvl, isPreview, baseIlvl = C_Item.GetDetailedItemLevelInfo(itemLink)
        local itemName, linkedItem, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent = C_Item.GetItemInfo(itemLink)

        if itemQuality < 3 then return end
    

        -- If itemLink was a number, we need to get the itemLink from the Item object.
        if type(itemLink) == "number" then
            itemLink = linkedItem
        end

        local CanEquip = C_Item.DoesItemContainSpec(CompareItemID, select(3, UnitClass("player")))
        if not CanEquip and WhoGotLootsSavedData.HideUnequippable then
            -- if there's no active frames, hide the main window.
            if #WhoLootData.ActiveFrames == 0 then
                WhoLootData.MainFrame:Close()
            end
            return
        end

        if itemType ~= "Armor" and itemType ~= "Weapon" then return end

        local BottomText = {}

        -- If we can equip this item, check if it's an upgrade.
        if CanEquip then

            -- Unhide the main window
            WhoLootData.MainFrame:Open()

            -- First, check if we're at the minimum character level.
            if UnitLevel("player") < itemMinLevel then
                table.insert(BottomText, "|cFFFF0000Level " .. itemMinLevel .. "|r")
            end

            local slotName = GetItemSlotName(itemLink)
            local slotID = GetInventorySlotInfo(slotName)
            local OurILVL = 0
            local CurrentItemLink = nil
            local Skip = false

            -- If this is a trinket, find the lowest ilvl trinket we have.
            if itemEquipLoc == "INVTYPE_TRINKET" then
                local trinket1 = GetInventoryItemLink("player", 13)
                local trinket2 =  GetInventoryItemLink("player", 14)

                local trinket1id = select(1, C_Item.GetItemInfoInstant(trinket1))
                local trinket2id = select(1, C_Item.GetItemInfoInstant(trinket2))

                -- Quick check to see if we have the same trinket.
                if CompareItemID == trinket1id or CompareItemID == trinket2id then
                    -- If we have the same trinket, but it's at a lower ilvl, we want to show it.
                    if trinket1id == CompareItemID then
                        if C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(13)) < efectiveIlvl then
                            Skip = false
                        else
                            Skip = true
                        end
                    elseif trinket2id == CompareItemID then
                        if C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(14)) < efectiveIlvl then
                            Skip = false
                        else
                            Skip = true
                        end
                    end
                end

                local trinket1Ilvl = 0
                local trinket2Ilvl = 0
                if trinket1 then
                    trinket1Ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(13))
                end
                if trinket2 then
                    trinket2Ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(14))
                end
                OurILVL = math.min(trinket1Ilvl, trinket2Ilvl)

                CurrentItemLink = trinket1Ilvl < trinket2Ilvl and trinket1 or trinket2

            -- Same for ring
            elseif itemEquipLoc == "INVTYPE_FINGER" then
                local ring1 = GetInventoryItemLink("player", 11)
                local ring2 = GetInventoryItemLink("player", 12)

                local ring1id = select(1, C_Item.GetItemInfoInstant(ring1))
                local ring2id = select(1, C_Item.GetItemInfoInstant(ring2))

                -- Quick check to see if we have the same ring.
                if CompareItemID == ring1id or CompareItemID == ring2id then
                    -- If we have the same ring, but it's at a lower ilvl, we want to show it.
                    if ring1id == CompareItemID then
                        if C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(11)) < efectiveIlvl then
                            Skip = false
                        else
                            Skip = true
                        end
                    elseif ring2id == CompareItemID then
                        if C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(12)) < efectiveIlvl then
                            Skip = false
                        else
                            Skip = true
                        end
                    end
                end

                local ring1Ilvl = 0
                local ring2Ilvl = 0
                if ring1 then
                    ring1Ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(11))
                end
                if ring2 then
                    ring2Ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(12))
                end
                OurILVL = math.min(ring1Ilvl, ring2Ilvl)

                CurrentItemLink = ring1Ilvl < ring2Ilvl and ring1 or ring2

            -- If it's an offhand, we want to compare it to the main hand.
            elseif itemEquipLoc == "INVTYPE_HOLDABLE" or itemEquipLoc == "INVTYPE_WEAPONOFFHAND" then
                slotID = 16
                OurILVL = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slotID))
                CurrentItemLink = GetInventoryItemLink("player", slotID)
                table.insert(BottomText, "Mainhand:")

            -- Normal comparison.
            else
                CurrentItemLink = GetInventoryItemLink("player", GetItemSlotName(itemLink))
            end

            if not Skip then

                -- Compare Against the item we have in the same slot.
                local IsNotArmor = ItemType == "Trinket" or ItemType == "Ring" or ItemType == "Weapon" or ItemType == "Neck" or ItemType == "Cloak"

                -- Check if this is an armor piece.
                if CurrentItemLink then 
                    OurILVL = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slotID))
                end

                -- Show the ilvl diff if any
                local ilvlDiff = efectiveIlvl - OurILVL
                if ilvlDiff > 0 then
                    table.insert(BottomText, "|cFF00FF00+" .. ilvlDiff .. "|r ilvl")
                elseif ilvlDiff < 0 then
                    table.insert(BottomText, "|cFFFF0000" .. ilvlDiff .. "|r ilvl")
                end

                -- Next, figure out which stat is relevant to us. Get the player's main stats, and find the highest one.
                local PlayerTopStat = WGLUtil.GetPlayerMainStat()

                -- Get the compare item's stats.
                local CompareItemStats = C_Item.GetItemStats(itemLink)
                
                -- Now, get the main stat of our currently equipped item (if we have one)
                local diffStat = 0
                if itemEquipLoc ~= "INVTYPE_HOLDABLE" and itemEquipLoc ~= "INVTYPE_WEAPONOFFHAND" then

                    local CompareItemMainStat = nil
                    if CompareItemStats then
                        CompareItemMainStat =  WGLUtil.GetItemMainStat(CompareItemStats, PlayerTopStat)
                    end

                    -- If we have an item equipped in the same slot, compare the main stats.
                    if CurrentItemLink then

                        ourItemMainStat = WGLUtil.GetItemMainStat(C_Item.GetItemStats(CurrentItemLink), PlayerTopStat)

                        if CompareItemMainStat ~= nil then
                            diffStat = CompareItemMainStat - ourItemMainStat
                        elseif ourItemMainStat ~= nil then
                            diffStat = -ourItemMainStat
                        else
                            diffStat = 0
                        end
                    end

                    -- Create a text showing the difference in main stat.
                    if diffStat ~= 0 then
                        local diffStatText = ""
                        if diffStat > 0 then
                            diffStatText = "|cFF00FF00+" .. diffStat .. "|r"
                        elseif diffStat < 0 then
                            diffStatText = "|cFFFF0000" .. diffStat .. "|r"
                        end
                        table.insert(BottomText, diffStatText .. " " .. PlayerTopStat)
                    end
                end

                -- If the item level is the same as what we have now, give a quick stat change breakdown.
                if itemEquipLoc ~= "INVTYPE_HOLDABLE" and itemEquipLoc ~= "INVTYPE_WEAPONOFFHAND" then
                    local stats = {
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

                    local preferredOrder = { "Haste", "Mastery", "Versatility", "Crit", "Vers", "Avoidance", "Leech", "Speed", "Indestructible" }

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
                        end
                    end

                    -- Get the stats of our currently equipped item.
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
                        end
                    end

                    -- Compare the stats.
                    for _, stat in ipairs(preferredOrder) do
                        local value = stats[stat]
                        local diff = value.theirs - value.ours
                        local statName = WGLUtil.SimplifyStatName(stat)

                        if statName ~= nil then

                            -- Overrides for some stats.
                            if(statName == "Indest") then
                                if diff > 0 then
                                    table.insert(BottomText, "|cFF00FF00+Indestructible|r")
                                elseif diff < 0 then
                                    table.insert(BottomText, "|cFFFF0000-Indestructible|r")
                                end
                            -- Normal stat display
                            else
                                if diff > 0 then
                                    table.insert(BottomText, "|cFF00FF00+" .. diff .. "|r " .. statName)
                                elseif diff < 0 then
                                    table.insert(BottomText, "|cFFFF0000" .. diff .. "|r " .. statName)
                                end
                            end
                        end
                    end
                end
            else
                table.insert(BottomText, "|cFFFF0000Unique Equipped|r")
            end
        end

        if not CanEquip then
            if WGLUtil.IsArmorPiece(itemEquipLoc) then
                table.insert(BottomText, "|cffff0000" .. itemSubType .. "|r")
            else
                table.insert(BottomText, "|cffff0000" .. _G[itemEquipLoc] .. "|r")
            end
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
            frame.Player = player
            local playerClass = select(2, UnitClass(player))
            frame.PlayerText:SetText("|c" .. RAID_CLASS_COLORS[playerClass].colorStr .. player:sub(1, 8) .. "|r")
            frame.ItemText:SetText("|c" .. select(4, GetItemQualityColor(itemQuality)) .. "[" .. itemName  .. "]" .. "|r")
            frame.BottomText:SetText(table.concat(BottomText, ", "))
            frame.Icon:SetTexture(itemTexture)
            frame.Item = itemLink
            frame:DropIn(1.0, 0.2)

            -- Store the frame in the ChildFrames table.
            WhoLootData.ActiveFrames[#WhoLootData.ActiveFrames + 1] = frame
            WhoLootData.ResortFrames()

            -- Set a shift + click function to add the item link to the chat box.
            frame:SetScript("OnMouseDown", function(self, button)
                if IsShiftKeyDown() then
                    ChatEdit_InsertLink(itemLink)
                end
            end)

            -- Play a sound
            if WhoGotLootsSavedData.SoundEnabled == true or WhoGotLootsSavedData.SoundEnabled == nil then
                PlaySound(145739)
            end
        else
            print("ERROR: Couldn't find an available frame from pool. This shouldn't happen.")
        end
    end)
end

function WhoLootData.HoverFrame(fromFrame, toState)

    if fromFrame == nil or fromFrame.Animating then return end
    if fromFrame == nil then
        print("ERROR: Couldn't find the frame in the ActiveFrames table.")
        return
    end

    if toState then
        GameTooltip:SetOwner(fromFrame, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(fromFrame.Item)
        GameTooltip:Show()

        -- On hover we're going to move some things over time.
        fromFrame:SetScript("OnUpdate", function(self, elapsed)

            if fromFrame.HoverAnimDelta == nil then fromFrame.HoverAnimDelta = 0 end
            fromFrame.HoverAnimDelta = fromFrame.HoverAnimDelta + elapsed * 2
            local progress = WGLUtil.Clamp(fromFrame.HoverAnimDelta / WhoLootFrameData.HoverAnimTime, 0, 1)
            progress = math.sin(progress * math.pi / 2)

            WGLUtil.LerpBackdropColor(fromFrame.background, WhoLootFrameData.HoverColor, WhoLootFrameData.ExitColor, 1 - progress)

            fromFrame.PlayerText:SetAlpha(1 - progress)
            fromFrame.Icon:ClearAllPoints()
            fromFrame.Icon:SetPoint("TOPLEFT",
                WGLUtil.LerpFloat(WhoLootFrameData.IconStartLeftPos, WhoLootFrameData.IconEndLeftPos, progress), WhoLootFrameData.IconTopPos)
            fromFrame.Icon:SetAlpha(1 - progress)
            fromFrame.ItemText:ClearAllPoints()
            fromFrame.ItemText:SetPoint("TOPLEFT",
                WGLUtil.LerpFloat(WhoLootFrameData.ItemNameStartLeftPos, WhoLootFrameData.ItemNameEndLeftPos, progress), WhoLootFrameData.ItemNameTopPos)
            fromFrame.BottomText:ClearAllPoints()
            fromFrame.BottomText:SetPoint("TOPLEFT", fromFrame.ItemText, "BOTTOMLEFT", 0, -2)

            if progress >= 1 then
                fromFrame:SetScript("OnUpdate", nil) -- Stop the animation
            end

        end)
    else
        GameTooltip:Hide()

        -- On leave we're going to move some things back over time.
        if fromFrame.HoverAnimDelta == nil then fromFrame.HoverAnimDelta = WhoLootFrameData.HoverAnimTime end
        fromFrame:SetScript("OnUpdate", function(self, elapsed)
            fromFrame.HoverAnimDelta = fromFrame.HoverAnimDelta - elapsed
            local progress = WGLUtil.Clamp(fromFrame.HoverAnimDelta / WhoLootFrameData.HoverAnimTime, 0, 1)
            progress = math.sin(progress * math.pi / 2)

            WGLUtil.LerpBackdropColor(fromFrame.background, WhoLootFrameData.HoverColor, WhoLootFrameData.ExitColor, 1 - progress)

            fromFrame.PlayerText:SetAlpha(1 - progress)
            fromFrame.Icon:ClearAllPoints()
            fromFrame.Icon:SetPoint("TOPLEFT",
                WGLUtil.LerpFloat(WhoLootFrameData.IconStartLeftPos, WhoLootFrameData.IconEndLeftPos, progress), WhoLootFrameData.IconTopPos)
            fromFrame.Icon:SetAlpha(1 - progress)
            fromFrame.ItemText:ClearAllPoints()
            fromFrame.ItemText:SetPoint("TOPLEFT",
                WGLUtil.LerpFloat(WhoLootFrameData.ItemNameStartLeftPos, WhoLootFrameData.ItemNameEndLeftPos, progress), WhoLootFrameData.ItemNameTopPos)
            fromFrame.BottomText:ClearAllPoints()
            fromFrame.BottomText:SetPoint("TOPLEFT", fromFrame.ItemText, "BOTTOMLEFT", 0, -2)

            if progress <= 0 then
                fromFrame:SetScript("OnUpdate", nil) -- Stop the animation
                fromFrame.HoverAnimDelta = nil
            end
        end)
    end
end


-- Function to resort the frames, if we remove one.
function WhoLootData.ResortFrames()
    
    -- Loop through the in-use frames, and set their position starting at the top of the mainwindowbg.
    local numFrames = #WhoLootData.ActiveFrames
    for i, frame in ipairs(WhoLootData.ActiveFrames) do
        frame:ClearAllPoints()
        frame:SetPoint("TOP", WhoLootData.MainFrame, "BOTTOM", 0, (i - 1) * -36 + 6 )
    end

    -- If there are no frames to show, and the option is enabled, hide the main window.
    if numFrames == 0 and WhoGotLootsSavedData.AutoCloseOnEmpty == true then
        WhoLootData.MainFrame:Close()
    end
end

-- Define the slash commands
SLASH_WHOLOOT1 = "/whogotloots"
SLASH_WHOLOOT2 = "/wgl"

-- Register the command handler
SlashCmdList["WHOLOOT"] = function(msg, editbox)
    if msg:sub(1, 3) == "add" then
        local itemID = tonumber(msg:sub(5))
        
        if itemID then
            AddLootFrame(GetUnitName("player"), itemID)
        else
            -- Try parsing it as an itemLink.
            local itemLink = msg:sub(5)
            AddLootFrame(GetUnitName("player"), itemLink)
        end
    else
        if WhoLootData.MainFrame:IsVisible() then
            WhoLootData.MainFrame:Close()
        else
            WhoLootData.MainFrame:Open()
        end
    end
end