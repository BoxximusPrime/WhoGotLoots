-- Inspection broker.
--
-- WoW only exposes another player's equipped items after an inspection. This broker
-- serializes and throttles those requests, lets temporarily unavailable players wait
-- without blocking the rest of the queue, and fans one equipment snapshot out to
-- every pending loot comparison for that player.

WGLCache = {
    Queue = {},
    ActiveJob = nil,
    EquipmentCache = {},
    NextRequestID = 1,
    NextJobID = 1,
    LastNotifyInspectTime = -math.huge,
    SendingNotifyInspect = false,
}

WGL_Request_Cache = {}
WGLCache_Frequency = 0.2
WGLCache_NotifyInterval = 2
WGLCache_ResponseTimeout = 2.5
WGLCache_ReadTimeout = 1.5
WGLCache_IdentityTimeout = 10
WGLCache_RangeTimeout = 25
WGLCache_CacheLifetime = 600
WGLCache_GroupRefreshInterval = 60
WGLCache_MaxAttempts = 2

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function HasValue(value)
    if IsSecret(value) then return true end
    return value ~= nil
end

local function SafeEquals(left, right)
    if IsSecret(left) or IsSecret(right) then return false end
    if left == nil or right == nil then return false end
    return left == right
end

local function SafeUnitIsUnit(left, right)
    if IsSecret(left) or IsSecret(right) then return false end
    if not left or not right then return false end

    local sameUnit = UnitIsUnit(left, right)
    return not IsSecret(sameUnit) and sameUnit == true
end

local function SafeDebugName(value)
    if IsSecret(value) then return "Restricted" end
    if value == nil then return "Restricted" end
    return tostring(value)
end

local function IsRequestActive(request)
    if request and request.IsActive then
        return not request.Cancelled and request.IsActive(request)
    end

    return request and
        not request.Cancelled and
        request.Frame and
        request.Frame.InUse and
        request.Frame.QueuedRequest == request.ID and
        request.Frame.Generation == request.FrameGeneration
end

local function SameIdentity(record, unitToken, playerGUID, playerName)
    if record.PlayerGUID and playerGUID and
        not IsSecret(record.PlayerGUID) and not IsSecret(playerGUID) then
        return SafeEquals(record.PlayerGUID, playerGUID)
    end
    if record.PlayerName and playerName and
        not IsSecret(record.PlayerName) and not IsSecret(playerName) then
        return SafeEquals(record.PlayerName, playerName)
    end
    return SafeUnitIsUnit(record.UnitToken, unitToken)
end

local function GetSafeUnitIdentity(unitToken)
    if not unitToken or not UnitExists(unitToken) then return nil, nil end

    local playerGUID = UnitGUID(unitToken)
    if IsSecret(playerGUID) then playerGUID = nil end

    local name, realm = UnitFullName(unitToken)
    if IsSecret(name) or IsSecret(realm) then return playerGUID, nil end
    if name and realm and realm ~= "" then
        return playerGUID, name .. "-" .. realm:gsub("%s+", "")
    end
    return playerGUID, name
end

local function UnitMatchesIdentity(unitToken, playerGUID, playerName)
    if not unitToken or not UnitExists(unitToken) then return false end

    local currentGUID, currentName = GetSafeUnitIdentity(unitToken)
    if playerGUID and not IsSecret(playerGUID) and currentGUID then
        return SafeEquals(playerGUID, currentGUID)
    end
    if playerName and currentName then return SafeEquals(playerName, currentName) end
    return not playerGUID and not playerName
end

