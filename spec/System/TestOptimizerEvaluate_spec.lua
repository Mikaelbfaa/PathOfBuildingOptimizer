describe("TestOptimizerEvaluate", function()
	local harness = dofile("Optimizer/Harness.lua")
	local evaluate = dofile("Optimizer/Evaluate.lua")

	it("loads a build file and reports metadata", function()
		local loadedBuild, errMsg = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		assert.truthy(loadedBuild, errMsg)
		local report = evaluate.buildReport(loadedBuild)
		assert.are.equals("string", type(report.build.className))
		assert.are.equals("number", type(report.build.level))
		assert.are.equals("number", type(report.build.passivePointsUsed))
		assert.truthy(report.build.passivePointsUsed > 0)
		assert.are.equals("Toxic Rain", report.build.mainSkill)
	end)

	it("summary stats agree with the calc output", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local report = evaluate.buildReport(loadedBuild)
		local output = loadedBuild.calcsTab.mainOutput
		assert.are.equals(output.Life, report.summary.Life)
		assert.are.equals(output.Mana, report.summary.Mana)
		assert.are.equals(output.TotalEHP, report.summary.TotalEHP)
		assert.truthy(report.summary.CombinedDPS > 0)
		assert.are.equals(output.FireResist, report.defence.FireResist)
		assert.are.equals(output.PhysicalMaximumHitTaken, report.defence.PhysicalMaximumHitTaken)
	end)

	it("recalculates after a committed change", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local lifeBefore = loadedBuild.calcsTab.mainOutput.Life
		loadedBuild.configTab.input.customMods = "+500 to maximum Life"
		loadedBuild.configTab:BuildModList()
		local output = harness.recalc()
		assert.truthy(output.Life > lifeBefore)
	end)

	it("binds a working zlib when the platform provides one", function()
		harness.init()
		local deflated = Deflate("optimizer zlib roundtrip test")
		if deflated and #deflated > 0 then
			assert.are.equals("optimizer zlib roundtrip test", Inflate(deflated))
		end
	end)

	it("encodes a full report as valid JSON", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local report = evaluate.buildReport(loadedBuild, true)
		local jsonText = evaluate.reportToJSON(report)
		local dkjson = require "dkjson"
		local decoded, _, decodeErr = dkjson.decode(jsonText)
		assert.falsy(decodeErr)
		assert.are.equals(report.build.className, decoded.build.className)
		assert.are.equals("number", type(decoded.full.Life))
	end)
end)
