WhoGotLootUtil = {}

-- List of inventory slot IDs for armor pieces only --
WhoGotLootUtil.ArmorPieces = {
  "INVTYPE_HEAD",
  "INVTYPE_SHOULDER",
  "INVTYPE_CHEST",
  "INVTYPE_HAND",
  "INVTYPE_WRIST",
  "INVTYPE_LEGS",
  "INVTYPE_FEET",
  "INVTYPE_WAIST"
}

WhoGotLootUtil.WeaponSlots = {
  "INVTYPE_WEAPON",
  "INVTYPE_2HWEAPON",
  "INVTYPE_WEAPONMAINHAND",
  "INVTYPE_WEAPONOFFHAND",
  "INVTYPE_SHIELD",
  "INVTYPE_RANGED",
  "INVTYPE_RANGEDRIGHT",
  "INVTYPE_THROWN",
  "INVTYPE_RANGED2"
}

function WhoGotLootUtil.IsArmorPiece(slotID)
  for _, armorSlotID in ipairs(WhoGotLootUtil.ArmorPieces) do
    if slotID == armorSlotID then
      return true
    end
  end
  return false
end

WhoGotLootUtil.Backdrop = 
{
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  edgeSize = 4,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

 function WhoGotLootUtil.GetPlayerMainStat()
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

-- Find which is the highest stat between agility, strength, and intellect.
function WhoGotLootUtil.GetItemMainStat(mainStat, findStat)
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