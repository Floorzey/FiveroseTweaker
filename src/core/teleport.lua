return function(api)
	local players = game:GetService('Players')
	local player = players.LocalPlayer
	local env = getgenv()
	local queue = type(queue_on_teleport) == 'function' and queue_on_teleport
		or type(queueonteleport) == 'function' and queueonteleport
		or type(syn) == 'table' and type(syn.queue_on_teleport) == 'function' and syn.queue_on_teleport
	local queued = false
	local saved = false
	local owner = api.token
	local queueid = tostring(api.token)..':'..tostring(os.clock())

	env.fiverosetweaker_queue_owner = owner

	local function quote(value)
		return string.format('%q', tostring(value))
	end

	local function script()
		local lines = {
			'local env = getgenv()',
			'local token = '..quote(queueid),
			'if env.fiverosetweaker_teleport_consumed == token or env.fiverosetweaker_teleport_loading == token then return end',
			'env.fiverosetweaker_teleport_loading = token',
			'env.fiverosetweaker_branch = '..quote(api.branch),
			'env.fiverosetweaker_repo = '..quote(api.repo),
			'env.fiverosetweaker_dev = '..tostring(api.dev == true),
			'env.fiverosetweaker_path = '..quote(api.path),
			'env.fiverosetweaker_profile = '..quote(api.profile and api.profile.name or 'default'),
			'local ok, err = pcall(function()'
		}

		if api.dev then
			lines[#lines + 1] = '\tlocal source = readfile(env.fiverosetweaker_path..\'/main.lua\')'
		else
			lines[#lines + 1] = '\tlocal source = game:HttpGet(env.fiverosetweaker_repo..\'/\'..env.fiverosetweaker_branch..\'/main.lua\', true)'
		end

		lines[#lines + 1] = '\tloadstring(source, \'@fiverosetweaker/main.lua\')()'
		lines[#lines + 1] = 'end)'
		lines[#lines + 1] = 'if ok then env.fiverosetweaker_teleport_consumed = token end'
		lines[#lines + 1] = 'if env.fiverosetweaker_teleport_loading == token then env.fiverosetweaker_teleport_loading = nil end'
		lines[#lines + 1] = 'if not ok then warn(\'[fiverosetweaker] \'..tostring(err)) end'
		return table.concat(lines, '\n')
	end

	local connection = player.OnTeleport:Connect(function(state)
		if rawget(env, 'fiverosetweaker_queue_owner') ~= owner then
			return
		end

		if state == Enum.TeleportState.Failed then
			queued = false
			saved = false
			api.teleport_queued = false
			return
		end

		if state ~= Enum.TeleportState.Started then
			return
		end

		if not saved and type(api.save) == 'function' then
			saved = true
			pcall(api.save, api)
		end

		if queued or not queue then
			return
		end

		local ok, err = pcall(queue, script())

		if ok then
			queued = true
			api.teleport_queued = true
		else
			api.teleport_queued = false
			warn('[fiverosetweaker] teleport queue failed: '..tostring(err))
		end
	end)

	api:clean(connection)
	api:clean(function()
		if rawget(env, 'fiverosetweaker_queue_owner') == owner then
			env.fiverosetweaker_queue_owner = nil
		end
	end)
	return connection
end
