-- Path of Building
--
-- Module: Optimizer Objective
-- Scores a build as a league starter. Hard constraints follow the criteria
-- extracted from expert tier lists (see docs/research/league-starters.md):
-- no reliance on uniques, functional on four links, capped resistances and a
-- defensive floor when measured with self found gear and an honest config.
-- The weighted score bands below are modelling priors, not sourced constants,
-- and are meant to be tuned against known tier lists.
--

local objective = { }

-- Scoring bands and weights. Damage and pool bands are log scaled between
-- floor and ceiling. Weights sum to one.
objective.defaults = {
	enemy = "Pinnacle",
	ssf = true,
	maxUniques = 2,
	damageFloor = 50000, damageCeiling = 2000000,
	maxHitFloor = 3000, maxHitCeiling = 15000,
	ehpFloor = 15000, ehpCeiling = 80000,
	recoveryCap = 0.30,
	weights = {
		damage = 0.20,
		maxHit = 0.15,
		ehp = 0.10,
		recovery = 0.10,
		resistances = 0.10,
		chaosRes = 0.05,
		gearAgnostic = 0.15,
		linkRatio = 0.15,
	},
}

local function clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

-- Log scaled normalization of value between floor and ceiling
local function logScore(value, floor, ceiling)
	if not value or value <= 0 then
		return 0
	end
	return clamp(math.log(value / floor) / math.log(ceiling / floor), 0, 1)
end

local function getStat(output, statName)
	return data.powerStatList.GetFromOutput(output, { stat = statName }, true)
end

-- Lists the unique items equipped in the active item set
function objective.listEquippedUniques(build)
	local uniques = { }
	for _, slot in ipairs(build.itemsTab.orderedSlots) do
		local item = build.itemsTab.items[slot.selItemId]
		if item and (item.rarity == "UNIQUE" or item.rarity == "RELIC") then
			table.insert(uniques, { slot = slot.label or slot.slotName, name = item.title or item.name })
		end
	end
	return uniques
end

-- Flags gems that are not obtainable at league start: levels above twenty,
-- quality above twenty and Awakened or Exceptional supports. Transfigured
-- gems are legal, they only require Labyrinth runs.
function objective.listGemFlags(build)
	local flags = { }
	for groupIndex, group in ipairs(build.skillsTab.socketGroupList) do
		for _, gemInstance in ipairs(group.gemList) do
			if gemInstance.gemData and gemInstance.enabled then
				local name = gemInstance.nameSpec or "?"
				if name:match("^Awakened") then
					table.insert(flags, name .. " is an Awakened gem")
				elseif gemInstance.gemData.tagString and gemInstance.gemData.tagString:match("Exceptional") then
					table.insert(flags, name .. " is an Exceptional support")
				end
				if (gemInstance.level or 1) > 20 and not name:match("^Awakened") then
					table.insert(flags, name .. " is level " .. gemInstance.level .. ", corruption needed")
				end
				if (gemInstance.quality or 0) > 20 then
					table.insert(flags, name .. " has " .. gemInstance.quality .. " quality")
				end
			end
		end
	end
	return flags
end

-- Measures how much of the main socket group damage survives on four links.
-- Keeps the three first enabled supports, which guides usually order by
-- importance, disables the rest and compares combined DPS. Restores the
-- group afterwards. Returns nil when the build has no main socket group.
function objective.measureLinkDelta(build)
	local group = build.skillsTab.socketGroupList[build.mainSocketGroup]
	if not group then
		return nil
	end
	local fullDPS = getStat(build.calcsTab.mainOutput, "CombinedDPS")
	local disabled = { }
	local supportCount = 0
	for _, gemInstance in ipairs(group.gemList) do
		if gemInstance.gemData and gemInstance.enabled and gemInstance.gemData.grantedEffect
				and gemInstance.gemData.grantedEffect.support then
			supportCount = supportCount + 1
			if supportCount > 3 then
				gemInstance.enabled = false
				table.insert(disabled, gemInstance)
			end
		end
	end
	local fourLinkDPS = fullDPS
	if #disabled > 0 then
		build.buildFlag = true
		runCallback("OnFrame")
		fourLinkDPS = getStat(build.calcsTab.mainOutput, "CombinedDPS")
		for _, gemInstance in ipairs(disabled) do
			gemInstance.enabled = true
		end
		build.buildFlag = true
		runCallback("OnFrame")
	end
	return {
		fullDPS = fullDPS,
		fourLinkDPS = fourLinkDPS,
		ratio = fullDPS > 0 and fourLinkDPS / fullDPS or 0,
	}
