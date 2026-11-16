local _, ns = ...

ALoot = {}

local SKILLS = {
	[171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
	[197] = "Tailoring", [165] = "Leatherworking", [186] = "Mining", [185] = "Cooking", [129] = "FirstAid",
}

local all
function ALoot.AllItems()
	if all then return all end
	all = {}
	for _, row in ipairs(ns.Search("", nil, true)) do
		if row.kind == "item" then all[#all + 1] = row.id end
	end
	return all
end

local KIND = { Crafting = "craft", Factions = "reputation", PvP = "pvp", Collections = "collection" }

function ALoot.SourceText(id)
	local text = ns.SourceText(id)
	local srcs = ns.Sources(id)
	local first = srcs and srcs[1]
	local kind
	if first and first.spell then
		kind = "craft"
	elseif first and first.group then
		local g = first.group
		kind = KIND[g.module]
		if not kind then kind = (g.cat == "Raids") and "raid" or "dungeon" end
	end
	return text, kind
end

function ALoot.Sources(id)
	local out = {}
	for _, src in ipairs(ns.Sources(id) or {}) do
		out[#out + 1] = {
			text = ns.SourceLabel(src),
			module = src.group and src.group.module,
			place = src.group and src.group.name,
			category = src.group and src.group.cat,
			spell = src.spell,
			token = src.token,
			rate = src.rate,
		}
	end
	return out
end

function ALoot.Open(id)
	if not id then
		ns.UI.Show()
		return
	end
	local srcs = ns.Sources(id)
	local first = srcs and srcs[1]
	ns.UI.Show()
	if first and first.group then
		ns.UI.Go(first.group, first.section)
	else
		local name = ns.ItemName(id)
		if name then ns.UI.SetSearch(name) end
	end
end

function ALoot.WishToggle(id)
	return ns.Wish.Toggle(id)
end

function ALoot.OnWishlist(id)
	return ns.Wish.OnAny(id) ~= nil
end

local recipes = {}
function ALoot.ProfessionRecipes(prof)
	if type(prof) == "number" then prof = SKILLS[prof] end
	if type(prof) ~= "string" then return {} end
	local key = prof:lower():gsub("%s+", "")
	if recipes[key] then return recipes[key] end
	local out, seen = {}, {}
	for _, cat in ipairs(ns.Categories("Crafting")) do
		for _, g in ipairs(cat.groups) do
			if g.ttype == "Profession" and (g.key:lower() == key or g.name:lower():gsub("%s+", "") == key) then
				for _, section in ipairs(g.sections) do
					for _, list in pairs(section.loot or {}) do
						for _, e in ipairs(list) do
							local spell = e[2]
							if type(spell) == "number" and type(e[3]) ~= "string" and not seen[spell] then
								seen[spell] = true
								local info = ns.CraftInfo(spell)
								if info then
									local recipe = ns.RecipeForSpell(spell)
									out[#out + 1] = {
										spell = spell, item = info.item, skill = info.learn or 0,
										recipe = recipe,
										source = recipe and (ns.SourceText(recipe) or "Recipe item") or "Trainer",
									}
								end
							end
						end
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.skill ~= b.skill then return a.skill < b.skill end
		return a.spell < b.spell
	end)
	recipes[key] = out
	return out
end
