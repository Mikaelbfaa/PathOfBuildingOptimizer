# Driving the PoB Engine Headlessly: Optimizer Engineering Guide

Research date: 2026-08-12, verified against this repository (fork of Path of Building Community, LuaJIT 5.1 under SimpleGraphic). Companion documents: `poe-fundamentals.md`, `league-starters.md`, `prior-art.md`.

There is no optimizer in upstream PoB, but nearly all the machinery an optimizer needs already exists for the tree heat map, the item DB sorting and the trade query generator. This document maps it.

## 1. Headless bootstrap

`src/HeadlessWrapper.lua` (76 lines, read it whole):
1. Loads `_SimpleGraphic.def.lua`, which defines every SimpleGraphic global; rendering calls are stubs, while `LoadModule`, `PLoadModule`, `PCall`, `ConPrintf` are real.
2. Overrides `GetVirtualScreenSize` (1920x1080), defines `runCallback(name, ...)` dispatching to the launch object, monkeypatches `require` to swallow `lcurl.safe` (no networking headless).
3. Runs `Launch.lua`, then `OnInit` and one `OnFrame`. One frame is mandatory after any mode switch because mode changes are deferred to the next frame (`main:OnFrame` in `src/Modules/Main.lua`).
4. Exposes globals: `build` (the BUILD mode object from `src/Modules/Build.lua`), `newBuild()`, `loadBuildFromXML(xmlText, name)`, `loadBuildFromJSON(characterJSON)` (PoE API character import via `build.importTab`).

Run it:

```
cd src
LUA_PATH="../runtime/lua/?.lua;../runtime/lua/?/init.lua" luajit HeadlessWrapper.lua
```

Or under busted (`.busted` at repo root sets directory `src`, helper `HeadlessWrapper.lua`); Docker via `docker-compose up`.

Important limitations:
- `Deflate`/`Inflate` in `src/_SimpleGraphic.def.lua` return empty strings headless, so import/export share codes (URL-safe base64 of zlib-deflated XML, see `ImportTab.lua` around line 504/631) do not work without binding a real zlib into those two globals. Raw XML works fine.
- `REGENERATE_MOD_CACHE=1` env var controls ModCache regeneration (`src/Modules/Main.lua` around line 130).

## 2. The evaluation loop

### 2.1 Read stats

`build.calcsTab.mainOutput` is a flat table of about 1000 numeric stats, populated by `CalcsTab:BuildOutput()` (`src/Classes/CalcsTab.lua` around line 441):

```lua
self.mainEnv    = self.calcs.buildOutput(self.build, "MAIN")   -- always EFFECTIVE buff mode
self.mainOutput = self.mainEnv.player.output
self.calcsEnv   = self.calcs.buildOutput(self.build, "CALCS")  -- honors calcsTab.input.misc_buffMode
```

Canonical minimal examples: `spec/GenerateBuilds.lua` and `spec/System/TestBuilds_spec.lua` (loads XML, diffs every output key against a snapshot). Full field dumps live in `spec/TestBuilds/*.lua` snapshots.

Curated stat lists:
- `data.powerStatList` (`src/Modules/Data.lua` lines 128-234): the optimization-target list, with accessor `data.powerStatList.GetFromOutput(output, statTable, skipTransform)` handling FullDPS fallback (CombinedDPS plus minion), Minion prefixes and player-plus-minion summing.
- `displayStats` in `src/Modules/BuildDisplayStats.lua`: sidebar stats with formatting metadata, including per-type MaximumHitTaken, res with overcap, TotalNetRegen, TotalBuildDegen.
- Raw fields set in `src/Modules/CalcOffence.lua` (TotalDPS, CombinedDPS, WithDotDPS family, ailment DPS, costs, cooldowns, per-hand sub-tables) and `src/Modules/CalcDefence.lua` (pools, res, block, suppression, TotalEHP, per-type MaximumHitTaken and EHP, regen/degen). Useful direct helpers: `calcs.takenHitFromDamage`, `calcs.reducePoolsByDamage`, `calcs.hitChance`, `calcs.armourReduction`.
- `mainEnv.player.modDB` is queryable (`Sum`, `More`, `Flag`); `mainOutput.SkillDPS` is the per-skill FullDPS breakdown.

### 2.2 Mutate and recalculate (committed state)

Mutators set `build.buildFlag = true`; the next `OnFrame` (`src/Modules/Build.lua` around line 1244) wipes the global cache, rebuilds socket groups, calls `BuildOutput`. Pattern: mutate, set flag, `runCallback("OnFrame")`, read output. Examples from the spec suite:

