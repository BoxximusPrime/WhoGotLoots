-- Define a table to store global variables
WhoLootData = {}
WhoLootData.ChildFrames = {} -- Contains sub tables with each frame, progress bar, and timer.
WhoLootData.DefaultDuration = 60 -- Default duration for each frame to be visible.

MainFrame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
MainFrame:SetParent(UIParent)

WhoLootData.MainFrame = MainFrame

-- Register Events --
MainFrame:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
MainFrame:RegisterEvent("PLAYER_LOGOUT"); -- Fired when about to log out
MainFrame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")

-- Handle Events --
function MainFrame:OnEvent(event, arg1, arg2, arg3, arg4, arg5)
    if event == "ADDON_LOADED" and arg1 == "WhoGotLoots" then

        WhoLootsOptionsEntries.LoadOptions()

        -- Set window position (we do this after loading the options, because the saved position is loaded in LoadOptions)
        if WhoGotLootsSavedData.SavedPos then
            WhoLootData.MainFrame:SetPoint(unpack(WhoGotLootsSavedData.SavedPos))
        else
            WhoLootData.MainFrame:SetPoint("CENTER")
        end

        -- Set window scale.
        WhoLootData.MainFrame:SetScale(WhoGotLootsSavedData.SavedSize)

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
        --print("getGearItemLvl    " .. slotID .. "     " .. texture .. "     " .. tostring(checkRelic))
        if (slotID ~= nil) then
            local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
            if C_Item.DoesItemExist(itemLocation) then
                lvl = C_Item.GetCurrentItemLevel(itemLocation)
            end
        end
    end
    --print("getGearItemLvl("..slotName..") " .. "  slotID: " .. slotID .. "  itemlevel: " .. lvl)
    return format("%s", lvl)
end

