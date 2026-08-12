-- Path of Building
--
-- Module: Optimizer Report
-- Ranks builds as league starters and explains the ranking.
-- Command line usage, from the src directory:
--   LUA_PATH="../runtime/lua/?.lua;../runtime/lua/?/init.lua;;" luajit Optimizer/Report.lua <build xml> [more build xmls...]
-- Prints a ranked JSON report to stdout.
--

local report = { }

local subscoreLabels = {
	damage = "damage",
	maxHit = "maximum hit taken",
	ehp = "effective hit pool",
	recovery = "recovery",
	resistances = "elemental resistances",
	chaosRes = "chaos resistance",
	gearAgnostic = "gear independent damage",
	linkRatio = "four link damage retention",
}

-- Builds human readable reasons from an evaluation result: failed hard
-- constraints first, then the strongest and weakest subscores
local function buildReasons(result)
	local reasons = { }
	if not result.constraints.uniques.pass then
		table.insert(reasons, "Uses " .. result.constraints.uniques.count .. " unique items, above the league start allowance")
	end
	if not result.constraints.resistances.pass then
		table.insert(reasons, "Lowest elemental resistance is " .. string.format("%.0f", result.constraints.resistances.minimum) .. ", below the 75 cap")
	end
	if not result.constraints.gems.pass then
		table.insert(reasons, "Gems not obtainable at league start: " .. table.concat(result.constraints.gems.flags, "; "))
	end
	local ordered = { }
	for key, value in pairs(result.subscores) do
		table.insert(ordered, { key = key, value = value })
	end
	table.sort(ordered, function(a, b) return a.value > b.value end)
	if #ordered > 0 then
		table.insert(reasons, "Strongest: " .. subscoreLabels[ordered[1].key] .. " and " .. subscoreLabels[ordered[2].key])
		table.insert(reasons, "Weakest: " .. subscoreLabels[ordered[#ordered].key] .. " and " .. subscoreLabels[ordered[#ordered - 1].key])
	end
	return reasons
end

-- Loads, normalizes and scores each build file, returns entries sorted by
-- descending league start score
function report.rankBuilds(paths, options)
	local harness = dofile("Optimizer/Harness.lua")
	local evaluate = dofile("Optimizer/Evaluate.lua")
	local objective = dofile("Optimizer/Objective.lua")
	local entries = { }
	for _, path in ipairs(paths) do
		local loadedBuild, errMsg = harness.loadBuildFile(path)
		if loadedBuild then
			-- One broken build must not abort the whole ranking run
			local ok, entryOrErr = pcall(function()
				local meta = evaluate.buildReport(loadedBuild).build
				local result = objective.evaluateLeagueStart(loadedBuild, options)
				return {
					path = path,
					build = meta,
					score = result.score,
					subscores = result.subscores,
					constraints = result.constraints,
					linkDelta = result.linkDelta,
					reasons = buildReasons(result),
				}
			end)
			if ok then
				table.insert(entries, entryOrErr)
			else
				table.insert(entries, { path = path, error = tostring(entryOrErr) })
			end
		else
			table.insert(entries, { path = path, error = errMsg })
		end
	end
	table.sort(entries, function(a, b) return (a.score or -1) > (b.score or -1) end)
	for rank, entry in ipairs(entries) do
		entry.rank = rank
	end
	return entries
end

-- Command line entry point
local function main()
	if not arg[1] then
		print("Usage: luajit Optimizer/Report.lua <build xml> [more build xmls...]")
		os.exit(1)
	end
	local harness = dofile("Optimizer/Harness.lua")
	harness.init()
	local paths = { }
	for index = 1, #arg do
		table.insert(paths, arg[index])
	end
	local entries = report.rankBuilds(paths)
	local dkjson = require "dkjson"
	print(dkjson.encode({ ranking = entries }, { indent = true }))
end

if arg and arg[0] and arg[0]:match("Report%.lua$") then
	main()
end

return report
