-- Define a table to store global variables
WhoLootData = {}
WhoLootData.DefaultDuration = 60 -- Default duration for each frame to be visible.
WhoLootData.ActiveFrames = {} -- A table to store all active frames.

MainFrame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
MainFrame.name = "WhoLoots"
MainFrame:SetParent(UIParent)
MainFrame:SetDontSavePosition(true)
WhoLootData.MainFrame = MainFrame

-- Register Events --
MainFrame:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
MainFrame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")

-- Handle Events --
function MainFrame:OnEvent(event, arg1, arg2, arg3, arg4, arg5)
    if event == "ADDON_LOADED" and arg1 == "WhoGotLoots" then

        WhoGotLootsSavedData = WhoGotLootsSavedData or {}
        WhoLootsOptionsEntries.LoadOptions()

        if WhoGotLootsSavedData.FirstBoot == false then MainFrame:Hide() end
        WhoGotLootsSavedData.FirstBoot = false

        -- Set window scale.
        WhoLootData.MainFrame:SetScale(WhoGotLootsSavedData.SavedSize)

        -- Set window position (we do this after loading the options, because the saved position is loaded in LoadOptions)
        if WhoGotLootsSavedData.SavedPos then
            WhoLootData.MainFrame:ClearAllPoints()
            WhoLootData.MainFrame:SetPoint(unpack(WhoGotLootsSavedData.SavedPos))
        else
            WhoLootData.MainFrame:ClearAllPoints()
            WhoLootData.MainFrame:SetPoint("CENTER", nil, "CENTER")
        end

    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        local itemLink = arg3
        AddLootFrame(arg5, itemLink)
    end
end
MainFrame:SetScript("OnEvent", MainFrame.OnEvent)

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
        INVTYPE_RANGEDRIGHT = "RangedSlot",
        INVTYPE_RELIC = "RangedSlot",
        INVTYPE_TABARD = "TabardSlot",
        INVTYPE_BODY = "ShirtSlot"
    }
    return equipLocToSlotName[equipLoc]
end

-- ======================================================================= --
-- ======================================================================= --

