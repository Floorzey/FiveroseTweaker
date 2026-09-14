return function(api)
	local lib = api.lib
	local tabs = api.tabs
	local options = api.options
	local original = rawget(lib, 'ToggleKeybind')
	local id = 'fiverose_gui_bind'

	if api.backend == 'universal' then
		local native

		for _, flag in ipairs({
			'Menu Bind',
			'Menu Keybind',
			'GUI Bind',
			'Gui Bind',
			'Toggle Keybind'
		}) do
			native = api.ui and api.ui:findflag(flag)

			if type(native) == 'table' then
				break
			end
		end

		if type(native) ~= 'table' then
			warn('[fiverosetweaker] Universal Fiverose Menu Bind was not found; GUI rebind skipped')
			return
		end

		local before = options[id]
		local picker = api.ui:wrapkey(native, id, 'E')

		if type(picker) ~= 'table' then
			warn('[fiverosetweaker] Universal Fiverose Menu Bind could not be wrapped; GUI rebind skipped')
			return
		end

		options[id] = picker
		api:own(id)
		api.gui_bind = picker
		api.nokey = api.nokey or {}
		api.nokey[id] = true

		api:clean(function()
			if api.binds and api.binds.active == picker then
				api.binds:cancel(picker)
			end

			if options[id] == picker then
				options[id] = before
			end

			api.nokey[id] = nil
			api:disown(id)

			if api.gui_bind == picker then
				api.gui_bind = nil
			end

			picker:Destroy()
		end)

		return picker
	end

	local function alive(obj)
		return typeof(obj) == 'Instance' and obj.Parent ~= nil
	end

	local function has(tab, wanted)
		wanted = wanted:lower()

		for _, side in ipairs(type(tab) == 'table' and rawget(tab, 'Sides') or {}) do
			if alive(side) then
				for _, obj in ipairs(side:GetDescendants()) do
					if (obj:IsA('TextLabel') or obj:IsA('TextButton') or obj:IsA('TextBox'))
						and tostring(obj.Text):lower() == wanted then

						return true
					end
				end
			end
		end

		return false
	end

	local function info()
		for _, tab in pairs(tabs) do
			if type(tab) == 'table'
				and type(rawget(tab, 'AddLeftGroupbox')) == 'function'
				and has(tab, 'account')
				and has(tab, 'script status') then

				return tab
			end
		end
	end

	local function default()
		if type(original) == 'table' and type(rawget(original, 'Value')) == 'string' then
			return original.Value
		end

		if typeof(original) == 'EnumItem' and original.EnumType == Enum.KeyCode then
			return original.Name
		end

		return 'RightShift'
	end

	local tab = info()

	if not tab then
		warn('[fiverosetweaker] Fiverose info tab not found; GUI rebind skipped')
		return
	end

	local box = tab:AddLeftGroupbox('gui keybind', 'keyboard')
	local before = options[id]
	local label = box:AddLabel('gui key')

	label:AddKeyPicker(id, {
		Default = default(),
		SyncToggleState = false,
		Mode = 'Press',
		Text = 'gui key',
		NoUI = false,
		Blacklisted = {'MB1', 'MB2'}
	})

	local picker = options[id]

	if type(picker) ~= 'table' then
		error('GUI key picker was not created')
	end

	api:own(id)
	api.gui_bind = picker
	lib.ToggleKeybind = picker

	api:clean(function()
		if api.binds and api.binds.active == picker then
			api.binds:cancel(picker)
		end

		if rawget(lib, 'ToggleKeybind') == picker then
			lib.ToggleKeybind = original
		end

		local item = options[id]

		if item ~= before and type(item) == 'table' and type(rawget(item, 'Destroy')) == 'function' then
			pcall(item.Destroy, item)
		end

		if options[id] == item and item ~= before then
			options[id] = before
		end

		api:disown(id)

		if type(box) == 'table' and type(rawget(box, 'Destroy')) == 'function' then
			pcall(box.Destroy, box)
		end

		if api.gui_bind == picker then
			api.gui_bind = nil
		end
	end)

	return picker
end
