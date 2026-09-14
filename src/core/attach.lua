return function(api)
	local env = getgenv()
	local core = game:GetService('CoreGui')
	local timeout = math.clamp(tonumber(env.fiverosetweaker_attach_timeout) or 15, 1, 60)

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

	repeat
		api:active()

		for _, candidate in ipairs(findguis()) do
			local nextuni = unitry[candidate] or 0

			if universal(candidate) and os.clock() >= nextuni then
				unitry[candidate] = os.clock() + 2
				local ok, result = pcall(function()
					local make = api:import('src/core/ui_universal.lua')
					return make(api, candidate)
				end)

				if ok and result then
					return result
				end

				unierr = result
			end

			local found = findlib(candidate)

			if found then
				gui = candidate
				lib = found
				break
			end
		end

		if lib then
			break
		end

		task.wait(0.25)
	until os.clock() - started >= timeout

	api:active()

	if not gui then
		error('real Fiverose ScreenGui not found within '..timeout..'s')
	end

	if not lib then
		if unierr then
			error('Universal Fiverose attach failed: '..tostring(unierr))
		end

		error('live Fiverose UI library not found within '..timeout..'s')
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