-- Find which is the highest stat between agility, strength, and intellect.
local function getHighestStat(mainStat)
    local highestStat = 0
    local highestStatName = ""
    for stat, value in pairs(mainStat) do
        if stat == "ITEM_MOD_AGILITY_SHORT" or stat == "ITEM_MOD_STRENGTH_SHORT" or stat == "ITEM_MOD_INTELLECT_SHORT" then
            if value > highestStat then
                highestStat = value
                highestStatName = stat
            end
        end
    end
    return highestStatName
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

    -- Unhide the main window
    MainFrame:Show()

    if type(player) ~= "string" then
        player = tostring(player)
    end

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

        local CanEquip = C_Item.DoesItemContainSpec(CompareItemID, select(3, UnitClass("player")))
        if not CanEquip and WhoGotLootsSavedData.HideUnequippable then
            return
        end

        if itemType ~= "Armor" and itemType ~= "Weapon" then return end

        -- Create a new frame to display the player and item.
        -- We want this frame to be within the mainwindowbg.
        local newframe =  CreateFrame("Frame", nil, nil, "BackdropTemplate")
        newframe:SetWidth(240)
        newframe:SetHeight(35)
        newframe:SetPoint("TOP", 0, -20)

        -- Create a text showing which player it was.
        player = player:gsub("%-.*", "")
        local playerClass = select(2, UnitClass(player))
        local text = newframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
        text:SetPoint("LEFT", 10, 0)
        local classColor = RAID_CLASS_COLORS[playerClass]
        if classColor then
            text:SetText("|c" .. classColor.colorStr .. player:sub(1, 10) .. "|r")
        else
            text:SetText(player:sub(1, 10))
        end
        text:SetParent(newframe)

        -- Create a progress bar that will show the timer's progress.
        local progressBar = CreateFrame("StatusBar", nil, newframe)
        progressBar:SetSize(100, 2)
        progressBar:SetPoint("BOTTOMLEFT",  1, 1)
        progressBar:SetPoint("BOTTOMRIGHT", -1, 1)
        progressBar:SetMinMaxValues(0, WhoLootData.DefaultDuration)
        progressBar:SetValue(0)
        progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        progressBar:SetStatusBarColor(1, 1, 1, 0.6)
        progressBar:SetParent(newframe)

        -- Show the item's icon.
        local itemTexture = newframe:CreateTexture(nil, "OVERLAY")
        itemTexture:SetTexture(CompareItem:GetItemIcon())
        itemTexture:SetSize(22, 22)
        itemTexture:SetPoint("TOPLEFT", 55, -5)
        itemTexture:SetParent(newframe)

        -- Show the item's name.
        local itemText = newframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemText:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
        itemText:SetPoint("TOPLEFT", 85, -8)
        itemText:SetText("|c" .. select(4, GetItemQualityColor(CompareItem:GetItemQuality())) .. "[" .. itemName  .. "]" .. "|r")
        itemText:SetParent(newframe)

        local slotID = GetInventorySlotInfo(GetItemSlotName(itemLink))
        local CurrentItemLink = GetInventoryItemLink("player", slotID)
        local MyCurrentItemID = C_Item.GetItemIDForItemInfo(CurrentItemLink)
        local CurrentItem = Item:CreateFromItemID(MyCurrentItemID)

        CurrentItem:ContinueOnItemLoad(function()

            local BottomText = {}

            local ItemType = select(6, GetItemInfo(CurrentItemLink))
            local IsNotArmor = ItemType == "Trinket" and ItemType == "Ring" and ItemType == "Weapon" and ItemType == "Neck" and ItemType == "Cloak"

            local MatchesArmorType = true
            if not IsNotArmor then
                local ourArmorType = select(7, GetItemInfo(CurrentItemLink))
                MatchesArmorType = ourArmorType == itemSubType
            end

            -- Determine if we can equip the item.
            -- This is kinda hackish, but get the tooltip and check for red text.
            -- local tooltip = CreateFrame("GameTooltip", "WhoLootTooltip", nil, "GameTooltipTemplate")
            -- tooltip:SetOwner(UIParent, "ANCHOR_NONE")
            -- --tooltip:SetHyperlink(linkedItem)
            -- tooltip:SetItemByID(CompareItemID)
            -- for i = 1, tooltip:NumLines() do
            --     local r, g, b = _G["WhoLootTooltipTextRight" .. i]:GetTextColor()
            --     -- If the text is mostly red, we can't equip it.
            --     if r > 0.9 and g < 0.2 and b < 0.2 then
            --         CanEquip = false
            --         break
            --     end
            -- end

            -- If we can equip this item, check if it's an upgrade.
            if CanEquip then
                -- Next, check if we're at the minimum character level.
                if UnitLevel("player") < itemMinLevel then
                    table.insert(BottomText, "|cFFFF0000Level " .. itemMinLevel .. "|r")
                end

                local ourIlvl = 0

                -- If this is a trinket, find the highest ilvl trinket we have.
                if itemEquipLoc == "INVTYPE_TRINKET" then
                    local trinket1 = GetInventoryItemLink("player", 13)
                    local trinket2 = GetInventoryItemLink("player", 14)
                    local trinket1Ilvl = 0
                    local trinket2Ilvl = 0
                    if trinket1 then
                        trinket1Ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(13))
                    end
                    if trinket2 then
                        trinket2Ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(14))
                    end
                    ourIlvl = math.max(trinket1Ilvl, trinket2Ilvl)

                -- If this is a ring, we need to check both rings.
                elseif itemEquipLoc == "INVTYPE_FINGER" then
                    local ring1 = GetInventoryItemLink("player", 11)
                    local ring2 = GetInventoryItemLink("player", 12)
                    local ring1Ilvl = 0
                    local ring2Ilvl = 0
                    if ring1 then
                        ring1Ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(11))
                    end
                    if ring2 then
                        ring2Ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(12))
                    end
                    ourIlvl = math.max(ring1Ilvl, ring2Ilvl)

                -- Normal comparison.
                else
                    ourIlvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slotID))
                end

                local ilvlDiff = efectiveIlvl - ourIlvl
                local diffText = ""
                if ilvlDiff > 0 then
                    diffText = "|cFF00FF00+" .. ilvlDiff .. "|r"
                elseif ilvlDiff < 0 then
                    diffText = "|cFFFF0000" .. ilvlDiff .. "|r"
                end

                -- ADD ITEM LEVEL
                table.insert(BottomText, diffText .. "|r ilvl")
                
                -- Figure out the main stat difference.
                if itemEquipLoc ~= "INVTYPE_TRINKET" and itemEquipLoc ~= "INVTYPE_NECK" and itemEquipLoc ~= "INVTYPE_FINGER" then

                    -- Get the main stat of the item we're comparing to.
                    local compareItemMainStat = C_Item.GetItemStats(linkedItem)
                    if compareItemMainStat ~= nil then
                        
                        -- Now, get the main stat of our currently equipped item.
                        local highestStatName = getHighestStat(compareItemMainStat)

                        -- Get the main stat of our currently equipped item.
                        local ourItemMainStat = C_Item.GetItemStats(CurrentItemLink)
                        local ourHighestStatName = getHighestStat(ourItemMainStat)

                        -- Now get the difference between the two.
                        local diffStat = compareItemMainStat[highestStatName] - ourItemMainStat[ourHighestStatName]

                        -- The stat names look like "ITEM_MOD_AGILITY_SHORT", so we need to strip the "ITEM_MOD_" and "_SHORT" parts.
                        highestStatName = highestStatName:gsub("ITEM_MOD_", ""):gsub("_SHORT", "")

                        -- Make the stat name look nice.
                        if highestStatName == "AGILITY" then
                            highestStatName = "Agility"
                        elseif highestStatName == "STRENGTH" then
                            highestStatName = "Strength"
                        elseif highestStatName == "INTELLECT" then
                            highestStatName = "Intellect"
                        end

                        -- Create a text showing the difference in main stat.
                        table.insert(BottomText, "+|c" .. (diffStat > 0 and "ff00ff00" or "ffff0000") .. diffStat .. "|r " .. highestStatName)
                    end
                end
            end

            if not CanEquip then
                if WhoGotLootUtil.IsArmorPiece(itemEquipLoc) then
                    table.insert(BottomText, "|cffff0000" .. itemSubType .. "|r")
                else
                    table.insert(BottomText, "|cffff0000" .. _G[itemEquipLoc] .. "|r")
                end
            end

            BottomTextFrame = newframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            BottomTextFrame:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
            BottomTextFrame:SetPoint("TOPLEFT", itemText, "BOTTOMLEFT", 0, -2)
            BottomTextFrame:SetText(table.concat(BottomText, "  "))
            BottomTextFrame:SetParent(newframe)
        end)

        -- Register a mouseover to show the item tooltip.
        newframe:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(linkedItem)
            GameTooltip:Show()
            self:SetBackdropColor(0.4, 0.4, 0.4, 1)
        end)

        newframe:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        end)

        local textTotalLength = text:GetStringWidth() + itemText:GetStringWidth() + 105

        -- Create a close button to remove the frame.
        local close = CreateFrame("Button", nil, newframe, "UIPanelCloseButton")
        close:SetSize(15, 15)
        close:SetPoint("RIGHT", -3, 0)
        close:SetScript("OnClick", function(self)
            -- Remove the frame instantly not using the fade out function.
            for i, f in ipairs(WhoLootData.ChildFrames) do
                if f[1] == newframe then
                    table.remove(WhoLootData.ChildFrames, i)
                end
            end
            newframe:Hide()
            ResortFrames()
        end)

        -- Store the frame in the ChildFrames table.
        table.insert(WhoLootData.ChildFrames, {newframe, progressBar, WhoLootData.DefaultDuration})

        -- Make it look nice.
        local backdrop = {
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 4,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }

        newframe:SetBackdrop(backdrop)
        newframe:SetBackdropBorderColor(0, 0, 0, 1) -- Set the border color (RGBA)

        newframe:SetParent(MainFrame)
        AnimateFrameScale(newframe, 1.0, 0.2)

        ResortFrames()

        -- Play a sound
        print(WhoLootsOptionsEntries.SoundEnabled)
        if WhoLootsOptionsEntries.SoundEnabled == true then PlaySound(145739) end
    end)