local function PruneRequests(job)
    local activeRequests = {}

    for _, request in ipairs(job.Requests) do
        if IsRequestActive(request) then
            activeRequests[#activeRequests + 1] = request
        else
            request.Cancelled = true
            WGL_Request_Cache[request.ID] = nil
        end
    end

    job.Requests = activeRequests
    return #activeRequests > 0
end

local function ResolveUnit(job)
    if not IsSecret(job.UnitToken) and UnitMatchesIdentity(job.UnitToken, job.PlayerGUID, job.PlayerName) then
        return job.UnitToken
    end

    if HasValue(job.PlayerGUID) then
        local resolvedUnit = UnitTokenFromGUID(job.PlayerGUID)
        if not IsSecret(resolvedUnit) and resolvedUnit and UnitExists(resolvedUnit) then
            job.UnitToken = resolvedUnit
            return resolvedUnit
        end
    end

    if not IsSecret(job.PlayerName) and job.PlayerName and UnitExists(job.PlayerName) then
        job.UnitToken = job.PlayerName
        return job.PlayerName
    end

    local resolvedByName = WGLU.GetPlayerUnitByName(job.PlayerName)
    if resolvedByName then
        job.UnitToken = resolvedByName
        return resolvedByName
    end

    return nil
end

local DualWieldSpecializations = {
    [72] = true,
    [251] = true,
    [259] = true,
    [260] = true,
    [261] = true,
    [263] = true,
    [268] = true,
    [269] = true,
    [577] = true,
    [581] = true,
}

local function ShouldCompareBothWeaponSlots(request, snapshot)
    local specID = snapshot and snapshot.SpecID
    if not specID or not DualWieldSpecializations[specID] then return false end
    if request.ItemEquipLoc == "INVTYPE_WEAPON" then return true end
    return request.ItemEquipLoc == "INVTYPE_2HWEAPON" and specID == 72
end

local function GetComparisonSlots(request, snapshot)
    local itemLocation = request.ItemLocation
    if itemLocation == INVSLOT_FINGER1 or itemLocation == INVSLOT_FINGER2 then
        return INVSLOT_FINGER1, INVSLOT_FINGER2
    elseif itemLocation == INVSLOT_TRINKET1 or itemLocation == INVSLOT_TRINKET2 then
        return INVSLOT_TRINKET1, INVSLOT_TRINKET2
    elseif ShouldCompareBothWeaponSlots(request, snapshot) then
        return INVSLOT_MAINHAND, INVSLOT_OFFHAND
    end

    return itemLocation, nil
end

local function GetInspectedItemLevel(unitToken, slot)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return nil end

    local tooltipData = C_TooltipInfo.GetInventoryItem(unitToken, slot)
    if not tooltipData then return nil end

    local itemLevelLineType = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemLevel or 31
    for _, line in ipairs(tooltipData.lines or {}) do
        if line.type == itemLevelLineType and not IsSecret(line.leftText) and type(line.leftText) == "string" then
            local text = line.leftText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local itemLevel = tonumber(text:match("(%d+)") or "")
            if itemLevel and itemLevel > 0 then return itemLevel end
        end
    end

    local overrideItemLevel = tooltipData.overrideItemLevel
    if not IsSecret(overrideItemLevel) and type(overrideItemLevel) == "number" and overrideItemLevel > 0 then
        return overrideItemLevel
    end

    return nil
end

local function CaptureEquipment(unitToken)
    local specID = GetInspectSpecialization and GetInspectSpecialization(unitToken) or nil
    if IsSecret(specID) or not specID or specID <= 0 then specID = nil end

    local snapshot = {
        Slots = {},
        InspectedAt = GetTime(),
        SpecID = specID,
    }

    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemLink = GetInventoryItemLink(unitToken, slot)
        local itemLevel = 0

        if itemLink then
            -- An inspected player's hyperlink can expose an unscaled/base item
            -- level. The unit-and-slot tooltip contains the effective value that
            -- Blizzard actually displays for that player.
            itemLevel = GetInspectedItemLevel(unitToken, slot)

            local linkItemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
            if itemLevel and itemLevel > 0 and linkItemLevel and linkItemLevel ~= itemLevel then
                WGLU.DebugPrint(
                    "Scaled inspected slot " .. slot .. " for " .. SafeDebugName(unitToken) ..
                    ": tooltip " .. itemLevel .. ", hyperlink " .. linkItemLevel
                )
            end
        end

        snapshot.Slots[slot] = {
            ItemLink = itemLink or false,
            ItemLevel = itemLevel,
        }
    end

    return snapshot
end

local function SnapshotHasImmediateData(snapshot, requests)
    for _, request in ipairs(requests) do
        if request.WarmOnly then return false end
        local firstSlot, secondSlot = GetComparisonSlots(request, snapshot)
        local firstSlotData = snapshot.Slots[firstSlot]
        local secondSlotData = secondSlot and snapshot.Slots[secondSlot] or nil
        if request.RequireSpec and not snapshot.SpecID then return false end
        if not firstSlotData or firstSlotData.ItemLink == false then return false end
        if secondSlot and (not secondSlotData or secondSlotData.ItemLink == false) then return false end
    end

    return true
end

local function SnapshotHasRequestedEquipment(snapshot, requests)
    local hasComparisonRequest = false

    for _, request in ipairs(requests) do
        if not request.WarmOnly then
            hasComparisonRequest = true
            local firstSlot, secondSlot = GetComparisonSlots(request, snapshot)
            local firstSlotData = snapshot.Slots[firstSlot]
            local secondSlotData = secondSlot and snapshot.Slots[secondSlot] or nil

            if request.RequireSpec and not snapshot.SpecID then return false end
            if not firstSlotData or type(firstSlotData.ItemLevel) ~= "number" or firstSlotData.ItemLevel < 0 then
                return false
            end
            if secondSlot and
                (not secondSlotData or type(secondSlotData.ItemLevel) ~= "number" or
                    secondSlotData.ItemLevel < 0) then
                return false
            end
        end
    end

    return hasComparisonRequest
end

local function SnapshotHasAnyEquipment(snapshot)
    for _, slotData in pairs(snapshot.Slots) do
        if slotData.ItemLink ~= false and slotData.ItemLevel and slotData.ItemLevel > 0 then
            return true
        end
    end

    return false
end

local function SnapshotReadyAfterInspect(snapshot, requests)
    local hasComparisonRequest = false
    for _, request in ipairs(requests) do
        if not request.WarmOnly then
            hasComparisonRequest = true
            break
        end
    end

    if hasComparisonRequest then
        return SnapshotHasRequestedEquipment(snapshot, requests)
    end

    return SnapshotHasAnyEquipment(snapshot)
end

local function GetComparisonItemLevel(snapshot, request)
    local firstSlot, secondSlot = GetComparisonSlots(request, snapshot)
    local firstSlotData = snapshot.Slots[firstSlot]
    if not firstSlotData or type(firstSlotData.ItemLevel) ~= "number" or firstSlotData.ItemLevel < 0 then
        return nil
    end
    local firstLevel = firstSlotData.ItemLevel

    if not secondSlot then return firstLevel end

    local secondSlotData = snapshot.Slots[secondSlot]
    if not secondSlotData or type(secondSlotData.ItemLevel) ~= "number" or secondSlotData.ItemLevel < 0 then
        return nil
    end
    local secondLevel = secondSlotData.ItemLevel
    return math.min(firstLevel, secondLevel)
end

local function FindCachedEquipment(job)
    local now = GetTime()

    for index = #WGLCache.EquipmentCache, 1, -1 do
        local record = WGLCache.EquipmentCache[index]
        if now - record.Snapshot.InspectedAt > WGLCache_CacheLifetime then
            table.remove(WGLCache.EquipmentCache, index)
        elseif SameIdentity(record, job.UnitToken, job.PlayerGUID, job.PlayerName) then
            return record.Snapshot
        end
    end

    return nil
end

local function StoreCachedEquipment(job, snapshot)
    for index = #WGLCache.EquipmentCache, 1, -1 do
        local record = WGLCache.EquipmentCache[index]
        if SameIdentity(record, job.UnitToken, job.PlayerGUID, job.PlayerName) then
            table.remove(WGLCache.EquipmentCache, index)
        end
    end

    WGLCache.EquipmentCache[#WGLCache.EquipmentCache + 1] = {
        UnitToken = job.UnitToken,
        PlayerGUID = job.PlayerGUID,
        PlayerName = job.PlayerName,
        Snapshot = snapshot,
    }
end

local function FinishRequest(request, theirItemLevel, specID)
    if not IsRequestActive(request) then return end

    local debugDelta = WGLUIBuilder.GetItemLevelDelta(request.ItemLevel, theirItemLevel)
    WGLU.DebugPrint(
        "Inspection comparison for " .. SafeDebugName(request.PlayerName or request.UnitName) ..
        ": dropped " .. SafeDebugName(request.ItemLevel) ..
        " - equipped " .. SafeDebugName(theirItemLevel) ..
        " = " .. SafeDebugName(debugDelta)
    )

    if request.OnComplete then
        request.Status = "Finished"
        local ok, errorMessage = pcall(request.OnComplete, request, theirItemLevel, specID)
        WGL_Request_Cache[request.ID] = nil
        if not ok then geterrorhandler()(errorMessage) end
        return
    end

    local upgradeText, isUpgradeForThem =
        WhoLootData.MainFrame:CompareItemLevels(request.ItemLevel, theirItemLevel)
    local resultText

    WhoLootData.MainFrame:SetItemUpgradeStatus(request, theirItemLevel)

    if isUpgradeForThem then
        resultText = "|cFFFFFFFFThem: |cFFe28743" .. upgradeText .. "|r"
    elseif request.GoodForPlayer then
        resultText = "|cFFFFFFFFThem:|r |cFFb7d672" .. upgradeText
    else
        resultText = "|cFFFFFFFFThem:|r " .. upgradeText
    end

    if request.FailureFrame then
        WGLUIBuilder.HideStatFrame(request.Frame, request.FailureFrame, "primary")
    end

    if request.RetryFrame then
        request.RetryFrame:EnableMouse(false)
        request.RetryFrame:SetScript("OnMouseDown", nil)
        request.RetryFrame:SetScript("OnEnter", nil)
        request.RetryFrame:SetScript("OnLeave", nil)
        WGLUIBuilder.SetStatFrameText(request.Frame, request.RetryFrame, resultText, "primary")
    else
        WGLUIBuilder.AddStatToBreakdown(
            request.Frame,
            resultText,
            "prepend",
            nil,
            2,
            "primary"
        )
    end

    request.Status = "Finished"
    request.Frame.LoadingIcon:FadeOut()
    request.Frame.QueuedRequest = nil
    WGL_Request_Cache[request.ID] = nil
end

local function FailRequest(request, reason)
    if not IsRequestActive(request) then return end

    request.Status = reason

    if request.OnFailure then
        local ok, errorMessage = pcall(request.OnFailure, request, reason)
        WGL_Request_Cache[request.ID] = nil
        if not ok then geterrorhandler()(errorMessage) end
        return
    end

    request.Frame:HideUpgradeGlow()
    request.Frame.LoadingIcon:FadeOut()

    local failureText = "|cFFFFFFFFThem:|r |cFF9D9D9D" .. reason .. "|r"
    if request.FailureFrame then
        WGLUIBuilder.SetStatFrameText(request.Frame, request.FailureFrame, failureText, "primary")
    else
        request.FailureFrame = WGLUIBuilder.AddStatToBreakdown(
            request.Frame,
            failureText,
            "prepend",
            nil,
            2,
            "primary"
        )
    end

    if request.RetryFrame then
        WGLUIBuilder.SetStatFrameText(request.Frame, request.RetryFrame, "Try Inspect", "primary")
    else
        request.RetryFrame = WGLUIBuilder.AddStatToBreakdown(
            request.Frame,
            "Try Inspect",
            "prepend",
            nil,
            3,
            "primary"
        )
    end

    request.RetryFrame:EnableMouse(true)
    request.RetryFrame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then WGLCache.RetryRequest(request) end
    end)
    request.RetryFrame:SetScript("OnEnter", function(self)
        WGLUIBuilder.ColorBGSlicedFrame(self, "backdrop", 1, 1, 1, 0.2)
    end)
    request.RetryFrame:SetScript("OnLeave", function(self)
        WGLUIBuilder.ColorBGSlicedFrame(self, "backdrop", 1, 1, 1, 0.1)
    end)

    request.Frame.QueuedRequest = nil
    WGL_Request_Cache[request.ID] = nil
