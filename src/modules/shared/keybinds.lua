return function(api)
	local input = api.input or game:GetService('UserInputService')
	local lib = api.native_lib or api.lib
	local toggles = api.toggles
	local options = api.options
	local created = {}
	local wrapped = {}
	local blocked = {'MB1', 'MB2'}
	local aliases = {
		MB1 = 'MouseButton1',
		MB2 = 'MouseButton2',
		MB3 = 'MouseButton3'
	}
	local native = {
		MouseButton1 = 'MB1',
		MouseButton2 = 'MB2',
		MouseButton3 = 'MB3'
	}

	local function copy(tab)
		local result = {}

		for key, value in pairs(type(tab) == 'table' and tab or {}) do
			result[key] = value
		end

		return result
	end

	local function keyname(value)
		if type(typeof) == 'function' and typeof(value) == 'EnumItem' then
			value = value.Name
		end

		value = tostring(value or 'None')
		value = value:gsub('Enum%.KeyCode%.', '')
		value = value:gsub('Enum%.UserInputType%.', '')
		value = (value == 'NONE' or value == 'Unknown') and 'None' or value
		return aliases[value] or value
	end

	local function field(obj, name)
		local ok, value = pcall(function()
			return obj[name]
		end)

		return ok and value or nil
	end

	local function inputkey(obj)
		local kind = keyname(field(obj, 'UserInputType'))
		return kind == 'Keyboard' and keyname(field(obj, 'KeyCode')) or kind
	end

	local function valuekey(value)
		if type(value) == 'table' then
			return value[1] or value.Key or value.Value
		end

		return value
	end

	local function setkey(value, key)
		if type(value) ~= 'table' then
			return key
		end

		local result = copy(value)
		result[1] = key

		if value.Key ~= nil then
			result.Key = key
		end

		if value.Value ~= nil then
			result.Value = key
		end

		return result
	end

	local function backend(value)
		if api.backend == 'universal' then
			return value
		end

		local key = native[keyname(valuekey(value))]
		return key and setkey(value, key) or value
	end

	local function blacklisted(picker, key)
		for _, value in ipairs(type(picker) == 'table' and rawget(picker, 'Blacklisted') or {}) do
			if keyname(value) == key then
				return true
			end
		end

		return false
	end

	local function close(picker)
		local obj = type(picker) == 'table' and rawget(picker, 'Native') or picker

		if type(obj) == 'table' then
			obj.Open = false
		end

		if type(lib) == 'table' then
			if rawget(lib, 'OpenElement') == obj then
				lib.OpenElement = nil
			end

			lib.IsPicking = false
		end
	end

	local bind = {
		down = {},
		skip = {}
	}
	api.binds = bind

	function bind:begin(picker)
		if type(picker) ~= 'table' or rawget(picker, 'Destroyed') == true then
			return false
		end

		if self.active == picker then
			return true
		end

		self:cancel()
		self.active = picker
		self.old = {
			value = tostring(rawget(picker, 'Value') or 'None'),
			mode = tostring(rawget(picker, 'Mode') or 'Toggle'),
			modifiers = copy(rawget(picker, 'Modifiers'))
		}

		if type(lib) == 'table' then
			lib.IsPicking = true
		end

		return true
	end

	function bind:cancel(picker)
		if picker and self.active ~= picker then
			return false
		end

		local active = self.active
		local old = self.old
		self.active = nil
		self.old = nil

		if active and type(rawget(active, 'CancelCapture')) == 'function' then
			pcall(active.CancelCapture, active, old)
		end

		if active then
			close(active)
		elseif type(lib) == 'table' and rawget(lib, 'IsPicking') == true then
			close(rawget(lib, 'OpenElement'))
		elseif type(lib) == 'table' then
			lib.IsPicking = false
		end

		return active ~= nil
	end

	function bind:commit(key, value)
		local active = self.active
		local old = self.old

		if not active or type(rawget(active, 'SetValue')) ~= 'function' then
			return false
		end

		self.skip[key] = true
		self.active = nil
		self.old = nil
		self.setting = true
		local ok = pcall(active.SetValue, active, {
			value,
			old and old.mode or 'Toggle',
			old and old.modifiers or {}
		})
		self.setting = nil
		close(active)

		if type(api.queue_save) == 'function' then
			api:queue_save()
		end

		return ok
	end

	function bind:pick(key)
		if not self.active then
			return false
		end

		key = keyname(key)

		if key == 'Escape' then
			self.skip[key] = true
			self:cancel()
			return true
		end

		local old = self.old and keyname(self.old.value) or 'None'

		if key == 'Backspace' or key == 'Delete' or key == old then
			self:commit(key, 'None')
			return true
		end

		if blacklisted(self.active, key) then
			self.skip[key] = true
			return true
		end

		local value = key
		self:commit(key, value)
		return true
	end

	function bind:began(obj, processed, focused)
		local key = inputkey(obj)

		if key == 'None' then
			return false
		end

		if self.skip[key] then
			self.down[key] = true
			return true
		end

		if self.down[key] then
			return true
		end

		self.down[key] = true

		if self:pick(key) then
			return true
		end

		return processed == true or focused == true
	end

	function bind:ended(obj)
		local key = inputkey(obj)
		local skipped = self.skip[key] == true
		self.down[key] = nil
		self.skip[key] = nil
		return skipped
	end

	function bind:suppress(obj)
		local key = inputkey(obj)
		self.down[key] = true
		self.skip[key] = true
	end

	function bind:blocked(picker)
		if self.active or type(lib) == 'table' and rawget(lib, 'IsPicking') == true then
			return true
		end

		if input and type(input.GetFocusedTextBox) == 'function' and input:GetFocusedTextBox() then
			return true
		end

		return next(self.skip) ~= nil
	end

	local function guard(picker)
		if type(picker) ~= 'table'
			or rawget(picker, 'Type') ~= 'KeyPicker'
			or wrapped[picker]
			or api.backend == 'universal' then

			return
		end

		local data = {picker = picker}
		local oldset = rawget(picker, 'SetValue')

		if type(oldset) == 'function' then
			local set
			set = function(self, value, ...)
				if not bind.setting and type(lib) == 'table' and rawget(lib, 'IsPicking') == true then
					bind:begin(self)
					local key = keyname(valuekey(value))
					bind:pick(key)

					return self
				end

				return oldset(self, backend(value), ...)
			end

			picker.SetValue = set
			data.oldset = oldset
			data.set = set
		end

		for _, name in ipairs({'Callback', 'DoClick'}) do
			local old = rawget(picker, name)

			if type(old) == 'function' then
				local call = function(...)
					if bind:blocked(picker) then
						return
					end

					return old(...)
				end

				picker[name] = call
				data[name] = {old = old, call = call}
			end
		end

		wrapped[picker] = data
		wrapped[#wrapped + 1] = data
	end

	local function cleanup()
		bind:cancel()
		table.clear(bind.down)
		table.clear(bind.skip)

		for index = #wrapped, 1, -1 do
			local data = wrapped[index]
			local picker = data.picker

			if data.set and rawget(picker, 'SetValue') == data.set then
				picker.SetValue = data.oldset
			end

			for _, name in ipairs({'Callback', 'DoClick'}) do
				local hook = data[name]

				if hook and rawget(picker, name) == hook.call then
					picker[name] = hook.old
				end
			end

			wrapped[picker] = nil
			wrapped[index] = nil
		end

		for index = #created, 1, -1 do
			local item = created[index]
			local picker = item.picker

			if options[item.id] == picker and type(rawget(picker, 'Destroy')) == 'function' then
				pcall(picker.Destroy, picker)
			end

			if options[item.id] == picker then
				options[item.id] = nil
			end
		end

		if api.binds == bind then
			api.binds = nil
		end
	end

	api:clean(cleanup)

	local function has(toggle)
		for _, addon in ipairs(type(toggle) == 'table' and rawget(toggle, 'Addons') or {}) do
			if type(addon) == 'table'
				and rawget(addon, 'Type') == 'KeyPicker'
				and rawget(addon, 'Destroyed') ~= true then

				return true
			end
		end

		return false
	end

	function api:addkey(toggle, id, text, default)
		if type(self.active) == 'function' then
			self:active()
		end

		if type(toggle) ~= 'table' or has(toggle) or options[id] ~= nil then
			return
		end

		local ok, add = pcall(function()
			return toggle.AddKeyPicker
		end)

		if not ok or type(add) ~= 'function' then
			return
		end

		local before = options[id]
		ok = pcall(add, toggle, id, {
			Default = default or 'None',
			SyncToggleState = true,
			Mode = 'Toggle',
			Text = text or tostring(rawget(toggle, 'Text') or id),
			NoUI = false,
			Blacklisted = blocked
		})

		local picker = options[id]

		if not ok then
			if picker ~= before and type(picker) == 'table' and type(rawget(picker, 'Destroy')) == 'function' then
				pcall(picker.Destroy, picker)
			end

			if options[id] == picker then
				options[id] = before
			end

			return
		end

		if type(picker) ~= 'table' then
			return
		end

		guard(picker)
		self:own(id)
		created[#created + 1] = {id = id, picker = picker}
		return picker
	end

	function api:finish_keybinds()
		for _, picker in pairs(options) do
			guard(picker)
		end

		local ids = {}

		for id, toggle in pairs(toggles) do
			if type(toggle) == 'table' then
				ids[#ids + 1] = id
			end
		end

		table.sort(ids, function(a, b)
			local left = tostring(a)
			local right = tostring(b)

			if left == right then
				return type(a) < type(b)
			end

			return left < right
		end)

		for _, toggleid in ipairs(ids) do
			if not (api.nokey and api.nokey[toggleid]) then
				local toggle = toggles[toggleid]
				local slug = tostring(toggleid):lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
				local base = 'fiverose_tweaker_auto_'..(slug ~= '' and slug or 'module')
				local id = base
				local suffix = 1

				while options[id] ~= nil do
					suffix = suffix + 1
					id = base..'_'..suffix
				end

				api:addkey(toggle, id, rawget(toggle, 'Text') or tostring(toggleid), 'None')
			end
		end

		for _, picker in pairs(options) do
			guard(picker)
		end

		return created
	end

	return created
end
