# Knowledge Layer for League Starter Classification

Date: 2026-08-12. Status: approved design, pending implementation.

## Context

The league starter scorer (src/Optimizer/Objective.lua) measures builds with the PoB engine: defensive floors, gear independence, link retention, delivery uptime, damage ceiling. Validated against the full Maxroll 3.29 tier list (42 builds, tmp-validation benchmark), the measured subscores reach Spearman about 0.13 with default weights and cap at about 0.37 with fitted weights. The residual gap is information that no build file contains: clear feel, playstyle cost, ceiling trajectory and per-league meta momentum. This design adds those as a curated knowledge layer, following the project's hybrid principle: engine for numbers, curated knowledge for judgment. It serves both per-build ranking and, later, the Phase 3 generator's archetype selection.

## Data model

New top level directory `knowledge/`.

### knowledge/archetypes.lua (stable trait table)

Returns a list of rules, evaluated in order, first match wins, ending with a catch-all default. Each rule:

```lua
{
	name = "spell totems",
	match = { delivery = "decoupled", flag = "totem" },
	clearFeel = 0.5,        -- how the archetype clears packs in practice, 0 to 1
	playstyleEase = 0.7,    -- one button and forgiving = high, piano = low
	ceilingTrajectory = 0.4 -- how far the archetype scales with currency
}
```

Match fields, all optional and AND-combined:
- `delivery`: "melee" | "selfHit" | "decoupled" (from objective.classifyDelivery)
- `flag`: a skillFlags key that must be true on the main skill (totem, mine, trap, melee, projectile, area, spell, attack)
- `minion`: true to require a minion main skill
- `dot`: true to require the main damage to be over time (TotalDot share above half)

Seed contents come from docs/research (RF, chaos DoT, totems, traps and mines, minions, melee slams, bows, channelling, self cast). The table only changes when the game changes structurally.

### knowledge/league-3_29.lua (per league curated file)

```lua
return {
	league = "3.29",
	defaultMomentum = 0.5,
	skills = {
		["Winter Orb"] = { momentum = 0.9, note = "projectiles 1 to 2-3, crit 6 to 7.5" },
		["Elemental Hit"] = { momentum = 0.35, note = "added damage lowered 17 percent" },
	},
	supports = {
		["Spell Totem"] = { momentum = 0.3, note = "55-50 less, was 49-40" },
	},
}
```

Momentum is 0 to 1 with 0.5 meaning untouched by the patch. Notes cite the change; sources stay in the curation commit message or the research docs. The initial 3.29 file is drafted from the patch note verification already done (fact check pass of 2026-08-12).

## Matching semantics

- Archetype: evaluate rules top down against the build's delivery classification and main skill (mainEnv.player.mainSkill); first match supplies clearFeel, playstyleEase, ceilingTrajectory.
- Momentum: look up the main skill's gem name in skills (fall back to defaultMomentum), then fold in delivery: the minimum momentum among enabled linked supports with entries. Final metaMomentum = (skillMomentum + supportMomentum) / 2 when a support entry exists, else skillMomentum. This encodes the Hexblast lesson: a buffed skill on a nerfed delivery is a net loss.
- Loader lives in a new src/Optimizer/Knowledge.lua module: loads the archetype table plus the league file matching the current tree version, exposes matchArchetype(build) and skillMomentum(build).

## Scoring integration

Three new subscores in Objective.computeSubscores: clearFeel, metaMomentum, playstyleEase (values straight from the knowledge layer). ceilingTrajectory is blended into the existing damageCeiling subscore: measured ceiling and trajectory averaged, keeping one ceiling number.

Default weights (sum 1.00): damage 0.10, maxHit 0.11, ehp 0.06, recovery 0.06, resistances 0.07, chaosRes 0.04, gearAgnostic 0.13, linkRatio 0.11, bossUptime 0.11, damageCeiling 0.04, clearFeel 0.07, metaMomentum 0.07, playstyleEase 0.03.

Report reasons label knowledge derived subscores explicitly, for example "meta momentum: nerfed delivery this league". No input derives from Maxroll's tier opinions, so the tmp-validation benchmark remains a fair target; after implementation the benchmark is re-run and weights re-fit for a data informed set, subject to user approval.

## Curation workflow (knowledge/README.md)

Per league, at patch notes release:
1. Research agents sweep the official patch notes (and reveal coverage) for gem and support deltas.
2. Claude drafts knowledge/league-X.lua with momentum values and notes, citing sources, using only verified numbers (lesson: SEO numbers like the Winter Orb "+80 percent" must not enter).
3. The user reviews and corrects the draft (domain review is the quality gate).
4. Commit. The archetype table is only touched when a structural game change warrants it.

## Generator reuse (Phase 3)

The archetype table is the generator's menu: rank archetypes by traits plus current momentum before proposing candidate builds. No additional data model needed.

## Testing and acceptance

- Unit specs for rule matching (synthetic skillFlags and delivery combinations) and momentum lookup with support folding.
- Pipeline spec: evaluateLeagueStart on a test build populates the three new subscores in range.
- Acceptance: full 42-build benchmark re-run; expect default weight Spearman to improve from about 0.13; re-fit weights and report the new ceiling.

## Out of scope

- Automated scraping pipelines (rejected: quality).
- ML on historical corpora (deferred).
- Creator consensus tiers as an input (circular against the benchmark).
- A better engine measured clear model (computeClearCoverage stays parked).
