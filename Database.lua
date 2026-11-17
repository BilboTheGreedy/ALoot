local _, ns = ...

ns.MODULES = {
	{ key = "DungeonsAndRaids", title = "Dungeons & Raids" },
	{ key = "Crafting", title = "Crafting" },
	{ key = "Factions", title = "Factions" },
	{ key = "PvP", title = "PvP" },
	{ key = "Collections", title = "Collections" },
}

local CAT_MAP = {
	["Forever Dungeons"] = { "Dungeons", "Forever" },
	["Forever Raids"] = { "Raids", "Forever" },
	["20 Raids"] = { "Raids", "20" },
	["40 Raids"] = { "Raids", "40" },
}

local PROFESSIONS = {
	[1] = "First Aid", [2] = "Blacksmithing", [3] = "Leatherworking", [4] = "Alchemy", [5] = "Herbalism",
	[6] = "Cooking", [7] = "Mining", [8] = "Tailoring", [9] = "Engineering", [10] = "Enchanting",
	[11] = "Fishing", [12] = "Skinning", [13] = "Poisons", [14] = "Jewelcrafting", [15] = "Inscription",
}

local function prettify(key)
	local s = key:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
	return s
end

local function areaName(id)
	if C_Map and C_Map.GetAreaInfo then
		local n = C_Map.GetAreaInfo(id)
		if type(n) == "string" and n ~= "" then return n end
	end
	return nil
end

function ns.FactionName(id)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local d = C_Reputation.GetFactionDataByID(id)
		if d and d.name then return d.name, d.reaction end
	end
	if GetFactionInfoByID then
		local name, _, standing = GetFactionInfoByID(id)
		if name then return name, standing end
	end
	return nil
end

function ns.Resolve(str, fallback)
	if type(str) ~= "string" then return fallback end
	local failed = false
	str = str:gsub("@area:(%d+)@", function(id)
		local n = areaName(tonumber(id))
		if not n then failed = true end
		return n or ""
	end)
	str = str:gsub("@faction:(%d+)@", function(id)
		local n = ns.FactionName(tonumber(id))
		if not n then failed = true end
		return n or ""
	end)
	str = str:gsub("%$([A-Z][A-Z0-9_]+)", function(g)
		local v = _G[g]
		if type(v) == "string" then return v end
		failed = true
		return ""
	end)
	if failed and fallback then return fallback end
	return str
end

local groups = {}
local byId = {}
local byModule = {}
local byInstance = {}
local built = false

