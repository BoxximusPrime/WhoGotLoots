WGLU = {}

 function WGLU.GetPlayerMainStat()
    local stats = {
        Strength = { base = 0, effective = 0 },
        Agility = { base = 0, effective = 0 },
        Intellect = { base = 0, effective = 0 }
    }

    stats.Strength.base, stats.Strength.effective = UnitStat("player", 1)
    stats.Agility.base, stats.Agility.effective = UnitStat("player", 2)
    stats.Intellect.base, stats.Intellect.effective = UnitStat("player", 4)

    if stats.Strength.effective > stats.Agility.effective and stats.Strength.effective > stats.Intellect.effective then
        return "Strength"
    elseif stats.Agility.effective > stats.Strength.effective and stats.Agility.effective > stats.Intellect.effective then
        return "Agility"
    elseif stats.Intellect.effective > stats.Strength.effective and stats.Intellect.effective > stats.Agility.effective then
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
  if UnitExists("target") and UnitGUID("target") == guid then
    return "target"
  end

  for i = 1, 4 do
    local unit = "party" .. i
    if UnitExists(unit) and UnitGUID(unit) == guid then
      return unit
    end
  end

  for i = 1, 40 do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitGUID(unit) == guid then
      return unit
    end
  end
end

function WGLU.DebugPrint(message)
  if WGLDEBUG then print(message) end
end

-- Determine if an item has the specified mainstat.
-- mainstat is a string, either "agility", "strength", or "intellect"
function WGLU.ItemHasMainStat(itemLink, mainStat)

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