```lua
build.skillsTab:PasteSocketGroup("Fireball 20/0  1\n...")        -- skills
build.configTab.input.enemyIsBoss = "Pinnacle"                    -- config
build.configTab.input.customMods = "+200 to all resistances"
build.configTab:BuildModList()                                    -- required after touching input
build.itemsTab:CreateDisplayItemFromRaw(rawText)                  -- items
build.itemsTab:AddDisplayItem()
build.spec:AllocNode(build.spec.nodes[id])                        -- tree, allocates whole path
build.spec:DeallocNode(node)
build.characterLevel = 90
build.buildFlag = true
runCallback("OnFrame")
```

### 2.3 Hypothetical evaluation (no state change)

`src/Modules/Calcs.lua`:
- `calcs.getMiscCalculator(build)` (line 124): returns `calcFunc(override, useFullDPS), baseOutput`. Full env rebuild per call, roughly single-digit milliseconds for a simple build. Pass `useFullDPS=false` to skip the multi-skill roll-up. Supported override keys (consumed in `src/Modules/CalcSetup.lua`): `addNodes` and `removeNodes` (tables keyed by node objects), `repSlotName` plus `repItem` (item swap, handles 2H offhand blanking), `spec` (whole PassiveSpec swap), `toggleFlask`/`toggleTincture`, `conditions`.
- `calcs.getNodeCalculator(build)` (line 116): incremental tree-only evaluator; builds the env once, then per call only wipes the player modDB and re-adds node mods before `calcs.perform`. Cheapest path for pure-tree search. Instantiated by `CalcsTab:BuildOutput` but currently has no callers; a free fast path.
- `calcs.initEnv(build, mode, override, specEnv)` supports an `accelerate` partial-wipe table (flags `nodeAlloc`, `requirementsItems`, `requirementsGems`, `skills`, `everything`); only `calcs.calcFullDPS` uses it today. The biggest untapped batching lever.

Caveat: the output table returned by `calcFunc` is reused between calls in some paths; copy out needed scalars immediately (PowerBuilder caches by `node.modKey` for this reason).

### 2.4 Caching layers

- `src/Data/ModCache.lua` (2.3 MB): memoized `modLib.parseMod` per literal mod line. Novel generated mod strings pay one ModParser pass, then cache in-memory.
- `GlobalCache` (`src/Data/Global.lua`, helpers in `Common.lua`): per-skill outputs per mode; deliberately bypassed in CALCULATOR mode so comparisons are honest; wiped on every committed recalc.
- No published benchmarks; tuning constants imply single-digit ms per misc-calc eval and seconds for a full-tree PowerBuilder sweep (the UI throttles it with `nodePowerMaxDepth`). CI runs thousands of evals per test run. Profiler available (`runtime/lua/lua-profiler.lua`).

## 3. Existing scoring machinery (reuse, do not rewrite)

### 3.1 Node power (tree heat map)

`CalcsTab:PowerBuilder` (`src/Classes/CalcsTab.lua` line 496): scores every tree node by bucketed path distance, dedupes identical nodes by `modKey`, evaluates allocated nodes with `removeNodes` and others with `addNodes`, computes whole-path power, handles mastery effects and all cluster-jewel notables, writes `node.power = {singleStat, pathPower, offence, defence, ...}`. Runs fine synchronously headless (coroutine yields are guarded).

`CalcsTab:CalculatePowerStat(selection, original, modified)` (line 742) diffs any powerStatList stat. `CalculateCombinedOffDefStat` (line 748) is PoB's hand-tuned generic objective (normalized life/armour/ES/evasion/regen deltas plus relative CombinedDPS delta).

`TreeTab:BuildPowerReportList` (line 1057) turns node.power into the sorted power report (the "DPS per point" table); `PowerReportListControl` is its UI.

### 3.2 Item and mod scoring

`src/Classes/TradeQueryGenerator.lua`:
- `WeightedRatioOutputs(baseOutput, newOutput, statWeights)` (line 170): the weighted multi-stat objective (capped ratios, lower-is-better transforms, FullDPS fallback).
- `GenerateModWeights` (line 541): for each candidate mod, writes it onto a blank test item, evaluates via `calcFunc({repSlotName, repItem})`, scores per-unit weight. `GeneratePassiveNodeWeights` (line 591) does the same for tree nodes.
- Mod data: `src/Data/QueryMods.lua` x `src/Data/TradeSiteStats.lua`, keyed by item category with roll ranges.

`ItemsTab` uses `GetMiscCalculator` throughout for affix power, item DB sorting, anoint power and implicit ranking; `ItemDBControl` sorts the unique DB by measured stat gain.

