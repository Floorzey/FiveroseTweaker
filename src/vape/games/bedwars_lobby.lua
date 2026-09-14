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


__fiverose_source = "bedwars/6872265039 - lobby/base.lua"
local run = __fiverose_run
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local kickThread = task.spawn(lplr.Kick, lplr, 'Bedwars is no longer supported by Vape V4, thank you for 5 years of support ❤️')
if coroutine.status(kickThread) ~= 'dead' then
	game:Shutdown()
end

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end

	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function() return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9) end)
		if KnitInit then break end
		task.wait()
	until KnitInit
	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end
	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local Client = require(replicatedStorage.TS.remotes).default.Client

	bedwars = setmetatable({
		Client = Client,
		CrateItemMeta = debug.getupvalue(Flamework.resolveDependency('client/controllers/global/reward-crate/crate-controller@CrateController').onStart, 3),
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	vape:Clean(function()
		table.clear(bedwars)
	end)
end)

for _, v in vape.Modules do
	if v.Category == 'Combat' then
		vape:Remove(i)
	end
end


__fiverose_source = "bedwars/6872265039 - lobby/Combat/Sprint.lua"


run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = false end) end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() bedwars.SprintController:stopSprinting() end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end) end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)


__fiverose_source = "bedwars/6872265039 - lobby/World/AutoGamble.lua"


run(function()
	local AutoGamble
	
	AutoGamble = vape.Categories.World:CreateModule({
		Name = 'AutoGamble',
		Function = function(callback)
			if callback then
				AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
					if data.openingPlayer == lplr then
						local tab = bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
						notif('AutoGamble', 'Won '..tab.displayName, 5)
					end
				end))
	
				repeat
					if not bedwars.CrateAltarController.activeCrates[1] then
						for _, v in bedwars.Store:getState().Consumable.inventory do
							if v.consumable:find('crate') then
								bedwars.CrateAltarController:pickCrate(v.consumable, 1)
								task.wait(1.2)
								if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][2] then
									bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
										crateId = bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
									})
								end
								break
							end
						end
					end
					task.wait(1)
				until not AutoGamble.Enabled
			end
		end,
		Tooltip = 'Automatically opens lucky crates, piston inspired!'
	})
end)
end
