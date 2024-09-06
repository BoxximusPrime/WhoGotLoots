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

function WhoGotLootUtil.IsArmorPiece(slotID)
  for _, armorSlotID in ipairs(WhoGotLootUtil.ArmorPieces) do
    if slotID == armorSlotID then
      return true
    end
  end
  return false
end