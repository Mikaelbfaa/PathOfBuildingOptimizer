# Path of Exile 1: Build Design Knowledge Base

Research date: 2026-08-12. Game version at time of writing: 3.29.x, league "Curse of the Allflame" (launched 24 July 2026).

This document is the foundation knowledge base for the build optimizer. Companion documents: `league-starters.md` (league start criteria and expert methodology), `pob-engine-guide.md` (how to drive this repo's calculation engine headlessly), `prior-art.md`.

Practical rule for the optimizer: treat numbers as patch-volatile and structure as stable. Sections below separate the two. All balance data consumed by the optimizer must be data-driven and league-versioned; hard-coded numbers rot within one league.

## 1. Recent-patch context (things older guides get wrong)

| Patch | League | Released |
|---|---|---|
| 3.25 | Settlers of Kalguur | Jul 2024 |
| 3.26 | Secrets of the Atlas | 2025 |
| 3.27 | Keepers of the Flame | Oct 2025 |
| 3.28 | Mirage | Mar 2026 |
| 3.29 | Curse of the Allflame (current) | Jul 2026 |

Structural changes an optimizer must know:

1. **Socket colours are largely gone (3.29).** All sockets roll white by default and accept any gem colour; matching colour only grants +10% gem quality. Off-colour socketing is no longer a constraint.
2. **Awakened support gems retired (3.28).** Replaced by 40+ "Exceptional Support" gems (max level 3, transformative effects, dropped from Atlas bosses with the Originator Voidstone). Only Awakened Empower/Enlighten/Enhance remain.
3. **Atlas rebuilt (3.28).** Start in the centre, four quadrants, tiered map drops, 138 Atlas passive points, Nightmare Maps (former T17) and Originator Maps (T16.5), fourth Voidstone from the Incarnations.
4. **Mana cost model changed (3.29).** "Reduced mana cost" became "Mana Cost Efficiency" with hyperbolic diminishing returns (100% efficiency is about half cost, 200% about a third). Zero-cost stacking is gone; mana is a binding constraint again.
5. **21 ascendancies, not 19.** Raider was deleted in 3.25 and replaced by Warden; Scion gained Reliquarian (3.28) and Luminary (3.29). Reliquarian's notables are unique-item effects that GGG rotates every league by design, so it must be modelled as league-versioned data.
6. **3.29 is a spellcaster patch.** 100+ spells buffed; any "self-cast is dead" heuristic from 3.20-3.27 is stale.

## 2. Game fundamentals

### 2.1 Classes and ascendancies

Seven base classes positioned at different start points on a shared passive tree; start position and base attributes are the only level-1 differences. Attribute alignment: Str (Marauder), Str/Dex (Duelist), Dex (Ranger), Dex/Int (Shadow), Int (Witch), Str/Int (Templar), centre (Scion).

| Base class | Ascendancies | Archetype pull |
|---|---|---|
| Marauder | Juggernaut, Berserker, Chieftain | Jugg: armour/endurance/tank. Berserker: raw more-damage via rage at a defensive cost. Chieftain: fire/totems/regen, very forgiving |
| Duelist | Slayer, Gladiator, Champion | Slayer: leech/overleech, AoE, culling. Gladiator: block plus bleed. Champion: permanent Fortify, impale, the defensive generalist |
| Ranger | Warden, Deadeye, Pathfinder | Warden: elemental attacks, tinctures. Deadeye: projectiles/clear speed, frenzy. Pathfinder: flask uptime/effect, poison, ailment immunity |
| Shadow | Assassin, Trickster, Saboteur | Assassin: crit. Trickster: ES/evasion hybrid recovery. Saboteur: traps/mines, classic low-budget engine |
| Witch | Necromancer, Elementalist, Occultist | Necro: the minion class. Elementalist: golems, ailments, exposure, guaranteed shock. Occultist: ES, chaos, curses, Profane Bloom |
| Templar | Inquisitor, Hierophant, Guardian | Inquisitor: crit that ignores res, consecrated ground, the RF home. Hierophant: totems and mana. Guardian: auras, minion hybrid |
| Scion | Ascendant, Reliquarian, Luminary | Ascendant: weakened versions of two other ascendancies. Reliquarian: rotating unique-item notables. Luminary: permanent mercenary ally |

**Ascendancy points: 8 total** (2 per Labyrinth: Normal, Cruel, Merciless, Eternal). One ascendancy notable is often worth 5-15 regular tree points and several effects are unobtainable elsewhere. Ascendancy choice is the single highest-leverage build decision.

### 2.2 Passive skill tree

- About 1300 nodes; **123 points max** (99 from levels, 24 from quests).
- Node types: small passives (pathing and attribute supply), notables (cluster payoff), keystones (rule-changers with drawbacks, see 6.7), masteries (one option per cluster type after allocating a notable there; each option once globally; a hidden 15-20 points of value that naive optimizers miss), jewel sockets (about 21).
- **Cluster jewels** (outer sockets) graft sub-trees: Large (8-12 passives, up to 3 notables, 2 sockets), Medium (4-6, up to 2, 1 socket), Small (2-3, up to 1). Implicit enchant defines the theme and notable pool.
- **Timeless jewels** rewrite every passive in radius by seed; a combinatorial space of its own and a frequent source of build-defining power.
- **Anointments** (amulet, Blight oils) grant any notable free, often replacing 5-7 points of travel.
- Optimizer framing: the tree is a shortest-path-with-prizes problem (Steiner tree / orienteering variant), not a knapsack. Travel cost dominates. Masteries, anoints and cluster jewels act as teleport edges that break naive pathing heuristics.

### 2.3 Skill gems and supports

- Active gems provide the skill; support gems modify linked actives only. Max 6 links (body armour, 2H weapons): 1 active plus 5 supports. The 5L to 6L step is usually a 30-50% more-damage jump.
- **Tag gating**: supports only apply to skills with matching tags (Attack, Spell, Projectile, Melee, AoE, Minion, Trap, Mine, Totem, Duration, Channelling, element tags, and so on). Tag matching is the hard constraint of link selection.
- **Gem levels**: spell base damage grows roughly geometrically with gem level, so "+X to level of gems" acts as a more-multiplier for spells/minions/DoT and is nearly worthless for attacks that scale off weapon damage. This asymmetry is one of the most important facts in build design.
- **Quality**: 20% standard; effect varies per gem. Since 3.29 a colour-matched socket adds +10% quality.
- **Mana multipliers**: most supports cost 110-160% mana; a real constraint post-3.29.
- **Vaal gems**: corrupted variants granting a souls-charged burst version alongside the base skill; used as boss-phase cooldowns.
- **Transfigured gems** ("of X" variants, unlocked via Labyrinth): mechanically distinct versions of base skills. A large fraction of the current meta is transfigured gems; each variant must be treated as a distinct skill.
- **Exceptional supports (3.28+)**: max level 3, endgame link upgrades.

### 2.4 Items

- Rarity: Normal (0 affixes), Magic (1 prefix, 1 suffix), Rare (up to 3 and 3), Unique (fixed mods, variable rolls).
- Base type determines implicits, defence type, weapon speed/crit, attribute requirements and legal affix pools (spell suppression only rolls on dex bases, for example). Item level gates affix tiers (top tiers need ilvl 81-86).
- Prefixes are usually offence and flat defence; suffixes are resistances, attributes, speed, suppression, ailment avoidance. **Resistances are always suffixes**, so res, attributes, suppression and ailment avoidance all compete for the same 3 suffix slots per item. This "suffix tax" is the core gear budgeting problem.
- Influence (Shaper/Elder/Conqueror), Eldritch implicits, fractured mods, synthesis implicits, veiled mods, essences and fossils unlock exclusive mod pools, often the only source of a build-critical stat.
- Crafting is a first-class power source (bench, metacrafting, essences, recombinators).
- Corruption (Vaal Orb) can add powerful implicits at brick risk.

### 2.5 Flasks

- 5 slots, typically 1 life plus 4 utility. Charges gained on kill (more from magic/unique flasks), on crit, or via Pathfinder.
- Life flask standard craft: instant recovery when on low life, plus bleed or curse removal.
- Utility bases: Quicksilver, Granite, Jade, Basalt, Quartz, Silver, Diamond, elemental resist flasks, Amethyst, and others.
- **Instilling Orb** adds auto-trigger conditions ("used when charges reach full") which make flask uptime near-automatic; a load-bearing part of modern defence.
- **Enkindling Orb** trades charge gain during effect for much higher effect; only good with an external charge source (chiefly Mageblood).
- Mageblood makes 4 utility flasks permanently active at increased effect, effectively converting them into auras. Canonical example of a build-enabling unique changing the constraint set.
- Offensive flasks are commonly 30-60% of a build's PoB DPS, and PoB assumes flasks active. PoB DPS is therefore an uptime-conditional number (see 5.5).

### 2.6 Leagues and economy

- Challenge leagues run 3-4 months, fresh economy, all characters start over. Variants: Trade SC/HC, SSF, Ruthless.
- A build's quality is inseparable from its cost curve. The community scores three bands: league start (0-10 divines), mid-league (10-100), endgame ceiling (100+). SSF is a hard constraint switch: only self-craftable rares and common uniques exist.

### 2.7 Campaign and endgame

- Acts 1-10, level 1 to about 68-70. **Kitava penalties: minus 30% all elemental res after Act 5 and again after Act 10 (minus 60% total).** Uncapped res is what matters.
- Labyrinth four times for the 8 ascendancy points plus helmet enchants.
- The campaign is its own optimization problem: no 6-links, no ascendancy for 30 levels, no budget. League-start viability means functioning on a 4-link with self-found rares.
- Endgame: maps T1-16 (white 1-5, yellow 6-10, red 11-16), Nightmare and Originator maps above that, 4 Voidstones from pinnacle bosses, 138 Atlas passives (a farming-strategy layer mostly orthogonal to character build).
- Pinnacle ladder, roughly easiest to hardest: map bosses, Guardians, Shaper/Elder, Sirus, Maven, Exarch/Eater, Uber Elder, then Uber versions (about 10x effective life, reduced ailment and curse effect on them) unlocked by Atlas keystones.

## 3. Anatomy of a build

A build is a selection over roughly ten coupled decision layers: ascendancy; main skill (and transfigured variant); support set; passive tree path plus masteries and anoint; jewels (regular/abyss/cluster/timeless); gear (9 slots of base, influence, 6 affixes, implicit, corruption); aura reservation package; curse/exposure/debuff package; flasks and enchants; utility links (movement, guard, triggers).

### 3.1 The offensive pipeline (order of operations)

```
1.  Base damage         attacks: weapon damage (local mods first)
                        spells: from gem level
2.  Added flat damage   (rings, jewels, supports, heralds)
3.  x Added damage effectiveness (skill-specific)
4.  x Conversion / gain-as-extra (applied before scaling)
5.  x (1 + sum of increased - sum of reduced)   one additive bucket per tag
6.  x product of (1 + more_i) x (1 - less_i)    each its own multiplier
7.  x Crit (150% base multi plus additional crit multi)
8.  x Enemy side: (1 - res after curse/exposure/penetration)
9.  x Enemy side multipliers: shock, wither, increased damage taken
10. x Hit rate: speed, accuracy, projectile/AoE overlap, uptime
```

Structural facts:

- **"Increased" is one additive bucket per tag.** Marginal value of the next point is 1/(1 + total). A build at +400% increased gains only 0.2% per additional 1% increased.
- **"More"/"less" multipliers are each independent.** Supports carry most of the game's more-multipliers, which is why the 6th link and ascendancy multipliers beat large chunks of tree.
- **Added flat damage multiplies with everything downstream**; highest leverage for low-base skills.
- **Conversion double-dips in PoE1**: converted damage is scaled by modifiers of both the source and result types. Chaos is a terminal sink. (PoE2 removed this; do not mix sources.)
- **Crit**: base multi 150%; crit chance capped at 100% (95% practical). Accuracy is rolled twice for crits. Crit is a threshold investment: weak until chance is high, then excellent. A classic non-convexity that trips greedy optimizers.
- **DoT cannot crit and scales on its own additive multiplier**; hit and DoT investment barely overlap, so hybrid hit-plus-DoT builds are usually weaker than committed ones.

### 3.2 Damaging ailments (PoE1 values)

| Ailment | Source | Base magnitude | Duration | Stacks |
|---|---|---|---|---|
| Ignite | fire hit damage | 90% of base fire per second | 4s | no, strongest applies |
| Bleed | physical attack damage | 70% per second, 210% while target moves | 5s | no |
| Poison | phys plus chaos damage | 30% per second | 2s | yes, unlimited |

Ignite wants one huge hit; poison wants hit rate; bleed wants moving targets. Non-damaging ailments (shock, chill, freeze, scorch, brittle, sap) act as enemy-side multipliers or control.

### 3.3 Defensive layers

Canonical framing: **Avoidance, Mitigation, Recovery**; no single layer suffices.

Pools: Life (str-aligned), Energy Shield (int-aligned, recharges after 2s without damage), hybrid, Mind over Matter (mana as a pool), Ward.

Avoidance:
- Evasion: attacks only, entropy-based, 95% cap, downgrades crits; useless vs spells and DoT.
- Block: attack and spell block, 75% cap each (78 with max-block mods). Glancing Blows doubles chance but blocked hits deal about 65% damage.
- **Spell suppression: 100% cap, halves all spell hit damage. The most point-efficient defensive stat in the game**; near-mandatory for evasion/life builds. Rolls on dex-base gear suffixes.
- Ailment avoidance: target 100%; freeze and shock are the lethal ones.

Mitigation:
- Resistances: 75% cap, raisable to 90 via max-res sources. Each +1% max res above 75 is worth about 4% EHP vs that element. Chaos res is separate and commonly neglected.
- Armour: PDR = A / (A + 5D), 90% cap. Rule of thumb: armour 5x the hit gives 33% reduction, 10x gives 50%. Excellent vs many small hits, near-useless vs one huge hit; must be modelled per hit size, never as a flat percent.
- Additional flat PDR (endurance charges, Basalt) subtracts after armour, so it is strongest exactly where armour is weakest.
- Damage shifting (Lightning Coil, Taste of Hate, Cloak of Flame): converts incoming phys to elemental so capped res mitigates it.
- Guard skills: Molten Shell (armour-scaled absorb), Steelskin, Immortal Call; usually automated via Cast when Damage Taken or left-click.

Recovery:
- Leech (capped 20% of life per second by default; Slayer overleech; Vaal Pact doubles cap, removes regen), regen (never interrupted), recoup (over 4s), life gain on hit (instant), ES recharge (out-of-combat), recovery on block (instant).
- **Recovery must be redundant**: map mods disable leech, regen or flasks individually. One recovery mechanism means death to a map mod.

**DoT/degen is the gap in every plan**: it bypasses evasion, armour, suppression, block and most guard skills. Only res, max res, less-DoT-taken, regen and movement counter it. Hit survivability and DoT survivability must be scored as separate axes.

### 3.4 Utility

Movement speed (maps per hour and a defence), clear vs single target (see 5.6), mana sustain, reservation budget (see 6.1).

## 4. Build archetypes (scaling vector, gear dependency, weakness)

- **Attack crit** (bow/melee/wand): scales on weapon DPS, flat damage, crit chance then multi, speed, penetration. Gear dependency very high (the weapon is the build). Weakness: accuracy-starved early, expensive, crit variance, thin defences.
- **Self-cast spells**: scale on gem level, spell crit, cast speed, penetration/exposure. Plus-gem-level sources are effectively free more-multipliers. Gear dependency moderate. 3.29 heavily buffed this archetype.
- **DoT**:
  - Bleed: one big phys hit, triple damage vs moving enemies.
  - Ignite: one huge hit, non-stacking; wants burst not speed; proliferation clears.
  - Poison: stacks infinitely; wants hit rate; ramps, so poor vs phase bosses, great in long fights.
  - Chaos DoT casters (Essence Drain/Contagion, Soulrend): gem level plus DoT multi, extremely gear-cheap, classic league start.
  - Common weaknesses: no burst, ramp time, phase transitions waste stacks.
- **Minions**: scale on minion gem levels, minion mods, auras; gear dependency low (perennial league starters). Weaknesses: AI, minion deaths, damage uptime, historically nerf-targeted.
- **Totems/traps/mines**: player-decoupled damage, safe, very low gear dependency, best-in-class starters. Structural weakness: you do not hit, so no leech and no on-hit/on-kill effects; defence must come from elsewhere.
- **Righteous Fire**: burn scales on your own max life/ES, fire res overcap and DoT multi; sustain loop with fire res regen mastery. Gear dependency low. Weakness: low single-target ceiling (needs a second skill), fixed AoE, recovery map mods.
- **Channelling** (Winter Orb, Cyclone, Scorching Ray): stage-based ramp, snapshot supports. Weakness: movement lock, ramp.
- **Triggers** (CoC, Manaforged, item triggers): decouple DPS from input, near-100% uptime while moving; constraint: 162ms per-spell-name cooldown, crit/speed floors. Gear dependency moderate-high.
- **Aura/attribute/armour stackers**: convert one stacked number into everything; highest ceiling, lowest budget viability, killed by single nerfs.

## 5. What makes a build strong (community evaluation)

### 5.1 Evaluation axes

1. League-start/budget viability (functions at 4L with self-found gear)
2. Clear speed (maps per hour)
3. Single-target/boss DPS with realistic uptime
4. Tankiness (max hit and layered EHP, not raw life)
5. Currency scaling ceiling
6. Complexity/button count
7. Nerf-resilience

The community taxonomy is mapper vs boss-killer vs all-rounder, crossed with budget bands.

### 5.2 DPS thresholds (soft, inflation-prone; do not hard-code)

Order-of-magnitude priors, in PoB full-buff terms: yellow maps 50-150k; red maps and Guardians 100-500k; normal pinnacles 250k-3M; Uber-tier 5M+ (comfortable 10-20M). More reliable framing: time-to-kill against the boss's damage output; ubers have about 10x normal pinnacle life. Repeated community rule: about 5M PoB DPS minimum for a squishy build, about 1M acceptable for a genuinely tanky one (an implied 5x defence-to-DPS exchange rate).

### 5.3 Defensive thresholds (reliable)

75% ele res capped with 20-50 overcap; chaos res at least 0 and ideally 75; suppression 100% or block 75/75 or evade 95 as the avoidance layer; armour matched to expected hit sizes; PoB maximum hit taken bigger than the content's one-shots; life about 5-6.5k or ES 8-15k endgame; sustained recovery of 20%+ pool per second from at least two independent sources; 100% ailment avoidance; movement speed 25-35% boots.

### 5.4 Defensive layering doctrine

Cover disjoint threat categories (phys hit, ele hit, spell hit, chaos, DoT, ailments, one-shots, chip). Layers multiply. Ask "what kills me", not "how much EHP". Uptime-dependent layers need engineered uptime (Instilling, Automation, Enduring Cry).

### 5.5 Damage uptime (the number PoB lies about)

PoB headline DPS assumes all flasks, charges, buffs and debuffs active, perfect positioning, zero ramp and no phases. Real sustained DPS is typically 20-50% of it. Uptime factors an optimizer should model as multipliers: flask uptime on bosses, charge generation single-target, ramp (stacks/stages/brands/totem placement), movement downtime, phase windows, debuff application reliability, accuracy, projectile/AoE overlap. Modelling uptime honestly is where an algorithm can beat naive PoB-maxing.

### 5.6 Clear vs bossing trade-off

Clear wants AoE, chain/pierce, explosions, movement, no aiming; bossing wants concentration, ramp, debuff stacking. Supports directly trade one for the other, so the standard solution is two link configurations (clear and boss). The optimizer should optimize two objectives with a shared budget. Builds good at both without swaps rate highest.

## 6. Where power actually comes from

Approximate attribution for a well-built endgame character (modelling prior, not a sourced statistic): the 6-link carries 30-45% of damage (mostly more-multipliers); ascendancy 15-30% of damage and 20-30% of defence; gear 25-40% damage and 40-55% defence; tree 15-25% damage (saturating increased) and 25-35% defence; jewels 10-25%; auras/flasks/charges 15-40% multiplicative; enemy-side debuffs a 30-80% multiplier.

Insights:
1. **The tree is a poor damage source and a good defence source.** Past the early damage nodes, marginal tree points buy defence.
2. More-multipliers concentrate in gems and ascendancies.
3. Gem levels are the caster's weapon.

### 6.1 Build-enabling uniques vs generic rares

Enabling uniques grant effects obtainable nowhere else and change the constraint set (Mageblood, Ashes of the Stars, Aegis Aurora, Melding of the Flesh, Progenesis, Lightning Coil, Dissolution of the Flesh, Soul Mantle, Mjolner/Cospri, RF enablers, Watcher's Eye and so on). Rares supply the fungible budget (life, res, attributes, flat damage, crit multi, speed, suppression). These are two different optimization problems: uniques are structural switches for an outer discrete search; rares are a continuous affix-budget knapsack under the suffix tax. A build's gearing difficulty is measured by how many suffixes go to taxes before any go to power; ascendancies and uniques that pay taxes for you are systematically undervalued by naive optimizers.

## 7. Key interactions experts exploit

### 7.1 Reservation efficiency
Effective reservation = base / (1 + efficiency). Aura selection is bin-packing over the mana pool where efficiency and pool are purchasable. Aura effect does not reduce reservation. Enlighten is local efficiency for its links. Life reservation and Eldritch Battery are alternate pools. Common breakpoints: the 4th 35% aura, a useful Precision level, leaving enough unreserved mana to cast.

### 7.2 Cost efficiency (3.29)
Hyperbolic; high-cast-rate builds face a real mana wall; Praxis, leech, Clarity and Arcane Surge rose in value.

### 7.3 Enemy-side multipliers (the most underrated lever)
- Shock: increased damage taken (20% default, 50%+ scaled), applies to all damage. A guaranteed shock equals a support gem.
- Curses: 1 by default, minus-res curses and Despair; Doom for self-cast. **Pinnacle bosses take 66% less hex effect; Marks are exempt**, which is why boss setups use Marks.
- Exposure: flat minus-res, additive with curses; same-type sources do not stack.
- Penetration: applied last per hit; partially redundant with res-lowering, do not double-count.
- Wither: up to 15 stacks of 6% increased chaos damage taken (90% total).
- A build running shock plus exposure plus mark plus wither has a 2-3x multiplier that costs almost nothing in the damage budget; ubers reduce ailment and curse effect, which is exactly why full-debuff PoB numbers overstate uber performance.

### 7.4 More vs increased decision rule
Given total increased X%, a new I% increased is worth I/(100+X); a new M% more is worth M/100. At X=400, a 40% more support beats a 100% increased notable two to one. Saturated builds should buy flat damage, more-multipliers, enemy debuffs, crit multi or speed, never more increased.

### 7.5 Flask uptime engineering
Instilling triggers, Enkindling, Pathfinder and Mageblood turn a 20-40% uptime resource into a near-100% one. Since flasks carry 30-60% of damage and much defence, this is one of the highest-ROI optimizations and is invisible to naive stat summing.

### 7.6 Keystone combinatorics
Keystones are model-transforming switches: CI (immune to chaos, 1 life), EB (ES to mana), MoM, Vaal Pact, Ghost Reaver, Iron Reflexes, Resolute Technique (deletes accuracy and crit), Glancing Blows, Elemental Overload (anti-crit budget option), Ancestral Bond, Avatar of Fire, Precise Technique, and so on. They interact combinatorially (CI+EB+Ghost Reaver; RT+EO; Glancing Blows+Aegis). Treating them as independent boolean stats produces nonsense; solve as an outer discrete search over switch combinations.

### 7.7 The glass cannon trade
Every budget point is fungible across offence and defence: slot competition, suffix competition, reservation competition (Determination vs Hatred is the canonical trade), tree competition, keystone competition. Higher defence lets you clear the same content with far less damage because it converts "dodge every mechanic" into "keep DPSing", which also raises effective uptime; this is why tanky builds often out-farm higher-PoB glass cannons.

## 8. Implications for the optimizer algorithm

1. Two objectives, not one: sustained boss DPS and effective max-hit/recovery as a Pareto frontier, with clear throughput as a third axis.
2. Model uptime explicitly: effective DPS = nominal DPS times uptime factors.
3. Model armour against a hit-size distribution, not a scalar.
4. Threat-category coverage as a constraint, not a score; DoT is a separate category that bypasses most layers.
5. The tree is orienteering with teleport edges; travel cost dominates.
6. Gear is a 6-affix constrained knapsack with a hard suffix tax.
7. Uniques and keystones are model-transforming switches: outer discrete search, inner continuous solve.
8. Links are tag-constrained set cover with a mana budget; solve clear and boss configs separately.
9. Reservation is bin-packing over a purchasable pool.
10. Enemy-side debuffs are a separate multiplicative block with boss-specific penalties; model the target, not just the character.
11. Diminishing returns are the core structure; marginal-value comparison is the right primitive.
12. Everything data-driven and league-versioned.

## 9. Confidence flags

High confidence: current league 3.29; 21 ascendancies; socket rework; Exceptional supports; Atlas rework; armour and evasion formulas; PoE1 ailment magnitudes; conversion double-dipping; 66% boss hex reduction with Marks exempt.
Medium: exact cost-efficiency curve; Voidstone naming.
Low (priors only, do not hard-code): DPS threshold table; power-attribution percentages.
Not obtained: poe.ninja live meta (JS-rendered), poewiki direct pages (bot protection), reddit (blocked). Sources consulted instead: official forum/patch notes, PoEDB, Maxroll resources and patch coverage, Fandom wiki mechanics pages, PoE Vault, Odealo archetype articles.