end

-- Hard constraint checks. Each entry has pass and detail fields.
function objective.checkConstraints(build, options)
	local output = build.calcsTab.mainOutput
	local uniques = objective.listEquippedUniques(build)
	local gemFlags = objective.listGemFlags(build)
	local minEleRes = math.min(output.FireResist or 0, output.ColdResist or 0, output.LightningResist or 0)
	return {
		uniques = {
			pass = #uniques <= options.maxUniques,
			count = #uniques,
			list = uniques,
		},
		resistances = {
			pass = minEleRes >= 75,
			minimum = minEleRes,
		},
		gems = {
			pass = #gemFlags == 0,
			flags = gemFlags,
		},
	}
end

-- Computes the weighted subscores from the current calc output
function objective.computeSubscores(build, linkDelta, options)
	local output = build.calcsTab.mainOutput
	local combinedDPS = getStat(output, "CombinedDPS")
	local dotDPS = getStat(output, "TotalDot")
	local minionDPS = output.Minion and output.Minion.CombinedDPS or 0
	local pool = math.max((output.Life or 0) + (output.EnergyShield or 0), 1)
	local recoveryRate = ((output.TotalNetRegen or 0) + (output.LifeLeechRate or 0)) / pool
	local resShortfall = 0
	for _, statName in ipairs({ "FireResist", "ColdResist", "LightningResist" }) do
		resShortfall = resShortfall + math.max(0, 75 - (output[statName] or 0))
	end
	return {
		damage = logScore(combinedDPS, options.damageFloor, options.damageCeiling),
		maxHit = logScore(output.SecondMinimalMaximumHitTaken, options.maxHitFloor, options.maxHitCeiling),
		ehp = logScore(output.TotalEHP, options.ehpFloor, options.ehpCeiling),
		recovery = clamp(recoveryRate / options.recoveryCap, 0, 1),
		resistances = clamp(1 - resShortfall / 135, 0, 1),
		chaosRes = clamp(((output.ChaosResist or -60) + 60) / 135, 0, 1),
		gearAgnostic = combinedDPS > 0 and clamp((dotDPS + minionDPS) / combinedDPS, 0, 1) or 0,
		linkRatio = linkDelta and linkDelta.ratio or 0,
	}
end

-- Full league start evaluation pipeline: normalizes the config, optionally
-- swaps in the self found template gear, measures the link delta and scores
-- the result. This mutates the loaded build, reload it afterwards if the
-- original state matters.
function objective.evaluateLeagueStart(build, options)
	options = options or { }
	for key, value in pairs(objective.defaults) do
		if options[key] == nil then
			options[key] = value
		end
	end
	local config = dofile("Optimizer/Config.lua")
	local strippedConfig = config.normalizeConfig(build, { enemy = options.enemy })
	local replacedGear
	if options.ssf then
		replacedGear = config.applySSFTemplateGear(build)
	end
	local linkDelta = objective.measureLinkDelta(build)
	local constraints = objective.checkConstraints(build, options)
	local subscores = objective.computeSubscores(build, linkDelta, options)
	local score = 0
	for key, weight in pairs(options.weights) do
		score = score + weight * (subscores[key] or 0)
	end
	return {
		score = score,
		subscores = subscores,
		constraints = constraints,
		linkDelta = linkDelta,
		strippedConfig = strippedConfig,
		replacedGear = replacedGear,
	}
end

return objective