-- Function to add a loot frame to the main window.
function AddLootFrame(player, itemLink)

    -- If it was our loot, don't show the frame.
    if player == UnitName("player") then return end

    if UnitClass(player) == nil then player = "player" end

    -- If we've ran out of frames, remove the oldest one.
    if #WhoLootData.ActiveFrames >= WhoGotLootsNumFrames then
        local frame = WhoLootData.ActiveFrames[1][1]
        frame.InUse = false
        frame.Frame:Hide()
        table.remove(WhoLootData.ActiveFrames, 1)
    end

    -- Unhide the main window
    MainFrame:Show()

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

        -- If itemLink was a number, we need to get the itemLink from the Item object.
        if type(itemLink) == "number" then
            itemLink = linkedItem
        end

        local CanEquip = C_Item.DoesItemContainSpec(CompareItemID, select(3, UnitClass("player")))
        if not CanEquip and WhoGotLootsSavedData.HideUnequippable then
            return
        end

        if itemType ~= "Armor" and itemType ~= "Weapon" then return end

        local BottomText = {}

        -- If we can equip this item, check if it's an upgrade.
        if CanEquip then

            -- First, check if we're at the minimum character level.
            if UnitLevel("player") < itemMinLevel then
                table.insert(BottomText, "|cFFFF0000Level " .. itemMinLevel .. "|r")
            end

            local slotID = GetInventorySlotInfo(GetItemSlotName(itemLink))
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
                local PlayerTopStat = WhoGotLootUtil.GetPlayerMainStat()

                -- Get the compare item's stats.
                local CompareItemStats = C_Item.GetItemStats(itemLink)
                
                -- Now, get the main stat of our currently equipped item (if we have one)
                local diffStat = 0
                if itemEquipLoc ~= "INVTYPE_HOLDABLE" and itemEquipLoc ~= "INVTYPE_WEAPONOFFHAND" then

                    local CompareItemMainStat = nil
                    if CompareItemStats then
                        CompareItemMainStat =  WhoGotLootUtil.GetItemMainStat(CompareItemStats, PlayerTopStat)
                    end

                    -- If we have an item equipped in the same slot, compare the main stats.
                    if CurrentItemLink then

                        ourItemMainStat = WhoGotLootUtil.GetItemMainStat(C_Item.GetItemStats(CurrentItemLink), PlayerTopStat)

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
                if ilvlDiff == 0 and diffStat == 0 and not (itemEquipLoc == "INVTYPE_HOLDABLE" and itemEquipLoc == "INVTYPE_WEAPONOFFHAND") then
                    local stats = {
                        Haste = { ours = 0, theirs = 0 },
                        Mastery = { ours = 0, theirs = 0 },
                        Versatility = { ours = 0, theirs = 0 },
                        Crit = { ours = 0, theirs = 0 }
                    }

                    -- Get the stats of the item we're comparing to.
                    for stat, value in pairs(CompareItemStats) do
                        if stat == "ITEM_MOD_HASTE_RATING_SHORT" then stats.Haste.theirs = value
                        elseif stat == "ITEM_MOD_MASTERY_RATING_SHORT" then stats.Mastery.theirs = value
                        elseif stat == "ITEM_MOD_VERSATILITY" then stats.Versatility.theirs = value
                        elseif stat == "ITEM_MOD_CRIT_RATING_SHORT" then stats.Crit.theirs = value
                        end
                    end

                    -- Get the stats of our currently equipped item.
                    local ourItemStats = C_Item.GetItemStats(CurrentItemLink)
                    for stat, value in pairs(ourItemStats) do
                        if stat == "ITEM_MOD_HASTE_RATING_SHORT" then stats.Haste.ours = value
                        elseif stat == "ITEM_MOD_MASTERY_RATING_SHORT" then stats.Mastery.ours = value
                        elseif stat == "ITEM_MOD_VERSATILITY" then stats.Versatility.ours = value
                        elseif stat == "ITEM_MOD_CRIT_RATING_SHORT" then stats.Crit.ours = value
                        end
                    end

                    -- Compare the stats.
                    for stat, value in pairs(stats) do
                        local diff = value.theirs - value.ours
                        local statName = WhoGotLootUtil.SimplifyStatName(stat)

                        if statName ~= nil then
                            if diff > 0 then
                                table.insert(BottomText, "|cFF00FF00+" .. diff .. "|r " .. statName)
                            elseif diff < 0 then
                                table.insert(BottomText, "|cFFFF0000" .. diff .. "|r " .. statName)
                            end
                        end
                    end
                end
            else
                table.insert(BottomText, "|cFFFF0000Unique Equipped|r")
            end
        end

        if not CanEquip then
            if WhoGotLootUtil.IsArmorPiece(itemEquipLoc) then
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
            local playerClass = select(2, UnitClass(player))
            frame.Player:SetText("|c" .. RAID_CLASS_COLORS[playerClass].colorStr .. player:sub(1, 10) .. "|r")
            frame.ItemName:SetText("|c" .. select(4, GetItemQualityColor(itemQuality)) .. "[" .. itemName  .. "]" .. "|r")
            frame.BottomText:SetText(table.concat(BottomText, "  "))
            frame.Icon:SetTexture(itemTexture)
            frame.ProgBar:SetValue(0)
            frame.InUse = true
            frame.Frame:SetParent(MainFrame)
            AnimateFrameScale(frame, 1.0, 0.2)

            -- Store the frame in the ChildFrames table.
            WhoLootData.ActiveFrames[#WhoLootData.ActiveFrames + 1] = { frame, WhoLootData.DefaultDuration }

            WhoLootData.ResortFrames()

            -- Play a sound
            if WhoGotLootsSavedData.SoundEnabled == true or WhoGotLootsSavedData.SoundEnabled == nil then
                PlaySound(145739)
            end
        else
            print("ERROR: Couldn't find an available frame from pool. This shouldn't happen.")
        end
    end)
