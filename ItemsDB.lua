WGLItemsDB = {}
local _, playerclass = UnitClass("player")

-- Can the player equip this at all?
function WGLItemsDB.CanEquip(item, class)
    return WGLItemsDB.IsAppropriate(item, class) ~= nil
end

-- Is the item "appropriate", per transmog rules -- i.e. is it equipable and of the primary armor-type
-- TODO: class-restricted items, offhand-restricted items?
function WGLItemsDB.IsAppropriate(item, class)
    class = class or playerclass
    local slot, _, itemclass, itemsubclass = select(4, C_Item.GetItemInfoInstant(item))

    -- Cloaks are cloth, technically. But everyone can wear them.
    if slot == 'INVTYPE_CLOAK' then return true end

    if not (class and ClassAndGearDB[class] and itemclass and itemsubclass) then
        return
    end

    -- Is this an armor type?
    local isArmor = itemclass == Enum.ItemClass.Armor

    -- Also get the player's specialization
    local specID = GetSpecializationInfo(GetSpecialization())
    local spec = GetSpecByNumber(specID)

    if ClassAndGearDB.ALL[itemclass] ~= nil and ClassAndGearDB.ALL[itemclass][itemsubclass] ~= nil then
        return ClassAndGearDB.ALL[itemclass][itemsubclass]
    end

    if isArmor then
        if ClassAndGearDB[class]["armor"] ~= nill then
            return ClassAndGearDB[class]["armor"][itemsubclass]
        end
    else
        if ClassAndGearDB[class][spec] ~= nill and ClassAndGearDB[class][spec][itemsubclass] ~= nil then
            return ClassAndGearDB[class][spec][itemsubclass]
        end
    end
end

function GetSpecByNumber(number)
    for class, specs in pairs(class_specs) do
        for spec, specNumber in pairs(specs) do
            if specNumber == number then
                return spec
            end
        end
    end
end

-- Data
-- Specs and their IDs
class_specs = {
    DEATHKNIGHT = {
        Blood = 250,
        Frost = 251,
        Unholy = 252,
    },
    WARRIOR = {
        Arms = 71,
        Fury = 72,
        Protection = 73,
    },
    PALADIN = {
        Holy = 65,
        Protection = 66,
        Retribution = 70,
    },
    HUNTER = {
        BeastMastery = 253,
        Marksmanship = 254,
        Survival = 255,
    },
    SHAMAN = {
        Elemental = 262,
        Enhancement = 263,
        Restoration = 264,
    },
    DEMONHUNTER = {
        Havoc = 577,
        Vengeance = 581,
    },
    ROGUE = {
        Assassination = 259,
        Outlaw = 260,
        Subtlety = 261,
    },
    MONK = {
        Brewmaster = 268,
        Windwalker = 269,
        Mistweaver = 270,
    },
    DRUID = {
        Balance = 102,
        Feral = 103,
        Guardian = 104,
        Restoration = 105,
    },
    PRIEST = {
        Discipline = 256,
        Holy = 257,
        Shadow = 258,
    },
    MAGE = {
        Arcane = 62,
        Fire = 63,
        Frost = 64,
    },
    WARLOCK = {
        Affliction = 256,
        Demonology = 266,
        Destruction = 267,
    },
    EVOKER = {
        Devastation = 1467,
        Preservation = 1468,
        Augmentation = 1473,
    }
}

