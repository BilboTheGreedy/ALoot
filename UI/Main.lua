local _, ns = ...
local UI = ns.UI
local C = UI.colors
local Wish = ns.Wish

local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local TICK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local frame
local state = {
	module = "DungeonsAndRaids",
	groupId = nil,
	section = nil,
	diff = nil,
	slot = "ALL",
	armor = "ALL",
	view = "group",
	query = "",
	stack = {},
}

local function filter()
	local class = ns.db.classFilter
	if class == "MINE" then class = ns.playerClass end
	return { class = class, slot = state.slot, armor = state.armor }
end

local function currentGroup()
	return state.groupId and ns.Group(state.groupId)
end

local function insertLink(link)
	if not link then return end
	if ChatFrameUtil and ChatFrameUtil.InsertLink then
		if ChatFrameUtil.InsertLink(link) then return end
	end
	if ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
end

local function preview(link)
	if not link then return end
	if DressUpItemLink then
		DressUpItemLink(link)
	elseif DressUpLink then
		DressUpLink(link)
	end
end

local function pushDetail(title, build)
	state.stack[#state.stack + 1] = { title = title, build = build }
	UI.RefreshContent()
end

local function showTooltip(row)
	local d = row.data
	if not d then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	if d.kind == "item" then
		if GameTooltip.SetItemByID then
			GameTooltip:SetItemByID(d.id)
		else
			GameTooltip:SetHyperlink("item:" .. d.id)
		end
	elseif d.kind == "spell" then
		local info = ns.CraftInfo(d.id)
		if info and info.item then
			if GameTooltip.SetItemByID then
				GameTooltip:SetItemByID(info.item)
			else
				GameTooltip:SetHyperlink("item:" .. info.item)
			end
		elseif GameTooltip.SetSpellByID then
			GameTooltip:SetSpellByID(d.id)
		end
		if info then
			if info.prof then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(string.format("%s  %d / %d / %d", info.prof, info.learn or 0, info.yellow or 0, info.grey or 0), 1, 0.82, 0)
			end
			for i, id in ipairs(info.reagents) do
				local need = info.counts[i] or 1
				local have = ns.BagCount(id)
				local name = ns.ItemName(id) or ("item " .. id)
				local r, g, b = 0.9, 0.3, 0.3
				if have >= need then r, g, b = 0.3, 0.9, 0.3 end
				GameTooltip:AddDoubleLine(need .. "x " .. name, have .. "/" .. need, 0.9, 0.9, 0.9, r, g, b)
			end
		end
		GameTooltip:Show()
	elseif d.kind == "set" then
		local info = ns.SetInfo(d.id)
		GameTooltip:AddLine(ns.SetName(d.id), 1, 0.82, 0)
		if info then
			for _, id in ipairs(info.items) do
				local item = ns.Item(id)
				local r, g, b = ns.QualityColor(item and item.quality or 1)
				GameTooltip:AddLine(ns.ItemName(id) or ("item " .. id), r, g, b)
			end
		end
		GameTooltip:Show()
	elseif d.kind == "goto" or d.kind == "boss" then
		if d.group then
			GameTooltip:AddLine(d.text, 1, 1, 1)
			GameTooltip:AddLine("Click to open", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		else
			GameTooltip:Hide()
		end
	else
		GameTooltip:Hide()
	end
end

local function clickRow(row, button)
	local d = row.data
	if not d then return end
	if d.kind == "item" then
		if IsShiftKeyDown() then
			insertLink(ns.ItemLink(d.id))
		elseif IsControlKeyDown() then
			preview(ns.ItemLink(d.id))
		elseif IsAltKeyDown() then
			Wish.Toggle(d.id)
		elseif button == "RightButton" then
			local name = ns.ItemName(d.id) or "Item"
			pushDetail(name, function() return ns.ItemSourceRows(d.id) end)
		else
			local name = ns.ItemName(d.id) or "Item"
			if ns.TokenData(d.id) then
				pushDetail(name, function() return ns.TokenRows(d.id) end)
			else
				pushDetail(name, function() return ns.ItemSourceRows(d.id) end)
			end
		end
	elseif d.kind == "spell" then
		local info = ns.CraftInfo(d.id)
		if IsShiftKeyDown() and info and info.item then
			insertLink(ns.ItemLink(info.item))
		elseif IsControlKeyDown() and info and info.item then
			preview(ns.ItemLink(info.item))
		elseif IsAltKeyDown() and info and info.item then
			Wish.Toggle(info.item)
		else
			local name = (info and info.item and ns.ItemName(info.item)) or ns.SpellName(d.id) or "Recipe"
			pushDetail(name, function() return ns.CraftRows(d.id) end)
		end
	elseif d.kind == "set" then
		pushDetail(ns.SetName(d.id), function() return ns.SetRows(d.id) end)
	elseif d.kind == "goto" or d.kind == "boss" then
		if d.group then UI.Go(d.group, d.section) end
	end
end

local function createLootRow(list)
	local row = CreateFrame("Button", nil, list)
	row.bg = UI.Fill(row, { 1, 1, 1, 0 })
	row.hl = UI.Fill(row, C.hover, "HIGHLIGHT")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(30, 30)
	row.icon:SetPoint("LEFT", 8, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.rim = UI.Tex(row, "BORDER", { 0, 0, 0, 1 })
	row.rim:SetPoint("TOPLEFT", row.icon, -1, 1)
	row.rim:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)
	row.name = UI.Text(row, "GameFontHighlight")
	row.sub = UI.Text(row, "GameFontDisableSmall", "LEFT", C.dim)
	row.right = UI.Text(row, "GameFontHighlightSmall", "RIGHT", C.dim)
	row.right:SetPoint("RIGHT", -52, 0)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
	row.name:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 1)
	row.sub:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
	row.title = UI.Text(row, "GameFontNormal")
	row.title:SetPoint("LEFT", 10, 0)
	row.title:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
	row.line = UI.Tex(row, "ARTWORK", C.line)
	row.line:SetPoint("BOTTOMLEFT", 8, 0)
	row.line:SetPoint("BOTTOMRIGHT", -4, 0)
	row.line:SetHeight(1)
	row.tick = row:CreateTexture(nil, "OVERLAY")
	row.tick:SetSize(14, 14)
	row.tick:SetPoint("RIGHT", -30, 0)
	row.tick:SetTexture(TICK)
	row.star = CreateFrame("Button", nil, row)
	row.star:SetSize(18, 18)
	row.star:SetPoint("RIGHT", -6, 0)
	row.star.tex = row.star:CreateTexture(nil, "ARTWORK")
	row.star.tex:SetAllPoints()
	row.star.tex:SetTexture(STAR)
	row.star:SetScript("OnClick", function(self)
		local d = row.data
		if not d then return end
		local id = d.id
		if d.kind == "spell" then
			local info = ns.CraftInfo(d.id)
			id = info and info.item
		end
		if id then Wish.Toggle(id) end
	end)
	row.star:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Wishlist: " .. Wish.Active().name, 1, 0.82, 0)
		GameTooltip:Show()
	end)
	row.star:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", clickRow)
	row:SetScript("OnEnter", function(self)
		list.hovered = self
		showTooltip(self)
	end)
	row:SetScript("OnLeave", function(self)
		if list.hovered == self then list.hovered = nil end
		GameTooltip:Hide()
	end)
	return row
