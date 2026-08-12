# League Starter Builds: Expert Criteria and Methodology

Research date: 2026-08-12. Current league: 3.29 "Curse of the Allflame" (launched 2026-07-24, patch 3.29.1). Companion documents: `poe-fundamentals.md`, `pob-engine-guide.md`, `prior-art.md`.

Source-quality note: primary sources are maxroll.gg, pathofbuilding.community, poe.ninja docs, pathofexile.com, pohx.net. Much indexed tier-list content is SEO/currency-seller material that paraphrases creator videos; numbers from those sources are flagged in the original research as lower trust.

## 1. What a league starter is

Consolidated from guide authors' own definitions: a build that finishes the campaign cleanly with minimal currency and readily available gear, enters maps without begging for uniques, survives the new league pressure while undergeared, and has a believable upgrade path after the first weekend. Maxroll frames its entire league-starter category as builds that are "easy to set up and work right out of the box without the need for expensive endgame items and uniques".

## 2. The criteria set (algorithm-ready)

### 2.1 Hard constraints (reject a candidate that violates these)

1. **Zero mandatory uniques** in the level 1-75 configuration. Cheap optional uniques (a few chaos) are fine; chase uniques are strictly post-start.
2. **Legal, continuous gem chain from level 1**: every gem obtainable from quest reward or vendor at or below the required level. Gates: Act 3 Library (Siosa, about level 31) unlocks all gems requiring level 31 or less; Transfigured gems require Labyrinth runs; some builds swap main skill at defined milestones.
3. **Functions on a 4-link** with a defined 4L support set. A 6-link or Tabula is not assumable.
4. **Defensive gates**: about 75% elemental res at level 68 entering maps; by red maps 75% res plus at least 30% chaos res plus one avoidance layer plus one recovery layer.
5. **Transition respec cost priced honestly.** Since 3.25 passives are respecced with gold at Faustus in Kingsmarch (core since 3.26); cost scales with level and is cheap during the campaign, so mid-campaign archetype swaps are no longer cost-gated. Quests grant 20 refund points and Orbs of Regret (1 per point, 5 per ascendancy point) remain the fallback; the old "80+ Regrets for a full swap" framing is legacy. Whether gold respec extends to ascendancy points is unverified; treat ascendancy changes as Regret-priced.
6. Attribute requirements satisfiable. (3.29 made socket colour a soft objective rather than a hard constraint: any gem fits any socket, but a colour match grants +10% gem quality.)

### 2.2 Weighted objective terms

| Term | Signal |
|---|---|
| Gear-agnostic scaling | fraction of damage from gem levels / minions / DoT vs from weapon local DPS. The single most predictive property. |
| 4L to 6L delta | small delta means the build is not gated on a 6-link |
| Campaign smoothness | number of skill swaps; earliest level the main skill is online; dead zones |
| Defensive floor at 68 | EHP and recovery with self-found rares and honest config |
| Clear vs single target balance | both needed to farm Voidstones; score separately |
| Budget elasticity | power gain per divine across 0, 1, 5 divines; steep early curve preferred, no keystone-item cliff |
| Button count | penalty per extra active input per pack; one-button builds rate highest for starters |
| Patch delta | net of skill gem changes x delivery-support changes x ascendancy changes x relevant unique changes; must be computed multiplicatively, not additively |
| Nerf-risk prior | discount archetypes historically targeted and anything above about 10% ladder share |
| League mechanic fit | can it farm the current mechanic while undergeared |
| Opportunity cost | rank against the current S-tier frontier ("reaches similar checkpoints with fewer compromises"), not in absolute terms |

### 2.3 Player segmentation

Tier lists split by operator skill: simple low-APM builds (RF, Winter Orb, Stormburst Totems, Absolution) for newer players; higher-APM efficient builds (Slams, Static Strike) for experienced racers. Selection is also goal-conditioned (mapping, bossing, minions, league mechanic).

### 2.4 The validation standard

The empirical proof creators use: clear a T11 red map deathless at about level 67 with only ground-found items, and farm Merciless Lab and T10-12 comfortably. Simulate builds at level 67-75 with SSF-quality rares, never at level 100 with mirror gear.

## 3. Perennial starter archetypes and why they persist

