local _, ns = ...

local Wish = {}
ns.Wish = Wish

function Wish.Lists()
	return ns.db.lists
end

function Wish.Active()
	local lists = ns.db.lists
	local i = ns.chardb.list or 1
	if not lists[i] then
		i = 1
		ns.chardb.list = 1
	end
	return lists[i], i
end

function Wish.Select(i)
	if ns.db.lists[i] then
		ns.chardb.list = i
		ns:Fire("WISHLIST_CHANGED")
	end
end

function Wish.Has(id)
	local list = Wish.Active()
	return list.items[id] ~= nil
end

function Wish.OnAny(id)
	for _, list in ipairs(ns.db.lists) do
		if list.items[id] then return list.name end
	end
	return nil
end

function Wish.Toggle(id)
	local list = Wish.Active()
	if list.items[id] then
		list.items[id] = nil
	else
		list.items[id] = true
	end
	ns:Fire("WISHLIST_CHANGED")
end

function Wish.Count(list)
	local n = 0
	for _ in pairs((list or Wish.Active()).items) do n = n + 1 end
	return n
end

function Wish.New(name)
	name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return end
	local lists = ns.db.lists
	lists[#lists + 1] = { name = name, items = {} }
	ns.chardb.list = #lists
	ns:Fire("WISHLIST_CHANGED")
end

function Wish.Rename(name)
	name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return end
	Wish.Active().name = name
	ns:Fire("WISHLIST_CHANGED")
end

function Wish.Delete()
	local lists = ns.db.lists
	local _, i = Wish.Active()
	if #lists <= 1 then
		lists[1].items = {}
	else
		table.remove(lists, i)
		ns.chardb.list = 1
	end
	ns:Fire("WISHLIST_CHANGED")
end

function Wish.CountIn(g, sectionIndex)
	local list = Wish.Active()
	if not next(list.items) then return 0 end
	local n = 0
	for id in pairs(list.items) do
		local srcs = ns.Sources(id)
		if srcs then
			for _, s in ipairs(srcs) do
				if s.group == g and (not sectionIndex or s.section == sectionIndex) then
					n = n + 1
					break
				end
			end
		end
	end
	return n
end

function Wish.Rows(filter)
	local list = Wish.Active()
	local buckets = {}
	local order = {}
	local function bucket(key, title)
		if not buckets[key] then
			buckets[key] = { title = title, rows = {} }
			order[#order + 1] = key
		end
		return buckets[key]
	end
	for id in pairs(list.items) do
		local srcs = ns.Sources(id)
		local src = srcs and srcs[1]
		local b
		if src and src.token then
			local sub = ns.Sources(src.token)
			src = sub and sub[1] or nil
		end
		if src and src.group then
			b = bucket(src.group.id, src.group.name)
			b.group = src.group
		else
			b = bucket("~", "Other")
		end
		local info = ns.Item(id)
		if ns.Passes({ kind = "item", id = id }, filter) then
			b.rows[#b.rows + 1] = { kind = "item", id = id, showSource = true }
		end
	end
	table.sort(order, function(a, b) return buckets[a].title < buckets[b].title end)
	local rows = {}
	for _, key in ipairs(order) do
		local b = buckets[key]
		if #b.rows > 0 then
			table.sort(b.rows, function(x, y)
				return (ns.ItemName(x.id) or "") < (ns.ItemName(y.id) or "")
			end)
			rows[#rows + 1] = { kind = "boss", text = b.title, group = b.group, count = #b.rows }
			for _, r in ipairs(b.rows) do rows[#rows + 1] = r end
		end
	end
	if #rows == 0 then
		rows[1] = { kind = "note", text = "This list is empty. Click the star on any item to add it." }
	end
	return rows
end

ns:On("CHAT_MSG_LOOT", function(msg)
	if not ns.db or not ns.db.alerts then return end
	if type(msg) ~= "string" or ns.IsSecret(msg) then return end
	local id = tonumber(msg:match("|Hitem:(%d+)"))
	if not id then return end
	local listName = Wish.OnAny(id)
	if not listName then return end
	local link = msg:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)") or ns.ItemLink(id) or ("item " .. id)
	ns.Print("wishlist item looted: " .. link .. " (" .. listName .. ")")
	if PlaySound and SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST then
		pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST)
	end
	ns:Fire("ITEMS_UPDATED")
end)
