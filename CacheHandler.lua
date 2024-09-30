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
    Finished = 3, -- The item has been received. This will only show if for some reason something broke with handling the item.
    Failed = 4    -- The inspect failed.
}
-- Create a debug frame that shows our cache requests.
CacheDebugFrame = CreateFrame("Frame", "WGLCacheDebugFrame", UIParent)
CacheDebugFrame:SetSize(300, 200)
CacheDebugFrame:SetPoint("TOPLEFT", 100, -100)
-- CacheDebugFrame:Hide()

CacheDebugFrame.BG = CacheDebugFrame:CreateTexture(nil, "BACKGROUND")
CacheDebugFrame.BG:SetAllPoints()
CacheDebugFrame.BG:SetColorTexture(0, 0, 0, 0.5)

CacheDebugFrame.Text = CacheDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CacheDebugFrame.Text:SetPoint("TOPLEFT", 10, -10)
CacheDebugFrame.Text:SetText("Cache Requests")
CacheDebugFrame.Text:SetJustifyH("LEFT")


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

        UpdateQueueDebugList()
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

local function GetLowestItemLink(unitName, slot1, slot2)
    local itemLink1 = GetInventoryItemLink(unitName, slot1)
    local itemLink2 = GetInventoryItemLink(unitName, slot2)

    if itemLink1 and itemLink2 then
        local itemLevel1 = C_Item.GetDetailedItemLevelInfo(itemLink1)
        local itemLevel2 = C_Item.GetDetailedItemLevelInfo(itemLink2)
        return itemLevel1 < itemLevel2 and itemLink1 or itemLink2
    end
    return nil
end

local function SetText(request, text)
    if not request.Frame then return end
    request.Frame.LoadingIcon:FadeOut()
    request.Frame.BottomText2:SetText(text)
end

local function HandleInspections(fromTimer)
    local keysToRemove = {}

    for ID, request in pairs(WGL_Request_Cache) do
        if request.QueryStage == WGLCacheCacheStage.Sent then
            if fromTimer then
                request.Time = request.Time + WGLCache_Frequency
            end

            -- Keep updating the unit name, in case people leave/join
            request.UnitName = WGLU.GetPlayerUnitByGUID(request.PlayerGUID)

            -- Attempt to get the item link.
            if request.UnitName and request.QueryStage ~= WGLCacheCacheStage.Finished then
                local itemLink
                if request.ItemLocation == INVSLOT_FINGER1 or request.ItemLocation == INVSLOT_FINGER2 then
                    itemLink = GetLowestItemLink(request.UnitName, INVSLOT_FINGER1, INVSLOT_FINGER2)
                elseif request.ItemLocation == INVSLOT_TRINKET1 or request.ItemLocation == INVSLOT_TRINKET2 then
                    itemLink = GetLowestItemLink(request.UnitName, INVSLOT_TRINKET1, INVSLOT_TRINKET2)
                else
                    itemLink = GetInventoryItemLink(request.UnitName, request.ItemLocation)
                end

                if itemLink then
                    table.insert(keysToRemove, ID)
                    request.QueryStage = WGLCacheCacheStage.Finished

                    local itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
                    local playerName = select(6, GetPlayerInfoByGUID(request.PlayerGUID))

                    if itemLevel < request.ItemLevel then
                        request.Frame.BottomText2:SetText("|cFFFFFFFFThem: |cFFe28743+" .. request.ItemLevel - itemLevel .. " ilvl upgrade for " .. playerName .. "|r")
                    else
                        if request.GoodForPlayer then
                            request.Frame.BottomText2:SetText("|cFFFFFFFFThem:|r |cFFb7d672" .. (itemLevel - request.ItemLevel) .. " ilvl downgrade")
                        else
                            request.Frame.BottomText2:SetText("|cFFFFFFFFThem:|r " .. (itemLevel - request.ItemLevel) .. " ilvl downgrade")
                        end
                    end
                    if request.TextString ~= "" then
                        request.Frame.BottomText2:SetText(request.Frame.BottomText2:GetText() .. ', ' .. request.TextString)
                    end

                    request.Frame.LoadingIcon:FadeOut()
                    UpdateQueueDebugList()
                end
            end

            if not request.UnitName and request.QueryStage == WGLCacheCacheStage.Finished then
                table.insert(keysToRemove, ID)
                SetText("Couldn't find player")
            end

            if request.UnitName and request.QueryStage == WGLCacheCacheStage.Finished then
                table.insert(keysToRemove, ID)
                SetText("Inspect timed out")
            end

            -- If we've been waiting for a while, then we'll retry the inspect.
            if request.Time > WGLCache_RetryTime and request.UnitName and request.QueryStage ~= WGLCacheCacheStage.Finished then
                if CanInspect(request.UnitName) then
                    WGLU.DebugPrint("Can inspect " .. request.UnitName)
                    request.Tries = request.Tries + 1
                    request.Time = 0

                    if request.Tries < WGLCache_MaxRetries then
                        NotifyInspect(request.UnitName)
                        WGLU.DebugPrint("Retrying inspect for " .. request.UnitName)
                    else
                        table.insert(keysToRemove, ID)
                        SetText("Inspect timed out.")
                        request.QueryStage = WGLCacheCacheStage.Failed
                        ClearInspectPlayer()
                    end
                else
                    WGLU.DebugPrint("Can't inspect " .. request.UnitName)
                end
            end
        end
    end

    UpdateQueueDebugList()
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