| Archetype | Gear-agnostic mechanism | Notes |
|---|---|---|
| Righteous Fire (Chieftain) | degen scales on own life/ES, fire res overcap, gem level; zero aiming | safest beginner pick; needs a secondary single-target skill. Built on Chieftain in the modern game; Inquisitor RF is an outdated variant |
| Essence Drain / Contagion | chaos DoT from gem level; Contagion chain-spreads on death | recovery from ED; CI/block endgame |
| Toxic Rain | pod DoT from gem level; avoids needing an expensive weapon | strong SSF |
| Boneshatter / Slams | cheap gambled 2H sets the damage floor; huge defensive floor | nerf-resilient "old faithful" (no 3.29 gem change); praised for campaign speed, though Maxroll ranks the Juggernaut version B-tier in 3.29 |
| Explosive Arrow Ballista | fuses plus gem level; bow nearly irrelevant; totems tank | ballista support nerfed in 3.29 |
| Poison SRS / minions | minion gem levels; player is support | 3.29 buffed (minions no longer pause while attacking) |
| Winter Orb | channel-and-forget, auto-targeting | 3.29: projectiles 1 to 2-3, crit 6 to 7.5, 25% freeze chance, small base damage bump; roughly a 1.7x practical damage step per community PoB tests (the widely quoted "+80%" has no primary source); textbook buff-driven tier jump |
| Detonate Dead | one-button, corpse damage independent of gear | flat in 3.29 |
| Hexblast Mines | big damage, low gear | was a top starter in past leagues but is no longer strong in the current meta. Note the cause: Hexblast itself was buffed in 3.29 (1s cooldown, 0.85s cast) while the mine delivery was nerfed, a clean example of why delivery deltas must be computed multiplicatively; piano playstyle, penalized for starters |
| Lightning Arrow / TS Deadeye | classic transition starter | gated by bow quality; C-tier in 3.29 |

3.29 tier snapshot (Maxroll league-starter list, Aug 2026): S-tier Winter Orb (Elementalist), Kinetic Fusillade Ballista (Hierophant), Smite of Divine Judgement (Inquisitor), Poison Ranged Animate Weapons (Necromancer), Storm Burst of Repulsion Totem (Hierophant), Luminary (Scion). Note the disagreement signal: another expert list marks Luminary "avoid" for unproven mechanics, a genuine hype-vs-proven risk split (Maxroll itself lists Luminary with the guide still unpublished). Caution on tier labels: Maxroll's list only covers builds that have Maxroll guides, so tier claims for archetypes absent from it (Toxic Rain, Righteous Fire, Detonate Dead, Hexblast, Absolution) come from lower-trust aggregator sources and should always be labelled with their source.

## 4. League start progression structure

### 4.1 Campaign skeleton

- Acts 1-3: leveling skills; vendor regex for links; resistances pushed from Act 2 onward. Ascendancy 1 around level 30-33 (Normal Lab).
- Act 3 Library (about level 31): the big gem unlock and the most common transition gate.
- Act 5 Kitava: minus 30% all res; target 105% uncapped beforehand. Act 10 Kitava: another minus 30%.
- Cruel Lab around level 45-50, Merciless around 60 (unlocks Transfigured swaps), Eternal in maps.
- Act 9-10: Blood Aqueducts to about level 62 is the standard optional catch-up spot when under-levelled or under-linked; current 3.29 routing treats it as optional, not a mandatory stop. Maps at 68.
- Universal rules: life flask upgrades, stay within 6 levels of zone, avoid map mods hostile to the build's damage type. Since 3.29 a Crafting Bench is available in every town from Act 2 onward, making life/res/attribute fixes cheap without a hideout trip.

### 4.2 Transition gates (four canonical shapes)

1. Act 3 Library swap (level about 31): level with fire spells or generic attacks, buy the real skill after Fixture of Fate.
2. Level 28 mechanic swap (for example Spellslinger for ED/C).
3. Transfigured gem swap at the Divine Font, available from Normal Lab (about level 33) onward, not only post-Merciless; Lab difficulty just sets the number of options offered (Normal 2, Cruel 3, Merciless 4). Example: Sunder into Boneshatter of Complex Trauma, about 18 respec points.
4. Level 68 map entry: introduce cheap enabler items.

### 4.3 Ascendancy ordering

First points solve the current campaign bottleneck (clear speed or survivability), not the endgame one. Example orders: Juggernaut Unstoppable, Unflinching, Untiring, Unrelenting; Pathfinder damage, damage, speed.

### 4.4 Budget ladder shape

no uniques, then a sub-5c enabler unique, then the one 10-50c damage-multiplier unique, then a multi-divine defensive keystone item, then fractured-base crafted rares. Crafting routes for starters: essences, alteration spam, bench, fractured bases (not Harvest/Synthesis endgame routes; note 3.29 removed the Harvest Synthesise craft and non-unique Synthesised item acquisition, and changed Fractured Fossils to fracture one modifier instead of duplicating the item, so fractured-base economics shifted). 3.29 also added default bench crafts to reroll rares (3 Chaos for all modifiers, 8 Chaos for one).

### 4.5 Time milestones (community consensus)

Campaign 6-10 hours at a competent pace (4-6 for racers); first Atlas objectives by hour 6-12; yellow maps by day 2-3 casually; push tiers as soon as tolerable; the classic mistake is over-farming early zones hunting perfect gear.

## 5. How experts read patch notes (meta prediction)

Signal taxonomy extracted from 3.29 analysis:

