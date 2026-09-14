return function(api, entry, ...)
	local __native_readfile = readfile
	local __native_writefile = writefile
	local __native_isfile = isfile
	local __native_makefolder = makefolder
	local __fiverose_source = "base"

	local function __fiverose_trace(value)
		local trace = debug and debug.traceback
		return type(trace) == 'function' and trace(tostring(value), 2) or tostring(value)
	end

	local function __fiverose_run(func)
		local source = __fiverose_source
		local ok, result = xpcall(func, __fiverose_trace)
		if not ok then
			if api and type(api.vape_module_error) == 'function' then
				api:vape_module_error(source, result)
			else
				warn('[fiverosetweaker/vape] '..tostring(source)..': '..tostring(result))
			end
		end
		return ok, result
	end

	local function readfile(path)
		if api and type(api.vape_virtual_read) == 'function' then
			local found, value = api:vape_virtual_read(path)
			if found then return value end
		end
		if type(__native_readfile) == 'function' then
			return __native_readfile(path)
		end
		error('readfile unavailable: '..tostring(path), 2)
	end

	local function isfile(path)
		if api and type(api.vape_virtual_read) == 'function' then
			local found = api:vape_virtual_read(path)
			if found then return true end
		end
		if type(__native_isfile) == 'function' then
			local ok, value = pcall(__native_isfile, path)
			return ok and value == true
		end
		if type(__native_readfile) == 'function' then
			return pcall(__native_readfile, path)
		end
		return false
	end

	local function writefile(path, value)
		if api and type(api.vape_virtual_write) == 'function' and api:vape_virtual_write(path, value) then
			return
		end
		if type(__native_writefile) == 'function' then
			return __native_writefile(path, value)
		end
	end

	local function makefolder(path)
		if type(__native_makefolder) == 'function' then
			return __native_makefolder(path)
		end
	end


__fiverose_source = "skywars voxel/8542259458 - skywars lobby.lua"
local run = function(func) 
	func() 
end
local cloneref = cloneref or function(obj) 
	return obj 
end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local httpService = cloneref(game:GetService('HttpService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local sessioninfo = vape.Libraries.sessioninfo

run(function()
	local kills = sessioninfo:AddItem('Kills')
	local eggs = sessioninfo:AddItem('Eggs')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
end)
end
