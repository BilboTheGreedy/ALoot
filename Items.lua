local _, ns = ...

local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local IsEquipped = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
local RequestLoad = C_Item and C_Item.RequestLoadItemDataByID

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local cache = {}
local requested = {}

local QUALITY = {
	[0] = { 0.62, 0.62, 0.62 },
	[1] = { 1, 1, 1 },
	[2] = { 0.12, 1, 0 },
	[3] = { 0, 0.44, 0.87 },
	[4] = { 0.64, 0.21, 0.93 },
	[5] = { 1, 0.5, 0 },
	[6] = { 0.9, 0.8, 0.5 },
	[7] = { 0, 0.8, 1 },
}

function ns.QualityColor(q)
	local c = QUALITY[q or 1] or QUALITY[1]
	return c[1], c[2], c[3]
end

function ns.Item(id)
	local info = cache[id]
	if info then return info end
	local name, link, quality, ilvl, minLevel, itemType, subType, _, equipLoc, icon, _, classID, subclassID
	if GetInfo then
		name, link, quality, ilvl, minLevel, itemType, subType, _, equipLoc, icon, _, classID, subclassID = GetInfo(id)
	end
	if name then
		info = {
			id = id, name = name, link = link, quality = quality, ilvl = ilvl, minLevel = minLevel,
			type = itemType, subType = subType, equipLoc = equipLoc, icon = icon,
			classID = classID, subclassID = subclassID,
		}
		cache[id] = info
		return info
	end
	if not requested[id] then
		requested[id] = true
		if RequestLoad then pcall(RequestLoad, id) end
	end
	return nil
end

local kinds = {}

function ns.ItemKind(id)
	local k = kinds[id]
	if k then return k end
	local info = cache[id]
	if info and info.classID then
		k = { equipLoc = info.equipLoc, classID = info.classID, subclassID = info.subclassID }
	elseif GetInstant then
		local ok, _, _, _, loc, _, classID, subclassID = pcall(GetInstant, id)
		if ok and classID then
			k = { equipLoc = loc, classID = classID, subclassID = subclassID }
		end
	end
	if not k then
		ns.Item(id)
		return nil
	end
	kinds[id] = k
	return k
end

function ns.ItemIcon(id)
	local info = cache[id]
	if info and info.icon then return info.icon end
	local icon
	if GetIcon then icon = GetIcon(id) end
	if not icon and GetInstant then
		local _, _, _, _, tex = GetInstant(id)
		icon = tex
	end
	return icon or QUESTION
end

function ns.ItemName(id)
	local info = ns.Item(id)
	if info then return info.name, true end
	local n = ns.raw.names[id]
	if n then return n, false end
	return nil, false
end

function ns.ItemLink(id)
	local info = ns.Item(id)
	return info and info.link
end

function ns.Owned(id)
	if IsEquipped then
		local ok, eq = pcall(IsEquipped, id)
		if ok and not ns.IsSecret(eq) and eq then return true end
	end
	if GetCount then
		local ok, n = pcall(GetCount, id, true)
		if ok and type(n) == "number" and not ns.IsSecret(n) and n > 0 then return true end
	end
	return false
end

function ns.BagCount(id)
	if GetCount then
		local ok, n = pcall(GetCount, id, true)
		if ok and type(n) == "number" and not ns.IsSecret(n) then return n end
	end
	return 0
end

function ns.SpellName(id)
	local name
	if C_Spell and C_Spell.GetSpellName then
		name = C_Spell.GetSpellName(id)
	elseif GetSpellInfo then
		name = GetSpellInfo(id)
	end
	return name or ns.raw.spellnames[id]
end

function ns.SpellIcon(id)
	local tex
	if C_Spell and C_Spell.GetSpellTexture then
		tex = C_Spell.GetSpellTexture(id)
	elseif GetSpellTexture then
		tex = GetSpellTexture(id)
	end
	return tex or QUESTION
end

local ARMOR = {
	WARRIOR = 4, PALADIN = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2,
	PRIEST = 1, MAGE = 1, WARLOCK = 1,
}

local EXTRA_ARMOR = {
	WARRIOR = { [6] = true },
	PALADIN = { [6] = true, [7] = true },
	SHAMAN = { [6] = true, [9] = true },
	DRUID = { [8] = true },
}

local WEAPON = {
	WARRIOR = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 1, [10] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
	PALADIN = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 1 },
	HUNTER = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [6] = 1, [7] = 1, [8] = 1, [10] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
	ROGUE = { [2] = 1, [3] = 1, [4] = 1, [7] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
	PRIEST = { [4] = 1, [10] = 1, [15] = 1, [19] = 1 },
	SHAMAN = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [10] = 1, [13] = 1, [15] = 1 },
	MAGE = { [7] = 1, [10] = 1, [15] = 1, [19] = 1 },
	WARLOCK = { [7] = 1, [10] = 1, [15] = 1, [19] = 1 },
	DRUID = { [4] = 1, [5] = 1, [10] = 1, [13] = 1, [15] = 1 },
}

