WGLU = {}
WGLU.DebugMode = false

function WGLU.GetPlayerMainStat()
    local specialization = C_SpecializationInfo.GetSpecialization()
    if not specialization then return nil end

    local primaryStat = select(6, C_SpecializationInfo.GetSpecializationInfo(specialization))
    if primaryStat == 1 then
        return "Strength"
    elseif primaryStat == 2 then
        return "Agility"
    elseif primaryStat == 4 then
        return "Intellect"
    end
end

function WGLU.LerpFloat(a, b, t)
  return a + (b - a) * t
end

function WGLU.LerpBackdropColor(frame, a, b, t)
  local red = WGLU.LerpFloat(a[1], b[1], t)
  local green = WGLU.LerpFloat(a[2], b[2], t)
  local blue = WGLU.LerpFloat(a[3], b[3], t)
  local alpha = WGLU.LerpFloat(a[4], b[4], t)
  WGLUIBuilder.ColorBGSlicedFrame(frame, "backdrop", red, green, blue, alpha)
end

function WGLU.Clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

-- Find which is the highest stat between agility, strength, and intellect.
function WGLU.GetItemMainStat(ItemStats, findStat)
  findStat = findStat:lower()

  local foundStats = {}
  for stat, value in pairs(ItemStats) do
      local matchName = ""
      if stat == "ITEM_MOD_AGILITY_SHORT" then matchName = "agility"
      elseif stat == "ITEM_MOD_STRENGTH_SHORT" then matchName = "strength"
      elseif stat == "ITEM_MOD_INTELLECT_SHORT" then matchName = "intellect"
      end

      if value > 0 then foundStats[matchName] = value end
  end

  -- Return the stat we're looking for (findStat)
  if foundStats[findStat] == nil then return nil end
  return foundStats[findStat]
end

function WGLU.SimplifyStatName(statName)
  if statName == "Versatility" then return "Vers"
  elseif statName == "Crit" then return "Crit"
  elseif statName == "Haste" then return "Haste"
  elseif statName == "Mastery" then return "Mast"
  elseif statName == "Agility" then return "Agi"
  elseif statName == "Strength" then return "Str"
  elseif statName == "Intellect" then return "Int"
  elseif statName == "Stamina" then return "Stam"
  elseif statName == "Avoidance" then return "Avoid"
  elseif statName == "Leech" then return "Leech"
  elseif statName == "Speed" then return "Speed"
  elseif statName == "Indestructible" then return "Indest"
  elseif statName == "Armor" then return "Armor"
  else return nil end
end

function WGLU.SplitPlayerName(playerName)
  local name, realm = playerName:match("([^%-]+)%-(.+)")
  if realm == nil then return playerName, GetRealmName() end
  return name, realm
end

function WGLU.CheckIfItemIsShown(itemLink, player)
  for i, itemFrame in ipairs(WhoLootData.ActiveFrames) do
    if itemFrame.Item == itemLink and itemFrame.Player == player then
      return true
    end
  end
  return false
end

function WGLU.GetPlayerGUID(playerName)

  WGLU.DebugPrint("Finding GUID for player " .. playerName)

  -- If the player contains a realm, strip it.
  playerName = WGLU.SplitPlayerName(playerName)

  -- First, check target.
  if UnitExists("target") and playerName == "target" then
    return UnitGUID("target")
  end

  -- Is the player?
  if playerName == "player" then
    return UnitGUID("player")
  end

  -- Next, check if the player is in the group.
  for i = 1, 4 do
    local unit = "party" .. i
    if UnitExists(unit) and UnitName(unit) == playerName then
      return UnitGUID(unit)
    end
  end

  -- Next, check if the player is in the raid.
  for i = 1, 40 do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitName(unit) == playerName then
      return UnitGUID(unit)
    end
  end
end

function WGLU.GetPlayerUnitByGUID(guid)
  if not guid then return nil end
  return UnitTokenFromGUID(guid)
end

function WGLU.GetPlayerUnitByName(playerName)
  if issecretvalue and issecretvalue(playerName) then return nil end
  if not playerName then return nil end
  if UnitExists(playerName) then return playerName end

  local function NormalizeName(name)
    return name and string.lower(name) or nil
  end

  local function NormalizeRealm(realm)
    return realm and string.lower((string.gsub(realm, "[%s%-']", ""))) or nil
  end

  local incomingName, incomingRealm = string.match(playerName, "^([^%-]+)%-(.+)$")
  incomingName = NormalizeName(incomingName or playerName)
  incomingRealm = NormalizeRealm(incomingRealm)

  local function MatchesPlayer(unit)
    if not UnitExists(unit) then return false end

    local unitName, unitRealm = UnitFullName(unit)
    if (issecretvalue and (issecretvalue(unitName) or issecretvalue(unitRealm))) or not unitName then return false end

    unitName = NormalizeName(unitName)
    unitRealm = NormalizeRealm(unitRealm or GetNormalizedRealmName())

    if unitName ~= incomingName then return false end

    -- Same-realm loot messages are not consistent about including the realm.
    if not incomingRealm then return true end
    return unitRealm == incomingRealm

  end

  if MatchesPlayer("player") then return "player" end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if MatchesPlayer(unit) then return unit end
    end
  else
    for i = 1, GetNumSubgroupMembers() do
      local unit = "party" .. i
      if MatchesPlayer(unit) then return unit end
    end
  end

  return nil
end

function WGLU.DebugPrint(message)
  if WGLU.DebugMode then print(message) end
end

-- Determine if an item has the specified mainstat.
-- mainstat is a string, either "agility", "strength", or "intellect"
function WGLU.ItemHasMainStat(itemLink, mainStat)
  -- A character without a selected specialization has no primary stat yet.
  if not mainStat then return true end

  -- If the item is a neck, ring, or trinket, it doesn't have a main stat.
  local itemType = select(9, C_Item.GetItemInfo(itemLink))
  if itemType == "INVTYPE_NECK" or itemType == "INVTYPE_FINGER" or itemType == "INVTYPE_TRINKET" then
    return true
  end

  local stats = C_Item.GetItemStats(itemLink)
  if not stats then return false end

  local containsMainStat = false
  for stat in pairs(stats) do
    if mainStat == "Agility" and stat == "ITEM_MOD_AGILITY_SHORT" then
      containsMainStat = true
    elseif mainStat == "Strength" and stat == "ITEM_MOD_STRENGTH_SHORT" then
      containsMainStat = true
    elseif mainStat == "Intellect" and stat == "ITEM_MOD_INTELLECT_SHORT" then
      containsMainStat = true
    end
  end

  return containsMainStat
end

function WGLU.ItemQualityToText(quality)
  if quality == 0 then return "|cFF9D9D9DPoor|r"
  elseif quality == 1 then return "|cFFFFFFFFMeh|r"
  elseif quality == 2 then return "|cFF1EFF00Okay|r"
  elseif quality == 3 then return "|cFF0070DDNeat!|r"
  elseif quality == 4 then return "|cFFA335EEOmgg|r"
  elseif quality == 5 then return "|cFFFF8000OH SNAP|r"
  elseif quality == 6 then return "|cFFE6CC80Artifact|r"
  elseif quality == 7 then return "|cFF00CCFFHeirloom|r"
  elseif quality == 9 then return "|cFF00FF96WoW Token|r"
  else return "|cFF9D9D9DUnknown|r"
  end
end

function WGLU.OverrideEvent(frame, event, newHandler)
  local originalHandler = frame:GetScript(event)
  frame:SetScript(event, function(...)
    if originalHandler then
      originalHandler(...)
    end
    newHandler(...)
  end)
end
