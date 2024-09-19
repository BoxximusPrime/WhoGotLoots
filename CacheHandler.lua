-- Cache Variables.
WGLCache = {}
WGL_Request_Cache = {}
WGLCache_Timeout = 3
WGLCache_Frequency = 0.5

-- This is called when an item that another player is wearing hasn't been cached by the client.
-- We're going to add in the request data to the cache.
-- Each entry is basically an attempt to try GetInventoryItemLink until it no longer returns nil, then update the frame it was shown on.
function WGLCache.CreateRequest(playerGUID, request)

    WGLU.DebugPrint("Requesting item for " .. playerGUID)

    if playerGUID then
        request["Time"] = 0
        WGL_Request_Cache[playerGUID] = request
    end
end

local function HandleItemRecieved()

    -- We recieved a response from the server, re-try all the queued requests we have.
    for playerGUID, request in pairs(WGL_Request_Cache) do

        if request then

            request["Time"] = request["Time"] + WGLCache_Frequency

            -- Convert the playerGUID into a unit token.
            local unitName = WGLU.GetPlayerUnitByGUID(playerGUID)
            if unitName then

                local itemLink = GetInventoryItemLink(unitName, request["ItemLocation"])
                if itemLink then

                    -- Was it an item level increase for this player?
                    local itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
                    local playerName = select(6, GetPlayerInfoByGUID(playerGUID))

                    if itemLevel < request["ItemLevel"] then
                        request["Frame"].BottomText2:SetText("|cFFe28743+" .. request["ItemLevel"] - itemLevel  .. " ilvl upgrade for " .. playerName .. "|r")
                    else
                        request["Frame"].BottomText2:SetText("Them: " .. (itemLevel - request["ItemLevel"]) .. " ilvl downgrade |cFF00FF00[Tradeable]|r")
                    end
                    if request["TextString"] ~= "" then
                        request["Frame"].BottomText2:SetText(request["Frame"].BottomText2:GetText() .. ', ' .. request["TextString"])
                    end

                    request["Frame"].LoadingIcon:FadeOut()

                    -- Remove the request from the cache.
                    WGL_Request_Cache[playerGUID] = nil
                else
                    -- Has this request gone on too long?
                    if request["Time"] > WGLCache_Timeout then
                        request["Frame"].BottomText2:SetText(request["TextString"])
                        request["Frame"].LoadingIcon:FadeOut()
                        WGLU.DebugPrint("Request for " .. playerGUID .. " has timed out.")
                        WGL_Request_Cache[playerGUID] = nil
                    end
                end
            else
                WGLU.DebugPrint("Player not found for " .. playerGUID)
                WGL_Request_Cache[playerGUID] = nil
            end
        end
    end
end

-- Create a frame that handles the GET_ITEM_INFO_RECEIVED event.
-- This event is fired when the client receives information about an item from the server.
-- We'll use this event to update the item frame's bottom text with the item's stats.
local CacheHandler = CreateFrame("Frame")
CacheHandler:RegisterEvent("ITEM_DATA_LOAD_RESULT")

CacheHandler:SetScript("OnEvent", function(self, event, ...)
    if event == "ITEM_DATA_LOAD_RESULT" then
        HandleItemRecieved()
    end
end)

-- Register a timer to the frame, that will check for requests every 1 seconds.
CacheHandler:SetScript("OnUpdate", function(self, elapsed)
    self.TimeSinceLastUpdate = (self.TimeSinceLastUpdate or 0) + elapsed
    if self.TimeSinceLastUpdate > WGLCache_Frequency then
        self.TimeSinceLastUpdate = 0
        HandleItemRecieved()
    end
end)