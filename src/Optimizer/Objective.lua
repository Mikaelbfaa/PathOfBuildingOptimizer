-- Path of Building
--
-- Module: Optimizer Objective
-- Scores a build as a league starter. Hard constraints follow the criteria
-- extracted from expert tier lists (see docs/research/league-starters.md):
-- no reliance on uniques, functional on four links, capped resistances and a
-- defensive floor when measured with self found gear and an honest config.
-- Builds are evaluated at defined progression stages (early maps and midgame
-- by default) chosen from the build's own tree, item and skill sets, and the
-- stage scores are averaged. The weighted score bands below are modelling
-- priors, not sourced constants, meant to be tuned against known tier lists.
--

local objective = { }

-- Scoring bands and weights. Damage and pool bands are log scaled between
-- floor and ceiling. Weights sum to one.
objective.defaults = {
	enemy = "Pinnacle",
	ssf = true,
	trustConfig = false,
	maxUniques = 2,
	constraintPenalty = 0.5,
	stages = { "earlyMaps", "midgame" },
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

-- Progression stages a build is judged at. Keywords are matched against
-- tree, item set and skill set titles, earlier entries first.
objective.stages = {
	earlyMaps = {
		name = "earlyMaps",
		level = 82,
		keywords = { "early map", "entering map", "early game", "earlygame", "mapping", "early" },
	},
	midgame = {
		name = "midgame",
		level = 90,
		keywords = { "midgame", "mid game", "mid" },
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

-- Picks the candidate whose title or point count best matches the stage.
-- Candidates are { key, title, points } tables. A title keyword match
-- dominates; ties break on distance between the stage level and the level
-- evidenced by a number in the title or estimated from allocated points
-- (points is roughly level minus 19 once quest points are counted).
-- Returns nil when no candidate offers any signal at all.
function objective.chooseStageCandidate(candidates, stageDef)
	local best, bestRank
	local anySignal = false
	for _, cand in ipairs(candidates) do
		local title = (cand.title or ""):lower()
		local kwRank
		for i, keyword in ipairs(stageDef.keywords) do
			if title:find(keyword, 1, true) then
				kwRank = i
				break
			end
		end
		local level = tonumber(title:match("(%d+)"))
		if level and (level < 1 or level > 100) then
			level = nil
		end
		if not level and cand.points and cand.points > 0 then
			level = clamp(cand.points + 19, 1, 100)
		end
		if kwRank or level then
			anySignal = true
		end
		local levelDist = level and math.abs(level - stageDef.level) or 50
		local rank = (kwRank or 100) * 1000 + levelDist
		if not bestRank or rank < bestRank then
			bestRank = rank
			best = cand
		end
	end
	if not anySignal then
		return nil
	end
	return best
end

-- Switches the build to the tree, item set and skill set that best match the
-- given stage, sets the character level, and re-guesses the main socket
-- group. Returns a description of what was selected.
function objective.selectProgressionStage(build, stageDef)
	local selection = { stage = stageDef.name, level = stageDef.level }
	local specCands = { }
	for i, spec in ipairs(build.treeTab.specList) do
		table.insert(specCands, { key = i, title = spec.title, points = spec:CountAllocNodes() })
	end
	local chosen = objective.chooseStageCandidate(specCands, stageDef)
	if chosen then
		build.treeTab:SetActiveSpec(chosen.key)
		selection.spec = chosen.title or ("spec " .. chosen.key)
	end
	local itemCands = { }
	for _, setId in ipairs(build.itemsTab.itemSetOrderList) do
		table.insert(itemCands, { key = setId, title = build.itemsTab.itemSets[setId].title })
	end
	chosen = objective.chooseStageCandidate(itemCands, stageDef)
	if chosen then
		build.itemsTab:SetActiveItemSet(chosen.key)
		selection.itemSet = chosen.title or ("set " .. tostring(chosen.key))
	end
	local skillCands = { }
	for _, setId in ipairs(build.skillsTab.skillSetOrderList) do
		table.insert(skillCands, { key = setId, title = build.skillsTab.skillSets[setId].title })
	end
	chosen = objective.chooseStageCandidate(skillCands, stageDef)
	if chosen then
		build.skillsTab:SetActiveSkillSet(chosen.key)
		selection.skillSet = chosen.title or ("set " .. tostring(chosen.key))
	end
	build.characterLevel = stageDef.level
	build.characterLevelAutoMode = false
	build.mainSocketGroup = build.importTab:GuessMainSocketGroup()
	build.buildFlag = true
	runCallback("OnFrame")
	local env = build.calcsTab.mainEnv
	if env and env.player.mainSkill and env.player.mainSkill.activeEffect then
		selection.mainSkill = env.player.mainSkill.activeEffect.grantedEffect.name
	end
	return selection
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
-- gems are legal, they only require a Labyrinth run.
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

-- Measures how much combined DPS survives replacing the main weapon with a
-- plain white item of the same base. This captures gear agnosticism across
-- all delivery methods: spell totems, minions, DoT and gem level scaling
-- keep their damage, while weapon scaled attacks lose most of theirs.
function objective.measureWeaponIndependence(build)
	local slot = build.itemsTab.slots["Weapon 1"]
	local item = slot and build.itemsTab.items[slot.selItemId]
	if not item or not item.baseName then
		return 1
	end
	local calcFunc, calcBase = build.calcsTab:GetMiscCalculator()
	local baseDPS = getStat(calcBase, "CombinedDPS")
	if baseDPS <= 0 then
		return 0
	end
	local whiteItem = new("Item"):Item("Rarity: NORMAL\n" .. item.baseName)
	local output = calcFunc({ repSlotName = "Weapon 1", repItem = whiteItem })
	return clamp(getStat(output, "CombinedDPS") / baseDPS, 0, 1)
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
function objective.computeSubscores(build, linkDelta, weaponIndependence, options)
	local output = build.calcsTab.mainOutput
	local combinedDPS = getStat(output, "CombinedDPS")
	local pool = math.max((output.Life or 0) + (output.EnergyShield or 0), 1)
	local lifeRegen = output.NetLifeRegen or output.LifeRegenRecovery or output.LifeRegen or 0
	local esRegen = output.NetEnergyShieldRegen or output.EnergyShieldRegenRecovery or output.EnergyShieldRegen or 0
	local leech = (output.LifeLeechRate or 0) + (output.EnergyShieldLeechRate or 0)
	local recoveryRate = (math.max(lifeRegen, 0) + math.max(esRegen, 0) + leech) / pool
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
		gearAgnostic = weaponIndependence or 0,
		linkRatio = linkDelta and linkDelta.ratio or 0,
	}
end

-- Full league start evaluation pipeline. For each configured stage: switch
-- the build to that stage, normalize the config (kept as authored when
-- options.trustConfig is set, for guides from trusted sources), apply the
-- self found template gear, measure and score. Failed hard constraints
-- multiply the stage score by options.constraintPenalty each. The final
-- score is the mean over stages. This mutates the loaded build, reload it
-- afterwards if the original state matters.
function objective.evaluateLeagueStart(build, options)
	options = options or { }
	for key, value in pairs(objective.defaults) do
		if options[key] == nil then
			options[key] = value
		end
	end
	local config = dofile("Optimizer/Config.lua")
	local stageResults = { }
	local totalScore = 0
	local avgSubscores = { }
	for _, stageName in ipairs(options.stages) do
		local stageDef = objective.stages[stageName]
		local selection = objective.selectProgressionStage(build, stageDef)
		local strippedConfig = config.normalizeConfig(build, { enemy = options.enemy, keepInputs = options.trustConfig })
		local replacedGear
		if options.ssf then
			replacedGear = config.applySSFTemplateGear(build)
		end
		local linkDelta = objective.measureLinkDelta(build)
		local weaponIndependence = objective.measureWeaponIndependence(build)
		local constraints = objective.checkConstraints(build, options)
		local subscores = objective.computeSubscores(build, linkDelta, weaponIndependence, options)
		local rawScore = 0
		for key, weight in pairs(options.weights) do
			rawScore = rawScore + weight * (subscores[key] or 0)
			avgSubscores[key] = (avgSubscores[key] or 0) + (subscores[key] or 0) / #options.stages
		end
		local penalty = 1
		for _, constraint in pairs(constraints) do
			if not constraint.pass then
				penalty = penalty * options.constraintPenalty
			end
		end
		stageResults[stageName] = {
			selection = selection,
			subscores = subscores,
			rawScore = rawScore,
			penalty = penalty,
			score = rawScore * penalty,
			constraints = constraints,
			linkDelta = linkDelta,
			strippedConfig = strippedConfig,
			replacedGear = replacedGear,
		}
		totalScore = totalScore + rawScore * penalty
	end
	local firstStage = stageResults[options.stages[1]]
	return {
		score = totalScore / #options.stages,
		subscores = avgSubscores,
		constraints = firstStage.constraints,
		linkDelta = firstStage.linkDelta,
		replacedGear = firstStage.replacedGear,
		stages = stageResults,
		stageOrder = options.stages,
	}
end

return objective
