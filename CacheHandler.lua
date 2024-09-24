-- Cache Variables.
WGLCache = {}
WGL_Request_Cache = {}
WGLCache_RetryTime = 2
WGLCache_MaxRetries = 5
WGLCache_Frequency = 0.5

WGLCacheCurrentQuery = nil
WGLCacheCacheStage = {
    Sent = 1,    -- Inspect has been sent, waiting for a response.
    Queued = 2,  -- Waiting for the previous query to finish.
    Finished = 3 -- The item has been received. This will only show if for some reason something broke with handling the item.
}

-- This is called when an item that another player is wearing hasn't been cached by the client.
-- We're going to add in the request data to the cache.
-- Each entry is basically an attempt to try GetInventoryItemLink until it no longer returns nil, then update the frame it was shown on.
function WGLCache.CreateRequest(unitName, request)

    local playerGUID = UnitGUID(unitName)
    if playerGUID then
        request.Time = 0
        request.Tries = 0
        request.UnitName = unitName
        request.PlayerGUID = playerGUID
        
        -- Generate a random ID
        local ID = math.floor(GetTime())
        
        -- Make sure we don't already have this ID.
        while WGL_Request_Cache[ID] do ID = ID + 1 end
        request.ID = ID

        -- Add the request to the cache.
        WGL_Request_Cache[ID] = request
        
        -- If we're not currently querying, then we can send the inspect request.
        if WGLCacheCurrentQuery == nil then
            WGLCacheCurrentQuery = request
            request.Frame.BottomText2:SetText("Inspecting ...")
            NotifyInspect(unitName)
            request.QueryStage = WGLCacheCacheStage.Sent
        else
            request.Frame.BottomText2:SetText("Inspection Queued")
            WGLU.DebugPrint("Can't queue now, waiting for " .. playerGUID)
            request.QueryStage = WGLCacheCacheStage.Queued
        end

        return ID
    end
end

local function PrepareNextQuery()
    WGLCacheCurrentQuery = nil
    for ID, request in pairs(WGL_Request_Cache) do
        if request.QueryStage == WGLCacheCacheStage.Queued then
            WGLCacheCurrentQuery = request
            NotifyInspect(request.UnitName)
            request.QueryStage = WGLCacheCacheStage.Sent
            break
        end
    end
end

function WGLCache.RemoveRequest(ID)
    if WGL_Request_Cache[ID] then WGL_Request_Cache[ID] = nil end

    -- If we've removed the current query, then we can prepare the next one.
    if WGLCacheCurrentQuery and WGLCacheCurrentQuery["ID"] == ID then
        PrepareNextQuery()
    end
end