end

local function CompleteJob(job, snapshot)
    StoreCachedEquipment(job, snapshot)

    for _, request in ipairs(job.Requests) do
        local comparisonItemLevel = request.WarmOnly and nil or
            GetComparisonItemLevel(snapshot, request)
        FinishRequest(request, comparisonItemLevel, snapshot.SpecID)
    end

    job.State = "Finished"
end

local function FailJob(job, reason)
    for _, request in ipairs(job.Requests) do
        FailRequest(request, reason)
    end

    job.State = "Failed"
end

local function ReleaseActiveJob(clearInspect)
    if clearInspect then ClearInspectPlayer() end
    WGLCache.ActiveJob = nil
end

local function FindPendingJob(unitToken, playerGUID, playerName)
    local activeJob = WGLCache.ActiveJob
    if activeJob and SameIdentity(activeJob, unitToken, playerGUID, playerName) then
        return activeJob
    end

    for _, job in ipairs(WGLCache.Queue) do
        if SameIdentity(job, unitToken, playerGUID, playerName) then
            return job
        end
    end

    return nil
end

function WGLCache.CreateRequest(unitToken, request, playerGUID, playerName)
    request.ID = WGLCache.NextRequestID
    WGLCache.NextRequestID = WGLCache.NextRequestID + 1

    request.UnitName = unitToken
    if IsSecret(playerGUID) then
        request.PlayerGUID = playerGUID
    else
        request.PlayerGUID = playerGUID or UnitGUID(unitToken)
    end
    request.PlayerName = playerName or unitToken
    request.FrameGeneration = request.Frame and request.Frame.Generation or 0
    request.CreatedAt = GetTime()
    request.Status = "Queued"

    WGL_Request_Cache[request.ID] = request

    local job = FindPendingJob(unitToken, request.PlayerGUID, request.PlayerName)
    if not job then
        job = {
            ID = WGLCache.NextJobID,
            UnitToken = unitToken,
            PlayerGUID = request.PlayerGUID,
            PlayerName = request.PlayerName,
            Requests = {},
            State = "Queued",
            CreatedAt = GetTime(),
            NextAttemptAt = 0,
            Attempts = 0,
        }
        WGLCache.NextJobID = WGLCache.NextJobID + 1
        WGLCache.Queue[#WGLCache.Queue + 1] = job
    end

    job.Requests[#job.Requests + 1] = request
    return request.ID
end

function WGLCache.InvalidateEquipment(unitToken, playerGUID, playerName)
    for index = #WGLCache.EquipmentCache, 1, -1 do
        if SameIdentity(WGLCache.EquipmentCache[index], unitToken, playerGUID, playerName) then
            table.remove(WGLCache.EquipmentCache, index)
        end
    end
end

function WGLCache.WarmUnit(unitToken)
    if not unitToken or not UnitExists(unitToken) or SafeUnitIsUnit(unitToken, "player") then return nil end

    local playerGUID, playerName = GetSafeUnitIdentity(unitToken)
    if not playerGUID and not playerName then return nil end

    local identity = {
        UnitToken = unitToken,
        PlayerGUID = playerGUID,
        PlayerName = playerName,
    }
    if FindCachedEquipment(identity) then return nil end

    local pendingJob = FindPendingJob(unitToken, playerGUID, playerName)
    if pendingJob then
        for _, pendingRequest in ipairs(pendingJob.Requests) do
            if pendingRequest.WarmOnly and IsRequestActive(pendingRequest) then return nil end
        end
    end

    local request = {
        WarmOnly = true,
        IsActive = function()
            return IsInGroup() and UnitMatchesIdentity(unitToken, playerGUID, playerName)
        end,
        OnComplete = function() end,
        OnFailure = function() end,
    }

    return WGLCache.CreateRequest(unitToken, request, playerGUID, playerName)
end

function WGLCache.QueueGroupWarmups()
    if not IsInGroup() then return end

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            WGLCache.WarmUnit("raid" .. index)
        end
    else
        for index = 1, GetNumSubgroupMembers() do
            WGLCache.WarmUnit("party" .. index)
        end
    end
end

function WGLCache.CancelRequest(requestID)
    local request = requestID and WGL_Request_Cache[requestID]
    if not request then return end

    request.Cancelled = true
    request.Status = "Cancelled"
    WGL_Request_Cache[requestID] = nil
end

WGLCache.RemoveRequest = WGLCache.CancelRequest

function WGLCache.RetryRequest(request)
    if not request or
        not request.Frame or
        not request.Frame.InUse or
        request.Frame.Generation ~= request.FrameGeneration then
        return
    end

    if request.FailureFrame then
        WGLUIBuilder.HideStatFrame(request.Frame, request.FailureFrame, "primary")
    end
    if request.RetryFrame then
        request.RetryFrame:EnableMouse(false)
        request.RetryFrame:SetScript("OnMouseDown", nil)
        request.RetryFrame:SetScript("OnEnter", nil)
        request.RetryFrame:SetScript("OnLeave", nil)
        WGLUIBuilder.SetStatFrameText(request.Frame, request.RetryFrame, "Inspecting...", "primary")
    end

    request.Cancelled = false
    request.Frame.LoadingIcon:Unhide()
    request.Frame.QueuedRequest = WGLCache.CreateRequest(
        request.UnitName,
        request,
        request.PlayerGUID,
        request.PlayerName
    )
end

local function TryStartNextJob()
    if WGLCache.ActiveJob or #WGLCache.Queue == 0 then return end

    local now = GetTime()
    local jobsToCheck = #WGLCache.Queue

    for _ = 1, jobsToCheck do
        local job = table.remove(WGLCache.Queue, 1)

        if PruneRequests(job) then
            if now < job.NextAttemptAt then
                WGLCache.Queue[#WGLCache.Queue + 1] = job
            else
                local cachedSnapshot = FindCachedEquipment(job)
                if cachedSnapshot and SnapshotHasRequestedEquipment(cachedSnapshot, job.Requests) then
                    CompleteJob(job, cachedSnapshot)
                    return
                end

                local unitToken = ResolveUnit(job)
                if not unitToken then
                    if now - job.CreatedAt >= WGLCache_IdentityTimeout then
                        FailJob(job, "Player unavailable")
                    else
                        job.State = "Waiting for player"
                        job.NextAttemptAt = now + 1
                        WGLCache.Queue[#WGLCache.Queue + 1] = job
                    end
                else
                    local immediateSnapshot = CaptureEquipment(unitToken)
                    if immediateSnapshot and SnapshotHasImmediateData(immediateSnapshot, job.Requests) then
                        CompleteJob(job, immediateSnapshot)
                        return
                    end

                    if not CanInspect(unitToken) then
                        if now - job.CreatedAt >= WGLCache_RangeTimeout then
                            FailJob(job, "Out of inspect range")
                        else
                            job.State = "Waiting for range"
                            job.NextAttemptAt = now + 1
                            WGLCache.Queue[#WGLCache.Queue + 1] = job
                        end
                    elseif now - WGLCache.LastNotifyInspectTime < WGLCache_NotifyInterval then
                        table.insert(WGLCache.Queue, 1, job)
                        return
                    else
                        job.State = "Waiting for inspect data"
                        job.Attempts = job.Attempts + 1
                        job.ResponseDeadline = now + WGLCache_ResponseTimeout
                        WGLCache.ActiveJob = job

                        WGLCache.SendingNotifyInspect = true
                        NotifyInspect(unitToken)
                        WGLCache.SendingNotifyInspect = false
                        WGLCache.LastNotifyInspectTime = GetTime()
                        return
                    end
                end
            end
        end
    end
end

local function RetryOrFailActiveJob(reason)
    local job = WGLCache.ActiveJob
    if not job then return end

    ReleaseActiveJob(true)

    if job.Attempts < WGLCache_MaxAttempts and GetTime() - job.CreatedAt < WGLCache_RangeTimeout then
        job.State = "Queued for retry"
        job.NextAttemptAt = GetTime() + 1
        WGLCache.Queue[#WGLCache.Queue + 1] = job
    else
        FailJob(job, reason)
    end
end

local GroupWarmupGeneration = 0
local InventoryRefreshGeneration = {}

local function QueueGroupWarmupsDelayed()
    GroupWarmupGeneration = GroupWarmupGeneration + 1
    local generation = GroupWarmupGeneration
    -- Unit tokens and inspectability can settle at different times after joining
    -- or changing groups. These calls are cheap because WarmUnit deduplicates
    -- cached and already-queued members.
    for _, delay in ipairs({ 0.5, 2, 5 }) do
        C_Timer.After(delay, function()
            if generation == GroupWarmupGeneration then WGLCache.QueueGroupWarmups() end
        end)
    end
end

local function QueueInventoryRefresh(unitToken, playerGUID, playerName)
    InventoryRefreshGeneration[unitToken] = (InventoryRefreshGeneration[unitToken] or 0) + 1
    local generation = InventoryRefreshGeneration[unitToken]
    C_Timer.After(0.5, function()
        if InventoryRefreshGeneration[unitToken] ~= generation then return end
        if UnitMatchesIdentity(unitToken, playerGUID, playerName) then
            WGLCache.WarmUnit(unitToken)
        end
    end)
end

local function IsRecentOrActiveInspection(unitToken, playerGUID, playerName)
    if WGLCache.ActiveJob and
        SameIdentity(WGLCache.ActiveJob, unitToken, playerGUID, playerName) then
        return true
    end

    local now = GetTime()
    for _, record in ipairs(WGLCache.EquipmentCache) do
        if SameIdentity(record, unitToken, playerGUID, playerName) and
            now - record.Snapshot.InspectedAt < 2 then
            return true
        end
    end

    return false
end

local CacheHandler = CreateFrame("Frame")
CacheHandler:RegisterEvent("INSPECT_READY")
CacheHandler:RegisterEvent("GROUP_ROSTER_UPDATE")
CacheHandler:RegisterEvent("PLAYER_ENTERING_WORLD")
CacheHandler:RegisterEvent("UNIT_INVENTORY_CHANGED")

CacheHandler:SetScript("OnEvent", function(_, event, eventArg)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        QueueGroupWarmupsDelayed()
        return
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unitToken = eventArg
        if IsSecret(unitToken) or type(unitToken) ~= "string" or
            not (unitToken:match("^party%d+$") or unitToken:match("^raid%d+$")) then
            return
        end

        local playerGUID, playerName = GetSafeUnitIdentity(unitToken)
        if not playerGUID and not playerName then return end
        if IsRecentOrActiveInspection(unitToken, playerGUID, playerName) then return end

        WGLCache.InvalidateEquipment(unitToken, playerGUID, playerName)
        QueueInventoryRefresh(unitToken, playerGUID, playerName)
        return
    elseif event ~= "INSPECT_READY" then
        return
    end

    local inspecteeGUID = eventArg

    local job = WGLCache.ActiveJob
    if not job or job.State ~= "Waiting for inspect data" then return end

    if inspecteeGUID and job.PlayerGUID and
        not IsSecret(inspecteeGUID) and not IsSecret(job.PlayerGUID) and
        not SafeEquals(inspecteeGUID, job.PlayerGUID) then
        return
    end

    local inspecteeUnit = HasValue(inspecteeGUID) and UnitTokenFromGUID(inspecteeGUID) or nil
    if not IsSecret(inspecteeUnit) and inspecteeUnit and not IsSecret(job.UnitToken) and job.UnitToken then
        local sameUnit = UnitIsUnit(inspecteeUnit, job.UnitToken)
        if not IsSecret(sameUnit) and not sameUnit then return end
    end

    job.State = "Reading equipment"
    job.ReadAt = GetTime() + 0.15
    job.ReadDeadline = GetTime() + WGLCache_ReadTimeout
end)

hooksecurefunc("NotifyInspect", function()
    WGLCache.LastNotifyInspectTime = GetTime()

    if WGLCache.SendingNotifyInspect or not WGLCache.ActiveJob then return end

    local preemptedJob = WGLCache.ActiveJob
    WGLCache.ActiveJob = nil
    preemptedJob.State = "Preempted by another inspection"
    preemptedJob.NextAttemptAt = GetTime() + WGLCache_NotifyInterval
    table.insert(WGLCache.Queue, 1, preemptedJob)
end)

CacheHandler:SetScript("OnUpdate", function(self, elapsed)
    self.TimeSinceLastUpdate = (self.TimeSinceLastUpdate or 0) + elapsed
    if self.TimeSinceLastUpdate < WGLCache_Frequency then return end
    self.TimeSinceLastUpdate = 0

    local job = WGLCache.ActiveJob
    if job then
        if not PruneRequests(job) then
            ReleaseActiveJob(true)
        elseif job.State == "Waiting for inspect data" and GetTime() >= job.ResponseDeadline then
            RetryOrFailActiveJob("Inspection timed out")
        elseif job.State == "Reading equipment" and GetTime() >= job.ReadAt then
            local unitToken = ResolveUnit(job)
            local snapshot = unitToken and CaptureEquipment(unitToken)

            if snapshot and SnapshotReadyAfterInspect(snapshot, job.Requests) then
                CompleteJob(job, snapshot)
                ReleaseActiveJob(true)
            elseif GetTime() >= job.ReadDeadline then
                RetryOrFailActiveJob("Equipment unavailable")
            end
        end
    end

    TryStartNextJob()

    local now = GetTime()
    if not self.NextGroupRefreshAt then
        self.NextGroupRefreshAt = now + WGLCache_GroupRefreshInterval
    elseif now >= self.NextGroupRefreshAt then
        self.NextGroupRefreshAt = now + WGLCache_GroupRefreshInterval
        WGLCache.QueueGroupWarmups()
    end

    UpdateQueueDebugList()
end)

-- Debug frame shown by /wgl debug.
CacheDebugFrame = CreateFrame("Frame", "WGLCacheDebugFrame", UIParent)
CacheDebugFrame:SetSize(360, 220)
CacheDebugFrame:SetPoint("TOPLEFT", 100, -100)
CacheDebugFrame:Hide()

CacheDebugFrame.BG = CacheDebugFrame:CreateTexture(nil, "BACKGROUND")
CacheDebugFrame.BG:SetAllPoints()
CacheDebugFrame.BG:SetColorTexture(0, 0, 0, 0.75)

CacheDebugFrame.Text = CacheDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CacheDebugFrame.Text:SetPoint("TOPLEFT", 10, -10)
CacheDebugFrame.Text:SetPoint("BOTTOMRIGHT", -10, 10)
CacheDebugFrame.Text:SetJustifyH("LEFT")
CacheDebugFrame.Text:SetJustifyV("TOP")

function UpdateQueueDebugList()
    CacheDebugFrame:SetShown(WGLU.DebugMode)
    if not WGLU.DebugMode then return end

    local lines = {
        "Who Got Loots - Inspection Broker",
        "Queued jobs: " .. #WGLCache.Queue,
        "Cached equipment snapshots: " .. #WGLCache.EquipmentCache,
        "Pending requests: " .. tostring((function()
            local count = 0
            for _ in pairs(WGL_Request_Cache) do count = count + 1 end
            return count
        end)()),
    }

    if WGLCache.ActiveJob then
        lines[#lines + 1] = "Active: " ..
            SafeDebugName(WGLCache.ActiveJob.PlayerName) ..
            " - " .. WGLCache.ActiveJob.State ..
            " (attempt " .. WGLCache.ActiveJob.Attempts .. ")"
    else
        lines[#lines + 1] = "Active: none"
    end

    for index, job in ipairs(WGLCache.Queue) do
        if index > 8 then
            lines[#lines + 1] = "...and " .. (#WGLCache.Queue - 8) .. " more"
            break
        end

        lines[#lines + 1] = index .. ". " ..
            SafeDebugName(job.PlayerName) ..
            " - " .. job.State ..
            " (" .. #job.Requests .. " comparison(s))"
    end

    CacheDebugFrame.Text:SetText(table.concat(lines, "\n"))
end
