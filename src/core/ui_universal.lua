return function(api, root)
	local input = game:GetService('UserInputService')
	local gc = {}

	if type(getgc) == 'function' then
		local ok, result = pcall(getgc, true)

		if ok and type(result) == 'table' then
			gc = result
		end
	end
	local score = -1
	local lib
	local objects = {}
	local candidates = {}

	local function alive(obj)
		return typeof(obj) == 'Instance' and obj.Parent ~= nil
	end

	local function inside(obj, parent)
		return alive(obj)
			and alive(parent)
			and (obj == parent or obj:IsDescendantOf(parent))
	end

	local function linkeditems(items)
		if alive(items) then
			return inside(items, root)
		end

		if type(items) ~= 'table' then
			return false
		end

		for _, item in pairs(items) do
			if inside(item, root) then
				return true
			end
		end

		return false
	end

	local function metascore(meta)
		if type(meta) ~= 'table' then
			return -1
		end

		local value = rawget(meta, '__index') == meta and 2000 or 0

		for _, name in ipairs({
			'Window',
			'Panel',
			'Tab',
			'Column',
			'Section',
			'Toggle',
			'Slider',
			'Dropdown',
			'Textbox',
			'Button',
			'Label',
			'Keybind'
		}) do
			if type(rawget(meta, name)) == 'function' then
				value = value + 1000
			end
		end

		if type(rawget(meta, 'Flags')) == 'table' then
			value = value + 1000
		end

		if type(rawget(meta, 'ConfigFlags')) == 'table' then
			value = value + 1000
		end

		if alive(rawget(meta, 'Items')) then
			value = value + 1000
		end

		return value
	end

	local seen = {}

	for index, obj in ipairs(gc) do
		if type(obj) == 'table' then
			local meta = getmetatable(obj)

			if type(meta) == 'table' then
				if not seen[meta] then
					seen[meta] = true
					candidates[meta] = {
						score = metascore(meta),
						linked = false
					}
				end

				local candidate = candidates[meta]
				local items = rawget(obj, 'Items')

				if candidate and linkeditems(items) then
					candidate.linked = true
				end
			end
		end

		if index % 4000 == 0 then
			task.wait()
		end
	end

	for meta, candidate in pairs(candidates) do
		if candidate.linked and candidate.score > score then
			score = candidate.score
			lib = meta
		end
	end

	if score < 12000 or type(lib) ~= 'table' then
		error('Universal Fiverose library not found')
	end

	for index, obj in ipairs(gc) do
		if type(obj) == 'table'
			and getmetatable(obj) == lib
			and linkeditems(rawget(obj, 'Items')) then

			objects[#objects + 1] = obj
		end

		if index % 4000 == 0 then
			task.wait()
		end
	end

	local panel
	local tabs = {}
	local native = {}
	local menu

	for _, obj in ipairs(objects) do
		local items = rawget(obj, 'Items')

		if type(items) == 'table'
			and type(rawget(obj, 'SetMenuVisible')) == 'function'
			and type(rawget(obj, 'ToggleMenu')) == 'function'
			and alive(rawget(items, 'TabButtonHolder'))
			and alive(rawget(items, 'PageHolder')) then

			panel = obj
		elseif type(items) == 'table'
			and type(rawget(obj, 'OpenTab')) == 'function'
			and alive(rawget(items, 'Outline'))
			and alive(rawget(items, 'Page'))
			and type(rawget(obj, 'Name')) == 'string' then

			tabs[#tabs + 1] = obj
		elseif type(items) == 'table'
			and type(rawget(obj, 'Set')) == 'function'
			and type(rawget(obj, 'Flag')) == 'string' then

			native[#native + 1] = obj

			if rawget(obj, 'Flag') == 'Menu Bind'
				and rawget(obj, 'Key') ~= nil then

				menu = obj
			end
		end
	end

	if type(panel) ~= 'table' then
		error('Universal Fiverose panel not found')
	end

	local screen = rawget(lib, 'Items')

	if not alive(screen) or not screen:IsA('ScreenGui') then
		local holder = type(rawget(panel, 'Items')) == 'table'
			and rawget(rawget(panel, 'Items'), 'Window')

		screen = alive(holder) and holder:FindFirstAncestorOfClass('ScreenGui')
	end

	if not alive(screen) or not screen:IsA('ScreenGui') or screen ~= root then
		error('Universal Fiverose library does not match the detected UI')
	end

	local initial = setmetatable({}, {__mode = 'k'})
	initial[screen] = true

	for _, obj in ipairs(screen:GetDescendants()) do
		initial[obj] = true
	end

	local state = {
		lib = lib,
		panel = panel,
		screen = screen,
		objects = objects,
		native = native,
		menu = menu,
		tabs = {},
		wrapped = {},
		created = {},
		owneditems = {},
		ownedroots = setmetatable({}, {__mode = 'k'}),
		initial = initial,
		dropguards = {},
		inputitems = {},
		nativeitems = setmetatable({}, {__mode = 'k'}),
		dragging = {},
		inputcons = {},
		dead = false,
		serial = 0
	}

	local toggles = {}
	local options = {}
	local tabmap = {}
	local facade = {
		Backend = 'universal',
		Tabs = tabmap,
		Toggles = toggles,
		Options = options,
		Window = nil,
		ActiveTab = nil
	}

	local function dropdead(obj)
		local items = type(obj) == 'table' and rawget(obj, 'Items')
		local elements = type(items) == 'table' and rawget(items, 'DropdownElements')

		if typeof(elements) ~= 'Instance' then
			return true
		end

		local ok, parent = pcall(function()
			return elements.Parent
		end)

		return not ok or parent == nil
	end

	local function guarddropdown(obj)
		if type(obj) ~= 'table' then
			return obj
		end

		local items = rawget(obj, 'Items')

		if type(items) ~= 'table'
			or typeof(rawget(items, 'DropdownElements')) ~= 'Instance'
			or type(rawget(obj, 'SetVisible')) ~= 'function'
			or type(rawget(obj, 'Tween')) ~= 'function' then

			return obj
		end

		for _, guard in ipairs(state.dropguards) do
			if guard.obj == obj then
				return obj
			end
		end

		local oldvisible = rawget(obj, 'SetVisible')
		local oldtween = rawget(obj, 'Tween')
		local safevisible
		local safetween

		safetween = function(...)
			if dropdead(obj) then
				obj.Tweening = false
				obj.Open = false
				return
			end

			return oldtween(...)
		end

		safevisible = function(...)
			if dropdead(obj) then
				obj.Tweening = false
				obj.Open = false
				return
			end

			return oldvisible(...)
		end

		obj.Tween = safetween
		obj.SetVisible = safevisible
		state.dropguards[#state.dropguards + 1] = {
			obj = obj,
			oldvisible = oldvisible,
			oldtween = oldtween,
			safevisible = safevisible,
			safetween = safetween
		}

		return obj
	end

	for _, obj in ipairs(objects) do
		guarddropdown(obj)
	end

	local olddropdown = rawget(lib, 'Dropdown')
	local safedropdown

	if type(olddropdown) == 'function' then
		safedropdown = function(...)
			return guarddropdown(olddropdown(...))
		end

		lib.Dropdown = safedropdown
	end

	api:clean(function()
		if safedropdown and rawget(lib, 'Dropdown') == safedropdown then
			lib.Dropdown = olddropdown
		end

		for index = #state.dropguards, 1, -1 do
			local guard = state.dropguards[index]
			local obj = guard.obj

			if not dropdead(obj) then
				if rawget(obj, 'SetVisible') == guard.safevisible then
					obj.SetVisible = guard.oldvisible
				end

				if rawget(obj, 'Tween') == guard.safetween then
					obj.Tween = guard.oldtween
				end
			end

			state.dropguards[index] = nil
		end
	end)

	local keyaliases = {
		MB1 = 'MouseButton1',
		MB2 = 'MouseButton2',
		MB3 = 'MouseButton3'
	}

	local function keyname(value)
		if typeof(value) == 'EnumItem' then
			value = value.Name
		end

		value = tostring(value or 'NONE')
		value = value:gsub('Enum%.KeyCode%.', '')
		value = value:gsub('Enum%.UserInputType%.', '')
		value = (value == 'NONE' or value == 'Unknown') and 'None' or value
		return keyaliases[value] or value
	end

	local function keyenum(value)
		if typeof(value) == 'EnumItem' then
			return value
		end

		value = keyname(value)

		if value == 'None' then
			return 'NONE'
		end

		return Enum.KeyCode[value] or Enum.UserInputType[value] or 'NONE'
	end

	local function invalid(value)
		if type(value) == 'table' then
			return invalid(value.Key or value.Value or value[1])
		end

		return value == Enum.KeyCode.Unknown or keyname(value) == 'None'
	end

	local function emit(item)
		if type(rawget(item, 'Changed')) == 'function' then
			pcall(item.Changed, item.Value)
		end

		for _, callback in ipairs(rawget(item, '_changed') or {}) do
			pcall(callback, item.Value)
		end
	end

	local function rootof(obj, names)
		local items = type(obj) == 'table' and rawget(obj, 'Items')

		if type(items) ~= 'table' then
			return
		end

		for _, name in ipairs(names) do
			local value = rawget(items, name)

			if alive(value) then
				return value
			end
		end
	end

	local function setvisible(obj, value)
		if type(obj) ~= 'table' then
			return
		end

		for _, name in ipairs({
			'Toggle',
			'Slider',
			'Dropdown',
			'Textbox',
			'Button',
			'Label',
			'Keybind',
			'ColorpickerObject',
			'Outline',
			'Page'
		}) do
			local item = type(rawget(obj, 'Items')) == 'table'
				and rawget(rawget(obj, 'Items'), name)

			if alive(item) then
				item.Visible = value == true
			end
		end
	end

	local function clearflag(flag)
		if type(flag) ~= 'string' then
			return
		end

		local flags = rawget(lib, 'Flags')
		local config = rawget(lib, 'ConfigFlags')

		if type(flags) == 'table' then
			flags[flag] = nil
			flags[flag..'_MODE'] = nil
			flags[flag..'_LIST'] = nil
			flags[flag..'_RAINBOW_FLAG'] = nil
		end

		if type(config) == 'table' then
			config[flag] = nil
			config[flag..'_MODE'] = nil
			config[flag..'_LIST'] = nil
			config[flag..'_RAINBOW_FLAG'] = nil
		end
	end

	local inputsignals = {
		began = input.InputBegan,
		changed = input.InputChanged,
		ended = input.InputEnded
	}
	local inputneeds = {
		Dropdown = {began = true},
		Slider = {changed = true, ended = true},
		KeyPicker = {began = true, ended = true},
		ColorPicker = {began = true, changed = true, ended = true}
	}

	local function confunc(con)
		local ok, fn = pcall(function()
			return con.Function or con.Callback
		end)

		return ok and type(fn) == 'function' and fn or nil
	end

	local function consnapshot(signal)
		local result = {}

		if type(getconnections) ~= 'function' then
			return result
		end

		local ok, connections = pcall(getconnections, signal)

		if not ok or type(connections) ~= 'table' then
			return result
		end

		for _, con in ipairs(connections) do
			local fn = confunc(con)

			if fn then
				result[fn] = (result[fn] or 0) + 1
			end
		end

		return result
	end

	local function condisconnect(con)
		pcall(function()
			if type(con.Disable) == 'function' then
				con:Disable()
			elseif type(con.Disconnect) == 'function' then
				con:Disconnect()
			end
		end)
	end

	local function connectionmark(kind)
		local cons = rawget(lib, 'Connections')
		local mark = {
			library = type(cons) == 'table' and #cons or 0,
			signals = {}
		}
		local needs = inputneeds[kind]

		if needs and type(getconnections) == 'function' then
			for name in pairs(needs) do
				mark.signals[name] = consnapshot(inputsignals[name])
			end
		end

		return mark
	end

	local function addowned(item, con)
		if con == nil then
			return
		end

		local found = rawget(item, '_connectionset')

		if not found[con] then
			found[con] = true
			item._connections[#item._connections + 1] = con
		end
	end

	local function addlocal(item, signal, callback)
		if typeof(signal) ~= 'RBXScriptSignal' then
			return
		end

		local ok, con = pcall(signal.Connect, signal, callback)

		if ok then
			addowned(item, con)
		end
	end

	local function adoptconnections(item, mark)
		if type(item) ~= 'table' or rawget(item, '_owned') ~= true then
			return
		end

		mark = type(mark) == 'table' and mark or {library = tonumber(mark) or 0, signals = {}}
		local captured = {}
		local adopted = {}
		local adoptedset = {}
		local usedinput = false

		for name, before in pairs(mark.signals or {}) do
			local signal = inputsignals[name]

			if signal then
				local current = {}
				local list = {}
				local found = {}
				local ok, connections = pcall(getconnections, signal)

				for _, con in ipairs(ok and type(connections) == 'table' and connections or {}) do
					local fn = confunc(con)

					if fn then
						current[fn] = (current[fn] or 0) + 1

						if current[fn] > (before[fn] or 0) then
							captured[con] = true

							if not found[fn] then
								found[fn] = true
								list[#list + 1] = fn
							end

							condisconnect(con)
							usedinput = true
						end
					end
				end

				if #list > 0 then
					adopted[name] = list
					adoptedset[name] = true
				end
			end
		end

		for name, list in pairs(adopted) do
			if adoptedset[name] then
				item._input[name] = list
			end
		end

		local cons = rawget(lib, 'Connections')

		if type(cons) == 'table' then
			for index = (tonumber(mark.library) or #cons) + 1, #cons do
				local con = cons[index]

				if con ~= nil and not captured[con] then
					addowned(item, con)
				end
			end

			for index = #cons, (tonumber(mark.library) or #cons) + 1, -1 do
				if captured[cons[index]] then
					table.remove(cons, index)
				end
			end
		end

		if usedinput then
			state.inputitems[item] = true
			state.nativeitems[item.Native] = item
		end

		if rawget(item, '_inputtracked') then
			return
		end

		item._inputtracked = true
		local obj = item.Native
		local items = type(obj) == 'table' and rawget(obj, 'Items')

		if item.Type == 'Slider' and type(items) == 'table' then
			local outline = rawget(items, 'Outline')

			if alive(outline) then
				addlocal(item, outline.MouseButton1Down, function()
					if not item.Destroyed then
						state.dragging[item] = true
					end
				end)
			end
		elseif item.Type == 'ColorPicker' and type(items) == 'table' then
			for _, name in ipairs({'Alpha', 'Hue', 'SatValHolder'}) do
				local handle = rawget(items, name)

				if alive(handle) then
					addlocal(item, handle.MouseButton1Down, function()
						if not item.Destroyed then
							state.dragging[item] = true
						end
					end)
				end
			end
		end
	end

	local function releaseconnections(item)
		if type(item) ~= 'table' then
			return
		end

		state.inputitems[item] = nil
		state.dragging[item] = nil

		if type(rawget(item, 'Native')) == 'table' then
			state.nativeitems[item.Native] = nil
		end

		local list = rawget(item, '_connections') or {}
		local found = rawget(item, '_connectionset') or {}
		local native = rawget(item, 'Native')
		local binding = type(native) == 'table' and rawget(native, 'Binding')

		if rawget(item, '_owned') == true and binding ~= nil and not found[binding] then
			found[binding] = true
			list[#list + 1] = binding
		end

		for _, con in ipairs(list) do
			condisconnect(con)
		end

		local cons = rawget(lib, 'Connections')

		if type(cons) == 'table' then
			for index = #cons, 1, -1 do
				if found[cons[index]] then
					table.remove(cons, index)
				end
			end
		end

		table.clear(list)
		table.clear(found)
	end

	local function trackmethod(item, obj, name)
		if type(item) ~= 'table'
			or rawget(item, '_owned') ~= true
			or type(obj) ~= 'table' then

			return
		end

		local old = rawget(obj, name)

		if type(old) ~= 'function' then
			return
		end

		local wrapped

		wrapped = function(...)
			local mark = connectionmark(item.Type)
			local result = table.pack(pcall(old, ...))
			adoptconnections(item, mark)

			if not result[1] then
				error(result[2], 0)
			end

			return table.unpack(result, 2, result.n)
		end

		obj[name] = wrapped
		item._hooks[#item._hooks + 1] = {
			obj = obj,
			name = name,
			old = old,
			wrapped = wrapped
		}
	end

	local function tracknative(item, obj, mark)
		if type(item) ~= 'table' or rawget(item, '_owned') ~= true then
			return item
		end

		adoptconnections(item, mark)
		trackmethod(item, obj, 'SetVisible')
		trackmethod(item, obj, 'Tween')
		return item
	end

	local inputwarnings = {}

	local function runinput(item, name, ...)
		if type(item) ~= 'table' or item.Destroyed then
			return
		end

		for _, fn in ipairs(item._input[name] or {}) do
			local ok, err = pcall(fn, ...)

			if not ok then
				local native = rawget(item, 'Native')
				local id = type(native) == 'table' and rawget(native, 'Flag') or rawget(item, 'Id')
				local key = tostring(item.Type)..'/'..tostring(id or '?')..'/'..tostring(name)
				local now = os.clock()

				if now >= (inputwarnings[key] or 0) then
					inputwarnings[key] = now + 5
					warn('[fiverosetweaker/ui] '..key..': '..tostring(err))
				end
			end
		end
	end

	local function inputkey(obj)
		return obj.UserInputType == Enum.UserInputType.Keyboard
			and obj.KeyCode
			or obj.UserInputType
	end

	local function keymatches(item, obj)
		local native = type(item) == 'table' and rawget(item, 'Native')
		local key = type(native) == 'table' and rawget(native, 'Key')
		local current = inputkey(obj)

		return key ~= nil
			and key ~= 'NONE'
			and key ~= Enum.KeyCode.Unknown
			and (current == key or tostring(current) == tostring(key))
	end

	local function apiactive()
		return type(api.isactive) ~= 'function' or api:isactive()
	end

	local function mouseitem()
		local point = input:GetMouseLocation()

		for item in pairs(state.inputitems) do
			local root = type(item) == 'table' and rawget(item, 'Container')

			if not item.Destroyed and item.Type == 'KeyPicker' and alive(root) then
				local pos = root.AbsolutePosition
				local size = root.AbsoluteSize

				if point.X >= pos.X and point.Y >= pos.Y
					and point.X <= pos.X + size.X
					and point.Y <= pos.Y + size.Y then

					return item
				end
			end
		end
	end

	local function synccapture()
		local bind = api.binds

		if type(bind) ~= 'table' then
			return
		end

		local active = bind.active
		local wanted = mouseitem()

		if active and (active.Destroyed or rawget(active.Native, 'Open') ~= true) then
			bind:cancel(active)
			active = nil
		end

		for item in pairs(state.inputitems) do
			if not item.Destroyed
				and item.Type == 'KeyPicker'
				and rawget(item.Native, 'Open') == true then

				if not active then
					bind:begin(item)
					active = item
				elseif item ~= active then
					if item == wanted then
						bind:cancel(active)
						bind:begin(item)
						active = item
					else
						item.Native.Open = false
					end
				end
			end
		end

		return active
	end

	state.inputcons[#state.inputcons + 1] = input.InputBegan:Connect(function(obj, processed)
		if state.dead or not apiactive() then
			return
		end

		local bind = api.binds
		local active = synccapture()

		if active and obj.UserInputType == Enum.UserInputType.MouseButton1 then
			if mouseitem() ~= active then
				bind:cancel(active)
			end

			bind:suppress(obj)
			return
		end

		if bind then
			if bind:began(obj, processed, input:GetFocusedTextBox() ~= nil) then
				return
			end
		elseif processed or input:GetFocusedTextBox() then
			return
		end

		local called = {}
		local open = rawget(lib, 'OpenElement')
		local openitem = state.nativeitems[open]

		if openitem
			and (openitem.Type == 'Dropdown' or openitem.Type == 'ColorPicker') then

			called[openitem] = true
			runinput(openitem, 'began', obj, processed)
		end

		for item in pairs(state.inputitems) do
			if not item.Destroyed and item.Type == 'KeyPicker' then
				local native = item.Native

				if not called[item]
					and ((not bind and rawget(native, 'Open') == true) or keymatches(item, obj)) then

					called[item] = true
					runinput(item, 'began', obj, processed)
				end
			end
		end
	end)

	state.inputcons[#state.inputcons + 1] = input.InputChanged:Connect(function(obj)
		if state.dead or not apiactive() or obj.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		for item in pairs(state.dragging) do
			if item.Destroyed then
				state.dragging[item] = nil
			else
				runinput(item, 'changed', obj)
			end
		end
	end)

	state.inputcons[#state.inputcons + 1] = input.InputEnded:Connect(function(obj, processed)
		if state.dead or not apiactive() then
			return
		end

		local skipped = api.binds and api.binds:ended(obj)

		if obj.UserInputType == Enum.UserInputType.MouseButton1 then
			for item in pairs(state.dragging) do
				runinput(item, 'ended', obj, processed)
				state.dragging[item] = nil
			end
		end

		if skipped then
			return
		end

		for item in pairs(state.inputitems) do
			if not item.Destroyed
				and item.Type == 'KeyPicker'
				and tostring(rawget(item.Native, 'Mode')) == 'Hold'
				and keymatches(item, obj) then

				runinput(item, 'ended', obj, processed)
			end
		end
	end)

	api:clean(function()
		state.dead = true

		if api.binds then
			api.binds:cancel()
		end

		for index = #state.inputcons, 1, -1 do
			condisconnect(state.inputcons[index])
			state.inputcons[index] = nil
		end

		table.clear(state.inputitems)
		table.clear(state.dragging)
	end)

	local function ownroot(obj)
		if not alive(obj)
			or obj == screen
			or not inside(obj, screen)
			or state.initial[obj] then

			return
		end

		state.ownedroots[obj] = true
		return obj
	end

	local function trackowned(item)
		state.owneditems[#state.owneditems + 1] = item
		return item
	end

	local function destroyowned(...)
		for index = 1, select('#', ...) do
			local obj = select(index, ...)

			if state.ownedroots[obj] then
				state.ownedroots[obj] = nil

				if alive(obj) and obj ~= screen and inside(obj, screen) then
					pcall(obj.Destroy, obj)
				end
			end
		end
	end

	local function base(kind, id, obj, owned)
		local item = {
			Type = kind,
			Id = id,
			Native = obj,
			Container = rootof(obj, {
				'Toggle',
				'Slider',
				'Dropdown',
				'Textbox',
				'Button',
				'Label',
				'Keybind',
				'ColorpickerObject'
			}),
			Destroyed = false,
			_changed = {},
			_owned = owned ~= false,
			_extra = {},
			_hooks = {},
			_connections = {},
			_connectionset = {},
			_input = {began = {}, changed = {}, ended = {}}
		}

		function item:OnChanged(callback)
			if type(callback) == 'function' then
				self._changed[#self._changed + 1] = callback
			end

			return self
		end

		function item:SetVisible(value)
			setvisible(self.Native, value)
			return self
		end

		function item:Destroy()
			if self.Destroyed then
				return false
			end

			if api.binds and api.binds.active == self then
				api.binds:cancel(self)
			end

			self.Destroyed = true

			for index = #self._hooks, 1, -1 do
				local hook = self._hooks[index]

				if type(hook) == 'table'
					and rawget(hook.obj, hook.name) == hook.wrapped then

					hook.obj[hook.name] = hook.old
				end

				self._hooks[index] = nil
			end

			releaseconnections(self)

			if type(self._restore) == 'function' then
				pcall(self._restore)
				self._restore = nil
			end

			if self._owned then
				if rawget(lib, 'OpenElement') == self.Native then
					lib.OpenElement = nil
				end

				destroyowned(self.Container)
				clearflag(self._flag or self.Id)
			end

			if self.Id ~= nil and toggles[self.Id] == self then
				toggles[self.Id] = nil
			end

			if self.Id ~= nil and options[self.Id] == self then
				options[self.Id] = nil
			end

			return true
		end

		if item._owned then
			ownroot(item.Container)
			trackowned(item)
		end

		return item
	end

	local function wrapkey(obj, id, owned, mark, fallback)
		if type(obj) ~= 'table' or type(rawget(obj, 'Set')) ~= 'function' then
			return
		end

		local item = base('KeyPicker', id, obj, owned)
		tracknative(item, obj, mark)
		local old = rawget(obj, 'Set')
		local oldcallback = rawget(obj, 'Callback')
		local config = rawget(lib, 'ConfigFlags')
		local oldconfig = type(config) == 'table' and rawget(config, rawget(obj, 'Flag'))
		local guarded
		item._flag = rawget(obj, 'Flag') or id
		item.Value = keyname(rawget(obj, 'Key'))
		item.Mode = tostring(rawget(obj, 'Mode') or 'Toggle')
		item.Modifiers = type(rawget(obj, 'Modifiers')) == 'table' and table.clone(obj.Modifiers) or {}
		item.Blacklisted = type(rawget(obj, 'Blacklisted')) == 'table' and table.clone(obj.Blacklisted) or {}
		item.Fallback = tostring(fallback or 'None')

		if type(oldcallback) == 'function' then
			guarded = function(...)
				if api.binds and api.binds:blocked(item) then
					return
				end

				return oldcallback(...)
			end
			obj.Callback = guarded
		end

		local function update(silent)
			item.Value = keyname(rawget(obj, 'Key'))
			item.Mode = tostring(rawget(obj, 'Mode') or 'Toggle')
			item.Modifiers = type(rawget(obj, 'Modifiers')) == 'table'
				and table.clone(obj.Modifiers)
				or item.Modifiers

			if not silent then
				emit(item)
			end
		end

		local function keychange(value)
			return typeof(value) == 'EnumItem'
				or type(value) == 'table'
				and (value.Key ~= nil or value.Value ~= nil or value[1] ~= nil)
		end

		local function force(value, silent, wantedmode, wantedmods)
			local callback = rawget(obj, 'Callback')
			local mode = tostring(wantedmode or rawget(obj, 'Mode') or 'Toggle')
			local modifiers = type(wantedmods) == 'table'
				and table.clone(wantedmods)
				or table.clone(item.Modifiers)

			if mode == 'Press' then
				mode = 'Toggle'
			end

			obj.Callback = function() end
			obj.Modifiers = modifiers

			local ok, err = pcall(old, {
				Key = keyenum(value),
				Mode = mode,
				Active = false,
				Modifiers = modifiers
			})

			obj.Callback = callback

			if not ok then
				error(err, 0)
			end

			obj.Active = false
			update(silent)
		end

		local function set(value)
			local bind = api.binds

			if bind
				and not bind.setting
				and keychange(value)
				and (bind.active == item or rawget(obj, 'Open') == true) then

				if bind.active ~= item then
					bind:begin(item)
				end

				local key = type(value) == 'table'
					and (value.Key or value.Value or value[1])
					or value
				bind:pick(keyname(key))
				return
			end

			if keychange(value) then
				local callback = rawget(obj, 'Callback')
				obj.Callback = function() end
				local ok, err = pcall(old, value)
				obj.Callback = callback

				if not ok then
					error(err, 0)
				end
			else
				old(value)
			end

			update()
		end

		obj.Set = set

		if type(config) == 'table' then
			config[item._flag] = set
		end

		item._restore = function()
			if rawget(obj, 'Set') == set then
				obj.Set = old
			end

			if guarded and rawget(obj, 'Callback') == guarded then
				obj.Callback = oldcallback
			end

			if type(config) == 'table' and rawget(config, item._flag) == set then
				config[item._flag] = oldconfig
			end
		end

		function item:Repair()
			if invalid(rawget(obj, 'Key')) then
				force(self.Fallback)
				return true
			end

			return false
		end

		item:Repair()

		function item:SetValue(value)
			local key = value
			local mode = self.Mode
			local modifiers = self.Modifiers

			if type(value) == 'table' then
				key = value[1] or value.Key or value.Value
				mode = value[2] or value.Mode or mode
				modifiers = value[3] or value.Modifiers or modifiers
			end

			if mode == 'Press' then
				mode = 'Toggle'
			end

			self.Modifiers = type(modifiers) == 'table' and table.clone(modifiers) or {}
			obj.Modifiers = table.clone(self.Modifiers)

			set({
				Key = keyenum(key),
				Mode = mode,
				Active = rawget(obj, 'Active'),
				Modifiers = table.clone(self.Modifiers)
			})
		end

		function item:CancelCapture(oldvalue)
			oldvalue = type(oldvalue) == 'table' and oldvalue or {
				value = self.Value,
				mode = self.Mode,
				modifiers = self.Modifiers
			}
			self.Modifiers = type(oldvalue.modifiers) == 'table' and table.clone(oldvalue.modifiers) or {}
			force(oldvalue.value or self.Value, true, oldvalue.mode or self.Mode, self.Modifiers)
		end

		state.inputitems[item] = true
		state.nativeitems[obj] = item

		return item
	end

	local function directchildren(page)
		local result = {}

		if alive(page) then
			for _, child in ipairs(page:GetChildren()) do
				if child:IsA('Frame')
					and child:FindFirstChildOfClass('UIListLayout') then

					result[#result + 1] = child
				end
			end
		end

		table.sort(result, function(a, b)
			if a.AbsolutePosition.X == b.AbsolutePosition.X then
				return a.LayoutOrder < b.LayoutOrder
			end

			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end)

		return result
	end

	local wraptab
	local wrapbox

	local function wrapcolumn(frame)
		return setmetatable({
			Items = {
				Column = frame
			}
		}, lib)
	end

	local function create(class, props)
		local ok, obj = pcall(lib.Create, lib, class, props)

		if ok and alive(obj) then
			return obj
		end

		obj = Instance.new(class)

		for key, value in pairs(props or {}) do
			pcall(function()
				obj[key] = value
			end)
		end

		return obj
	end

	local function scrollcolumn(tab, order)
		local accent = Color3.fromRGB(19, 128, 225)
		local flags = rawget(lib, 'Flags')
		local value = type(flags) == 'table' and rawget(flags, 'Accent')

		if type(value) == 'table' and typeof(rawget(value, 'Color')) == 'Color3' then
			accent = value.Color
		end

		local frame = create('ScrollingFrame', {
			Parent = tab.Container,
			Name = 'FiveroseTweakerColumn',
			LayoutOrder = order,
			Size = UDim2.new(0, 100, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = accent,
			ScrollingDirection = Enum.ScrollingDirection.Y
		})

		create('UIListLayout', {
			Parent = frame,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 11)
		})

		create('UIPadding', {
			Parent = frame,
			PaddingRight = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4)
		})

		return wrapcolumn(frame)
	end

	wrapbox = function(obj, tab, title)
		local box = {
			Name = tostring(title or 'Section'),
			Native = obj,
			Container = rootof(obj, {'Section'}),
			Tab = tab,
			Destroyed = false,
			_items = {}
		}
		ownroot(box.Container)

		local function add(item)
			if item then
				box._items[#box._items + 1] = item
			end

			return item
		end

		function box:SetVisible(value)
			setvisible(self.Native, value)
			return self
		end

		function box:Destroy()
			if self.Destroyed then
				return false
			end

			self.Destroyed = true

			for index = #self._items, 1, -1 do
				local item = self._items[index]

				if type(item) == 'table'
					and type(rawget(item, 'Destroy')) == 'function' then

					pcall(item.Destroy, item)
				end

				self._items[index] = nil
			end

			destroyowned(self.Container)
			return true
		end

		function box:AddToggle(id, info)
			info = info or {}
			local item
			local mark = connectionmark()
			local obj = self.Native:Toggle({
				Name = info.Text or id,
				Flag = id,
				Default = info.Default == true,
				Callback = function(value)
					if item then
						item.Value = value == true
						emit(item)
					end
				end
			})

			item = base('Toggle', id, obj)
			tracknative(item, obj, mark)
			item.Text = tostring(info.Text or id)
			item.Value = rawget(obj, 'Enabled') == true
			item.Addons = {}
			item._flag = id

			function item:SetValue(value)
				value = value == true

				if self.Value == value and rawget(self.Native, 'Enabled') == value then
					return
				end

				self.Native.Enabled = value
				self.Native.Set(value)
			end

			function item:AddKeyPicker(keyid, keyinfo)
				keyinfo = keyinfo or {}
				local mark = connectionmark('KeyPicker')
				local key
				local obj = self.Native:Keybind({
					Name = keyinfo.Text or self.Text,
					Flag = keyid,
					Key = keyenum(keyinfo.Default),
					Mode = keyinfo.Mode == 'Press' and 'Toggle' or (keyinfo.Mode or 'Toggle'),
					Default = self.Value,
					ShowInList = keyinfo.NoUI ~= true,
					Callback = function(value)
						if keyinfo.SyncToggleState and item then
							item:SetValue(value == true)
						end
					end
				})

				key = wrapkey(obj, keyid, true, mark)

				if key then
					key.Blacklisted = type(keyinfo.Blacklisted) == 'table' and table.clone(keyinfo.Blacklisted) or {}
					self.Addons[#self.Addons + 1] = key
					options[keyid] = key
				end

				return key
			end

			local olddestroy = item.Destroy

			function item:Destroy()
				for index = #self.Addons, 1, -1 do
					local addon = self.Addons[index]

					if type(addon) == 'table'
						and type(rawget(addon, 'Destroy')) == 'function' then

						pcall(addon.Destroy, addon)
					end

					self.Addons[index] = nil
				end

				return olddestroy(self)
			end

			toggles[id] = item
			item:SetVisible(info.Visible ~= false)
			return add(item)
		end

		function box:AddSlider(id, info)
			info = info or {}
			local item
			local step = 10 ^ -(tonumber(info.Rounding) or 0)
			local mark = connectionmark('Slider')
			local obj = self.Native:Slider({
				Name = info.Text or id,
				Flag = id,
				Default = tonumber(info.Default) or 0,
				Min = tonumber(info.Min) or 0,
				Max = tonumber(info.Max) or 100,
				Decimal = step,
				Suffix = tostring(info.Suffix or ''),
				Callback = function(value)
					if item then
						item.Value = value
						emit(item)
					end
				end
			})

			item = base('Slider', id, obj)
			tracknative(item, obj, mark)
			item.Value = rawget(obj, 'Value')
			item.Min = rawget(obj, 'Min')
			item.Max = rawget(obj, 'Max')
			item._flag = id

			function item:SetValue(value)
				self.Native.Set(tonumber(value) or self.Value)
				self.Value = rawget(self.Native, 'Value')
			end

			options[id] = item
			item:SetVisible(info.Visible ~= false)
			return add(item)
		end

		function box:AddDropdown(id, info)
			info = info or {}
			local item
			local values = type(info.Values) == 'table' and table.clone(info.Values) or {}
			local mark = connectionmark('Dropdown')
			local obj = self.Native:Dropdown({
				Name = info.Text or id,
				Flag = id,
				Options = values,
				Default = info.Default or values[1],
				Callback = function(value)
					if item then
						item.Value = value
						emit(item)
					end
				end
			})

			item = base('Dropdown', id, obj)
			tracknative(item, obj, mark)
			item.Value = rawget(obj, 'Default') or info.Default
			item.Values = values
			item._flag = id

			function item:SetValue(value)
				self.Native.Set(value)
				self.Value = type(rawget(self.Native, 'Multi')) == 'boolean'
					and rawget(self.Native, 'Multi')
					and rawget(self.Native, 'MultiItems')
					or value
			end

			function item:SetValues(values)
				self.Values = type(values) == 'table' and table.clone(values) or {}
				self.Native.Options = self.Values

				if type(rawget(self.Native, 'RefreshOptions')) == 'function' then
					self.Native.RefreshOptions(self.Values)
				end
			end

			options[id] = item
			item:SetVisible(info.Visible ~= false)
			return add(item)
		end

		function box:AddInput(id, info)
			info = info or {}
			local item
			local mark = connectionmark()
			local obj = self.Native:Textbox({
				Name = info.Text or id,
				Flag = id,
				Default = tostring(info.Default or ''),
				PlaceHolder = tostring(info.Placeholder or ''),
				Callback = function(value)
					if item then
						item.Value = tostring(value or '')
						emit(item)
					end
				end
			})

			item = base('Input', id, obj)
			tracknative(item, obj, mark)
			item.Value = tostring(rawget(obj, 'Default') or info.Default or '')
			item._flag = id

			function item:SetValue(value)
				self.Native.Set(tostring(value or ''))
				self.Value = tostring(value or '')
			end

			options[id] = item
			item:SetVisible(info.Visible ~= false)
			return add(item)
		end

		function box:AddLabel(text)
			local mark = connectionmark()
			local obj = self.Native:Label({
				Name = tostring(text or '')
			})
			local item = base('Label', nil, obj)
			tracknative(item, obj, mark)
			item.Text = tostring(text or '')
			item._children = {}
			local olddestroy = item.Destroy

			function item:Destroy()
				for index = #self._children, 1, -1 do
					local child = self._children[index]

					if type(child) == 'table'
						and type(rawget(child, 'Destroy')) == 'function' then

						pcall(child.Destroy, child)
					end

					self._children[index] = nil
				end

				return olddestroy(self)
			end

			function item:AddColorPicker(id, info)
				info = info or {}
				local color
				local mark = connectionmark('ColorPicker')
				local obj = self.Native:Colorpicker({
					Name = info.Title or item.Text,
					Flag = id,
					Color = typeof(info.Default) == 'Color3' and info.Default or Color3.new(1, 1, 1),
					Alpha = tonumber(info.Transparency) or 0,
					Callback = function(value, alpha)
						if color then
							color.Value = value
							color.Transparency = alpha
							emit(color)
						end
					end
				})

				color = base('ColorPicker', id, obj)
				tracknative(color, obj, mark)
				color.Value = rawget(obj, 'Color')
				color.Transparency = rawget(obj, 'Alpha')
				color._flag = id

				function color:SetValueRGB(value, alpha)
					self.Native.Set(value, alpha)
					self.Value = value
					self.Transparency = alpha
				end

				function color:SetValue(value)
					self:SetValueRGB(value, self.Transparency)
				end

				options[id] = color
				self._children[#self._children + 1] = color
				return color
			end

			function item:AddKeyPicker(id, info)
				info = info or {}
				local mark = connectionmark('KeyPicker')
				local obj = self.Native:Keybind({
					Name = info.Text or item.Text,
					Flag = id,
					Key = keyenum(info.Default),
					Mode = info.Mode == 'Press' and 'Toggle' or (info.Mode or 'Toggle'),
					Default = false,
					ShowInList = info.NoUI ~= true,
					Callback = function() end
				})
				local key = wrapkey(obj, id, true, mark)

				if key then
					key.Blacklisted = type(info.Blacklisted) == 'table' and table.clone(info.Blacklisted) or {}
					options[id] = key
				end

				if key then
					self._children[#self._children + 1] = key
				end

				return key
			end

			return add(item)
		end

		function box:AddButton(info)
			info = info or {}
			local mark = connectionmark()
			local obj = self.Native:Button({
				Name = info.Text or 'Button',
				Callback = info.Func or function() end
			})
			local item = base('Button', nil, obj)
			tracknative(item, obj, mark)
			item.Text = tostring(info.Text or 'Button')
			return add(item)
		end

		return trackowned(box)
	end

	wraptab = function(obj, owned)
		local items = rawget(obj, 'Items')
		local tab = {
			Name = tostring(rawget(obj, 'Name') or 'Tab'),
			Native = obj,
			Sides = {
				type(items) == 'table' and rawget(items, 'Page')
			},
			Button = type(items) == 'table' and rawget(items, 'Outline'),
			Container = type(items) == 'table' and rawget(items, 'Page'),
			Visible = true,
			Destroyed = false,
			_owned = owned == true,
			_columns = {}
		}

		if tab._owned then
			ownroot(tab.Button)
			ownroot(tab.Container)
			trackowned(tab)
		end

		function tab:SetVisible(value)
			value = value == true
			self.Visible = value

			if alive(self.Button) then
				self.Button.Visible = value
			end

			if not value then
				self:Hide()
			end

			return self
		end

		function tab:Hide()
			local page = self.Container

			if alive(page) then
				page.Visible = false

				if alive(rawget(lib, 'Other')) then
					page.Parent = lib.Other
				end
			end

			if rawget(panel, 'TabInfo') == self.Native then
				panel.TabInfo = nil
			end

			if facade.ActiveTab == self then
				facade.ActiveTab = nil
			end

			return self
		end

		function tab:Show()
			if self.Destroyed then
				return self
			end

			self.Visible = true

			if alive(self.Button) then
				self.Button.Visible = true
			end

			self.Native.Tweening = false
			pcall(self.Native.OpenTab)
			facade.ActiveTab = self
			return self
		end

		local function column(side)
			if tab._columns[side] then
				return tab._columns[side]
			end

			local columns = directchildren(tab.Container)
			local frame

			if tab._owned then
				if side == 'left' then
					frame = columns[1]
				elseif #columns >= 2 then
					frame = columns[#columns]
				end
			elseif #columns > 0 then
				frame = side == 'right' and columns[#columns] or columns[1]
			end

			local obj

			if alive(frame) then
				obj = wrapcolumn(frame)
			elseif tab._owned then
				obj = scrollcolumn(tab, side == 'right' and 2 or 1)
			else
				obj = tab.Native:Column({})
			end

			tab._columns[side] = obj
			return obj
		end

		function tab:AddLeftGroupbox(title)
			local obj = column('left'):Section({
				Name = tostring(title or 'Section')
			})
			return wrapbox(obj, self, title)
		end

		function tab:AddRightGroupbox(title)
			local obj = column('right'):Section({
				Name = tostring(title or 'Section')
			})
			return wrapbox(obj, self, title)
		end

		function tab:Destroy()
			if self.Destroyed then
				return false
			end

			self.Destroyed = true

			if rawget(panel, 'TabInfo') == self.Native then
				panel.TabInfo = nil
			end

			if facade.ActiveTab == self then
				facade.ActiveTab = nil
			end

			if self._owned then
				destroyowned(self.Button, self.Container)
			end

			for key, value in pairs(tabmap) do
				if value == self then
					tabmap[key] = nil
				end
			end

			return true
		end

		return tab
	end

	for _, obj in ipairs(tabs) do
		local tab = wraptab(obj, false)
		local name = tostring(rawget(obj, 'Name') or 'Tab')
		tabmap[name] = tab

		if rawget(panel, 'TabInfo') == obj then
			facade.ActiveTab = tab
		end
	end

	local win = {}

	function win:AddTab(info)
		info = info or {}
		local obj = panel:Tab({
			Name = info.Name or 'Tab'
		})
		local tab = wraptab(obj, true)
		tabmap[tab.Name] = tab
		state.created[#state.created + 1] = tab
		return tab
	end

	facade.Window = win

	function facade:Notify(info)
		info = info or {}
		local title = tostring(info.Title or 'FiveroseTweaker')
		local text = tostring(info.Description or '')
		local name = text ~= '' and title..' | '..text or title

		return pcall(lib.Notification, lib, {
			Name = name,
			Lifetime = tonumber(info.Time) or 3
		})
	end

	function facade:Toggle()
		local value = rawget(panel, 'Open') ~= true
		panel.Open = value
		return pcall(panel.SetMenuVisible, value)
	end

	function state:findflag(flag)
		for _, obj in ipairs(self.native) do
			if rawget(obj, 'Flag') == flag then
				return obj
			end
		end
	end

	function state:wrapkey(obj, id, fallback)
		return wrapkey(obj, id, false, nil, fallback)
	end

	function state:mark()
		return {
			created = #self.created,
			owned = #self.owneditems
		}
	end

	function state:rollback(mark)
		if type(mark) ~= 'table' then
			return
		end

		for index = #self.owneditems, (mark.owned or 0) + 1, -1 do
			local item = self.owneditems[index]

			if type(item) == 'table' and type(rawget(item, 'Destroy')) == 'function' then
				pcall(item.Destroy, item)
			end

			self.owneditems[index] = nil
		end

		for index = #self.created, (mark.created or 0) + 1, -1 do
			self.created[index] = nil
		end
	end

	api.backend = 'universal'
	api.ui = state
	api.native_lib = lib
	api.native_panel = panel
	api.native_toggles = native
	api.lib = facade
	api.win = win
	api.gui = screen
	api.tab = nil
	api.tabs = tabmap

	local family = type(api.game) == 'table' and rawget(api.game, 'family')

	if type(family) == 'table' and rawget(family, 'native') == true then
		api.tab = win:AddTab({
			Name = 'FiveroseTweaker'
		})
	end
	api.toggles = toggles
	api.options = options
	api.owned = {}

	function api:own(id)
		self.owned[id] = true
		return id
	end

	function api:disown(id)
		if self.owned[id] then
			self.toggles[id] = nil
			self.options[id] = nil
		end

		self.owned[id] = nil

		if self.nokey then
			self.nokey[id] = nil
		end
	end

	function api:remove_tab(item)
		for key, current in pairs(tabmap) do
			if current == item then
				if type(current) == 'table' and type(rawget(current, 'Destroy')) == 'function' then
					pcall(current.Destroy, current)
				end

				if tabmap[key] == current then
					tabmap[key] = nil
				end

				return true
			end
		end

		return false
	end

	function api:notify(title, text, time)
		return facade:Notify({
			Title = title,
			Description = text,
			Time = time
		})
	end

	local con

	if alive(screen) then
		con = screen.AncestryChanged:Connect(function(_, parent)
			if parent == nil and api.state ~= 'unloaded' then
				api:unload()
			end
		end)

		api:clean(con)
	end

	api:clean(function()
		local list = {}

		for _, item in pairs(options) do
			list[#list + 1] = item
		end

		for _, item in pairs(toggles) do
			list[#list + 1] = item
		end

		for index = #list, 1, -1 do
			local item = list[index]

			if type(item) == 'table'
				and type(rawget(item, 'Destroy')) == 'function' then

				pcall(item.Destroy, item)
			end
		end

		api.remove_tab = nil

		for index = #state.owneditems, 1, -1 do
			local item = state.owneditems[index]

			if type(item) == 'table'
				and type(rawget(item, 'Destroy')) == 'function' then

				pcall(item.Destroy, item)
			end

			state.owneditems[index] = nil
		end

		table.clear(state.created)
	end)

	return api
end