local function HandleInspections(fromTimer)
    -- Create a list of keys to remove
    local keysToRemove = {}

    for ID, request in pairs(WGL_Request_Cache) do

        if request.QueryStage == WGLCacheCacheStage.Sent then

            -- Tick the timer for timeouts.
            if fromTimer then
                request.Time = request.Time + WGLCache_Frequency
            end

            -- Re-grab the unit name in case it's changed.
            request.UnitName = WGLU.GetPlayerUnitByGUID(request.PlayerGUID)

            -- If the request has timed out, then we'll remove it from the cache.
            if request.Time > WGLCache_RetryTime and request.UnitName then

                if CanInspect(request.UnitName) then
                    WGLU.DebugPrint("Can inspect " .. request.UnitName)
                    request.Tries = request.Tries + 1
                    request.Time = 0
    
                    -- If we've tried too many times, then we'll remove the request.
                    if request.Tries >= WGLCache_MaxRetries then
                        table.insert(keysToRemove, ID)
                        request.Frame.LoadingIcon:FadeOut()
                        request.Frame.BottomText2:SetText("Couldn't inspect")
                        request.QueryStage = WGLCacheCacheStage.Finished
                        ClearInspectPlayer()
                    else
                        NotifyInspect(request.UnitName)
                        request.Frame.BottomText2:SetText("Retrying")
                        WGLU.DebugPrint("Retrying inspect for " .. request.UnitName)
                    end
                else
                    WGLU.DebugPrint("Can't inspect " .. request.UnitName)
                end
            end

            -- Keep attempting to get the item link until it's found.
            if request.UnitName then

                -- If the requested item is a ring or trinket, then we need to copmare to the unit's lowest one.
                local isRing = request.ItemLocation == INVSLOT_FINGER1 or request.ItemLocation == INVSLOT_FINGER2
                local isTrinket = request.ItemLocation == INVSLOT_TRINKET1 or request.ItemLocation == INVSLOT_TRINKET2

                local ItemLink = nil
                local ItemLink1, ItemLink2 = nil, nil

                -- If it's a ring, then we need to find the lowest one.
                if isRing then
                    ItemLink1 = GetInventoryItemLink(request.UnitName, INVSLOT_FINGER1)
                    ItemLink2 = GetInventoryItemLink(request.UnitName, INVSLOT_FINGER2)

                    -- If both loaded, then we can compare.
                    if ItemLink1 and ItemLink2 then

                        -- Find which is lowest.
                        local itemLevel1 = C_Item.GetDetailedItemLevelInfo(ItemLink1)
                        local itemLevel2 = C_Item.GetDetailedItemLevelInfo(ItemLink2)

                        if itemLevel1 < itemLevel2 then
                            ItemLink = ItemLink1
                        else
                            ItemLink = ItemLink2
                        end
                    else
                        -- If only one loaded, then wait for the other.
                        return
                    end

                -- If it's a trinket, then we need to find the lowest one.
                elseif isTrinket then
                    ItemLink1 = GetInventoryItemLink(request.UnitName, INVSLOT_TRINKET1)
                    ItemLink2 = GetInventoryItemLink(request.UnitName, INVSLOT_TRINKET2)

                    -- If both loaded, then we can compare.
                    if ItemLink1 and ItemLink2 then

                        -- Find which is lowest.
                        local itemLevel1 = C_Item.GetDetailedItemLevelInfo(ItemLink1)
                        local itemLevel2 = C_Item.GetDetailedItemLevelInfo(ItemLink2)

                        if itemLevel1 < itemLevel2 then
                            ItemLink = ItemLink1
                        else
                            ItemLink = ItemLink2
                        end
                    else
                        -- If only one loaded, then wait for the other.
                        return
                    end

                -- Otherwise, just get the item in the same slot.
                else
                    ItemLink = GetInventoryItemLink(request.UnitName, request.ItemLocation)
                end

                if ItemLink then
                    table.insert(keysToRemove, ID)
                    request.QueryStage = WGLCacheCacheStage.Finished
                    PrepareNextQuery()

                    if InCombatLockdown() then WGLU.DebugPrint("Got item and was in combat") end

                    -- Was it an item level increase for this player?
                    local itemLevel = C_Item.GetDetailedItemLevelInfo(ItemLink)
                    local playerName = select(6, GetPlayerInfoByGUID(request.PlayerGUID))

                    if itemLevel < request.ItemLevel then
                        request.Frame.BottomText2:SetText("|cFFe28743+" .. request.ItemLevel - itemLevel  .. " ilvl upgrade for " .. playerName .. "|r")
                    else
                        request.Frame.BottomText2:SetText("Them: |cFF00FF00[Tradeable]|r " .. (itemLevel - request.ItemLevel) .. " ilvl downgrade")
                    end
                    if request.TextString ~= "" then
                        request.Frame.BottomText2:SetText(request.Frame.BottomText2:GetText() .. ', ' .. request.TextString)
                    end

                    request.Frame.LoadingIcon:FadeOut()
                end
            else
                request.Frame.LoadingIcon:FadeOut()
                request.Frame.BottomText2:SetText("Couldn't find player")
                WGLU.DebugPrint("No unit name found for GUID: " .. request.PlayerGUID)
            end
        end
    end

    -- Remove the keys marked for removal and start the next request
    for _, ID in ipairs(keysToRemove) do
        WGLCache.RemoveRequest(ID)
    end
end


-- Create a frame that handles the GET_ITEM_INFO_RECEIVED event.
-- This event is fired when the client receives information about an item from the server.
-- We'll use this event to update the item frame's bottom text with the item's stats.
local CacheHandler = CreateFrame("Frame")
CacheHandler:RegisterEvent("INSPECT_READY")

CacheHandler:SetScript("OnEvent", function(self, event, ...)
    if event == "INSPECT_READY" then
        HandleInspections(false)
    end
end)

-- Register a timer to the frame, that will check for requests every 1 seconds.
CacheHandler:SetScript("OnUpdate", function(self, elapsed)
    self.TimeSinceLastUpdate = (self.TimeSinceLastUpdate or 0) + elapsed
    if self.TimeSinceLastUpdate > WGLCache_Frequency then
        self.TimeSinceLastUpdate = 0
        HandleInspections(true)
    end
end)