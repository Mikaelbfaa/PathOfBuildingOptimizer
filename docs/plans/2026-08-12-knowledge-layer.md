# Knowledge Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a curated knowledge layer (archetype traits plus per-league meta momentum) as three new subscores in the league starter scorer, per docs/specs/2026-08-12-knowledge-layer-design.md.

**Architecture:** Two Lua data files under a new top level `knowledge/` directory; a loader module `src/Optimizer/Knowledge.lua` that matches a loaded build to an archetype rule and computes meta momentum; three new subscores wired into `src/Optimizer/Objective.lua` with rebalanced weights; a curation README.

**Tech Stack:** Lua (LuaJIT 5.1) inside the PoB headless environment; busted specs run via Docker (`docker compose run --rm busted-tests busted --lua=luajit --pattern=<Pattern>` from the repo root).

## Global Constraints

- Code comments: plain ASCII sentences only; never use em-dashes, unicode arrows, emojis or Markdown structure characters in code files.
- Commits: small, one logical change each; the user is the sole author; never add a Co-Authored-By trailer.
- Never commit CLAUDE.md, .claude or tmp-validation (all are in .git/info/exclude).
- Lua is indented with tabs. File headers follow the house style (`-- Path of Building` block).
- All busted commands below are run from the repo root; the working directory inside the container is src.
- Weights in Objective.defaults.weights must always sum to 1.00.

---

### Task 1: Knowledge data files

**Files:**
- Create: `knowledge/archetypes.lua`
- Create: `knowledge/league-3_29.lua`

**Interfaces:**
- Produces: `knowledge/archetypes.lua` returns an ordered list of rule tables `{ name, match = { delivery?, flags?, minion?, dot? }, clearFeel, playstyleEase, ceilingTrajectory }` ending in a catch-all rule with an empty match. `knowledge/league-3_29.lua` returns `{ league, defaultMomentum, skills = { [gemName] = { momentum, note } }, supports = { [gemName] = { momentum, note } } }`.

- [ ] **Step 1: Write knowledge/archetypes.lua**

```lua
-- Path of Building
--
-- Knowledge: archetype traits
-- Stable per archetype judgments the calculation engine cannot measure.
-- Rules are evaluated top down, first match wins, and the list must end
-- with a catch-all rule. Values are 0 to 1. Sources and rationale live in
-- docs/research/league-starters.md and poe-fundamentals.md.
--

return {
	{ name = "minion army", match = { minion = true },
		clearFeel = 0.60, playstyleEase = 0.80, ceilingTrajectory = 0.70 },
	{ name = "totem", match = { flags = { "totem" } },
		clearFeel = 0.50, playstyleEase = 0.70, ceilingTrajectory = 0.40 },
	{ name = "mine", match = { flags = { "mine" } },
		clearFeel = 0.60, playstyleEase = 0.30, ceilingTrajectory = 0.65 },
	{ name = "trap", match = { flags = { "trap" } },
		clearFeel = 0.55, playstyleEase = 0.50, ceilingTrajectory = 0.50 },
	{ name = "melee", match = { delivery = "melee" },
		clearFeel = 0.45, playstyleEase = 0.55, ceilingTrajectory = 0.60 },
	{ name = "damage over time", match = { dot = true },
		clearFeel = 0.70, playstyleEase = 0.75, ceilingTrajectory = 0.45 },
	{ name = "projectile attack", match = { flags = { "attack", "projectile" } },
		clearFeel = 0.80, playstyleEase = 0.65, ceilingTrajectory = 0.75 },
	{ name = "self cast spell", match = { flags = { "spell" } },
		clearFeel = 0.60, playstyleEase = 0.60, ceilingTrajectory = 0.65 },
	{ name = "generic", match = { },
		clearFeel = 0.50, playstyleEase = 0.60, ceilingTrajectory = 0.55 },
}
```

- [ ] **Step 2: Write knowledge/league-3_29.lua**

Momentum values come from the verified official 3.29 patch notes (see the fact check pass recorded in docs/research/league-starters.md). 0.5 means untouched. The file is intentionally partial; unlisted gems get defaultMomentum.

