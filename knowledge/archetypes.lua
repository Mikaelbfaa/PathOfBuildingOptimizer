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