ns.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

function ns.ClassName(class)
	local n = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]
	if n then return n end
	return class:sub(1, 1) .. class:sub(2):lower()
end

function ns.ClassColor(class)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

function ns.Usable(info, class)
	if not info or not class or class == "ALL" then return true end
	if info.classID == 4 then
		local sub = info.subclassID or 0
		if sub == 0 or info.equipLoc == "INVTYPE_CLOAK" then return true end
		if sub >= 1 and sub <= 4 then
			return sub <= (ARMOR[class] or 4)
		end
		local extra = EXTRA_ARMOR[class]
		return extra and extra[sub] or false
	elseif info.classID == 2 then
		local w = WEAPON[class]
		if not w or info.subclassID == 20 then return true end
		return w[info.subclassID or -1] ~= nil
	end
	return true
end

ns.SLOTS = {
	{ "ALL", "All slots" },
	{ "INVTYPE_HEAD", "Head" },
	{ "INVTYPE_NECK", "Neck" },
	{ "INVTYPE_SHOULDER", "Shoulder" },
	{ "INVTYPE_CLOAK", "Back" },
	{ "INVTYPE_CHEST", "Chest" },
	{ "INVTYPE_WRIST", "Wrist" },
	{ "INVTYPE_HAND", "Hands" },
	{ "INVTYPE_WAIST", "Waist" },
	{ "INVTYPE_LEGS", "Legs" },
	{ "INVTYPE_FEET", "Feet" },
	{ "INVTYPE_FINGER", "Finger" },
	{ "INVTYPE_TRINKET", "Trinket" },
	{ "WEAPON", "Weapons" },
	{ "OFFHAND", "Off-hand and shields" },
	{ "RANGED", "Ranged and relics" },
}

local SLOTGROUP = {
	INVTYPE_ROBE = "INVTYPE_CHEST",
	INVTYPE_WEAPON = "WEAPON", INVTYPE_2HWEAPON = "WEAPON", INVTYPE_WEAPONMAINHAND = "WEAPON",
	INVTYPE_WEAPONOFFHAND = "WEAPON",
	INVTYPE_SHIELD = "OFFHAND", INVTYPE_HOLDABLE = "OFFHAND",
	INVTYPE_RANGED = "RANGED", INVTYPE_RANGEDRIGHT = "RANGED", INVTYPE_THROWN = "RANGED", INVTYPE_RELIC = "RANGED",
}

function ns.SlotMatches(info, slot)
	if not slot or slot == "ALL" then return true end
	if not info then return false end
	local loc = info.equipLoc
	if not loc or loc == "" then return false end
	return (SLOTGROUP[loc] or loc) == slot
end

ns.ARMORS = {
	{ "ALL", "All armor" },
	{ 1, "Cloth" },
	{ 2, "Leather" },
	{ 3, "Mail" },
	{ 4, "Plate" },
	{ 6, "Shields" },
}

function ns.ArmorName(armor)
	for _, a in ipairs(ns.ARMORS) do
		if a[1] == armor then
			if armor ~= "ALL" and armor ~= 6 and C_Item and C_Item.GetItemSubClassInfo then
				local ok, n = pcall(C_Item.GetItemSubClassInfo, 4, armor)
				if ok and type(n) == "string" and n ~= "" then return n end
			end
			return a[2]
		end
	end
	return "All armor"
end

function ns.ArmorMatches(info, armor)
	if not armor or armor == "ALL" then return true end
	if not info then return false end
	if info.classID ~= 4 or info.subclassID ~= armor then return false end
	if armor == 1 and info.equipLoc == "INVTYPE_CLOAK" then return false end
	return true
end

function ns.SlotText(info)
	if not info then return nil end
	local parts = {}
	local loc = info.equipLoc
	if loc and loc ~= "" and _G[loc] then parts[#parts + 1] = _G[loc] end
	if info.subType and info.subType ~= "" and (info.classID == 2 or info.classID == 4) then
		if parts[1] ~= info.subType then parts[#parts + 1] = info.subType end
	elseif #parts == 0 and info.type then
		parts[#parts + 1] = info.subType and info.subType ~= "" and info.subType or info.type
	end
	if info.minLevel and info.minLevel > 0 then
		parts[#parts + 1] = "Level " .. info.minLevel
	end
	return table.concat(parts, "  ·  ")
end

ns:On("GET_ITEM_INFO_RECEIVED", function(id, ok)
	if not id or ns.IsSecret(id) then return end
	requested[id] = nil
	if ok == false then return end
	ns.Debounce("items", 0.15, function()
		ns:Fire("ITEMS_UPDATED")
	end)
end)
