-- Path of Building
--
-- Module: Optimizer Harness
-- Boots the headless environment for optimizer scripts and provides helpers
-- shared by all optimizer entry points. Scripts using this module must run
-- from the src directory, the same way as HeadlessWrapper.lua.
--

local harness = { }

-- Loads the headless wrapper unless the environment is already booted, which
-- is the case when running under busted with HeadlessWrapper.lua as helper.
-- Main.lua consumes arg[1] as a build link at startup, so the command line
-- is hidden during boot to keep script arguments intact.
function harness.init()
	if not loadBuildFromXML then
		local savedArg = arg
		arg = { }
		dofile("HeadlessWrapper.lua")
		arg = savedArg
	end
	return build
end

-- Reads a build XML file from disk and loads it as the active build
function harness.loadBuildFile(path)
	local fileHnd, errMsg = io.open(path, "r")
	if not fileHnd then
		return nil, "Cannot open build file: " .. (errMsg or path)
	end
	local xmlText = fileHnd:read("*a")
	fileHnd:close()
	local name = path:match("([^/\\]+)%.%w+$") or path
	loadBuildFromXML(xmlText, name)
	if not build.spec then
		return nil, "Build did not load correctly: " .. path
	end
	-- Complex builds can need extra frames before the first output exists
	for _ = 1, 3 do
		if build.calcsTab and build.calcsTab.mainOutput then
			break
		end
		runCallback("OnFrame")
	end
	if not (build.calcsTab and build.calcsTab.mainOutput) then
		return nil, "Build loaded but produced no calculation output: " .. path
	end
	return build
end

-- Commits pending build changes and rebuilds the calculation output
function harness.recalc()
	build.buildFlag = true
	runCallback("OnFrame")
	return build.calcsTab.mainOutput
end

return harness
