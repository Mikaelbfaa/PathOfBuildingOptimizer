-- Path of Building
--
-- Module: Optimizer Knowledge
-- Loads the curated knowledge layer (archetype traits and per league meta
-- momentum) and matches loaded builds against it. See
-- docs/specs/2026-08-12-knowledge-layer-design.md for the data contract.
--

local knowledge = { }

local archetypeTable
local leagueTable

-- Loads the data files, or accepts injected tables for testing. Passing nil
-- for either argument loads the corresponding file from the knowledge
-- directory at the repository root.
function knowledge.loadTables(archetypes, league)
	archetypeTable = archetypes or dofile("../knowledge/archetypes.lua")
	-- The league knowledge file is named after the engine's current tree
	-- version. A file for that version must exist under knowledge/.
	leagueTable = league or dofile("../knowledge/league-" .. latestTreeVersion .. ".lua")
end

local function ensureLoaded()
	if not archetypeTable then
		knowledge.loadTables(nil, nil)
	end
end

-- Strips a leading "Awakened " so an unlisted Awakened support can fall back
-- to its base gem's entry, for example Awakened Vicious Projectiles falls
-- back to Vicious Projectiles. This is a known partial heuristic: patch
-- notes usually address the base gem, but an Awakened variant can receive
-- its own independent change. The direct lookup by full name runs first, so
-- a curated entry keyed to the full Awakened name always takes precedence
-- over this fallback.
local function baseSupportName(name)
	return name:match("^Awakened (.+)$")
end

-- True when the build's main damage arrives as damage over time
local function isDotBuild(build)
	local output = build.calcsTab.mainOutput
	local combined = output.CombinedDPS or 0
	return combined > 0 and (output.TotalDot or 0) > combined * 0.5
end

-- Returns the first archetype rule matching the build. The delivery string
-- comes from objective.classifyDelivery, passed in by the caller to avoid a
-- circular module load. The data file ends with a catch-all rule, so this
-- never returns nil for valid data.
function knowledge.matchArchetype(build, delivery)
	ensureLoaded()
	local mainSkill = build.calcsTab.mainEnv and build.calcsTab.mainEnv.player.mainSkill
	local flags = mainSkill and mainSkill.skillFlags or { }
	local hasMinion = mainSkill and mainSkill.minion and true or false
	local dot = isDotBuild(build)
	for _, rule in ipairs(archetypeTable) do
		local match = rule.match
		local ok = true
		if match.delivery and match.delivery ~= delivery then
			ok = false
		end
		if ok and match.minion and not hasMinion then
			ok = false
		end
		if ok and match.dot and not dot then
			ok = false
		end
		if ok and match.flags then
			for _, flagName in ipairs(match.flags) do
				if not flags[flagName] then
					ok = false
					break
				end
			end
		end
		if ok then
			return rule
		end
	end
	return archetypeTable[#archetypeTable]
end

-- Meta momentum for the build's main skill, folding in the worst momentum
-- among its enabled linked supports when any has an entry. A buffed skill
-- on a nerfed delivery is a net loss.
function knowledge.skillMomentum(build)
	ensureLoaded()
	local mainSkill = build.calcsTab.mainEnv and build.calcsTab.mainEnv.player.mainSkill
	local skillName = mainSkill and mainSkill.activeEffect and mainSkill.activeEffect.grantedEffect.name
	local entry = skillName and leagueTable.skills[skillName]
	local momentum = entry and entry.momentum or leagueTable.defaultMomentum
	local group = build.skillsTab.socketGroupList[build.mainSocketGroup]
	local supportMomentum
	if group then
		for _, gemInstance in ipairs(group.gemList) do
			if gemInstance.enabled and gemInstance.gemData and gemInstance.gemData.grantedEffect
					and gemInstance.gemData.grantedEffect.support then
				local supportEntry = leagueTable.supports[gemInstance.nameSpec]
				if not supportEntry then
					local baseName = baseSupportName(gemInstance.nameSpec)
					supportEntry = baseName and leagueTable.supports[baseName]
				end
				if supportEntry and (not supportMomentum or supportEntry.momentum < supportMomentum) then
					supportMomentum = supportEntry.momentum
				end
			end
		end
	end
	if supportMomentum then
		return (momentum + supportMomentum) / 2
	end
	return momentum
end

return knowledge