```lua
-- Path of Building
--
-- Knowledge: league 3.29 meta momentum
-- Curated from the official 3.29 patch notes. 0.5 means untouched by the
-- patch, above means buffed, below means nerfed. Unlisted gems receive
-- defaultMomentum. Only verified numbers may be used as sources; see the
-- curation workflow in knowledge/README.md.
--

return {
	league = "3.29",
	defaultMomentum = 0.5,
	skills = {
		["Winter Orb"] = { momentum = 0.90, note = "projectiles 1 to 2-3, crit 6 to 7.5, 25 percent freeze" },
		["Fireball"] = { momentum = 0.70, note = "added damage effectiveness 370 to 480 at gem 20" },
		["Crackling Lance"] = { momentum = 0.70, note = "cast time 0.65 to 0.5, mana cost up 25 percent" },
		["Divine Ire"] = { momentum = 0.65, note = "steeper damage growth past gem 20" },
		["Hexblast"] = { momentum = 0.65, note = "cooldown 2 to 1 seconds, cast 1 to 0.85" },
		["Elemental Hit"] = { momentum = 0.35, note = "added elemental damage lowered 17 percent" },
		["Kinetic Blast"] = { momentum = 0.40, note = "Arcane Might 200 to 150, area damage penalty up" },
	},
	supports = {
		["Spell Totem"] = { momentum = 0.30, note = "55-50 percent less, was 49-40" },
		["Ballista Totem"] = { momentum = 0.35, note = "36-30 percent less, was 32-24" },
		["Barrage"] = { momentum = 0.75, note = "50-44 percent less, was 68-62, one more projectile" },
	},
}
```

- [ ] **Step 3: Sanity check both files parse**

Run: `docker compose run --rm busted-tests sh -c 'cd src && luajit -e "local a = dofile(\"../knowledge/archetypes.lua\"); local l = dofile(\"../knowledge/league-3_29.lua\"); print(#a, l.league)"'`
Expected: `9	3.29`

- [ ] **Step 4: Commit**

```bash
git add knowledge/archetypes.lua knowledge/league-3_29.lua
git commit -m "Add knowledge data for archetype traits and 3.29 momentum"
```

---

### Task 2: Knowledge loader module

**Files:**
- Create: `src/Optimizer/Knowledge.lua`
- Test: `spec/System/TestOptimizerKnowledge_spec.lua`

**Interfaces:**
- Consumes: the two data files from Task 1; `objective.classifyDelivery(build)` from `src/Optimizer/Objective.lua` (returns "melee", "selfHit" or "decoupled"); `build.calcsTab.mainEnv.player.mainSkill` (fields `skillFlags`, `minion`, `activeEffect.grantedEffect.name`); `build.calcsTab.mainOutput` (fields `TotalDot`, `CombinedDPS`); `build.skillsTab.socketGroupList[build.mainSocketGroup].gemList` entries (fields `enabled`, `nameSpec`, `gemData.grantedEffect.support`).
- Produces: module table with `knowledge.loadTables(archetypes, league)` (optional injection for tests; nil loads the real files), `knowledge.matchArchetype(build, delivery)` returning a rule table (never nil; delivery is the string from `objective.classifyDelivery`), `knowledge.skillMomentum(build)` returning a number 0 to 1. The delivery parameter avoids a circular dofile between Knowledge and Objective.

- [ ] **Step 1: Write the failing spec**

```lua
describe("TestOptimizerKnowledge", function()
	local harness = dofile("Optimizer/Harness.lua")
	local objective = dofile("Optimizer/Objective.lua")
	local knowledge = dofile("Optimizer/Knowledge.lua")

	local testArchetypes = {
		{ name = "minion army", match = { minion = true }, clearFeel = 0.6, playstyleEase = 0.8, ceilingTrajectory = 0.7 },
		{ name = "damage over time", match = { dot = true }, clearFeel = 0.7, playstyleEase = 0.75, ceilingTrajectory = 0.45 },
		{ name = "generic", match = { }, clearFeel = 0.5, playstyleEase = 0.6, ceilingTrajectory = 0.55 },
	}
	local testLeague = {
		league = "test",
		defaultMomentum = 0.5,
		skills = { ["Toxic Rain"] = { momentum = 0.8 } },
		supports = { ["Vicious Projectiles"] = { momentum = 0.2 } },
	}

	it("matches the real data files against a loaded build", function()
		knowledge.loadTables(nil, nil)
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local rule = knowledge.matchArchetype(loadedBuild, objective.classifyDelivery(loadedBuild))
		assert.are.equals("damage over time", rule.name)
		local momentum = knowledge.skillMomentum(loadedBuild)
		assert.truthy(momentum >= 0 and momentum <= 1)
	end)

	it("uses injected tables and folds nerfed supports into momentum", function()
		knowledge.loadTables(testArchetypes, testLeague)
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local rule = knowledge.matchArchetype(loadedBuild, objective.classifyDelivery(loadedBuild))
		assert.are.equals("damage over time", rule.name)
		-- Toxic Rain 0.8 averaged with Vicious Projectiles 0.2 gives 0.5
		assert.are.equals(0.5, knowledge.skillMomentum(loadedBuild))
		knowledge.loadTables(nil, nil)
	end)

	it("falls back to the default momentum for unlisted skills", function()
		knowledge.loadTables(testArchetypes, { league = "test", defaultMomentum = 0.5, skills = { }, supports = { } })
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		assert.are.equals(0.5, knowledge.skillMomentum(loadedBuild))
		knowledge.loadTables(nil, nil)
	end)
end)
```

