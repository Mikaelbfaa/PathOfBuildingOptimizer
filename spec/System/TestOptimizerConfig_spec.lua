describe("TestOptimizerConfig", function()
	local harness = dofile("Optimizer/Harness.lua")
	local config = dofile("Optimizer/Config.lua")

	it("strips custom mods and reports them", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local baseLife = loadedBuild.calcsTab.mainOutput.Life
		loadedBuild.configTab.input.customMods = "+500 to maximum Life"
		loadedBuild.configTab:BuildModList()
		harness.recalc()
		assert.truthy(loadedBuild.calcsTab.mainOutput.Life > baseLife)
		local stripped = config.normalizeConfig(loadedBuild)
		assert.are.equals("+500 to maximum Life", stripped.customMods)
		assert.are.equals(baseLife, loadedBuild.calcsTab.mainOutput.Life)
	end)

	it("preserves build defining inputs", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		loadedBuild.configTab.input.bandit = "Alira"
		loadedBuild.configTab:BuildModList()
		harness.recalc()
		config.normalizeConfig(loadedBuild)
		assert.are.equals("Alira", loadedBuild.configTab.input.bandit)
	end)

	it("sets the enemy benchmark", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		config.normalizeConfig(loadedBuild, { enemy = "Uber" })
		assert.are.equals("Uber", loadedBuild.configTab.input.enemyIsBoss)
	end)

	it("replaces gear with template rares", function()
		local loadedBuild = harness.loadBuildFile("../spec/TestBuilds/3.13/Mirage Archer Toxic Rain.xml")
		local replaced = config.applySSFTemplateGear(loadedBuild)
		assert.truthy(replaced["Body Armour"])
		local itemsTab = loadedBuild.itemsTab
		local bodySlot = itemsTab.slots["Body Armour"]
		assert.truthy(itemsTab.items[bodySlot.selItemId].name:match("^Optimizer Template Body"))
		local output = loadedBuild.calcsTab.mainOutput
		assert.truthy(output.Life > 0)
		assert.truthy(output.CombinedDPS > 0)
	end)
end)
