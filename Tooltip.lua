local _, ns = ...

local function addLines(tooltip, id)
	if not ns.db or not ns.db.tooltip then return end
	if not id or ns.IsSecret(id) then return end
	local srcs = ns.Sources(id)
	local listName = ns.Wish.OnAny(id)
	if not srcs and not listName then return end
	if srcs then
		local shown = 0
		for _, src in ipairs(srcs) do
			if shown >= 3 then
				tooltip:AddLine("  +" .. (#srcs - shown) .. " more", 0.6, 0.6, 0.6)
				break
			end
			tooltip:AddLine(ns.SourceLabel(src), 0.55, 0.8, 1)
			shown = shown + 1
		end
	end
	if listName then
		tooltip:AddLine("On wishlist: " .. listName, 1, 0.82, 0)
	end
	tooltip:Show()
end

local function fromData(tooltip, data)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
	local id = data and data.id
	if type(id) ~= "number" then return end
	addLines(tooltip, id)
end

local function fromLegacy(tooltip)
	if not tooltip.GetItem then return end
	local _, link = tooltip:GetItem()
	if type(link) ~= "string" then return end
	local id = tonumber(link:match("item:(%d+)"))
	if id then addLines(tooltip, id) end
end

ns:Listen("LOGIN", function()
	local hooked = false
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		hooked = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tooltip, data)
			pcall(fromData, tooltip, data)
		end)
	end
	if not hooked and GameTooltip and GameTooltip.HookScript then
		pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(tooltip)
			pcall(fromLegacy, tooltip)
		end)
	end
end)