-- This is a three-value system:
--  true: can equip and is appropriate
--  false: can equip but isn't appropriate
--  nil: can't equip
ClassAndGearDB = {
    ALL = {
        [Enum.ItemClass.Weapon] = {
            [Enum.ItemWeaponSubclass.Generic] = true,
            [Enum.ItemWeaponSubclass.Fishingpole] = true,
        },
        [Enum.ItemClass.Armor] = {
            [Enum.ItemArmorSubclass.Generic] = true, -- includes things like trinkets and rings
            [Enum.ItemArmorSubclass.Cosmetic] = true,
        },
    },
    DEATHKNIGHT = {
        armor = {
            [Enum.ItemArmorSubclass.Plate] = true,
            [Enum.ItemArmorSubclass.Mail] = false,
            [Enum.ItemArmorSubclass.Leather] = false,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Blood = {
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = false,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
        },
        Frost = {
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
        },
        Unholy = {
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = false,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
        },
    },
    WARRIOR = {
        armor = {
            [Enum.ItemArmorSubclass.Shield] = true,
            [Enum.ItemArmorSubclass.Plate] = true,
            [Enum.ItemArmorSubclass.Mail] = false,
            [Enum.ItemArmorSubclass.Leather] = false,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Fury = {
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Bows] = false,
            [Enum.ItemWeaponSubclass.Crossbow] = false,
            [Enum.ItemWeaponSubclass.Guns] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
        Arms = {
            [Enum.ItemWeaponSubclass.Dagger] = false,
            [Enum.ItemWeaponSubclass.Unarmed] = false,
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Mace1H] = false,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Staff] = false,
            [Enum.ItemWeaponSubclass.Bows] = false,
            [Enum.ItemWeaponSubclass.Crossbow] = false,
            [Enum.ItemWeaponSubclass.Guns] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
        Protection = {
            [Enum.ItemWeaponSubclass.Dagger] = false,
            [Enum.ItemWeaponSubclass.Unarmed] = false,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = false,
            [Enum.ItemWeaponSubclass.Mace2H] = false,
            [Enum.ItemWeaponSubclass.Sword2H] = false,
            [Enum.ItemWeaponSubclass.Polearm] = false,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Bows] = false,
            [Enum.ItemWeaponSubclass.Crossbow] = false,
            [Enum.ItemWeaponSubclass.Guns] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
    },
    PALADIN = {
        Holy = {
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Staff] = false,
            [Enum.ItemWeaponSubclass.Polearm] = true,
        },
        Protection = {
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = false,
            [Enum.ItemWeaponSubclass.Mace2H] = false,
            [Enum.ItemWeaponSubclass.Sword2H] = false,
            [Enum.ItemWeaponSubclass.Polearm] = false,
        },
        Retribution = {
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Mace1H] = false,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
        },
        armor = {
            [Enum.ItemArmorSubclass.Plate] = true,
            [Enum.ItemArmorSubclass.Mail] = false,
            [Enum.ItemArmorSubclass.Leather] = false,
            [Enum.ItemArmorSubclass.Cloth] = false,
            [Enum.ItemArmorSubclass.Shield] = true,
        },
    },
    HUNTER = {
        armor = {
            [Enum.ItemArmorSubclass.Mail] = true,
            [Enum.ItemArmorSubclass.Leather] = false,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        BeastMastery = {
            [Enum.ItemWeaponSubclass.Bows] = true,
            [Enum.ItemWeaponSubclass.Crossbow] = true,
            [Enum.ItemWeaponSubclass.Guns] = true,
            [Enum.ItemWeaponSubclass.Polearm] = false,
            [Enum.ItemWeaponSubclass.Staff] = false,
            [Enum.ItemWeaponSubclass.Dagger] = false,
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Unarmed] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
        Marksmanship = {
            [Enum.ItemWeaponSubclass.Bows] = true,
            [Enum.ItemWeaponSubclass.Crossbow] = true,
            [Enum.ItemWeaponSubclass.Polearm] = false,
            [Enum.ItemWeaponSubclass.Staff] = false,
            [Enum.ItemWeaponSubclass.Guns] = true,
            [Enum.ItemWeaponSubclass.Dagger] = false,
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Unarmed] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
        Survival = {
            [Enum.ItemWeaponSubclass.Bows] = false,
            [Enum.ItemWeaponSubclass.Crossbow] = false,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Guns] = false,
            [Enum.ItemWeaponSubclass.Dagger] = false,
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Unarmed] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
    },
    SHAMAN = {
        armor = {
            [Enum.ItemArmorSubclass.Shield] = true,
            [Enum.ItemArmorSubclass.Mail] = true,
            [Enum.ItemArmorSubclass.Leather] = false,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Elemental = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
        },
        Enhancement = {
            [Enum.ItemWeaponSubclass.Dagger] = false,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Staff] = false,
            [Enum.ItemWeaponSubclass.Axe2H] = false,
            [Enum.ItemWeaponSubclass.Mace2H] = false,
        },
        Restoration = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
        },
    },
    DEMONHUNTER = {
        armor = {
            [Enum.ItemArmorSubclass.Leather] = true,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Havoc = {
            [Enum.ItemWeaponSubclass.Warglaive] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
        },
        Vengeance = {
            [Enum.ItemWeaponSubclass.Warglaive] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
        },
    },
    ROGUE = {
        armor = {
            [Enum.ItemArmorSubclass.Leather] = true,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Assassination = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = false,
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Mace1H] = false,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Bows] = false,
            [Enum.ItemWeaponSubclass.Crossbow] = false,
            [Enum.ItemWeaponSubclass.Guns] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
        Outlaw = {
            [Enum.ItemWeaponSubclass.Dagger] = false,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Bows] = false,
            [Enum.ItemWeaponSubclass.Crossbow] = false,
            [Enum.ItemWeaponSubclass.Guns] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
        Subtlety = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = false,
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Mace1H] = false,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Bows] = false,
            [Enum.ItemWeaponSubclass.Crossbow] = false,
            [Enum.ItemWeaponSubclass.Guns] = false,
            [Enum.ItemWeaponSubclass.Thrown] = false,
        },
    },
    MONK = {
        armor = {
            [Enum.ItemArmorSubclass.Leather] = true,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Brewmaster = {
            [Enum.ItemWeaponSubclass.Unarmed] = false,
            [Enum.ItemWeaponSubclass.Axe1H] = false,
            [Enum.ItemWeaponSubclass.Mace1H] = false,
            [Enum.ItemWeaponSubclass.Sword1H] = false,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
        },
        Mistweaver = {
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
        },
        Windwalker = {
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
        },
    },
    DRUID = {
        armor = {
            [Enum.ItemArmorSubclass.Leather] = true,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Balance = {
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Dagger] = true,
        },
        Feral = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Bearclaw] = true,
            [Enum.ItemWeaponSubclass.Catclaw] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
        },
        Guardian = {
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Bearclaw] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
        },
        Restoration = {
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Polearm] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
        },
    },
    PRIEST = {
        armor = {
            [Enum.ItemArmorSubclass.Cloth] = true,
        },
        Discipline = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
        },
        Holy = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
        },
        Shadow = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
        },
    },
    MAGE = {
        armor = {
            [Enum.ItemArmorSubclass.Cloth] = true,
        },
        Arcane = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
        },
        Fire = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
        },
        Frost = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
        },
    },
    WARLOCK = {
        armor = {
            [Enum.ItemArmorSubclass.Cloth] = true,
        },
        Affliction = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
        },
        Demonology = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
        },
        Destruction = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Wand] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
        },
    },
    EVOKER = {
        armor = {
            [Enum.ItemArmorSubclass.Mail] = true,
            [Enum.ItemArmorSubclass.Leather] = false,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Devestation = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
        },
        Preservation = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
        },
        Augmentation = {
            [Enum.ItemWeaponSubclass.Dagger] = true,
            [Enum.ItemWeaponSubclass.Unarmed] = true,
            [Enum.ItemWeaponSubclass.Axe1H] = true,
            [Enum.ItemWeaponSubclass.Mace1H] = true,
            [Enum.ItemWeaponSubclass.Sword1H] = true,
            [Enum.ItemWeaponSubclass.Axe2H] = true,
            [Enum.ItemWeaponSubclass.Mace2H] = true,
            [Enum.ItemWeaponSubclass.Sword2H] = true,
            [Enum.ItemWeaponSubclass.Staff] = true,
        },
    },
}