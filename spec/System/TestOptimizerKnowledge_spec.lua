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
