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