end

-- Function to resort the frames, if we remove one.
function ResortFrames()
    -- Loop through all the frames, and set their position starting at the top of the mainwindowbg.
    local numFrames = #WhoLootData.ChildFrames
    for frame in pairs(WhoLootData.ChildFrames) do
        WhoLootData.ChildFrames[frame][1]:SetPoint("TOPLEFT", 0, -20 - (frame - 1) * 34 - 5)
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
            -- Remove the frame from the ChildFrames table.
            for i, f in ipairs(WhoLootData.ChildFrames) do
                if f[1] == frame then
                    table.remove(WhoLootData.ChildFrames, i)
                end
            end
            self:Hide()
            self:SetScript("OnUpdate", nil)
            self = nil
            ResortFrames()
        end
    end)
end

-- Attach a looping function to the OnUpdate event of the main frame.
MainFrame:SetScript("OnUpdate", function(self, elapsed)
    for i, frame in ipairs(WhoLootData.ChildFrames) do
        local progressBar = frame[2]
        local timer = frame[3]
        if timer > 0 then
            timer = timer - elapsed
            progressBar:SetValue(timer)
            frame[3] = timer
        else
            FadeOutFrame(frame[1])
        end
    end
end)

-- Function to animate the scale of a frame.
function AnimateFrameScale(frame, targetScale, duration)
    local startTime = GetTime()
    local initialScale = 1.5
    local scaleChange = targetScale - initialScale

    frame:SetScript("OnUpdate", function(self, elapsed)
        local currentTime = GetTime()
        local progress = (currentTime - startTime) / duration

        local startColor = { r = 1, g = 1, b = 1}
        local endColor = { r = 0.15, g = 0.15, b = 0.15 }

        if progress >= 1 then
            frame:SetScale(targetScale)
            frame:SetBackdropColor(endColor.r, endColor.g, endColor.b, 1)
            frame:SetScript("OnUpdate", nil) -- Stop the animation
        else
            local newScale = initialScale + (scaleChange * progress)
            frame:SetScale(newScale)
            frame:SetBackdropColor(startColor.r + (endColor.r - startColor.r) * progress, startColor.g + (endColor.g - startColor.g) * progress, startColor.b + (endColor.b - startColor.b) * progress, 1)
        end
    end)