Note for the implementer: the Toxic Rain test build's main skill is Toxic Rain, a bow attack whose damage is dominated by pod DoT, so the dot rule must match before any attack rule. Its socket group contains Vicious Projectiles, which is why the injected support table uses that name.

- [ ] **Step 2: Run the spec to verify it fails**

Run: `docker compose run --rm busted-tests busted --lua=luajit --pattern=TestOptimizerKnowledge`
Expected: FAIL (Knowledge.lua does not exist yet, dofile error)

- [ ] **Step 3: Write src/Optimizer/Knowledge.lua**

```lua
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
	leagueTable = league or dofile("../knowledge/league-3_29.lua")
end

local function ensureLoaded()
	if not archetypeTable then
		knowledge.loadTables(nil, nil)
	end
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
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `docker compose run --rm busted-tests busted --lua=luajit --pattern=TestOptimizerKnowledge`
Expected: 3 successes / 0 failures

- [ ] **Step 5: Commit**

```bash
git add src/Optimizer/Knowledge.lua spec/System/TestOptimizerKnowledge_spec.lua
git commit -m "Add knowledge loader with archetype matching and momentum"
```

---

### Task 3: Scoring integration

**Files:**
- Modify: `src/Optimizer/Objective.lua` (defaults.weights table; computeSubscores; the ceiling blend)
- Modify: `src/Optimizer/Report.lua` (subscoreLabels table)
- Modify: `spec/System/TestOptimizerObjective_spec.lua` (pipeline spec)

**Interfaces:**
- Consumes: `knowledge.matchArchetype(build)` and `knowledge.skillMomentum(build)` from Task 2.
- Produces: subscores table gains `clearFeel`, `metaMomentum`, `playstyleEase`; `damageCeiling` becomes the mean of the measured ceiling score and the archetype's `ceilingTrajectory`.

- [ ] **Step 1: Extend the pipeline spec with a failing assertion**

In `spec/System/TestOptimizerObjective_spec.lua`, inside the test "evaluates a build with the full league start pipeline", the loop over `objective.defaults.weights` already asserts every weighted subscore is in range, so adding the new weights makes it cover the new subscores. Add these explicit lines after the loop:

```lua
		assert.truthy(result.subscores.clearFeel > 0)
		assert.truthy(result.subscores.metaMomentum > 0)
		assert.truthy(result.subscores.playstyleEase > 0)
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `docker compose run --rm busted-tests busted --lua=luajit --pattern=TestOptimizerObjective`
Expected: FAIL on the clearFeel assertion (nil comparison)

- [ ] **Step 3: Update Objective.lua weights**

Replace the weights table in `objective.defaults` with (sums to 1.00):

```lua
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
```

- [ ] **Step 4: Wire the knowledge layer into computeSubscores**

At the top of `computeSubscores` in `src/Optimizer/Objective.lua`, load the knowledge module and fetch the traits, then add the three subscores and blend the ceiling. The function currently ends with the table containing `damageCeiling = ceilingScore or 0`; change it to:

```lua
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
```

- [ ] **Step 5: Add report labels**

In `src/Optimizer/Report.lua`, extend `subscoreLabels`:

```lua
	clearFeel = "clear feel (knowledge)",
	metaMomentum = "meta momentum (knowledge)",
	playstyleEase = "playstyle ease (knowledge)",
```

- [ ] **Step 6: Run all optimizer specs**