1. **Direct gem deltas produce tier jumps.** Winter Orb's projectile buff (1 to 2-3, roughly 1.7x in practice) went S-tier on every list; Elemental Hit minus 17% added damage dropped it down lists (the Slayer version still holds A-tier, so the drop is soft).
2. **Support-gem deltas hit whole archetypes** (Spell Totem and mine support nerfs). Experts route around the delivery method, and the net effect of skill-buff-plus-delivery-nerf requires simulation, not additive reasoning (Kinetic Fusillade stayed S-tier despite its delivery nerf).
3. **Delivery-method audit procedure**: check what delivers your skill (totem, mine, trigger, self-cast); verify item sources still exist; recalculate mana (3.29 lightning spells cast faster but cost more); note removed crafting routes as build-killers.
4. **Constraint-removal buffs raise every build's floor** (the 3.29 socket rework), disproportionately helping builds that had the removed problem.
5. **Buffed-but-unpopular is the value pick**: unpriced items, a full league before nerfs.
6. **Risk classes**: historically nerf-targeted archetypes and anything with dominant ladder share carry a discount (Minion Pact was reworked into Communion Support the patch after it dominated; GGG published no usage figure, so treat any specific percentage circulating for it as unsourced).
7. **Epistemic humility**: experts leave builds unranked on insufficient information and treat pre-launch reads as provisional; GGG has hotfix-nerfed metas mid-week-1.

## 6. How experts optimize an existing PoB (the review checklist)

### 6.1 Defensive review
Res capped with overcap headroom; chaos res at least 30; suppression 100 where class-appropriate; ailment avoidance 100; guard skill present and automated; defensive auras fitted to the build's defence type and reservation budget; flasks alt-rolled and Instilling-automated; recovery adequate and redundant; armour at least 25k or equivalent layer; endurance charges. Caution: the once-standard "aura triple" advice (Determination plus Grace plus Defiance Banner) dates from around patch 3.18 and is no longer current; evergreen guide pages can carry advice that is years stale, so aura recommendations must come from current-league sources.

### 6.2 Damage review
Gem levels (21/20, plus-level gear); accuracy 100% for attacks; correct support gems for what the build actually scales (check swaps for real more-multipliers); exposure and curse present; flat damage on rings/amulet for hit builds; crit chance before crit multi; 6-link or plus-2 corrupted gear later.

### 6.3 Config honesty (the most-cited failure mode)
Set boss enemy type (community benchmark is PoB Shaper/Pinnacle DPS, which is what poe.ninja publishes); enable only buffs, charges and enemy conditions the character actually maintains; set bandit and pantheon; match level/act res penalties; pick the variant balancing damage, survivability and practicality rather than the highest number.

### 6.4 Tree efficiency
Masteries are the best point-for-point value; evaluate whole branches to the final useful node; increased-damage stacking saturates (value against the existing pool; more-multipliers, flat damage and penetration live in other buckets); cluster jewels are an optimization, not a start enabler; defensive minimums are hard constraints, damage is the objective.

### 6.5 Upgrade priority
Remove the current bottleneck (boss damage, res, recovery, weapon) before luxury slots; the slot with most headroom first.

### 6.6 Common errors catalogued
Supports not actually linked; CWDT level above linked gem requirements; res pacing behind act penalties; tooltip DPS chased instead of configured effective DPS.

## 7. Data sources for the algorithm

| Source | Access | Use |
|---|---|---|
| poe.ninja economy API | public, documented (poe.ninja/docs/api) | item/currency prices for budget tiers |
| poe.ninja builds API | internal, explicitly off-limits | do not depend on it |
| GGG official APIs (leagues, character, public stash) | public/OAuth, developer docs; note new OAuth application registration is currently closed, so OAuth-gated endpoints may be unavailable; Leagues and Public Stashes need no OAuth | sanctioned build and economy data |
| pobb.in | open source (Dav1dde/pasteofexile); raw XML per paste | creator build distribution channel |
| pobarchives.com | over 20,000 archived builds, about 3,760 tagged League Starter (the widely quoted 7300 figure is from the author's March 2024 announcement); filters for leaguestarter/trending/author; this repo already has a provider class | seed corpus |
| poedb.tw | datamined tables | gem progressions, quest rewards, mod pools |
| Maxroll league-starter tier list and guides | web | expert labels for validation |

Sampling heuristics: study ladder ranks about 500-2000, not the top 100; the league-starter signal is a skill popular across all levels in week 1 (high-level-only popularity marks a transition target); build data lags patches, so read patch notes first in week 1.

## 8. Scoring model synthesis

Combine section 2.1 hard constraints with the section 2.2 weighted objective; validate per section 2.4 (level 67-75, SSF-quality gear, honest config); rank relative to the current tier-list frontier; recompute on patch ingestion per section 5. Expert tier lists (section 3) are the ground-truth labels for calibrating weights.
