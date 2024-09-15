WGLUtil = {}

function WGLUtil.IsArmorPiece(slotID)
  for _, armorSlotID in ipairs(WGLUtil.ArmorPieces) do
    if slotID == armorSlotID then
      return true
    end
  end
  return false
end

WGLUtil.Backdrop = 
{
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  edgeSize = 4,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

 function WGLUtil.GetPlayerMainStat()
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

function WGLUtil.LerpFloat(a, b, t)
  return a + (b - a) * t
end

function WGLUtil.LerpBackdropColor(frame, a, b, t)
  local red = WGLUtil.LerpFloat(a[1], b[1], t)
  local green = WGLUtil.LerpFloat(a[2], b[2], t)
  local blue = WGLUtil.LerpFloat(a[3], b[3], t)
  local alpha = WGLUtil.LerpFloat(a[4], b[4], t)
  WGLUIBuilder.ColorBGSlicedFrame(frame, "backdrop", red, green, blue, alpha)
end

function WGLUtil.Clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

-- Find which is the highest stat between agility, strength, and intellect.
function WGLUtil.GetItemMainStat(mainStat, findStat)
  local highestStat = 0
  local highestStatName = ""
  findStat = findStat:lower()

  local foundStats = {}
  for stat, value in pairs(mainStat) do
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

function WGLUtil.SimplifyStatName(statName)
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

function WGLUtil.SplitPlayerName(playerName)
  local name, realm = playerName:match("([^%-]+)%-(.+)")
  if realm == nil then return playerName, GetRealmName() end
  return name, realm
end

function WGLUtil.CheckIfItemIsShown(itemLink, player)
  for i, itemFrame in ipairs(WhoLootData.ActiveFrames) do
    if itemFrame.Item == itemLink and itemFrame.Player == player then
      return true
    end
  end
  return false
end

-- Determine if an item has the specified mainstat
-- mainstat is a string, either "agility", "strength", or "intellect"
function WGLUtil.ItemHasMainStat(itemLink, mainStat)
  local stats = C_Item.GetItemStats(itemLink)

  local containsMainStat = false
  for stat, value in pairs(stats) do
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

function WGLUtil.GetPlayerSpec()
  local specID = GetSpecializationInfo(GetSpecialization())
  for class, id in pairs(SPECS) do
    if id == specID then
      return class
    end
  end
  return nil
end