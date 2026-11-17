local ADDON, ns = ...

ns.raw = { loot = {} }

local defaults = {
	scale = 1,
	tooltip = true,
	alerts = true,
	autoselect = true,
	classFilter = "ALL",
	needed = false,
	lists = { { name = "Wishlist", items = {} } },
}

local charDefaults = {
	list = 1,
}

ACore.New(ADDON, ns, { db = "ALootDB", defaults = defaults, profile = true, shared = { "lists" }, char = "ALootCharDB", charDefaults = charDefaults })

ns:Listen("READY", function()
	if #ns.db.lists == 0 then
		ns.db.lists[1] = { name = "Wishlist", items = {} }
	end
end)

function ns.Options()
	local db = ns.db
	local UI = ns.UI
	local function changed() ns:Fire("OPTIONS") end
	local entries = {
		{ text = "Options", title = true },
		UI.Check(db, "tooltip", "Show where items come from in tooltips"),
		UI.Check(db, "alerts", "Announce wishlist items when they drop"),
		UI.Check(db, "autoselect", "Open on the instance I am in"),
		UI.Check(db, "needed", "Only show what I can use and do not own", changed),
		{
			text = "Minimap button", checked = ACore.MinimapShown(),
			func = function() ACore.SetMinimap(not ACore.MinimapShown()) end,
		},
		{ text = "Window size", title = true },
	}
	for _, s in ipairs({ 0.8, 0.9, 1, 1.1, 1.2, 1.35 }) do
		entries[#entries + 1] = {
			text = math.floor(s * 100 + 0.5) .. "%", checked = math.abs((db.scale or 1) - s) < 0.01,
			func = function()
				db.scale = s
				changed()
			end,
		}
	end
	return entries
end

ACore.Register({
	name = "ALoot",
	options = function() return ns.Options() end,
	title = "ALoot",
	slash = "/aloot",
	desc = "loot browser",
	toggle = function() ns.UI.Toggle() end,
})

SLASH_ALOOT1 = "/aloot"
SLASH_ALOOT2 = "/al"
SlashCmdList["ALOOT"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" then
		ns.UI.Toggle()
	elseif msg == "minimap" then
		ACore.SetMinimap(not ACore.MinimapShown())
	elseif msg == "reset" then
		ns.db.scale = 1
		ns.db.pos = nil
		ns:Fire("LAYOUT_RESET")
	else
		ns.UI.Show()
		ns.UI.SetSearch(msg)
	end
end

function ALoot_OnCompartmentClick()
	ns.UI.Toggle()
end

BINDING_HEADER_ALOOT = "ALoot"
BINDING_NAME_ALOOT_TOGGLE = "Toggle ALoot"
function ALoot_ToggleBinding()
	ns.UI.Toggle()
end
