return function(api)
	local env = getgenv()
	local core = game:GetService('CoreGui')
	local configuredtimeout = tonumber(env.fiverosetweaker_attach_timeout)
	local timeout = configuredtimeout and configuredtimeout > 0
		and math.clamp(configuredtimeout, 1, 600)
		or math.huge

	local function alive(obj)
		return typeof(obj) == 'Instance' and obj.Parent ~= nil
	end

	local function inside(obj, root)
		return alive(obj) and alive(root) and (obj == root or obj:IsDescendantOf(root))
	end

	local function universal(gui)
		if not alive(gui) or not gui:IsA('ScreenGui') then
			return false
		end

		local reach = false
		local controls = false

		for _, obj in ipairs(gui:GetDescendants()) do
			if obj:IsA('TextLabel') or obj:IsA('TextButton') or obj:IsA('TextBox') then
				local text = tostring(obj.Text):lower()

				if text:find('universal reach', 1, true) then
					reach = true
				elseif text == 'firetouch settings'
					or text == 'hombolo settings'
					or text == 'menu bind' then

					controls = true
				end
			end
		end

		return reach and controls
	end

	local function scoregui(gui)
		if not alive(gui) or not gui:IsA('ScreenGui') then
			return -1
		end

		local score = 0

		for _, obj in ipairs(gui:GetDescendants()) do
			if obj:IsA('TextLabel') or obj:IsA('TextButton') or obj:IsA('TextBox') then
				local text = tostring(obj.Text):lower()

				if text:find('fiverose', 1, true) then
					score = score + 500
				end

				if text == 'account' or text == 'script status' then
					score = score + 100
				elseif text == 'no charge timeout' or text == 'infinite stamina' then
					score = score + 250
				elseif text == 'auto defense' or text == 'instant actions' then
					score = score + 100
				end
			end
		end

		return score
	end

	local function findguis()
		local list = {}
		local seen = {}
		local map = rawget(env, 'fiverosemapper')
		local mapped = type(map) == 'table' and rawget(map, 'library')
		local mappedgui = type(mapped) == 'table' and rawget(mapped, 'ScreenGui')

		local function add(gui)
			if alive(gui) and gui:IsA('ScreenGui') and not seen[gui] then
				seen[gui] = true
				list[#list + 1] = gui
			end
		end

		add(mappedgui)

		if type(gethui) == 'function' then
			local ok, hui = pcall(gethui)

			if ok and alive(hui) then
				if hui:IsA('ScreenGui') then
					add(hui)
				end

				for _, obj in ipairs(hui:GetDescendants()) do
					if obj:IsA('ScreenGui') then
						add(obj)
					end
				end
			end
		end

		for _, obj in ipairs(core:GetDescendants()) do
			if obj:IsA('ScreenGui') then
				add(obj)
			end
		end

		if type(getinstances) == 'function' then
			local ok, instances = pcall(getinstances)

			if ok and type(instances) == 'table' then
				for _, obj in ipairs(instances) do
					if typeof(obj) == 'Instance' and obj:IsA('ScreenGui') then
						add(obj)
					end
				end
			end
		end

		local ranked = {}

		for _, gui in ipairs(list) do
			local score = scoregui(gui)

			if score >= 500 or gui == mappedgui then
				ranked[#ranked + 1] = {gui = gui, score = score}
			end
		end

		table.sort(ranked, function(a, b)
			return a.score > b.score
		end)

		local result = {}

		for _, item in ipairs(ranked) do
			result[#result + 1] = item.gui
		end

		return result
	end

	local function valid(lib)
		if type(lib) ~= 'table' then
			return false
		end

		local win = rawget(lib, 'Window')

		if type(win) ~= 'table' then
			return false
		end

		local ok, add = pcall(function()
			return win.AddTab
		end)

		return ok and type(add) == 'function'
			and type(rawget(lib, 'Tabs')) == 'table'
			and type(rawget(lib, 'Toggles')) == 'table'
			and type(rawget(lib, 'Options')) == 'table'
	end

	local function linked(lib, gui)
		if not valid(lib) or not alive(gui) then
			return false
		end

		local screen = rawget(lib, 'ScreenGui')
		local holder = rawget(lib, 'WindowContainer')

		if screen == gui or inside(screen, gui) or inside(gui, screen) or inside(holder, gui) then
			return true
		end

		for _, toggle in pairs(rawget(lib, 'Toggles')) do
			local container = type(toggle) == 'table' and rawget(toggle, 'Container')

			if inside(container, gui) then
				return true
			end
		end

		return false
	end

	local function findlib(gui)
		local map = rawget(env, 'fiverosemapper')
		local mapped = type(map) == 'table' and rawget(map, 'library')

		if linked(mapped, gui) then
			return mapped
		end

		local best
		local bestscore = -1
		local seen = {}

		local function scan(lib)
			if seen[lib] or not linked(lib, gui) then
				return
			end

			seen[lib] = true

			local score = 0
			local screen = rawget(lib, 'ScreenGui')
			local holder = rawget(lib, 'WindowContainer')

			if screen == gui then
				score = score + 5000
			elseif inside(screen, gui) or inside(gui, screen) then
				score = score + 3000
			end

			if inside(holder, gui) then
				score = score + 1500
			end

			for _, name in ipairs({'NoChargeTimeout', 'InfiniteStamina', 'AutoDive'}) do
				local toggle = rawget(rawget(lib, 'Toggles'), name)
				local container = type(toggle) == 'table' and rawget(toggle, 'Container')

				if inside(container, gui) then
					score = score + 1500
					break
				end
			end

			if score > bestscore then
				best = lib
				bestscore = score
			end
		end

		if type(getgc) == 'function' then
			local ok, objects = pcall(getgc, true)

			if ok and type(objects) == 'table' then
				for _, obj in ipairs(objects) do
					scan(obj)
				end
			end
		end

		if type(getreg) == 'function' then
			local ok, objects = pcall(getreg)

			if ok and type(objects) == 'table' then
				local count = 0

				for _, obj in pairs(objects) do
					count = count + 1

					if count > 10000 then
						break
					end

					scan(obj)
				end
			end
		end

		return best
	end

	local function destroy(obj, root)
		if type(obj) == 'table' and type(rawget(obj, 'Destroy')) == 'function' then
			pcall(obj.Destroy, obj)
			return
		end

		if alive(obj) and inside(obj, root) and obj ~= root then
			pcall(obj.Destroy, obj)
		end
	end

	local function removetab(lib, tabs, key, tab, fallback, root)
		local active = rawget(lib, 'ActiveTab') == tab

		if active then
			local ok, hide = pcall(function()
				return tab.Hide
			end)

			if ok and type(hide) == 'function' then
				pcall(hide, tab)
			end

			if rawget(lib, 'ActiveTab') == tab then
				lib.ActiveTab = nil
			end
		end

		if type(tab) == 'table' and type(rawget(tab, 'Destroy')) == 'function' then
			pcall(tab.Destroy, tab)
		else
			for _, side in ipairs(type(tab) == 'table' and rawget(tab, 'Sides') or {}) do
				destroy(side, root)
			end

			for _, name in ipairs({'Button', 'ButtonHolder', 'Container'}) do
				destroy(type(tab) == 'table' and rawget(tab, name), root)
			end
		end

		if tabs[key] == tab then
			tabs[key] = nil
		end

		if active and fallback and rawget(lib, 'Unloaded') ~= true then
			for _, item in pairs(tabs) do
				local ok, show = pcall(function()
					return item.Show
				end)

				if item ~= tab and ok and type(show) == 'function' then
					pcall(show, item)
					break
				end
			end
		end
	end

	local function intab(obj, tab)
		if not alive(obj) or type(tab) ~= 'table' then
			return false
		end

		for _, side in ipairs(rawget(tab, 'Sides') or {}) do
			if inside(obj, side) then
				return true
			end
		end

		for _, name in ipairs({'Button', 'ButtonHolder', 'Container'}) do
			if inside(obj, rawget(tab, name)) then
				return true
			end
		end

		return false
	end

	local function purgetab(lib, tab)
		for _, registry in ipairs({rawget(lib, 'Toggles'), rawget(lib, 'Options')}) do
			if type(registry) == 'table' then
				local remove = {}

				for id, item in pairs(registry) do
					local container = type(item) == 'table' and rawget(item, 'Container')

					if intab(container, tab) then
						remove[#remove + 1] = id
					end
				end

				for _, id in ipairs(remove) do
					registry[id] = nil
				end
			end
		end
	end

	local started = os.clock()
	local gui
	local lib
	local unitry = {}
	local unierr
	local queued = setmetatable({}, {__mode = 'k'})
	local retry = setmetatable({}, {__mode = 'k'})
	local inspect = setmetatable({}, {__mode = 'k'})
	local watched = setmetatable({}, {__mode = 'k'})
	local watchers = {}
	local markedgui = false
	local nextfallback = os.clock() + 10

	local function mark(name)
		local fastboot = rawget(api, 'fastboot')
		if type(fastboot) == 'table' and type(rawget(fastboot, 'mark')) == 'function' then
			pcall(fastboot.mark, fastboot, name)
		end
	end

	local function stopwatchers()
		for index = #watchers, 1, -1 do
			local connection = watchers[index]
			pcall(connection.Disconnect, connection)
			watchers[index] = nil
		end
	end

	local function queue(candidate)
		if alive(candidate) and candidate:IsA('ScreenGui') then
			queued[candidate] = true
		end
	end

	local function queuefrom(obj)
		if not alive(obj) then
			return
		end

		if obj:IsA('ScreenGui') then
			queue(obj)
			return
		end

		if obj:IsA('TextLabel') or obj:IsA('TextButton') or obj:IsA('TextBox') then
			queue(obj:FindFirstAncestorOfClass('ScreenGui'))
		end
	end

	local function watch(root)
		if not alive(root) or watched[root] then
			return
		end

		watched[root] = true
		queuefrom(root)
		local ok, connection = pcall(function()
			return root.DescendantAdded:Connect(queuefrom)
		end)

		if ok and connection then
			watchers[#watchers + 1] = connection
		end
	end

	watch(core)

	if type(gethui) == 'function' then
		local ok, hui = pcall(gethui)
		if ok and alive(hui) then
			watch(hui)
		end
	end

	-- One initial discovery handles the case where FiveRose was loaded before
	-- Tweaker. After this, DescendantAdded drives normal discovery so we do not
	-- repeatedly walk CoreGui/getinstances/getgc while protected FiveRose is
	-- already CPU-bound during startup.
	for _, candidate in ipairs(findguis()) do
		queue(candidate)
	end

	repeat
		api:active()
		local now = os.clock()
		local work = {}

		for candidate in pairs(queued) do
			queued[candidate] = nil
			work[#work + 1] = candidate
		end

		for _, candidate in ipairs(work) do
			if not alive(candidate) then
				continue
			end

			local nextinspect = inspect[candidate] or 0
			if now < nextinspect then
				queued[candidate] = true
				continue
			end

			inspect[candidate] = now + 0.25
			local isuniversal = universal(candidate)
			local score = scoregui(candidate)

			if (isuniversal or score >= 500) and not markedgui then
				markedgui = true
				mark('fiverose_gui')
			end

			local nextuni = unitry[candidate] or 0
			if isuniversal and now >= nextuni then
				unitry[candidate] = now + 2
				local ok, result = pcall(function()
					local make = api:import('src/core/ui_universal.lua')
					return make(api, candidate)
				end)

				if ok and result then
					stopwatchers()
					return result
				end

				unierr = result
				queued[candidate] = true
			end

			if score >= 500 then
				local nexttry = retry[candidate] or 0
				if now >= nexttry then
					retry[candidate] = now + 0.75
					local found = findlib(candidate)

					if found then
						gui = candidate
						lib = found
						break
					end
				end

				-- The ScreenGui can appear a little before the Obsidian library table
				-- becomes discoverable. Requeue only this candidate instead of doing a
				-- global registry scan four times per second.
				queued[candidate] = true
			end
		end

		if lib then
			break
		end

		-- Rare executor GUIs can live outside CoreGui/gethui. Keep a slow fallback
		-- for those environments without making it part of the hot startup loop.
		if now >= nextfallback then
			nextfallback = now + 10
			for _, candidate in ipairs(findguis()) do
				queue(candidate)
			end
		end

		task.wait(0.1)
	until os.clock() - started >= timeout

	stopwatchers()

	api:active()

	if not gui then
		error(timeout == math.huge
			and 'real Fiverose ScreenGui not found'
			or 'real Fiverose ScreenGui not found within '..timeout..'s')
	end

	if not lib then
		if unierr then
			error('Universal Fiverose attach failed: '..tostring(unierr))
		end

		error(timeout == math.huge
			and 'live Fiverose UI library not found'
			or 'live Fiverose UI library not found within '..timeout..'s')
	end

	api:active()

	local win = rawget(lib, 'Window')
	local tabs = rawget(lib, 'Tabs')
	local native = type(api.game) == 'table'
		and type(api.game.family) == 'table'
		and api.game.family.native == true

	local tab

	if native then
		tab = win:AddTab({
			Name = 'FiveroseTweaker',
			Icon = 'wrench'
		})
	end

	api.lib = lib
	api.win = win
	api.gui = gui
	api.tab = tab
	api.tabs = tabs
	api.toggles = rawget(lib, 'Toggles')
	api.options = rawget(lib, 'Options')

	-- FiveRose has shipped more than one UI backend/version. Some older slider
	-- text inputs accept arbitrary text visually even though the backing slider
	-- still calculates with the previous numeric value. Keep validation here in
	-- the adapter so every supported UI gets the same numeric behavior.
	local numericguards = setmetatable({}, {__mode = 'k'})

	local function sliderprecision(item)
		return math.clamp(math.floor(tonumber(rawget(item, 'Rounding')) or 0), 0, 10)
	end

	local function rounded(value, decimals)
		local factor = 10 ^ decimals
		return math.round(value * factor) / factor
	end

	local function validnumerictext(text, decimals, allownegative)
		text = tostring(text or '')
		if text == '' then return true, nil end
		if text == '-' then return allownegative, nil end
		if text == '.' then return decimals > 0, nil end
		if text == '-.' then return allownegative and decimals > 0, nil end
		if text:find('[^%d%.%-]') then return false, nil end
		if not allownegative and text:find('-', 1, true) then return false, nil end
		if text:sub(2):find('-', 1, true) then return false, nil end

		local firstdot = text:find('.', 1, true)
		if firstdot then
			if decimals == 0 or text:find('.', firstdot + 1, true) then return false, nil end
			if #text - firstdot > decimals then return false, nil end
		end

		local value = tonumber(text)
		return value ~= nil, value
	end

	local function guardtextbox(item, textbox)
		if not alive(textbox) or not textbox:IsA('TextBox') or numericguards[textbox] then
			return
		end

		numericguards[textbox] = true
		local busy = false
		local min = tonumber(rawget(item, 'Min')) or -math.huge
		local max = tonumber(rawget(item, 'Max')) or math.huge
		local decimals = sliderprecision(item)
		local function current()
			return tonumber(rawget(item, 'Value'))
				or (min ~= -math.huge and min)
				or 0
		end
		local lastvalid = tostring(rounded(math.clamp(current(), min, max), decimals))

		local function write(text)
			busy = true
			textbox.Text = tostring(text)
			busy = false
		end

		local changed = textbox:GetPropertyChangedSignal('Text'):Connect(function()
			if busy then return end
			local text = textbox.Text
			local valid, value = validnumerictext(text, decimals, min < 0)

			if not valid then
				write(lastvalid)
				return
			end

			-- Empty/sign-only input is allowed while editing so backspace and negative
			-- values still feel normal. It never becomes the slider's stored value.
			if value == nil then return end

			value = rounded(math.clamp(value, min, max), decimals)
			local normalized = tostring(value)
			if tonumber(text) ~= value then
				write(normalized)
			end
			lastvalid = normalized
		end)

		local lost = textbox.FocusLost:Connect(function()
			if busy then return end
			local value = tonumber(textbox.Text) or tonumber(lastvalid) or current()
			value = rounded(math.clamp(value, min, max), decimals)

			local set = rawget(item, 'SetValue')
			if type(set) == 'function' then
				pcall(set, item, value)
			end

			lastvalid = tostring(value)
			write(lastvalid)
		end)

		api:clean(changed)
		api:clean(lost)
	end

	local function guardslider(item)
		if type(item) ~= 'table' or rawget(item, 'Type') ~= 'Slider' then
			return item
		end

		local roots = {}
		for _, key in ipairs({'Holder', 'Container'}) do
			local rootitem = rawget(item, key)
			if alive(rootitem) then
				roots[#roots + 1] = rootitem
			end
		end

		local nativeitem = rawget(item, 'Native')
		if type(nativeitem) == 'table' then
			local nativeholder = rawget(nativeitem, 'Holder')
			if alive(nativeholder) then roots[#roots + 1] = nativeholder end
			local items = rawget(nativeitem, 'Items')
			if type(items) == 'table' then
				for _, value in pairs(items) do
					if alive(value) then roots[#roots + 1] = value end
				end
			end
		end

		for _, rootitem in ipairs(roots) do
			if rootitem:IsA('TextBox') then
				guardtextbox(item, rootitem)
			end
			for _, descendant in ipairs(rootitem:GetDescendants()) do
				if descendant:IsA('TextBox') then
					guardtextbox(item, descendant)
				end
			end
		end

		return item
	end

	api.guard_slider = guardslider
	for _, item in pairs(api.options) do
		guardslider(item)
	end

	-- Keep watching the registry at a very low rate so sliders added later by a
	-- FiveRose update inherit the same validation without another Tweaker patch.
	api:clean(task.spawn(function()
		while api.guard_slider == guardslider and rawget(lib, 'Unloaded') ~= true do
			task.wait(1)
			for _, item in pairs(api.options) do
				guardslider(item)
			end
		end
	end))

	api:clean(function()
		api.guard_slider = nil
	end)

	api.owned = {}
	api._owned_prior = {}
	api._owned_tabs = setmetatable({}, {__mode = 'k'})

	function api:own_tab(item)
		if type(item) == 'table' then
			self._owned_tabs[item] = true
		end

		return item
	end

	if tab then
		api:own_tab(tab)
	end

	function api:own(id)
		if not self.owned[id] then
			self._owned_prior[id] = {
				toggle = type(self.toggles) == 'table' and rawget(self.toggles, id) or nil,
				option = type(self.options) == 'table' and rawget(self.options, id) or nil
			}
		end

		self.owned[id] = true
		return id
	end

	function api:disown(id)
		local prior = self._owned_prior[id]

		if prior then
			if type(self.toggles) == 'table' and rawget(self.toggles, id) ~= prior.toggle then
				self.toggles[id] = prior.toggle
			end

			if type(self.options) == 'table' and rawget(self.options, id) ~= prior.option then
				self.options[id] = prior.option
			end
		end

		self._owned_prior[id] = nil
		self.owned[id] = nil

		if self.nokey then
			self.nokey[id] = nil
		end
	end

	function api:remove_tab(item, fallback)
		if not self._owned_tabs[item] then
			return false
		end

		for key, current in pairs(tabs) do
			if current == item then
				purgetab(lib, item)
				removetab(lib, tabs, key, item, fallback == true, gui)
				self._owned_tabs[item] = nil
				return true
			end
		end

		return false
	end

	api:clean(function()
		local ids = {}

		for id in pairs(api.owned) do
			ids[#ids + 1] = id
		end

		for _, id in ipairs(ids) do
			api:disown(id)
		end

		api.remove_tab = nil
		api.own_tab = nil
		api._owned_tabs = nil
	end)

	function api:notify(title, text, time)
		return pcall(lib.Notify, lib, {
			Title = tostring(title),
			Description = tostring(text),
			Time = tonumber(time) or 3
		})
	end

	if tab then
		api:clean(function()
			for key, item in pairs(tabs) do
				if item == tab then
					removetab(lib, tabs, key, item, true, gui)
					break
				end
			end
		end)
	end

	if type(rawget(lib, 'OnUnload')) == 'function' then
		local callback = function()
			api:unload()
		end

		api:clean(function()
			local signals = rawget(lib, 'UnloadSignals')

			if type(signals) == 'table' then
				for index = #signals, 1, -1 do
					if signals[index] == callback then
						table.remove(signals, index)
					end
				end
			end
		end)
		lib:OnUnload(callback)
	end

	return api
end
