describe("TestOptimizerObjective", function()
	local harness = dofile("Optimizer/Harness.lua")
	local objective = dofile("Optimizer/Objective.lua")
	local report = dofile("Optimizer/Report.lua")

	it("evaluates a build with the full league start pipeline", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local result = objective.evaluateLeagueStart(loadedBuild)
		assert.truthy(result.score >= 0 and result.score <= 1)
		assert.are.equals("table", type(result.subscores))
		for key in pairs(objective.defaults.weights) do
			local value = result.subscores[key]
			assert.truthy(value >= 0 and value <= 1, key)
		end
		assert.are.equals("table", type(result.constraints))
		assert.are.equals("table", type(result.replacedGear))
		assert.truthy(result.linkDelta.ratio > 0 and result.linkDelta.ratio <= 1)
	end)

	it("measures a smaller four link DPS on a six link build", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local before = loadedBuild.calcsTab.mainOutput.CombinedDPS
		local linkDelta = objective.measureLinkDelta(loadedBuild)
		assert.truthy(linkDelta.fourLinkDPS < linkDelta.fullDPS)
		assert.are.equals(before, loadedBuild.calcsTab.mainOutput.CombinedDPS)
	end)

	it("flags gems above league start availability", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local group = loadedBuild.skillsTab.socketGroupList[loadedBuild.mainSocketGroup]
		for _, gemInstance in ipairs(group.gemList) do
			if gemInstance.gemData then
				gemInstance.level = 21
				break
			end
		end
		local flags = objective.listGemFlags(loadedBuild)
		assert.truthy(#flags > 0)
	end)

	it("ranks multiple builds", function()
		local entries = report.rankBuilds({
			"../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml",
			"../spec/TestBuilds/3.13/OccVortex.xml",
		})
		assert.are.equals(2, #entries)
		assert.truthy(entries[1].score >= entries[2].score)
		assert.are.equals(1, entries[1].rank)
		assert.are.equals("table", type(entries[1].reasons))
		assert.truthy(#entries[1].reasons > 0)
	end)
end)