end

local function setStar(row, id)
	if not id then
		row.star:Hide()
		return
	end
	row.star:Show()
	if Wish.Has(id) then
		row.star.tex:SetDesaturated(false)
		row.star.tex:SetAlpha(1)
	else
		row.star.tex:SetDesaturated(true)
		row.star.tex:SetAlpha(0.22)
	end
end

local function layout(row, mode)
	local iconed = mode == "icon"
	if iconed then
		row.icon:Show() row.rim:Show() row.name:Show() row.sub:Show() row.title:Hide()
	else
		row.icon:Hide() row.rim:Hide() row.name:Hide() row.sub:Hide() row.title:Show()
	end
	row.tick:Hide()
	row.star:Hide()
	row.line:Hide()
	row.right:SetText("")
	row.bg:SetColorTexture(1, 1, 1, 0)
	row.rim:SetColorTexture(0, 0, 0, 1)
	row.hl:Hide()
end

local function updateItemRow(row, d)
	layout(row, "icon")
	row.hl:Show()
	local info = ns.Item(d.id)
	local name = ns.ItemName(d.id)
	row.icon:SetTexture(ns.ItemIcon(d.id))
	row.name:SetText(name or ("Item " .. d.id))
	if info then
		local r, g, b = ns.QualityColor(info.quality)
		row.name:SetTextColor(r, g, b)
		row.rim:SetColorTexture(r * 0.8, g * 0.8, b * 0.8, 1)
	else
		row.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
	end
	local sub
	if d.showSource then
		sub = ns.SourceText(d.id)
	end
	if not sub then sub = ns.SlotText(info) end
	if ns.TokenData(d.id) and not d.showSource then
		sub = (sub and (sub .. "  ·  ") or "") .. "click to see what it is for"
	end
	row.sub:SetText(sub or "")
	local right = {}
	if d.need then
		local have = ns.BagCount(d.id)
		local color = have >= d.need and "|cff55dd55" or "|cffdd5555"
		right[#right + 1] = color .. have .. "/" .. d.need .. "|r"
	end
	if d.amount then right[#right + 1] = tostring(d.amount) end
	if d.price then right[#right + 1] = d.price end
	if d.rate then right[#right + 1] = string.format("%.1f%%", d.rate) end
	row.right:SetText(table.concat(right, "  "))
	if not d.need and ns.Owned(d.id) then row.tick:Show() end
	setStar(row, d.id)
end

local function updateSpellRow(row, d)
	layout(row, "icon")
	row.hl:Show()
	local craft = ns.CraftInfo(d.id)
	local item = craft and craft.item
	if item then
		local info = ns.Item(item)
		row.icon:SetTexture(ns.ItemIcon(item))
		row.name:SetText(ns.ItemName(item) or ns.SpellName(d.id) or ("Recipe " .. d.id))
		if info then
			local r, g, b = ns.QualityColor(info.quality)
			row.name:SetTextColor(r, g, b)
			row.rim:SetColorTexture(r * 0.8, g * 0.8, b * 0.8, 1)
		else
			row.name:SetTextColor(C.text[1], C.text[2], C.text[3])
		end
		setStar(row, item)
		if ns.Owned(item) then row.tick:Show() end
	else
		row.icon:SetTexture(ns.SpellIcon(d.id))
		row.name:SetText(ns.SpellName(d.id) or ("Recipe " .. d.id))
		row.name:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
	if craft then
		local parts = {}
		for i, id in ipairs(craft.reagents) do
			if i > 4 then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = (craft.counts[i] or 1) .. "x " .. (ns.ItemName(id) or "?")
		end
		row.sub:SetText(table.concat(parts, ", "))
		if craft.learn and craft.learn > 0 then
			row.right:SetText(string.format("|cffff8040%d|r |cffffff00%d|r |cff808080%d|r", craft.learn, craft.yellow or 0, craft.grey or 0))
		end
	else
		row.sub:SetText("")
	end
end

local function updateSetRow(row, d)
	layout(row, "icon")
	row.hl:Show()
	local info = ns.SetInfo(d.id)
	local first = info and info.items[1]
	row.icon:SetTexture(first and ns.ItemIcon(first) or QUESTION)
	row.name:SetText(ns.SetName(d.id))
	local r, g, b = ns.QualityColor(info and info.quality or 4)
	if info and info.class then r, g, b = ns.ClassColor(info.class) end
	row.name:SetTextColor(r, g, b)
	local parts = {}
	if info then
		parts[#parts + 1] = #info.items .. " pieces"
		if info.class then parts[#parts + 1] = ns.ClassName(info.class) end
		if info.ilvl and info.ilvl > 0 then parts[#parts + 1] = "item level " .. info.ilvl end
	end
	row.sub:SetText(table.concat(parts, "  ·  "))
	row.right:SetText(">")
end

local function updateLootRow(row, d)
	if d.kind == "item" then
		updateItemRow(row, d)
	elseif d.kind == "spell" then
		updateSpellRow(row, d)
	elseif d.kind == "set" then
		updateSetRow(row, d)
	elseif d.kind == "boss" then
		layout(row, "title")
		row.hl:SetShown(d.group ~= nil)
		row.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.09)
		row.title:SetText(d.text)
		row.title:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
		if d.count then
			row.right:SetText(d.count .. (d.count == 1 and " item" or " items"))
		elseif d.level then
			row.right:SetText("Level " .. d.level)
		end
	elseif d.kind == "header" then
		layout(row, "title")
		row.line:Show()
		row.title:SetText(d.text or "")
		if d.class then
			row.title:SetTextColor(ns.ClassColor(d.class))
		else
			row.title:SetTextColor(C.text[1], C.text[2], C.text[3])
		end
		row.right:SetText(d.desc or "")
	elseif d.kind == "note" then
		layout(row, "title")
		row.title:SetText(d.text or "")
		row.title:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
	elseif d.kind == "rep" then
		layout(row, "title")
		row.line:Show()
		local name, standing = ns.FactionName(d.faction)
		local label = _G["FACTION_STANDING_LABEL" .. d.standing] or ("Standing " .. d.standing)
		row.title:SetText((name or "Reputation") .. ":  " .. label)
		if type(standing) == "number" and standing >= d.standing then
			row.title:SetTextColor(0.35, 0.87, 0.35)
			row.right:SetText("reached")
		else
			row.title:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
			local mine = type(standing) == "number" and _G["FACTION_STANDING_LABEL" .. standing]
			row.right:SetText(mine and ("you: " .. mine) or "")
		end
	elseif d.kind == "rank" then
		layout(row, "icon")
		row.icon:SetTexture(d.icon)
		row.name:SetText(d.text or "")
		row.name:SetTextColor(C.text[1], C.text[2], C.text[3])
		row.sub:SetText(d.desc or "")
	elseif d.kind == "goto" then
		layout(row, "icon")
		row.hl:Show()
		local section = d.group and d.section and d.group.sections[d.section]
		if section and section.display and SetPortraitTextureFromCreatureDisplayID then
			SetPortraitTextureFromCreatureDisplayID(row.icon, section.display)
		else
			row.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
		end
		row.name:SetText(d.text or "")
		row.name:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
		row.sub:SetText(d.sub or "")
		row.right:SetText(">")
	else
		layout(row, "title")
		row.title:SetText("")
	end
end

local function navData()
	local data = {}
	for _, cat in ipairs(ns.Categories(state.module)) do
		data[#data + 1] = { header = cat.name }
		for _, g in ipairs(cat.groups) do
			data[#data + 1] = { group = g }
		end
	end
	return data
end

local function createNavRow(list)
	local row = CreateFrame("Button", nil, list)
	row.bg = UI.Fill(row, { 1, 1, 1, 0 })
	row.hl = UI.Fill(row, C.hover, "HIGHLIGHT")
	row.right = UI.Text(row, "GameFontDisableSmall", "RIGHT", C.dim)
	row.right:SetPoint("RIGHT", -6, 0)
	row.text = UI.Text(row, "GameFontHighlightSmall")
	row.text:SetPoint("LEFT", 14, 0)
	row.text:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
	row:SetScript("OnClick", function(self)
		local d = self.data
		if d and d.group then UI.Go(d.group, nil) end
	end)
	return row
end

local function updateNavRow(row, d)
	if d.header then
		row.hl:Hide()
		row.bg:SetColorTexture(1, 1, 1, 0)
		row.text:SetText(d.header:upper())
		row.text:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
		row.text:SetPoint("LEFT", 8, 0)
		row.right:SetText("")
		return
	end
	local g = d.group
	row.hl:Show()
	row.text:SetPoint("LEFT", 16, 0)
	row.text:SetText(g.name)
	local selected = state.groupId == g.id
	if selected then
		row.bg:SetColorTexture(C.select[1], C.select[2], C.select[3], C.select[4])
		row.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	else
		row.bg:SetColorTexture(1, 1, 1, 0)
		row.text:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
	local parts = {}
	local wanted = Wish.CountIn(g)
	if wanted > 0 then parts[#parts + 1] = "|cffffd100" .. wanted .. "*|r" end
	if g.tag then parts[#parts + 1] = g.tag end
	local level = ns.LevelText(g)
	if level then parts[#parts + 1] = level end
	row.right:SetText(table.concat(parts, "  "))
end

local function sectionData()
	local g = currentGroup()
	local data = {}
	if not g then return data end
	data[1] = { all = true, group = g }
	for i, s in ipairs(g.sections) do
		data[#data + 1] = { group = g, index = i, section = s }
	end
	return data
end

local function createSectionRow(list)
	local row = CreateFrame("Button", nil, list)
	row.bg = UI.Fill(row, { 1, 1, 1, 0 })
	row.hl = UI.Fill(row, C.hover, "HIGHLIGHT")
	row.portrait = row:CreateTexture(nil, "ARTWORK")
	row.portrait:SetSize(24, 24)
	row.portrait:SetPoint("LEFT", 6, 0)
	row.right = UI.Text(row, "GameFontDisableSmall", "RIGHT", C.dim)
	row.right:SetPoint("RIGHT", -6, 0)
	row.text = UI.Text(row, "GameFontHighlightSmall")
	row.text:SetPoint("LEFT", 36, 0)
	row.text:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
	row:SetScript("OnClick", function(self)
		local d = self.data
		if d then UI.Go(d.group, d.index) end
	end)
	return row
end

local function updateSectionRow(row, d)
	local selected = state.view == "group" and #state.stack == 0 and state.section == d.index
	if selected then
		row.bg:SetColorTexture(C.select[1], C.select[2], C.select[3], C.select[4])
		row.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	else
		row.bg:SetColorTexture(1, 1, 1, 0)
		row.text:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
	if d.all then
		row.portrait:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
		row.portrait:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		row.text:SetText("Everything")
		local wanted = Wish.CountIn(d.group)
		row.right:SetText(wanted > 0 and ("|cffffd100" .. wanted .. "*|r") or "")
		return
	end
	local s = d.section
	row.portrait:SetTexCoord(0, 1, 0, 1)
	if s.display and SetPortraitTextureFromCreatureDisplayID then
		SetPortraitTextureFromCreatureDisplayID(row.portrait, s.display)
	else
		row.portrait:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
		row.portrait:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	row.text:SetText(ns.SectionName(s))
	if s.extra and not selected then
		row.text:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
	end
	local parts = {}
	local wanted = Wish.CountIn(d.group, d.index)
	if wanted > 0 then parts[#parts + 1] = "|cffffd100" .. wanted .. "*|r" end
	local level = ns.SectionLevel(s)
	if level then parts[#parts + 1] = level end
	row.right:SetText(table.concat(parts, "  "))
end

local function classLabel()
	local c = ns.db.classFilter
	if c == "ALL" then return "All classes" end
	if c == "MINE" then return "My class" end
	return ns.ClassName(c)
end

local function slotLabel()
	for _, s in ipairs(ns.SLOTS) do
		if s[1] == state.slot then return s[2] end
	end
	return "All slots"
end

local function classMenu(anchor)
	local entries = {
		{ text = "All classes", checked = ns.db.classFilter == "ALL", func = function() ns.db.classFilter = "ALL" UI.RefreshContent() end },
		{ text = "My class (" .. ns.ClassName(ns.playerClass) .. ")", checked = ns.db.classFilter == "MINE", func = function() ns.db.classFilter = "MINE" UI.RefreshContent() end },
	}
	for _, class in ipairs(ns.CLASSES) do
		local r, g, b = ns.ClassColor(class)
		entries[#entries + 1] = {
			text = ns.ClassName(class), color = { r, g, b }, checked = ns.db.classFilter == class,
			func = function() ns.db.classFilter = class UI.RefreshContent() end,
		}
	end
	UI.Menu(anchor, entries)
end

local function slotMenu(anchor)
	local entries = {}
	for _, s in ipairs(ns.SLOTS) do
		entries[#entries + 1] = {
			text = s[2], checked = state.slot == s[1],
			func = function() state.slot = s[1] UI.RefreshContent() end,
		}
	end
	UI.Menu(anchor, entries)
end

local function armorMenu(anchor)
	local entries = {}
	for _, a in ipairs(ns.ARMORS) do
		entries[#entries + 1] = {
			text = ns.ArmorName(a[1]), checked = state.armor == a[1],
			func = function() state.armor = a[1] UI.RefreshContent() end,
		}
	end
	UI.Menu(anchor, entries)
end

local function optionsMenu(anchor)
	local db = ns.db
	local function toggle(text, key, after)
		return {
			text = text, checked = db[key],
			func = function()
				db[key] = not db[key]
				if after then after() end
			end,
		}
	end
	local entries = {
		{ text = "Options", title = true },
		toggle("Show where items come from in tooltips", "tooltip"),
		toggle("Announce wishlist items when they drop", "alerts"),
		toggle("Open on the instance I am in", "autoselect"),
		{
			text = "Minimap button", checked = ACore.MinimapShown(),
			func = function() ACore.SetMinimap(not ACore.MinimapShown()) end,
		},
		{ text = "Window size", title = true },
	}
	for _, s in ipairs({ 0.8, 0.9, 1, 1.1, 1.2, 1.35 }) do
		entries[#entries + 1] = {
			text = math.floor(s * 100 + 0.5) .. "%", checked = math.abs(db.scale - s) < 0.01,
			func = function()
				db.scale = s
				frame:SetScale(s)
			end,
		}
	end
	UI.Menu(anchor, entries)
end

local function wishMenu(anchor)
	local entries = { { text = "Wishlists", title = true } }
	local _, active = Wish.Active()
	for i, list in ipairs(Wish.Lists()) do
		entries[#entries + 1] = {
			text = list.name .. "  (" .. Wish.Count(list) .. ")", checked = i == active,
			func = function() Wish.Select(i) end,
		}
	end
	entries[#entries + 1] = { text = "Manage", title = true }
	entries[#entries + 1] = { text = "New list...", func = function() UI.Prompt("Name of the new wishlist", "", Wish.New) end }
	entries[#entries + 1] = { text = "Rename this list...", func = function() UI.Prompt("New name", Wish.Active().name, Wish.Rename) end }
	entries[#entries + 1] = {
		text = "Delete this list", color = { 0.9, 0.4, 0.4 },
		func = function()
			UI.Confirm("Delete the wishlist \"" .. Wish.Active().name .. "\"?", Wish.Delete)
		end,
	}
	UI.Menu(anchor, entries)
end

local function build()
	frame = CreateFrame("Frame", "ALootFrame", UIParent)
	frame:SetSize(1000, 640)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:Hide()
	UI.Fill(frame, C.bg)
	UI.Border(frame, { 0, 0, 0, 1 })
	if UISpecialFrames then table.insert(UISpecialFrames, "ALootFrame") end

	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(40)
	UI.Fill(bar, C.bar)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() frame:StartMoving() end)
	bar:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, rel, x, y = frame:GetPoint(1)
		ns.db.pos = { point, rel, x, y }
	end)

	local title = UI.Text(bar, "GameFontNormalLarge", "LEFT", C.accent)
	title:SetPoint("LEFT", 14, 0)
	title:SetText("ALoot")

	local search = UI.EditBox(bar, "Search items, bosses, places", function(text)
		ns.Debounce("search", 0.2, function()
			local q = text:gsub("^%s+", ""):gsub("%s+$", "")
			if q == state.query then return end
			state.query = q
			state.stack = {}
			if q == "" then
				if state.view == "search" then state.view = state.before or "group" end
			else
				if state.view ~= "search" then state.before = state.view end
				state.view = "search"
			end
			UI.RefreshAll()
		end)
	end)
	search:SetPoint("LEFT", 212, 0)
	search:SetWidth(330)
	frame.search = search

	local all = UI.Button(bar, "All loot", function()
		state.stack = {}
		if state.query ~= "" then
			state.query = ""
			state.before = "all"
			frame.search.box:SetText("")
			frame.search.box:ClearFocus()
		end
		if state.view == "all" then
			state.view = "group"
		else
			state.view = "all"
		end
		UI.RefreshAll()
	end)
	all:SetPoint("LEFT", search, "RIGHT", 6, 0)
	frame.allButton = all

	local close = UI.Button(bar, "x", function() frame:Hide() end)
	close:SetPoint("RIGHT", -8, 0)
	close:SetWidth(26)

	local options = UI.Button(bar, "Options", function(self) optionsMenu(self) end)
	options:SetPoint("RIGHT", close, "LEFT", -6, 0)

	local wish = UI.Button(bar, "Wishlist", function(self, button)
		if button == "RightButton" then
			wishMenu(self)
			return
		end
		state.stack = {}
		if state.view == "wishlist" then
			state.view = "group"
		else
			state.view = "wishlist"
		end
		UI.RefreshAll()
	end)
	wish:SetPoint("RIGHT", options, "LEFT", -6, 0)
	frame.wishButton = wish

	local nav = CreateFrame("Frame", nil, frame)
	nav:SetPoint("TOPLEFT", 0, -40)
	nav:SetPoint("BOTTOMLEFT", 0, 22)
	nav:SetWidth(204)
	UI.Fill(nav, C.panel)

	frame.moduleButtons = {}
	for i, mod in ipairs(ns.MODULES) do
		local b = UI.Button(nav, mod.title, function()
			state.module = mod.key
			UI.RefreshNav()
		end)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 25)
		b:SetPoint("RIGHT", nav, "RIGHT", -6, 0)
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", 10, 0)
		b.key = mod.key
		frame.moduleButtons[i] = b
	end

	local navList = UI.List(nav, 22, createNavRow, updateNavRow)
	navList:SetPoint("TOPLEFT", 0, -12 - #ns.MODULES * 25)
	navList:SetPoint("BOTTOMRIGHT", 0, 4)
	frame.navList = navList

	local sec = CreateFrame("Frame", nil, frame)
	sec:SetPoint("TOPLEFT", nav, "TOPRIGHT", 1, 0)
	sec:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 1, 0)
	sec:SetWidth(214)
	UI.Fill(sec, C.panel)

	local head = UI.Text(sec, "GameFontNormal", "LEFT", C.accent)
	head:SetPoint("TOPLEFT", 10, -10)
	head:SetPoint("RIGHT", -8, 0)
	frame.groupTitle = head
	local headSub = UI.Text(sec, "GameFontDisableSmall", "LEFT", C.dim)
	headSub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -3)
	headSub:SetPoint("RIGHT", -8, 0)
	frame.groupSub = headSub

	local secList = UI.List(sec, 28, createSectionRow, updateSectionRow)
	secList:SetPoint("TOPLEFT", 0, -46)
	secList:SetPoint("BOTTOMRIGHT", 0, 4)
	frame.sectionList = secList

	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", sec, "TOPRIGHT", 1, 0)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 22)

	local tools = CreateFrame("Frame", nil, content)
	tools:SetPoint("TOPLEFT")
	tools:SetPoint("TOPRIGHT")
	tools:SetHeight(36)
	UI.Fill(tools, { 0.075, 0.08, 0.1, 1 })

	local back = UI.Button(tools, "< Back", function()
		table.remove(state.stack)
		UI.RefreshContent()
	end)
	back:SetPoint("LEFT", 8, 0)
	frame.back = back

	local viewTitle = UI.Text(tools, "GameFontNormal", "LEFT", C.text)
	viewTitle:SetPoint("LEFT", 10, 0)
	frame.viewTitle = viewTitle

	local slotButton = UI.Button(tools, "All slots", function(self) slotMenu(self) end)
	slotButton:SetPoint("RIGHT", -10, 0)
	frame.slotButton = slotButton
	local armorButton = UI.Button(tools, "All armor", function(self) armorMenu(self) end)
	armorButton:SetPoint("RIGHT", slotButton, "LEFT", -6, 0)
	frame.armorButton = armorButton
	local classButton = UI.Button(tools, "All classes", function(self) classMenu(self) end)
	classButton:SetPoint("RIGHT", armorButton, "LEFT", -6, 0)
	frame.classButton = classButton
	local listButton = UI.Button(tools, "Lists", function(self) wishMenu(self) end)
	listButton:SetPoint("RIGHT", classButton, "LEFT", -6, 0)
	frame.listButton = listButton

	frame.diffButtons = {}
	for i = 1, 4 do
		local b = UI.Button(tools, "", function(self)
			state.diff = self.diff
			UI.RefreshContent()
		end)
		frame.diffButtons[i] = b
	end
	viewTitle:SetPoint("RIGHT", listButton, "LEFT", -8, 0)

	local loot = UI.List(content, 38, createLootRow, updateLootRow)
	loot:SetPoint("TOPLEFT", 0, -38)
	loot:SetPoint("BOTTOMRIGHT", 0, 2)
	frame.lootList = loot

	local foot = CreateFrame("Frame", nil, frame)
	foot:SetPoint("BOTTOMLEFT")
	foot:SetPoint("BOTTOMRIGHT")
	foot:SetHeight(22)
	UI.Fill(foot, C.bar)
	local hint = UI.Text(foot, "GameFontDisableSmall", "LEFT", C.dim)
	hint:SetPoint("LEFT", 10, 0)
	hint:SetText("Click: details    Shift-click: link    Ctrl-click: try on    Alt-click or star: wishlist    Right-click: sources")
	local count = UI.Text(foot, "GameFontDisableSmall", "RIGHT", C.dim)
	count:SetPoint("RIGHT", -10, 0)
	frame.count = count

	frame:SetScale(ns.db.scale or 1)
	local pos = ns.db.pos
	frame:ClearAllPoints()
	if pos and pos[1] then
		frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
	else
		frame:SetPoint("CENTER")
	end

	frame:SetScript("OnHide", function()
		UI.CloseMenu()
		GameTooltip:Hide()
	end)
end

function UI.RefreshNav()
	if not frame then return end
	for _, b in ipairs(frame.moduleButtons) do
		b:SetActive(b.key == state.module)
	end
	frame.navList:SetData(navData(), frame.navModule == state.module)
	frame.navModule = state.module
end

function UI.RefreshSections()
	if not frame then return end
	local g = currentGroup()
	if g then
		frame.groupTitle:SetText(g.name)
		local parts = { g.cat }
		if g.tag then parts[#parts + 1] = g.tag end
		local level = ns.LevelText(g)
		if level then parts[#parts + 1] = "level " .. level end
		frame.groupSub:SetText(table.concat(parts, "  ·  "))
	else
		frame.groupTitle:SetText("")
		frame.groupSub:SetText("")
	end
	frame.sectionList:SetData(sectionData(), frame.sectionGroup == state.groupId)
	frame.sectionGroup = state.groupId
end

function UI.RefreshContent(keep)
	if not frame or not frame:IsShown() then return end
	local g = currentGroup()
	local top = state.stack[#state.stack]
	local rows, titleText
	local showDiffs = false
	if top then
		rows = top.build()
		titleText = top.title
	elseif state.view == "search" then
		local found, total = ns.Search(state.query, filter())
		rows = found
		titleText = "Search: " .. state.query .. "  (" .. total .. ")"
		if #rows == 0 then
			rows = { { kind = "note", text = "Nothing found. Check the class, armor and slot filters." } }
		end
	elseif state.view == "all" then
		local found, total = ns.Search("", filter(), true)
		rows = found
		titleText = "All loot  (" .. total .. ")"
		if #rows == 0 then
			rows = { { kind = "note", text = "Nothing matches the current filters." } }
		end
	elseif state.view == "wishlist" then
		rows = Wish.Rows(filter())
		local list = Wish.Active()
		titleText = list.name .. "  (" .. Wish.Count(list) .. ")"
	elseif g then
		if not state.diff then state.diff = ns.DefaultDiff(g) end
		rows = ns.GroupRows(g, state.section, state.diff, filter())
		if #rows == 0 then
			rows = { { kind = "note", text = "Nothing here matches the current filters." } }
		end
		if state.section then
			titleText = ns.SectionName(g.sections[state.section])
		else
			titleText = g.name
		end
		showDiffs = #g.diffs > 1
	else
		rows = { { kind = "note", text = "Pick something on the left, or type in the search box." } }
		titleText = ""
	end

	frame.back:SetShown(top ~= nil)
	frame.viewTitle:ClearAllPoints()
	if top then
		frame.viewTitle:SetPoint("LEFT", frame.back, "RIGHT", 10, 0)
	else
		frame.viewTitle:SetPoint("LEFT", 10, 0)
	end
	frame.listButton:SetShown(state.view == "wishlist" and not top)

	local anchor = frame.listButton:IsShown() and frame.listButton or frame.classButton
	local shown = 0
	for i, b in ipairs(frame.diffButtons) do
		local d = showDiffs and not top and g.diffs[#g.diffs - i + 1]
		if d then
			b.diff = d[1]
			b:SetLabel(ns.Resolve(d[2], d[1]))
			b:SetActive(state.diff == d[1])
			b:ClearAllPoints()
			b:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
			b:Show()
			anchor = b
			shown = shown + 1
		else
			b:Hide()
		end
	end
	frame.viewTitle:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
	frame.viewTitle:SetText(titleText or "")

	frame.classButton:SetLabel(classLabel())
	frame.classButton:SetActive(ns.db.classFilter ~= "ALL")
	frame.slotButton:SetLabel(slotLabel())
	frame.slotButton:SetActive(state.slot ~= "ALL")
	frame.armorButton:SetLabel(ns.ArmorName(state.armor))
	frame.armorButton:SetActive(state.armor ~= "ALL")
	frame.allButton:SetActive(state.view == "all")
	frame.wishButton:SetLabel("Wishlist (" .. Wish.Count() .. ")")
	frame.wishButton:SetActive(state.view == "wishlist")

	local items = 0
	for _, r in ipairs(rows) do
		if r.kind == "item" or r.kind == "spell" or r.kind == "set" then items = items + 1 end
	end
	frame.count:SetText(items .. (items == 1 and " entry" or " entries"))
	frame.lootList:SetData(rows, keep)
end

function UI.RefreshAll(keep)
	UI.RefreshNav()
	UI.RefreshSections()
	UI.RefreshContent(keep)
end

function UI.Go(group, section)
	if not group then return end
	if state.groupId ~= group.id then state.diff = nil end
	state.module = group.module
	state.groupId = group.id
	state.section = section
	state.view = "group"
	state.stack = {}
	if state.query ~= "" and frame then
		state.query = ""
		frame.search.box:SetText("")
		frame.search.box:ClearFocus()
	end
	UI.RefreshAll()
	if frame then
		for i, d in ipairs(frame.navList.data) do
			if d.group == group then
				local list = frame.navList
				if i <= list.offset or i > list.offset + list:Visible() then
					list:ScrollTo(math.max(1, i - 3))
				end
				break
			end
		end
	end
end

local lastAuto
local function autoSelect()
	if not ns.db.autoselect then return false end
	if not IsInInstance or not GetInstanceInfo then return false end
	local ok, inInstance = pcall(IsInInstance)
	if not ok or not inInstance then
		lastAuto = nil
		return false
	end
	local ok2, _, _, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
	if not ok2 or type(instanceID) ~= "number" or ns.IsSecret(instanceID) then return false end
	if lastAuto == instanceID then return false end
	local g = ns.GroupByInstance(instanceID)
	if not g then return false end
	lastAuto = instanceID
	UI.Go(g, nil)
	return true
end

local warmed = false
local function warm()
	if warmed then return end
	warmed = true
	local queue = ns.UnnamedItems()
	local i = 0
	local function step()
		local n = 0
		while i < #queue and n < 12 do
			i = i + 1
			ns.Item(queue[i])
			n = n + 1
		end
		if i < #queue then ns.After(0.3, step) end
	end
	ns.After(1, step)
end

function UI.Show()
	if not ns.db then return end
	if not frame then build() end
	if not state.groupId then
		local cats = ns.Categories(state.module)
		local first = cats[1] and cats[1].groups[1]
		if first then state.groupId = first.id end
	end
	frame:Show()
	if not autoSelect() then UI.RefreshAll(true) end
	warm()
end

function UI.Hide()
	if frame then frame:Hide() end
end

function UI.Toggle()
	if frame and frame:IsShown() then
		UI.Hide()
	else
		UI.Show()
	end
end

function UI.SetSearch(text)
	if not frame then return end
	frame.search.box:SetText(text or "")
end

ns:Listen("ITEMS_UPDATED", function()
	if frame and frame:IsShown() then UI.RefreshContent(true) end
end)

ns:Listen("WISHLIST_CHANGED", function()
	if frame and frame:IsShown() then UI.RefreshAll(true) end
end)

ns:Listen("LAYOUT_RESET", function()
	if not frame then return end
	frame:SetScale(1)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER")
end)

ns:On("BAG_UPDATE_DELAYED", function()
	if frame and frame:IsShown() then
		ns.Debounce("bags", 0.5, function() UI.RefreshContent(true) end)
	end
end)