end

-- Function to resort the frames, if we remove one.
function WhoLootData.ResortFrames()
    
    -- Loop through the in-use frames, and set their position starting at the top of the mainwindowbg.
    local numFrames = #WhoLootData.ActiveFrames
    for i, frame in ipairs(WhoLootData.ActiveFrames) do
        frame[1].Frame:ClearAllPoints()
        frame[1].Frame:SetPoint("TOPLEFT", 0, -20 - (i - 1) * 34 - 5)
    end

    -- If there are no frames to show, and the option is enabled, hide the main window.
    if numFrames == 0 and WhoGotLootsSavedData.AutoCloseOnEmpty then
        MainFrame:Hide()
    end
end

function FadeOutFrame(frame)
    frame:SetScript("OnUpdate", function(self, elapsed)
        local alpha = self:GetAlpha()
        if alpha > 0 then
            local clamped = math.max(0, alpha - elapsed * 1.5)
            self:SetAlpha(clamped)
        else
            -- Remove the frame from the ActiveFrames table.
            for i, activeFrame in ipairs(WhoLootData.ActiveFrames) do
                if activeFrame[1].Frame == frame then
                    WhoLootData.ActiveFrames[i][1].InUse = false
                    table.remove(WhoLootData.ActiveFrames, i)
                    break
                end
            end
            self:Hide()
            self:SetScript("OnUpdate", nil)
            WhoLootData.ResortFrames()
        end
    end)
end

-- Attach a looping function to the OnUpdate event of the main frame.
MainFrame:SetScript("OnUpdate", function(self, elapsed)

    for i, frame in ipairs(WhoLootData.ActiveFrames) do
        local progressBar = frame[1].ProgBar
        local timer = frame[2]
        if timer > 0 then
            timer = timer - elapsed
            progressBar:SetValue(timer / WhoLootData.DefaultDuration)
            frame[2] = timer
        else
            FadeOutFrame(frame[1].Frame)
        end
    end
end)

-- Function to animate the scale of a frame.
function AnimateFrameScale(frame, targetScale, duration)
    local startTime = GetTime()
    local initialScale = 1.5
    local scaleChange = targetScale - initialScale
    frame.Frame:Show()
    frame.Frame:SetAlpha(1)

    frame.Frame:SetScript("OnUpdate", function(self, elapsed)
        local currentTime = GetTime()
        local progress = (currentTime - startTime) / duration

        local startColor = { r = 1, g = 1, b = 1}
        local endColor = { r = 0.15, g = 0.15, b = 0.15 }

        if progress >= 1 then
            frame.Frame:SetScale(targetScale)
            frame.Frame:SetBackdropColor(endColor.r, endColor.g, endColor.b, 1)
            frame.Frame:SetScript("OnUpdate", nil) -- Stop the animation
        else
            local newScale = initialScale + (scaleChange * progress)
            frame.Frame:SetScale(newScale)
            frame.Frame:SetBackdropColor(startColor.r + (endColor.r - startColor.r) * progress, startColor.g + (endColor.g - startColor.g) * progress, startColor.b + (endColor.b - startColor.b) * progress, 1)
        end
    end)
end

-- Create the parent frame
MainFrame:SetSize(150, 25)
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)

-- Record the window position.
MainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    WhoGotLootsSavedData.SavedPos = { point, relativeTo, relativePoint, xOfs, yOfs }
end)

-- Apply the backdrop to the frame
MainFrame:SetBackdrop(WhoGotLootUtil.Backdrop)
MainFrame:SetBackdropColor(0.2, 0.2, 0.2, 1) -- Set the background color (RGBA)
MainFrame:SetBackdropBorderColor(0, 0, 0, 1) -- Set the border color (RGBA)

