-- Path of Building
--
-- Module: Optimizer Harness
-- Boots the headless environment for optimizer scripts and provides helpers
-- shared by all optimizer entry points. Scripts using this module must run
-- from the src directory, the same way as HeadlessWrapper.lua.
--

local harness = { }

local zlibBound = false

-- The SimpleGraphic stubs for Deflate and Inflate return empty strings,
-- which silently breaks timeless jewel data loading and share codes when
-- running headless. Bind the system zlib through the LuaJIT FFI when one is
-- available; on systems without zlib the stubs remain and only those
-- features stay unavailable.
local function bindZlib()
	if zlibBound then
		return
	end
	zlibBound = true
	local okFFI, ffi = pcall(require, "ffi")
	if not okFFI then
		return
	end
	local zlib
	for _, name in ipairs({ "z", "libz.so.1", "zlib1", "zlib" }) do
		local ok, lib = pcall(ffi.load, name)
		if ok then
			zlib = lib
			break
		end
	end
	if not zlib then
		return
	end
	pcall(ffi.cdef, [[
		unsigned long compressBound(unsigned long sourceLen);
		int compress2(unsigned char *dest, unsigned long *destLen, const unsigned char *source, unsigned long sourceLen, int level);
		int uncompress(unsigned char *dest, unsigned long *destLen, const unsigned char *source, unsigned long sourceLen);
	]])
	function Inflate(text)
		local destSize = math.max(#text * 4, 65536)
		for _ = 1, 8 do
			local dest = ffi.new("unsigned char[?]", destSize)
			local destLen = ffi.new("unsigned long[1]", destSize)
			local result = zlib.uncompress(dest, destLen, text, #text)
			if result == 0 then
				return ffi.string(dest, tonumber(destLen[0]))
			elseif result ~= -5 then
				return nil, "zlib uncompress error " .. result
			end
			destSize = destSize * 4
		end
		return nil, "zlib uncompress output too large"
	end
	function Deflate(text)
		local bound = tonumber(zlib.compressBound(#text))
		local dest = ffi.new("unsigned char[?]", bound)
		local destLen = ffi.new("unsigned long[1]", bound)
		local result = zlib.compress2(dest, destLen, text, #text, 9)
		if result == 0 then
			return ffi.string(dest, tonumber(destLen[0]))
		end
		return nil, "zlib compress error " .. result
	end
end

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
	bindZlib()
	return build
end

-- Returns and clears any pending engine error prompt. A set promptMsg makes
-- every later frame a no-op, so it must be cleared or one broken build would
-- wedge the whole session.
local function takePromptMsg()
	if __mainObject__ and __mainObject__.promptMsg then
		local msg = tostring(__mainObject__.promptMsg)
		__mainObject__.promptMsg = nil
		return (msg:gsub("%c+", " "):gsub("%^%d", ""):sub(1, 300))
	end
end

-- Reads a build XML file from disk and loads it as the active build
function harness.loadBuildFile(path)
	harness.init()
	local fileHnd, errMsg = io.open(path, "r")
	if not fileHnd then
		return nil, "Cannot open build file: " .. (errMsg or path)
	end
	local xmlText = fileHnd:read("*a")
	fileHnd:close()
	local name = path:match("([^/\\]+)%.%w+$") or path
	loadBuildFromXML(xmlText, name)
	local promptMsg = takePromptMsg()
	if promptMsg then
		return nil, "Engine error while loading " .. path .. ": " .. promptMsg
	end
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
	promptMsg = takePromptMsg()
	if promptMsg then
		return nil, "Engine error while loading " .. path .. ": " .. promptMsg
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
	local promptMsg = takePromptMsg()
	if promptMsg then
		ConPrintf("Optimizer: engine error during recalc: %s", promptMsg)
	end
	return build.calcsTab.mainOutput
end

return harness