end


local backdrop = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 4,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Create the parent frame
MainFrame:SetSize(150, 25)
MainFrame:SetPoint("CENTER")
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
MainFrame:SetBackdrop(backdrop)
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

-- Create the child frame
local text = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("LEFT", 10, 0)
text:SetJustifyH("LEFT")
text:SetText("Who Got Loots")
text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
-- change font color
text:SetTextColor(1, 1, 1)

-- Ensure the child frame is properly anchored to the parent frame
text:SetParent(MainFrame)

-- Add a button to close the window
local closeBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -3, -5)
closeBtn:SetSize(15, 15)
closeBtn:SetScript("OnClick", function(self)
    MainFrame:Hide()
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
        WhoLootsOptionsFrame:SetPoint("TOPLEFT", MainFrame, "TOPRIGHT", 26, 0)
        WhoLootsOptionsFrame:SetScript("OnUpdate", function(self, elapsed)
            local alpha = self:GetAlpha()
            if alpha < 1 then
                local clamped = math.min(1, alpha + elapsed * 4)
                self:SetAlpha(clamped)
                self:SetPoint("TOPLEFT", MainFrame, "TOPRIGHT", (1 - clamped) * 26, 0)
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

-- Initially hide the frame
--MainFrame:Hide()

-- Define the slash commands
SLASH_WHOLOOT1 = "/wholoot"

-- Register the command handler
SlashCmdList["WHOLOOT"] = function(msg, editbox)
    if msg == "toggle" then
        if MainFrame:IsVisible() then
            MainFrame:Hide()
        else
            MainFrame:Show()
        end
        print("Frame has been " .. (MainFrame:IsVisible() and "shown" or "hidden") .. ".")
    elseif msg == "debug" then
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
            print("Invalid item ID.")
        end
    elseif msg:sub(1, 5) == "scale" then
        local scale = tonumber(msg:sub(7))
        if scale then
            MainFrame:SetScale(scale)
            WhoGotLootsSavedData.SavedSize = scale
        else
            print("Invalid scale.")
        end
    else
        print("Unknown command. Use '/wholoot toggle' or '/wholoot debug'.")
    end
end