### 3.3 Tree graph algorithms

`src/Classes/PassiveSpec.lua`: `BuildPathFromNode` (BFS setting `pathDist` and `path` for every node, respecting class starts and ascendancy borders), `BuildAllDependsAndPaths` (orphan detection, radius jewels, cluster subgraphs), `AllocNode`/`DeallocNode` (alloc takes the whole shortest path), `CountAllocNodes`, `GetShortestPathToClassStart`, `EncodeURL`/`DecodeURL` (tree URL codec). Cluster jewel subgraph synthesis in `BuildClusterJewelGraphs`/`BuildSubgraph` with data from `src/Data/ClusterJewels.lua`.

Point budget: `Build:EstimatePlayerProgress` (`src/Modules/Build.lua` around line 886) maps level to available points via the quest table.

Timeless jewel search already exists: `TreeTab:FindTimelessJewel` over precomputed seed tables in `src/Data/TimelessJewelData`.

## 4. Build representation

XML root `PathOfBuilding` with sections dispatched to `build.savers`: Build (level, class, ascendancy, bandit, pantheon, mainSocketGroup, plus cached PlayerStat elements readable without recalculation), Import, Calcs (inputs), Skills (skill sets, socket groups, gems with level/quality), Items (raw text blocks plus slot maps), Tree (Spec per tree: `nodes` comma list, `masteryEffects`, sockets, overrides), Config (inputs, custom mods), Notes, Party. Save via `build:SaveDB("code")`, load via `loadBuildFromXML`. Trees deliberately load last (jewel sockets need items).

A complete build = class and ascendancy, level, tree spec(s) with masteries and jewel sockets, items and item sets, skill sets with socket groups, config inputs, bandit, pantheon, main socket group, spectres, timeless data.

Share code = URL-safe base64 of Deflate(XML); needs real zlib headless (see section 1). Build-site download/upload lives in `src/Modules/BuildSiteTools.lua` (maxroll, pobb.in, poe.ninja, pastebin and others); `src/Classes/PoBArchivesProvider.lua` fetches trending/latest builds from pobarchives.com, a ready seed corpus.

## 5. Data available in-repo

- `src/Data/Skills/*.lua`: full per-level (1-40) gem data including damage, crit, effectiveness, costs. Gem metadata and attribute requirements in `src/Data/Gems.lua`.
- `src/Data/Uniques/*.lua` plus `Rares.lua`: item databases with roll ranges. `src/Data/Bases/*.lua`: all item bases.
- Affix pools: `ModExplicit.lua`, `ModItemExclusive.lua`, essence/eldritch/corrupted/veiled/cluster/abyss mod files.
- `src/Data/Minions.lua`, `Spectres.lua`; `src/Data/Bosses.lua` (EHP presets); `Pantheons.lua`; `ClusterJewels.lua`.
- `src/TreeData/<version>/tree.lua` (versions 2_6 through 3_29): raw walkable adjacency graph (`nodes[id].in/out`), processed by `src/Classes/PassiveTree.lua` into `.linked`, `.type`, `.modList`, `notableMap`, `keystoneMap`, `clusterNodeMap`, `masteryEffects`.

## 6. Reference code path (load, change, read)

```lua
-- from src/: luajit myScript.lua with LUA_PATH set as in section 1
dofile("HeadlessWrapper.lua")

local f = io.open("../spec/TestBuilds/3.13/Dual Savior.xml", "r")
local xml = f:read("*a"); f:close()
loadBuildFromXML(xml, "Dual Savior")

local base = build.calcsTab.mainOutput

-- hypothetical evaluation, no state change
local calcFunc, calcBase = build.calcsTab:GetMiscCalculator()
local node = build.spec.nodes[someNodeId]
local out = calcFunc({ addNodes = { [node] = true } }, true)
local gain = data.powerStatList.GetFromOutput(out, { stat = "FullDPS" })
           - data.powerStatList.GetFromOutput(calcBase, { stat = "FullDPS" })

-- committed mutation
build.configTab.input.enemyIsBoss = "Pinnacle"
build.configTab:BuildModList()
build.buildFlag = true
runCallback("OnFrame")
local after = build.calcsTab.mainOutput

-- save
local outXml = build:SaveDB("code")
```

Gotchas: always one OnFrame after SetMode or load; mainOutput is EFFECTIVE mode; `FullDPS` needs a socket group flagged includeInFullDPS (the powerStatList accessor falls back to CombinedDPS); node objects for overrides must come from `build.spec.nodes` or the tree cluster/notable maps, not raw tree data; `LaunchServer.lua` is only the OAuth redirect listener, unrelated to builds.
