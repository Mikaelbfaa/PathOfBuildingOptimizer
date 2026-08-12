# Prior Art: Automated PoE Build Optimization

Research date: 2026-08-12. Companion documents: `poe-fundamentals.md`, `league-starters.md`, `pob-engine-guide.md`.

## Existing tools

### alecrivet/poe-optimizer (closest prior art)
Python project (v0.9.3, last commit March 2026, small user base) with PoB vendored as a git submodule. Architecture: a Python-to-Lua bridge with a persistent worker pool that keeps Lua state alive across evaluations (about 2x speedup from batching, parallel across cores). Scope is deliberately narrow:
- Optimizes the passive tree only: add/remove/swap nodes preserving connectivity, jewel socket location swaps, cluster notable reallocation, mastery selection, point budget from character level.
- Does not touch items, gems or ascendancy; cannot start from scratch; existing builds only. (Keystones are ordinary tree nodes and are within its node search.)
- Algorithms: greedy local search over per-node marginal impact (5-10 minutes typical) and an experimental genetic algorithm with connectivity-respecting crossover/mutation (2-5 minutes). Objectives: DPS, life, EHP or balanced.

Lessons: the PoB headless evaluation loop is proven viable; tree-local search is the easy part; the value left on the table is items, gems, generation, budget constraints and league-starter knowledge. Their worker-pool batching is worth copying only if we outgrow single-process Lua.

### Others
- jbigalet/POE-skill-tree-optimizer: older genetic tree optimizer, same narrow scope.
- Lilylicious/PathOfPathing: tree planner generating near-optimal pathing (Steiner-style), tree only.
- Assorted "AI build generator" web tools and GPT wrappers: not grounded in any calculation engine; produce plausible-sounding but unverified builds.

## What does not exist (the gap)

No public tool generates builds from scratch grounded in PoB calculations; none models league-start constraints (budget, gem availability by level, 4-link viability, campaign progression); none ingests patch notes. The hard parts are exactly the ones prior art skipped: skill/ascendancy selection, item and gem choice, and the viability knowledge that is not in PoB's numbers (uptime, playstyle, degen management, economy).

## Data access notes

- poe.ninja: economy API public and documented; builds API internal and explicitly off-limits.
- pobb.in is open source (Dav1dde/pasteofexile); raw PoB XML retrievable per paste.
- pobarchives.com: over 20,000 archived builds with leaguestarter/trending/author filters (the 7300 figure circulating online is from the author's March 2024 announcement); this repo already ships a provider (`src/Classes/PoBArchivesProvider.lua`).
- pobapi (Python) parses PoB share codes if a non-Lua consumer is ever needed.
- GGG official leagues/character/public-stash APIs are the sanctioned bulk data route, with a caveat: new OAuth application registration is currently closed, so OAuth-gated endpoints (characters, account stashes) may be unavailable; Leagues and Public Stashes need no OAuth.
