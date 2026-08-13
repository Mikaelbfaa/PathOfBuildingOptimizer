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

## Momentum rubric

Draft momentum values by applying this rubric to each verified change, so
values are consistent and the review can focus on judgment calls:

| Momentum | Meaning |
|---|---|
| 0.90 | structural buff: extra projectiles, new mechanic, large multiplier |
| 0.70 | solid numeric buff: added damage effectiveness up, cast time cut, meaningful damage growth |
| 0.60 | minor buff: small numbers, quality of life that helps output |
| 0.50 | untouched by the patch |
| 0.40 | minor nerf: small numeric reductions |
| 0.30 | significant nerf: delivery or support multiplier worsened, key scaling cut |
| 0.15 | gutted or reworked away |

Judgment beats the rubric when they disagree; note why in the entry. Every
main skill and delivery support used by the validation benchmark should get
an explicit entry, even when it is `0.50` with note "untouched, verified",
so the momentum subscore is measured rather than defaulted for those builds.

The file is intentionally partial: unlisted gems get `defaultMomentum`.
Momentum folds the worst enabled linked support into the main skill score,
so delivery nerfs (totems, mines) automatically reach the builds they hurt.

Support lookups try the gem's full name first, so a curated entry keyed
to an Awakened support name always wins; when no entry exists for the
full name, the lookup strips a leading "Awakened " and retries with the
base name, since patch notes usually address the base gem.