-- Make the frame highlight when hovered over
MainFrame:SetScript("OnEnter", function(self)
    if WhoGotLootsSavedData.LockWindow then return end
    self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1) -- Set the border color (RGBA)
    self:SetBackdropColor(0.4, 0.4, 0.4, 1)
end)

MainFrame:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0, 0, 0, 1) -- Set the border color (RGBA)
    self:SetBackdropColor(0.2, 0.2, 0.2, 1)
end)

-- Create the title text
local text = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("LEFT", 10, 0)
text:SetJustifyH("LEFT")
text:SetText("Who Got Loots")
text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
    text:SetTextColor(1, 1, 1)

-- Ensure the title text is properly anchored to the parent frame
text:SetParent(MainFrame)

-- Add a button to close the window
local closeBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -3, -5)
closeBtn:SetSize(15, 15)
closeBtn:SetScript("OnClick", function(self)
    MainFrame:Hide()
    WhoLootData.OptionsFrame:Hide()
end)

-- Add a button to open the options menu
local optionsBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
optionsBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -6, 0)
optionsBtn:SetSize(15, 15)
optionsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
optionsBtn:SetScript("OnClick", function(self)
    if WhoLootsOptionsFrame:IsVisible() then 
        WhoLootsOptionsFrame:Hide()
    else
        -- Fade in the options frame, and make it slide into view.
        WhoLootsOptionsFrame:Show()
        WhoLootsOptionsFrame:SetAlpha(0)
        WhoLootsOptionsFrame:ClearAllPoints()

        -- Determine if we have enough space on the left side of the main frame.
        local WhichPoint = "TOPRIGHT"
        local frameWidth = MainFrame:GetWidth()
        local optionsFrameWidth = WhoLootsOptionsFrame:GetWidth()
        local screenWidth = GetScreenWidth()
        local MainFrameX, MainFrameY = MainFrame:GetCenter()

        if MainFrameX - optionsFrameWidth * MainFrame:GetScale() < 0 then
            WhichPoint = "TOPLEFT"
        end

        WhoLootsOptionsFrame:SetFrameStrata("HIGH")
        WhoLootsOptionsFrame:SetScript("OnUpdate", function(self, elapsed)
            local alpha = self:GetAlpha()
            if alpha < 1 then
                local clamped = math.min(1, alpha + elapsed * 4)
                self:SetAlpha(clamped)
                if WhichPoint == "TOPRIGHT" then
                    self:SetPoint(WhichPoint, MainFrame, "TOPLEFT", (1 - clamped) * -26, 0)
                else
                    self:SetPoint(WhichPoint, MainFrame, "TOPRIGHT", (1 - clamped) * 26, 0)
                end
            else
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end)

-- Add a button to add a random item.
local debug_addrandombtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
debug_addrandombtn:SetPoint("RIGHT", MainFrame, "TOPRIGHT", 60, 10)
debug_addrandombtn:SetSize(100, 20)
debug_addrandombtn:SetText("+ Random")
debug_addrandombtn:SetScript("OnClick", function(self)
    AddLootFrame("Andisae", 212407)
end)
debug_addrandombtn:Hide()

-- Define the slash commands
SLASH_WHOLOOT1 = "/wholoots"

-- Register the command handler
SlashCmdList["WHOLOOT"] = function(msg, editbox)
    if msg == "debug" then
        if debug_addrandombtn:IsVisible() then
            debug_addrandombtn:Hide()
        else
            debug_addrandombtn:Show()
        end
        print("Debug mode is now " .. (debug_addrandombtn:IsVisible() and "enabled" or "disabled") .. ".")
    elseif msg:sub(1, 3) == "add" then
        local itemID = tonumber(msg:sub(5))
        
        if itemID then
            AddLootFrame("Andisae", itemID)
        else
            -- Try parsing it as an itemLink.
            local itemLink = msg:sub(5)
            AddLootFrame("Andisae", itemLink)
        end
    else
        if MainFrame:IsVisible() then
            MainFrame:Hide()
        else
            MainFrame:Show()
        end
    end
end