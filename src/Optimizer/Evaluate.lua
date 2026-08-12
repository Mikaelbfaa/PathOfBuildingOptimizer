-- Path of Building
--
-- Module: Optimizer Evaluate
-- Loads a build file headlessly and reports its calculated stats.
-- Command line usage, from the src directory:
--   LUA_PATH="../runtime/lua/?.lua;../runtime/lua/?/init.lua;;" luajit Optimizer/Evaluate.lua <build xml path> [output json path]
-- The trailing double semicolon keeps the default search path so that the
-- Data modules can still be found. Without an output path the JSON report is
-- printed to stdout.
--

local evaluate = { }

-- Defensive stats reported in addition to the entries of data.powerStatList.
-- All of these are set by CalcDefence and may be nil for some builds.
local extraStatList = {
	"LifeUnreserved", "ManaUnreserved", "LifeRecoverable",
	"FireResist", "FireResistOverCap",
	"ColdResist", "ColdResistOverCap",
	"LightningResist", "LightningResistOverCap",
	"ChaosResist", "ChaosResistOverCap",
	"EffectiveBlockChance", "EffectiveSpellBlockChance", "EffectiveSpellSuppressionChance",
	"PhysicalMaximumHitTaken", "FireMaximumHitTaken", "ColdMaximumHitTaken",
	"LightningMaximumHitTaken", "ChaosMaximumHitTaken",
	"NetLifeRegen", "TotalNetRegen", "TotalBuildDegen",
	"ManaCost", "LifeCost",
}

-- Returns the name of the currently selected main skill, or nil
function evaluate.getMainSkillName(build)
	local env = build.calcsTab.mainEnv
	if env and env.player.mainSkill and env.player.mainSkill.activeEffect then
		return env.player.mainSkill.activeEffect.grantedEffect.name
	end
end

-- Builds a stat report table for the loaded build. The summary section holds
-- the curated optimization stats, the defence section the extra defensive
-- stats, and with includeFull the full flat calc output is attached as well.
function evaluate.buildReport(build, includeFull)
	local output = build.calcsTab.mainOutput
	local used = build.spec:CountAllocNodes()
	local report = {
		build = {
			className = build.spec.curClassName,
			ascendClassName = build.spec.curAscendClassName,
			level = build.characterLevel,
			passivePointsUsed = used,
			mainSkill = evaluate.getMainSkillName(build),
		},
		summary = { },
		defence = { },
	}
	for _, statEntry in ipairs(data.powerStatList) do
		if statEntry.stat then
			report.summary[statEntry.stat] = data.powerStatList.GetFromOutput(output, statEntry, true)
		end
	end
	for _, statName in ipairs(extraStatList) do
		report.defence[statName] = output[statName]
	end
	if includeFull then
		report.full = { }
		for key, value in pairs(output) do
			local valueType = type(value)
			if valueType == "number" or valueType == "string" or valueType == "boolean" then
				report.full[key] = value
			end
		end
	end
	return report
end

-- Encodes a report as pretty printed JSON
function evaluate.reportToJSON(report)
	local dkjson = require "dkjson"
	return dkjson.encode(report, { indent = true })
end

-- Command line entry point
local function main()
	local buildPath = arg[1]
	local outputPath = arg[2]
	if not buildPath then
		print("Usage: luajit Optimizer/Evaluate.lua <build xml path> [output json path]")
		os.exit(1)
	end
	local harness = dofile("Optimizer/Harness.lua")
	harness.init()
	local loadedBuild, errMsg = harness.loadBuildFile(buildPath)
	if not loadedBuild then
		print(errMsg)
		os.exit(1)
	end
	local report = evaluate.buildReport(loadedBuild, true)
	local jsonText = evaluate.reportToJSON(report)
	if outputPath then
		local fileHnd, fileErr = io.open(outputPath, "w")
		if not fileHnd then
			print("Cannot open output file: " .. (fileErr or outputPath))
			os.exit(1)
		end
		fileHnd:write(jsonText)
		fileHnd:close()
	else
		print(jsonText)
	end
end

-- Only run the entry point when invoked directly from the command line, not
-- when loaded as a module by other optimizer scripts or by the test suite
if arg and arg[0] and arg[0]:match("Evaluate%.lua$") then
	main()
end

return evaluate
