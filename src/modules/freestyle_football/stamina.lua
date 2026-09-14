return function(api)
	local context = api.freestyle
	local options = api.options
	local toggles = api.toggles
	local box = api.tab:AddLeftGroupbox('stamina multiplier', 'battery-charging')
	local state = {
		object = nil,
		meta = nil,
		old = nil,
		hook = nil,
		character = nil,
		connections = {},
		seen = {},
		enabled = false,
		generation = 0
	}

	local function edit(meta, func)
		local readonly = false

		if type(isreadonly) == 'function' then
			local ok, value = pcall(isreadonly, meta)
			readonly = ok and value == true
		end

		if type(setreadonly) == 'function' then
			pcall(setreadonly, meta, false)
		end

		local ok, err = pcall(func)

		if readonly and type(setreadonly) == 'function' then
			pcall(setreadonly, meta, true)
		end

		return ok, err
	end

	local function restore()
		if state.meta and state.old and state.hook then
			edit(state.meta, function()
				if state.meta.__newindex == state.hook then
					state.meta.__newindex = state.old
				end
			end)
		end

		for _, item in ipairs(state.connections) do
			if item.disabled then
				local ok, enable = pcall(function()
					return item.connection.Enable
				end)

				if ok and type(enable) == 'function' then
					pcall(enable, item.connection)
				end
			end
		end

		table.clear(state.connections)
		table.clear(state.seen)
		state.object = nil
		state.meta = nil
		state.old = nil
		state.hook = nil
	end

	local function pause()
		if type(getconnections) ~= 'function' then
			return
		end

		local knit = context:knit()

		if not knit or not state.enabled or (type(api.isactive) == 'function' and not api:isactive()) then
			return
		end

		local service

		pcall(function()
			service = knit.GetService('KeyHandlerService')
		end)

		if not service or type(service.GetKey) ~= 'function' then
			return
		end

		local remote

		pcall(function()
			remote = service:GetKey('UpdateStamina')
		end)

		if not remote or not remote.OnClientEvent then
			return
		end

		local ok, connections = pcall(getconnections, remote.OnClientEvent)

		if not ok or type(connections) ~= 'table' then
			return
		end

		for _, connection in ipairs(connections) do
			if not state.enabled or (type(api.isactive) == 'function' and not api:isactive()) then
				break
			end

			if not state.seen[connection] then
				state.seen[connection] = true

				local enabled = true
				local readok, value = pcall(function()
					return connection.Enabled
				end)

				if readok and value == false then
					enabled = false
				end

				local disabled = false

				local methodok, disable = pcall(function()
					return connection.Disable
				end)

				if enabled and methodok and type(disable) == 'function' then
					disabled = pcall(disable, connection)
				end

				state.connections[#state.connections + 1] = {
					connection = connection,
					disabled = disabled
				}
			end
		end
	end

	local function hook()
		if type(api.isactive) == 'function' and not api:isactive() then
			return false
		end

		restore()

		local object = context:stamina()

		if not object or type(getrawmetatable) ~= 'function' then
			return false
		end

		local ok, meta = pcall(getrawmetatable, object)

		if not ok or not meta or type(meta.__newindex) ~= 'function' then
			return false
		end

		local old = meta.__newindex
		local hookfn
		state.object = object
		state.meta = meta
		state.old = old
		hookfn = function(target, key, value)
			if state.hook == hookfn
				and state.enabled
				and target == object
				and key == 'Value'
				and type(value) == 'number'
				and value < target.Value then

				local option = options.stamina_multiplier_value
				local multiplier = math.max(1, tonumber(option and option.Value) or 1)
				value = target.Value - ((target.Value - value) / multiplier)
			end

			return old(target, key, value)
		end
		state.hook = hookfn

		if type(api.isactive) == 'function' and not api:isactive() then
			restore()
			return false
		end

		local installed = edit(meta, function()
			meta.__newindex = state.hook
		end)

		if installed and meta.__newindex == state.hook then
			pause()
			return true
		end

		restore()
		return false
	end

	local function installed()
		if not (state.object and state.meta and state.hook) or context:stamina() ~= state.object then
			return false
		end

		local ok, current = pcall(function()
			return state.meta.__newindex
		end)

		return ok and current == state.hook
	end

	local function watch(generation)
		local notifyat = os.clock() + 5
		local notified = false

		while state.enabled and state.generation == generation do
			if type(api.isactive) == 'function' and not api:isactive() then
				break
		end

			if installed() then
				pause()
				notifyat = os.clock() + 5
				notified = false
			elseif hook() then
				notifyat = os.clock() + 5
				notified = false
			elseif not notified and os.clock() >= notifyat then
				notified = true
				api:notify('Stamina Multiplier', 'Waiting for the current stamina object', 3)
			end

			task.wait(0.5)
		end

		if state.generation == generation then
			restore()
		end
	end

	local function set(enabled)
		state.enabled = enabled == true
		state.generation = state.generation + 1

		if state.character then
			state.character:Disconnect()
			state.character = nil
		end

		if not state.enabled then
			restore()
			return
		end

		state.character = context.player.CharacterAdded:Connect(function()
			restore()
		end)

		task.spawn(watch, state.generation)
	end

	local toggleid = 'stamina_multiplier'
	local valueid = 'stamina_multiplier_value'

	box:AddToggle(toggleid, {
		Text = 'stamina multiplier',
		Tooltip = 'slows stamina drain',
		Default = false
	})

	box:AddSlider(valueid, {
		Text = 'multiplier',
		Default = 1,
		Min = 1,
		Max = 10,
		Rounding = 1,
		Suffix = 'x'
	})

	api:own(toggleid)
	api:own(valueid)
	api:addkey(toggles[toggleid], 'fiverose_tweaker_stamina_key', 'Stamina Multiplier', 'None')

	toggles[toggleid]:OnChanged(function()
		set(toggles[toggleid].Value)
	end)

	api:clean(function()
		state.enabled = false
		state.generation = state.generation + 1

		if state.character then
			state.character:Disconnect()
			state.character = nil
		end

		restore()
	end)

	return state
end