-- Maintain a second list of requests that we can use to debug the cache.
-- We want these to expire slower than the actual cache requests.
-- We'll update this list every 1 second.
WGL_Request_Debug_Cache = {}

function UpdateQueueDebugList()

    if WGLU.DebugMode then CacheDebugFrame:Show() else CacheDebugFrame:Hide() end
    if WGLU.DebugMode == false then return end

    -- Copy the cache requests to the debug cache, except time.
    for ID, request in pairs(WGL_Request_Cache) do
        if not WGL_Request_Debug_Cache[ID] then
            WGL_Request_Debug_Cache[ID] = {
                UnitName = UnitName(request.UnitName) or "Unknown",
                ItemLocation = request.ItemLocation,
                ItemLevel = request.ItemLevel,
                QueryStage = request.QueryStage,
                Time = 0
            }
        else
            WGL_Request_Debug_Cache[ID].UnitName = UnitName(request.UnitName)
            WGL_Request_Debug_Cache[ID].ItemLocation = request.ItemLocation
            WGL_Request_Debug_Cache[ID].ItemLevel = request.ItemLevel
            WGL_Request_Debug_Cache[ID].QueryStage = request.QueryStage
        end
    end

    CacheDebugFrame.Text:SetText("Cache Requests")
    local i = 1
    for ID, request in pairs(WGL_Request_Debug_Cache) do
        local text = "|cFFFFFFFFUnit:|r " .. request.UnitName .. ", |cFFFFFFFFItemLoc:|r " .. request.ItemLocation .. ", |cFFFFFFFFILevel:|r " .. request.ItemLevel
        local stageNames = {
            [WGLCacheCacheStage.Sent] = "Sent",
            [WGLCacheCacheStage.Queued] = "Queued",
            [WGLCacheCacheStage.Finished] = "Finished"
        }
        local stageName = stageNames[request.QueryStage] or "Unknown"
        text = text .. "\n - |cFFFFFFFFStage:|r " .. stageName
        CacheDebugFrame.Text:SetText(CacheDebugFrame.Text:GetText() .. "\n" .. text)
        i = i + 1

        request.Time = request.Time + WGLCache_Frequency
    end

    -- Remove any entries whose time is above 20 seconds.
    for ID, request in pairs(WGL_Request_Debug_Cache) do
        if request.Time > 60 then WGL_Request_Debug_Cache[ID] = nil end
    end

end

-- Register a timer to the frame, that will check for requests every 1 seconds.
CacheHandler:SetScript("OnUpdate", function(self, elapsed)
    self.TimeSinceLastUpdate = (self.TimeSinceLastUpdate or 0) + elapsed
    if self.TimeSinceLastUpdate > WGLCache_Frequency then
        self.TimeSinceLastUpdate = 0
        HandleInspections(true)

        UpdateQueueDebugList()
    end
end)
