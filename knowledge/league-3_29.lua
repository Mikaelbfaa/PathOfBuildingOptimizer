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
		["Barrage Support"] = { momentum = 0.75, note = "50-44 percent less, was 68-62, one more projectile" },
	},
}
