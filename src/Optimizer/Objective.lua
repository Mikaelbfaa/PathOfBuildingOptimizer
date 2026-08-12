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
	-- Effective boss uptime by damage delivery. PoB DPS assumes perfect
	-- uptime; melee must disengage for boss mechanics while totems, minions,
	-- traps and mines keep dealing damage during movement. These are the
	-- first uptime factors from docs/research/poe-fundamentals.md 5.5.
	uptimeFactors = { melee = 0.65, selfHit = 0.85, decoupled = 1.0 },
	maxHitFloor = 3000, maxHitCeiling = 15000,
	ehpFloor = 15000, ehpCeiling = 80000,
	recoveryCap = 0.30,
	-- Bands for the endgame damage ceiling, measured on the build's own
	-- late stage gear rather than the self found templates
	ceilingFloor = 500000, ceilingCeiling = 50000000,
	weights = {
		damage = 0.10,
		maxHit = 0.11,
		ehp = 0.06,
		recovery = 0.06,
		resistances = 0.07,
		chaosRes = 0.04,
		gearAgnostic = 0.13,
		linkRatio = 0.11,
		bossUptime = 0.11,
		damageCeiling = 0.04,
		clearFeel = 0.07,
		metaMomentum = 0.07,
		playstyleEase = 0.03,
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
	-- Only used for the damage ceiling measurement; aspirational setups are
	-- exactly what it wants to see
	ceiling = {
		name = "ceiling",
		level = 95,
		keywords = { "aspirational", "mirror", "min-max", "minmax", "endgame", "end game", "late" },
		allowExcluded = true,
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

-- Setups that describe post league start wealth; never valid stage picks
local excludedTitleKeywords = { "aspirational", "mirror", "min-max", "minmax", "min max" }

local function isExcludedTitle(title)
	for _, keyword in ipairs(excludedTitleKeywords) do
		if title:find(keyword, 1, true) then
			return true
		end
	end
	return false
end

-- Picks the candidate whose title or point count best matches the stage.
-- Candidates are { key, title, points } tables. Aspirational and mirror
-- tier setups are excluded outright. A title keyword match dominates; ties
-- break on distance between the stage level and the level evidenced by a
-- number in the title or estimated from allocated points (points is roughly
-- level minus 19 once quest points are counted). Returns nil when no
-- candidate offers any signal, plus "excluded" when nothing valid remains.
function objective.chooseStageCandidate(candidates, stageDef)
	local best, bestRank
	local anySignal = false
	local anyValid = false
	for _, cand in ipairs(candidates) do
		local title = (cand.title or ""):lower()
		if isExcludedTitle(title) and not stageDef.allowExcluded then
			goto continue
		end
		anyValid = true
		local kwRank
		for i, keyword in ipairs(stageDef.keywords) do
			if title:find(keyword, 1, true) then
				kwRank = i
				break
			end
		end
		local level = tonumber(title:match("(%d+)"))
		if level and (level < 10 or level > 100) then
			-- Small numbers in titles are stage counters (2 Stone, 4 Stone),
			-- not character levels
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
		::continue::
	end
	if not anyValid then
		return nil, "excluded"
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
	local chosen, reason = objective.chooseStageCandidate(specCands, stageDef)
	if chosen then
		build.treeTab:SetActiveSpec(chosen.key)
		selection.spec = chosen.title or ("spec " .. chosen.key)
	elseif reason == "excluded" then
		-- Only aspirational or mirror tier trees exist; the build carries no
		-- data for this progression stage and cannot be scored honestly
		selection.noStageData = true
		return selection
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
	build.buildFlag = true
	runCallback("OnFrame")
	build.mainSocketGroup = objective.guessMainSocketGroupByDPS(build)
	build.buildFlag = true
	runCallback("OnFrame")
	local env = build.calcsTab.mainEnv
	if env and env.player.mainSkill and env.player.mainSkill.activeEffect then
		selection.mainSkill = env.player.mainSkill.activeEffect.grantedEffect.name
	end
	return selection
end

-- Returns the socket group index with the highest combined DPS when used as
-- the main group. More reliable than PoB's largest-group guess, which picks
-- aura or leveling groups on multi-setup guide builds. Skips disabled
-- groups, weapon swap groups and groups without an enabled active gem.
function objective.guessMainSocketGroupByDPS(build)
	local originalGroup = build.mainSocketGroup
	local bestIndex, bestDPS
	for index, group in ipairs(build.skillsTab.socketGroupList) do
		local hasActive = false
		for _, gemInstance in ipairs(group.gemList) do
			if gemInstance.gemData and gemInstance.enabled and gemInstance.gemData.grantedEffect
					and not gemInstance.gemData.grantedEffect.support then
				hasActive = true
				break
			end
		end
		if hasActive and group.enabled ~= false and not (group.slot and group.slot:match("Swap")) then
			build.mainSocketGroup = index
			build.buildFlag = true
			runCallback("OnFrame")
			local dps = getStat(build.calcsTab.mainOutput, "CombinedDPS")
			if not bestDPS or dps > bestDPS then
				bestDPS = dps
				bestIndex = index
			end
		end
	end
	build.mainSocketGroup = originalGroup
	return bestIndex or originalGroup
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
				-- Since 3.29 a colour matched socket grants 10 quality, so
				-- 30 quality is reachable at league start with a 20 quality gem
				if (gemInstance.quality or 0) > 30 then
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
		-- Cheap uniques are tolerated at league start per expert criteria,
		-- so the unique list is informational and never fails the build;
		-- price aware budgeting can tighten this once economy data exists
		uniques = {
			pass = true,
			count = #uniques,
			list = uniques,
		},
		resistances = {
			pass = minEleRes >= 75,
			minimum = minEleRes,
		},
		-- Gem availability flags are warnings, not failures: guides list
		-- level 21 gems in early setups and those cost a few chaos within
		-- days of launch, so penalizing them scrambles tier comparisons
		gems = {
			pass = true,
			flags = gemFlags,
		},
	}
end

-- Measures the endgame damage ceiling: switches the build to its best late
-- stage setup (aspirational and mirror tier trees are allowed here, that is
-- the point) with the build's own gear and reads combined DPS. Run this
-- before the league start stages so template gear does not leak in.
function objective.measureDamageCeiling(build, options)
	local config = dofile("Optimizer/Config.lua")
	local selection = objective.selectProgressionStage(build, objective.stages.ceiling)
	if selection.noStageData then
		return nil
	end
	config.normalizeConfig(build, { enemy = options.enemy, keepInputs = options.trustConfig })
	local dps = getStat(build.calcsTab.mainOutput, "CombinedDPS")
	return { dps = dps, selection = selection }
end

-- Scores how well the main skill covers packs while clearing: projectile
-- count, chain, pierce and area of effect. Currently unused: validated
-- against the Maxroll tier benchmark this proxy carried no signal, because
-- real clear (Contagion spread, explosion chains, lingering ground damage)
-- is invisible to these outputs. Kept for a future, better clear model.
function objective.computeClearCoverage(build)
	local mainSkill = build.calcsTab.mainEnv and build.calcsTab.mainEnv.player.mainSkill
	if mainSkill and mainSkill.minion then
		return 0.6
	end
	local output = build.calcsTab.mainOutput
	local projectiles = (output.ProjectileCount or 1) - 1
	local chains = math.min(output.ChainMax or 0, 3)
	local pierces = math.min(output.PierceCount or 0, 3)
	local projScore = math.min((projectiles + chains + pierces) / 6, 1)
	local aoeScore = math.min((output.AreaOfEffectRadiusMetres or 0) / 3, 1)
	return math.max(projScore, aoeScore)
end

-- Classifies how the main skill delivers damage: "decoupled" delivery keeps
-- dealing damage while the player repositions (totems, traps, mines,
-- minions), "melee" requires staying in melee range of the boss, and
-- "selfHit" covers everything else the player aims and lands personally
function objective.classifyDelivery(build)
	local mainSkill = build.calcsTab.mainEnv and build.calcsTab.mainEnv.player.mainSkill
	if not mainSkill then
		return "selfHit"
	end
	local flags = mainSkill.skillFlags or { }
	if flags.totem or flags.trap or flags.mine or mainSkill.minion then
		return "decoupled"
	end
	if flags.melee then
		return "melee"
	end
	return "selfHit"
end

-- Computes the weighted subscores from the current calc output
function objective.computeSubscores(build, linkDelta, weaponIndependence, ceilingScore, options)
	local output = build.calcsTab.mainOutput
	local delivery = objective.classifyDelivery(build)
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
	local knowledgeModule = dofile("Optimizer/Knowledge.lua")
	local archetype = knowledgeModule.matchArchetype(build, delivery)
	return {
		damage = logScore(combinedDPS, options.damageFloor, options.damageCeiling),
		maxHit = logScore(output.SecondMinimalMaximumHitTaken, options.maxHitFloor, options.maxHitCeiling),
		ehp = logScore(output.TotalEHP, options.ehpFloor, options.ehpCeiling),
		recovery = clamp(recoveryRate / options.recoveryCap, 0, 1),
		resistances = clamp(1 - resShortfall / 135, 0, 1),
		chaosRes = clamp(((output.ChaosResist or -60) + 60) / 135, 0, 1),
		gearAgnostic = weaponIndependence or 0,
		linkRatio = linkDelta and linkDelta.ratio or 0,
		bossUptime = options.uptimeFactors[delivery] or 1,
		damageCeiling = ((ceilingScore or 0) + archetype.ceilingTrajectory) / 2,
		clearFeel = archetype.clearFeel,
		metaMomentum = knowledgeModule.skillMomentum(build),
		playstyleEase = archetype.playstyleEase,
		delivery = delivery,
		archetype = archetype.name,
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
	local ceiling = objective.measureDamageCeiling(build, options)
	local ceilingScore = ceiling and logScore(ceiling.dps, options.ceilingFloor, options.ceilingCeiling) or 0
	local stageResults = { }
	local totalScore = 0
	local scoredStages = 0
	local sumSubscores = { }
	local firstScored
	for _, stageName in ipairs(options.stages) do
		local stageDef = objective.stages[stageName]
		local selection = objective.selectProgressionStage(build, stageDef)
		if selection.noStageData then
			stageResults[stageName] = { selection = selection, noStageData = true }
		else
			local strippedConfig = config.normalizeConfig(build, { enemy = options.enemy, keepInputs = options.trustConfig })
			local replacedGear
			if options.ssf then
				replacedGear = config.applySSFTemplateGear(build)
			end
			local linkDelta = objective.measureLinkDelta(build)
			local weaponIndependence = objective.measureWeaponIndependence(build)
			local constraints = objective.checkConstraints(build, options)
			local subscores = objective.computeSubscores(build, linkDelta, weaponIndependence, ceilingScore, options)
			local rawScore = 0
			for key, weight in pairs(options.weights) do
				rawScore = rawScore + weight * (subscores[key] or 0)
				sumSubscores[key] = (sumSubscores[key] or 0) + (subscores[key] or 0)
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
			firstScored = firstScored or stageResults[stageName]
			totalScore = totalScore + rawScore * penalty
			scoredStages = scoredStages + 1
		end
	end
	if scoredStages == 0 then
		return { noStageData = true, stages = stageResults, stageOrder = options.stages }
	end
	local avgSubscores = { }
	for key, sum in pairs(sumSubscores) do
		avgSubscores[key] = sum / scoredStages
	end
	return {
		score = totalScore / scoredStages,
		subscores = avgSubscores,
		constraints = firstScored.constraints,
		linkDelta = firstScored.linkDelta,
		replacedGear = firstScored.replacedGear,
		ceiling = ceiling,
		stages = stageResults,
		stageOrder = options.stages,
	}
end

return objective