local function build()
	if built then return end
	built = true
	for _, mod in ipairs(ns.MODULES) do
		local list = ns.raw.loot[mod.key] or {}
		local cats = {}
		local catOrder = {}
		for _, raw in ipairs(list) do
			local mapped = CAT_MAP[raw.cat]
			local catName = mapped and mapped[1] or raw.cat
			local g = {
				id = mod.key .. ":" .. raw.key,
				module = mod.key,
				key = raw.key,
				raw = raw,
				cat = ns.Resolve(catName, "General"),
				tag = mapped and mapped[2] or nil,
				level = raw.level,
				inst = raw.inst,
				faction = raw.faction,
				ttype = raw.ttype or "Item",
				sections = raw.bosses,
				diffs = raw.diffs or {},
			}
			local fallback = prettify(raw.key)
			if raw.name then
				g.name = ns.Resolve(raw.name, fallback)
			elseif raw.faction then
				g.name = ns.FactionName(raw.faction) or fallback
			elseif raw.map then
				g.name = areaName(raw.map) or fallback
			else
				g.name = fallback
			end
			groups[#groups + 1] = g
			byId[g.id] = g
			if g.inst then byInstance[g.inst] = g end
			if not cats[g.cat] then
				cats[g.cat] = { name = g.cat, groups = {} }
				catOrder[#catOrder + 1] = cats[g.cat]
			end
			table.insert(cats[g.cat].groups, g)
		end
		if mod.key == "DungeonsAndRaids" then
			for _, c in ipairs(catOrder) do
				if c.name == "Dungeons" then
					for i, g in ipairs(c.groups) do g.order = i end
					table.sort(c.groups, function(a, b)
						local la = a.level and (a.level[2] or a.level[1]) or 999
						local lb = b.level and (b.level[2] or b.level[1]) or 999
						if la ~= lb then return la < lb end
						return a.order < b.order
					end)
				end
			end
		end
		byModule[mod.key] = catOrder
	end
end

function ns.Categories(moduleKey)
	build()
	return byModule[moduleKey] or {}
end

function ns.Group(id)
	build()
	return byId[id]
end

function ns.GroupByInstance(instanceID)
	build()
	return byInstance[instanceID]
end

function ns.AllGroups()
	build()
	return groups
end

function ns.SectionName(section)
	return ns.Resolve(section.name, "?") or "?"
end

function ns.SectionLevel(section)
	local l = section.level
	if type(l) == "number" then
		if l >= 999 then return "??" end
		return tostring(l)
	end
	if type(l) == "table" and l[1] then
		if l[2] and l[2] ~= l[1] then return l[1] .. "-" .. l[2] end
		return tostring(l[1])
	end
	if type(l) == "string" then return l end
	return nil
end

function ns.LevelText(g)
	local l = g.level
	if not l then return nil end
	local lo, hi = l[2] or l[1], l[3] or l[2]
	if lo and hi and lo ~= hi then return lo .. "-" .. hi end
	return lo and tostring(lo) or nil
end

function ns.DefaultDiff(g)
	local want = ns.playerFaction:lower()
	for _, d in ipairs(g.diffs) do
		if d[1] == want then return want end
	end
	return g.diffs[1] and g.diffs[1][1] or "n"
end

local function coins(copper)
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		return C_CurrencyInfo.GetCoinTextureString(copper)
	end
	if GetCoinTextureString then return GetCoinTextureString(copper) end
	return math.floor(copper / 10000) .. "g"
end

local function priceText(price)
	if type(price) ~= "string" then return nil end
	local money = price:match("^money:(%d+)")
	if money then return coins(tonumber(money)) end
	return nil
end

local function sectionLoot(section, diff)
	local loot = section.loot
	if not loot then return nil end
	if loot[diff] then return loot[diff] end
	local want = ns.playerFaction:lower()
	if loot[want] then return loot[want] end
	if loot.n then return loot.n end
	for _, l in pairs(loot) do return l end
	return nil
end

local function itemRow(id, section, extra)
	local row = { kind = "item", id = id }
	local rates = section and section.npc and ns.raw.droprates[section.npc]
	if rates and rates[id] then row.rate = rates[id] end
	if extra then
		for k, v in pairs(extra) do row[k] = v end
	end
	return row
end

local function entryRows(e, ttype, section, out)
	local faction = ns.playerFaction
	if e.alliance == true and faction ~= "Alliance" then return end
	if e.horde == true and faction ~= "Horde" then return end
	local a, b = e[2], e[3]
	if a == nil or a == false then
		local id = faction == "Horde" and e.horde or e.alliance
		if type(id) ~= "number" then id = type(e.alliance) == "number" and e.alliance or e.horde end
		if type(id) == "number" then out[#out + 1] = itemRow(id, section) end
		return
	end
	if type(a) == "string" then
		local f, r = a:match("^f(%d+)rep(%d+)$")
		if f then
			out[#out + 1] = { kind = "rep", faction = tonumber(f), standing = tonumber(r) }
			return
		end
		local text, desc
		for i = 3, #e do
			if type(e[i]) == "string" and e[i] ~= "" then
				if not text then text = e[i] elseif not desc then desc = e[i] end
			end
		end
		local rank = a:match("^rank:(%d+)$")
		if rank then
			out[#out + 1] = {
				kind = "rank", rank = tonumber(rank),
				text = ns.Resolve(text, "Rank " .. rank), desc = desc,
				icon = string.format("Interface\\PvPRankBadges\\PvPRank%02d", tonumber(rank)),
			}
		else
			out[#out + 1] = { kind = "header", text = ns.Resolve(text, ""), desc = desc, icon = "Interface\\Icons\\" .. a }
		end
		return
	end
	if type(a) ~= "number" then return end
	if type(b) == "string" then
		if a == 0 then
			local text
			for i = 4, #e do
				if type(e[i]) == "string" and e[i] ~= "" then text = e[i] break end
			end
			out[#out + 1] = { kind = "note", text = text or "No loot data yet" }
		else
			out[#out + 1] = { kind = "header", text = ns.Resolve(b, ""), icon = a }
		end
		return
	end
	if ttype == "Profession" then
		out[#out + 1] = { kind = "spell", id = a }
	elseif ttype == "Set" then
		out[#out + 1] = { kind = "set", id = a }
	else
		out[#out + 1] = itemRow(a, section, { amount = e.amount, price = priceText(e.price), quest = e.quest })
		if type(b) == "number" then
			out[#out + 1] = itemRow(b, section, { amount = e.amount2 })
		end
	end
end

local function passes(row, filter)
	if row.kind ~= "item" or not filter then return true end
	local class, slot, armor = filter.class, filter.slot, filter.armor
	if filter.needed then
		if ns.Owned(row.id) then return false end
		local kind = ns.ItemKind(row.id)
		if kind and not ns.Usable(kind, ns.playerClass) then return false end
	end
	if (not class or class == "ALL") and (not slot or slot == "ALL") and (not armor or armor == "ALL") then return true end
	local info = ns.ItemKind(row.id)
	if not ns.SlotMatches(info, slot) then return false end
	if not ns.ArmorMatches(info, armor) then return false end
	if not info then return true end
	return ns.Usable(info, class)
end

ns.Passes = passes

local function prune(rows)
	local out = {}
	for i, row in ipairs(rows) do
		if row.kind == "header" or row.kind == "boss" or row.kind == "rep" then
			local nextRow
			for j = i + 1, #rows do
				local k = rows[j].kind
				if k == "boss" then break end
				if row.kind ~= "boss" and (k == "header" or k == "rep") then break end
				if k ~= "header" and k ~= "rep" then nextRow = rows[j] break end
			end
			if nextRow or row.keep then out[#out + 1] = row end
		else
			out[#out + 1] = row
		end
	end
	return out
end

function ns.SectionRows(g, index, diff, filter, out)
	out = out or {}
	local section = g.sections[index]
	if not section then return out end
	local list = sectionLoot(section, diff)
	if not list then return out end
	local sorted = {}
	for i, e in ipairs(list) do sorted[i] = e end
	table.sort(sorted, function(x, y) return (x[1] or 0) < (y[1] or 0) end)
	local ttype = section.ttype or g.ttype
	local tmp = {}
	for _, e in ipairs(sorted) do entryRows(e, ttype, section, tmp) end
	for _, row in ipairs(tmp) do
		row.group = g
		row.section = index
		if passes(row, filter) then out[#out + 1] = row end
	end
	return out
end

function ns.GroupRows(g, index, diff, filter)
	local rows = {}
	if index then
		ns.SectionRows(g, index, diff, filter, rows)
	else
		for i, section in ipairs(g.sections) do
			rows[#rows + 1] = { kind = "boss", text = ns.SectionName(section), group = g, section = i, level = ns.SectionLevel(section) }
			ns.SectionRows(g, i, diff, filter, rows)
		end
	end
	return prune(rows)
end

local sources
local spellToRecipe

local function addSource(id, src)
	local l = sources[id]
	if not l then
		l = {}
		sources[id] = l
	end
	for i = 1, #l do
		local o = l[i]
		if o.group == src.group and o.section == src.section and o.spell == src.spell and o.token == src.token then return end
	end
	l[#l + 1] = src
end

local function buildSources()
	if sources then return end
	sources = {}
	build()
	local profs = ns.raw.professions
	for _, g in ipairs(groups) do
		for si, section in ipairs(g.sections) do
			if not section.nosource and not g.raw.nosource then
				local ttype = section.ttype or g.ttype
				local rates = section.npc and ns.raw.droprates[section.npc]
				local seen = {}
				for _, list in pairs(section.loot or {}) do
					for _, e in ipairs(list) do
						local a, b = e[2], e[3]
						if ttype == "Profession" then
							if type(a) == "number" and type(b) ~= "string" then
								local p = profs[a]
								if p and p[1] and not seen[a] then
									seen[a] = true
									addSource(p[1], { group = g, section = si, spell = a })
								end
							end
						elseif ttype == "Item" then
							local ids = {}
							if type(a) == "number" and type(b) ~= "string" then ids[#ids + 1] = a end
							if type(a) == "number" and type(b) == "number" then ids[#ids + 1] = b end
							if type(e.alliance) == "number" then ids[#ids + 1] = e.alliance end
							if type(e.horde) == "number" then ids[#ids + 1] = e.horde end
							for _, id in ipairs(ids) do
								if id > 0 and not seen[id] then
									seen[id] = true
									addSource(id, { group = g, section = si, rate = rates and rates[id] })
								end
							end
						end
					end
				end
			end
		end
	end
	for token, data in pairs(ns.raw.tokens) do
		if type(data) == "table" and sources[token] then
			for _, v in ipairs(data) do
				local id = type(v) == "table" and v[1] or v
				if type(id) == "number" and id > 0 and id ~= token then
					addSource(id, { token = token })
				end
			end
		end
	end
end

function ns.Sources(id)
	buildSources()
	return sources[id]
end

local function sourceLabel(src)
	if src.token then
		local n = ns.ItemName(src.token)
		local sub = ns.Sources(src.token)
		local where = sub and sub[1] and sub[1].group and (" (" .. sub[1].group.name .. ")") or ""
		return "Token: " .. (n or "?") .. where
	end
	local g = src.group
	local section = g.sections[src.section]
	if src.spell then
		local p = ns.raw.professions[src.spell]
		local skill = p and p[3] and p[3] > 0 and (" " .. p[3]) or ""
		return "Crafted: " .. g.name .. skill
	end
	local text = ns.SectionName(section) .. " - " .. g.name
	if src.rate then text = text .. string.format("  (%.1f%%)", src.rate) end
	return text
end
ns.SourceLabel = sourceLabel

function ns.SourceText(id)
	local l = ns.Sources(id)
	if not l or #l == 0 then return nil end
	local text = sourceLabel(l[1])
	if #l > 1 then text = text .. "  +" .. (#l - 1) .. " more" end
	return text
end

function ns.SetName(id)
	local name
	if C_Item and C_Item.GetItemSetInfo then
		local ok, n = pcall(C_Item.GetItemSetInfo, id)
		if ok and type(n) == "string" then name = n end
	elseif GetItemSetInfo then
		name = GetItemSetInfo(id)
	end
	return name or ns.raw.setnames[id] or ("Set " .. id)
end

local CLASSBITS = {
	[1] = "WARRIOR", [2] = "PALADIN", [4] = "HUNTER", [8] = "ROGUE", [16] = "PRIEST",
	[64] = "SHAMAN", [128] = "MAGE", [256] = "WARLOCK", [1024] = "DRUID",
}

function ns.SetInfo(id)
	local s = ns.raw.sets[id]
	if not s then return nil end
	return {
		items = s[1] or {},
		quality = s[3],
		ilvl = s[4],
		class = CLASSBITS[s[5] or 0],
	}
end

function ns.SetRows(id)
	local rows = {}
	local info = ns.SetInfo(id)
	if not info then
		rows[1] = { kind = "note", text = "No data for this set" }
		return rows
	end
	for _, item in ipairs(info.items) do
		rows[#rows + 1] = { kind = "item", id = item, showSource = true }
	end
	return rows
end

function ns.TokenData(id)
	local t = ns.raw.tokens[id]
	if type(t) == "number" then
		return ns.raw.tokens[t], t
	end
	return t, id
end

function ns.TokenRows(id)
	local rows = {}
	local data, root = ns.TokenData(id)
	if type(data) ~= "table" then return rows end
	if root ~= id then
		rows[#rows + 1] = { kind = "item", id = root, showSource = true }
	end
	for _, v in ipairs(data) do
		if type(v) == "string" then
			local class = v:match("^class:(.+)$")
			if class then
				rows[#rows + 1] = { kind = "header", text = ns.ClassName(class), class = class, keep = true }
			end
		elseif type(v) == "table" then
			if type(v[1]) == "number" then
				rows[#rows + 1] = { kind = "item", id = v[1], amount = v[2] and ("x" .. v[2]) or nil }
			end
		elseif type(v) == "number" and v > 0 and v ~= id then
			rows[#rows + 1] = { kind = "item", id = v }
		end
	end
	return rows
end

function ns.CraftInfo(spell)
	local p = ns.raw.professions[spell]
	if not p then return nil end
	return {
		item = p[1] or nil,
		prof = PROFESSIONS[p[2] or 0],
		learn = p[3], yellow = p[4], grey = p[5],
		reagents = p[6] or {},
		counts = p[7] or {},
		makes = p[8] or 1,
	}
end

function ns.RecipeForSpell(spell)
	if not spellToRecipe then
		spellToRecipe = {}
		for item, data in pairs(ns.raw.recipes) do
			if type(data) == "table" and data[3] then
				spellToRecipe[data[3]] = item
			end
		end
	end
	return spellToRecipe[spell]
end

function ns.CraftRows(spell)
	local rows = {}
	local info = ns.CraftInfo(spell)
	if not info then
		rows[1] = { kind = "note", text = "No data for this recipe" }
		return rows
	end
	if info.item then
		rows[#rows + 1] = { kind = "header", text = "Creates", keep = true }
		rows[#rows + 1] = { kind = "item", id = info.item, amount = info.makes > 1 and ("x" .. info.makes) or nil }
	end
	if #info.reagents > 0 then
		rows[#rows + 1] = { kind = "header", text = "Reagents", keep = true }
		for i, id in ipairs(info.reagents) do
			local need = info.counts[i] or 1
			rows[#rows + 1] = { kind = "item", id = id, need = need }
		end
	end
	local recipe = ns.RecipeForSpell(spell)
	if recipe then
		rows[#rows + 1] = { kind = "header", text = "Taught by", keep = true }
		rows[#rows + 1] = { kind = "item", id = recipe, showSource = true }
	end
	return rows
end

function ns.ItemSourceRows(id)
	local rows = { { kind = "item", id = id } }
	local l = ns.Sources(id)
	if not l or #l == 0 then
		rows[#rows + 1] = { kind = "note", text = "No known source" }
		return rows
	end
	rows[#rows + 1] = { kind = "header", text = "Sources", keep = true }
	for _, src in ipairs(l) do
		if src.token then
			rows[#rows + 1] = { kind = "item", id = src.token, showSource = true }
		else
			rows[#rows + 1] = {
				kind = "goto", text = sourceLabel(src), group = src.group, section = src.section,
				sub = src.group.cat,
			}
		end
	end
	return rows
end

local lowerCache = {}
local searchIds

local function searchList()
	if searchIds then return searchIds end
	buildSources()
	local set = {}
	for id in pairs(sources) do set[id] = true end
	for id in pairs(ns.raw.names) do set[id] = true end
	searchIds = {}
	for id in pairs(set) do searchIds[#searchIds + 1] = id end
	table.sort(searchIds)
	return searchIds
end

function ns.UnnamedItems()
	local out = {}
	for _, id in ipairs(searchList()) do
		if not ns.raw.names[id] then out[#out + 1] = id end
	end
	return out
end

local function lname(id)
	local c = lowerCache[id]
	if c then return c end
	local name, final = ns.ItemName(id)
	if not name then return nil end
	local l = name:lower()
	if final then lowerCache[id] = l end
	return l
end

local setIds

local function setList()
	if setIds then return setIds end
	setIds = {}
	for id in pairs(ns.raw.sets) do setIds[#setIds + 1] = id end
	table.sort(setIds)
	return setIds
end

function ns.Search(query, filter, all)
	local words = {}
	for w in (query or ""):lower():gmatch("%S+") do words[#words + 1] = w end
	local rows = {}
	if #words == 0 and not all then return rows, 0 end
	local function match(text)
		if not text then return false end
		for i = 1, #words do
			if not text:find(words[i], 1, true) then return false end
		end
		return true
	end
	build()
	local places = 0
	if #words > 0 then
		for _, g in ipairs(groups) do
			if places >= 12 then break end
			if match(g.name:lower()) then
				rows[#rows + 1] = { kind = "goto", text = g.name, sub = g.cat, group = g }
				places = places + 1
			end
			for si, section in ipairs(g.sections) do
				if places >= 12 then break end
				local name = ns.SectionName(section)
				if section.npc and match(name:lower()) then
					rows[#rows + 1] = { kind = "goto", text = name, sub = g.name, group = g, section = si }
					places = places + 1
				end
			end
		end
	end
	if places > 0 then
		table.insert(rows, 1, { kind = "header", text = "Places", keep = true })
	end
	local plain = not filter or ((not filter.slot or filter.slot == "ALL") and (not filter.armor or filter.armor == "ALL"))
	if #words > 0 and plain then
		local sets = {}
		for _, id in ipairs(setList()) do
			local name = ns.SetName(id)
			local info = ns.SetInfo(id)
			local class = filter and filter.class
			if match(name:lower()) and (not class or class == "ALL" or not info or not info.class or info.class == class) then
				sets[#sets + 1] = { kind = "set", id = id, name = name }
			end
		end
		if #sets > 0 then
			table.sort(sets, function(a, b)
				if a.name ~= b.name then return a.name < b.name end
				return a.id < b.id
			end)
			rows[#rows + 1] = { kind = "header", text = "Sets", keep = true }
			for i = 1, math.min(#sets, 40) do rows[#rows + 1] = sets[i] end
		end
	end
	local found = {}
	local names = {}
	for _, id in ipairs(searchList()) do
		local n = lname(id)
		if n and match(n) then
			local row = { kind = "item", id = id, showSource = true }
			if passes(row, filter) then
				found[#found + 1] = row
				names[id] = n
			end
		end
	end
	table.sort(found, function(a, b)
		local x, y = names[a.id], names[b.id]
		if x ~= y then return x < y end
		return a.id < b.id
	end)
	if #rows > 0 and #found > 0 then
		rows[#rows + 1] = { kind = "header", text = "Items", keep = true }
	end
	for i = 1, #found do rows[#rows + 1] = found[i] end
	return prune(rows), #found
end
