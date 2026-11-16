local ADDON, ns = ...

ns.raw = { loot = {} }

local defaults = {
	scale = 1,
	tooltip = true,
	alerts = true,
	autoselect = true,
	classFilter = "ALL",
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

ACore.Register({
	name = "ALoot",
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
