-- Path of Building
--
-- Module: Optimizer Config
-- Normalizes a build for honest benchmarking. Resets configuration inputs to
-- their defaults so that scores do not depend on optimistic toggles, and can
-- replace equipped gear with modest self found template rares to measure the
-- league start floor of a build.
--

local config = { }

-- Configuration vars that define the build itself rather than describe a
-- combat situation, kept when normalizing
local preservedVars = {
	bandit = true,
	pantheonMajorGod = true,
	pantheonMinorGod = true,
	detonateDeadCorpseLife = true,
}

-- Resets every non preserved config input to its default value, disables all
-- custom modifier blocks, and optionally sets the enemy benchmark through
-- options.enemy (None, Boss, Pinnacle or Uber; the default is Pinnacle).
-- Returns a table of the stripped inputs for reporting.
function config.normalizeConfig(build, options)
	options = options or { }
	local configTab = build.configTab
	local stripped = { }
	local varNames = { }
	for var in pairs(configTab.input) do
		table.insert(varNames, var)
	end
	for _, var in ipairs(varNames) do
		if not preservedVars[var] then
			local value = configTab.input[var]
			local default = configTab:GetDefaultState(var, type(value))
			if value ~= default then
				stripped[var] = value
				configTab.input[var] = default
			end
		end
	end
	local configSet = configTab.configSets[configTab.activeConfigSetId]
	if configSet.customModsList then
		for _, block in ipairs(configSet.customModsList) do
			if block.enabled ~= false and block.text and #block.text > 0 then
				stripped.customModsList = stripped.customModsList or { }
				table.insert(stripped.customModsList, block.text)
				block.enabled = false
			end
		end
	end
	if options.enemy then
		configTab.input.enemyIsBoss = options.enemy
	end
	configTab:BuildModList()
	build.buildFlag = true
	runCallback("OnFrame")
	return stripped
end

-- Template rares approximating what a self found character wears when first
-- entering maps: flat life everywhere, mostly capped resistances after the
-- minus sixty campaign penalty, movement speed on boots and nothing else.
-- Bases are low requirement so that any class can equip them. Weapons,
-- shields, flasks and jewels are deliberately kept, as they are what the
-- build is actually judged on at this stage.
local templateSlots = {
	{ slotName = "Helmet", raw = "Rarity: RARE\nOptimizer Template Helmet\nIron Hat\nImplicits: 0\n+70 to maximum Life\n+35% to Fire Resistance\n+35% to Cold Resistance" },
	{ slotName = "Body Armour", raw = "Rarity: RARE\nOptimizer Template Body\nSimple Robe\nImplicits: 0\n+80 to maximum Life\n+35% to Fire Resistance\n+35% to Cold Resistance" },
	{ slotName = "Gloves", raw = "Rarity: RARE\nOptimizer Template Gloves\nIron Gauntlets\nImplicits: 0\n+60 to maximum Life\n+30% to Cold Resistance\n+30% to Lightning Resistance" },
	{ slotName = "Boots", raw = "Rarity: RARE\nOptimizer Template Boots\nIron Greaves\nImplicits: 0\n+60 to maximum Life\n25% increased Movement Speed\n+30% to Fire Resistance" },
	{ slotName = "Belt", raw = "Rarity: RARE\nOptimizer Template Belt\nLeather Belt\nImplicits: 1\n+30 to maximum Life\n+70 to maximum Life\n+35% to Cold Resistance\n+35% to Lightning Resistance" },
	{ slotName = "Amulet", raw = "Rarity: RARE\nOptimizer Template Amulet\nCoral Amulet\nImplicits: 1\nRegenerate 3 Life per second\n+60 to maximum Life\n+25 to all Attributes\n+30% to Lightning Resistance" },
	{ slotName = "Ring 1", raw = "Rarity: RARE\nOptimizer Template Ring\nCoral Ring\nImplicits: 1\n+25 to maximum Life\n+50 to maximum Life\n+30% to Fire Resistance\n+30% to Lightning Resistance" },
	{ slotName = "Ring 2", raw = "Rarity: RARE\nOptimizer Template Ring\nCoral Ring\nImplicits: 1\n+25 to maximum Life\n+50 to maximum Life\n+30% to Cold Resistance\n+30% to Lightning Resistance" },
}

-- Replaces the armour and jewellery slots with the template rares above.
-- Returns a table mapping slot names to the names of the replaced items.
function config.applySSFTemplateGear(build)
	local itemsTab = build.itemsTab
	local replaced = { }
	for _, template in ipairs(templateSlots) do
		local slot = itemsTab.slots[template.slotName]
		if slot then
			local prevItem = itemsTab.items[slot.selItemId]
			replaced[template.slotName] = prevItem and prevItem.name or "empty"
			itemsTab:CreateDisplayItemFromRaw(template.raw)
			local item = itemsTab.displayItem
			itemsTab:AddDisplayItem(true)
			slot:SetSelItemId(item.id)
		end
	end
	itemsTab:PopulateSlots()
	build.buildFlag = true
	runCallback("OnFrame")
	return replaced
end

return config