Run: `docker compose run --rm busted-tests busted --lua=luajit --pattern=TestOptimizer`
Expected: all pass (currently 15 plus the 3 from Task 2, plus this task's additions)

- [ ] **Step 7: Commit**

```bash
git add src/Optimizer/Objective.lua src/Optimizer/Report.lua spec/System/TestOptimizerObjective_spec.lua
git commit -m "Score builds with knowledge layer subscores"
```

---

### Task 4: Curation README

**Files:**
- Create: `knowledge/README.md`

**Interfaces:** none (documentation).

- [ ] **Step 1: Write knowledge/README.md**

```markdown
# Optimizer Knowledge Layer

Curated data the calculation engine cannot measure. Two files:

- `archetypes.lua`: stable per-archetype judgments (clear feel, playstyle
  ease, ceiling trajectory). Rules match on delivery, skill flags, minion
  and DoT status; first match wins; the list ends with a catch-all. Only
  touch this when the game changes structurally.
- `league-<version>.lua`: per-league meta momentum per skill and support
  gem, 0 to 1 with 0.5 meaning untouched by the patch.

## Per-league curation workflow

1. At patch notes release, sweep the official patch notes (research agents
   help here; the official forum thread is the only acceptable source for
   numbers; SEO paraphrases have burned us before, see
   docs/research/league-starters.md section 5).
2. Draft the new `league-<version>.lua` with momentum values and a note per
   entry citing the change.
3. The domain expert (Mikael) reviews and corrects the draft. This review
   is the quality gate; do not skip it.
4. Commit. Update `src/Optimizer/Knowledge.lua` if the league file name
   changes.

The file is intentionally partial: unlisted gems get `defaultMomentum`.
Momentum folds the worst enabled linked support into the main skill score,
so delivery nerfs (totems, mines) automatically reach the builds they hurt.
```

- [ ] **Step 2: Commit**

```bash
git add knowledge/README.md
git commit -m "Document the knowledge curation workflow"
```

---

### Task 5: Benchmark acceptance run

**Files:**
- Modify: `tmp-validation/fit-weights.py` (add the three new keys; this directory is git-excluded, no commit)

**Interfaces:**
- Consumes: the ranked outputs of `src/Optimizer/Report.lua` over the 43 decoded Maxroll builds in `tmp-validation/` (see `tmp-validation/analyze.py` for the merge and Spearman logic).

- [ ] **Step 1: Re-run the three benchmark batches**

From the repo root, run three parallel commands of the form `docker compose run --rm busted-tests sh -c 'cd src && LUA_PATH="../runtime/lua/?.lua;../runtime/lua/?/init.lua;;" luajit "Optimizer/Report.lua" --trust-config <paths>' > tmp-validation/full-batchN.txt 2>&1` with these path batches (all files live in `tmp-validation/`):
- Batch 1: S_WinterOrb_Elementalist, S_KineticFusillade_Hierophant, S_PoisonRAW_Necromancer, S_StormBurstTotem_Hierophant, S_Smite_Inquisitor, A_IceNova_Elementalist, A_EleHit_Slayer, B_EDContagion_Occultist, B_Boneshatter_Juggernaut, C_LightningArrow_Deadeye, C_EABallista_Champion (each as `../tmp-validation/<name>.xml`)
- Batch 2: A_KineticBlastClustering_Necromancer, A_PenanceBrandIgnite_Elementalist, A_CarrionGolems_Necromancer, A_ArakaaliSpider_Occultist, A_FrostbearerSpectres_Necromancer, A_FlickerStrike_Berserker, A_ExsanguinateMiner_Trickster, A_Earthshatter_Slayer, A_CycloneShockwave_Slayer, B_ReapIgnite_Elementalist, B_IceCrashIgnite_Chieftain, B_ViperStrikeMamba_Pathfinder, B_ShockNovaArchmage_Hierophant, B_HolyFlameTotem_Hierophant, B_PoisonSRS_Necromancer, B_ChaosMinionArmy_Necromancer
- Batch 3: B_HolyHammer_Inquisitor, B_PoisonousConcoction_Pathfinder, B_KineticBlast_Deadeye, B_FrostBlades_Slayer, C_StormBrand_Inquisitor, C_Earthquake_Gladiator, C_StormRain_Deadeye, C_EleHitSpectrum_Deadeye, C_Cyclone_Elementalist, C_TornadoTurbulence_Inquisitor, B_GlacialCascade_Elementalist, B_RollingMagmaMiner_Saboteur, B_IceTrap_Trickster, B_GroundSlamEarthshaking_Slayer, C_EviscerateBleed_Gladiator, C_IceShotMiner_Deadeye

Each batch takes several minutes.

- [ ] **Step 2: Analyze**

Run: `python tmp-validation/analyze.py`
Record: the full ranking, per-tier means and the Spearman value.

- [ ] **Step 3: Re-fit weights**

Add `clearFeel`, `metaMomentum`, `playstyleEase` to the `keys` list in `tmp-validation/fit-weights.py`, then run: `python tmp-validation/fit-weights.py`
Record: best achievable Spearman and the fitted weights.

- [ ] **Step 4: Report to the user**

Present: default-weight Spearman (baseline 0.13), fitted ceiling (baseline 0.37), the new ranking table, and a recommendation on adopting fitted weights. Do not change the default weights without the user's approval.
```

## Self-review notes

- Spec coverage: data model (Task 1), matching and loader (Task 2), scoring integration including the ceiling blend and labels (Task 3), curation workflow (Task 4), acceptance benchmark (Task 5). The spec's generator reuse section requires no code now.
- The spec's `flag` singular field is implemented as a `flags` list, matching the spec's intent of AND-combined conditions; the spec examples map directly.
- Type consistency: `knowledge.loadTables(archetypes, league)`, `knowledge.matchArchetype(build)`, `knowledge.skillMomentum(build)` are used with the same signatures in Tasks 2 and 3.
