return function(api, entry)
	local tweenservice = game:GetService('TweenService')
	local textservice = game:GetService('TextService')
	local inputservice = game:GetService('UserInputService')
	local httpservice = game:GetService('HttpService')
	local runservice = game:GetService('RunService')
	local mods = {}
	local modlist = {}
	local count = {}
	local cats = {}
	local owned = {}
	local stack = {}
	local dead = false
	local prior = {}
	local bridge
	local priorvape = shared.vape
	local uimark = api.ui and api.ui.mark and api.ui:mark()
	local overlayscreen = Instance.new('ScreenGui')
	local scaledgui = Instance.new('Frame')
	local clickgui = Instance.new('Frame')
	local overlay = Instance.new('Frame')
	local holder = Instance.new('Folder')
	local guiscale = {Scale = 1}

	for id in pairs(api.owned or {}) do
		prior[id] = true
	end

	overlayscreen.Name = 'FiveroseTweakerOverlay'
	overlayscreen.ResetOnSpawn = false
	overlayscreen.IgnoreGuiInset = true
	overlayscreen.DisplayOrder = 999999
	overlayscreen.ZIndexBehavior = Enum.ZIndexBehavior.Global
	overlayscreen.Enabled = true

	local guiparent = game:GetService('CoreGui')

	if type(gethui) == 'function' then
		local ok, result = pcall(gethui)

		if ok and typeof(result) == 'Instance' then
			guiparent = result
		end
	elseif typeof(api.gui) == 'Instance' and api.gui.Parent then
		guiparent = api.gui.Parent
	end

	if type(protectgui) == 'function' then
		pcall(protectgui, overlayscreen)
	elseif syn and type(syn.protect_gui) == 'function' then
		pcall(syn.protect_gui, overlayscreen)
	end

	overlayscreen.Parent = guiparent

	scaledgui.Name = 'ScaledGui'
	scaledgui.BackgroundTransparency = 1
	scaledgui.BorderSizePixel = 0
	scaledgui.Size = UDim2.fromScale(1, 1)
	scaledgui.Parent = overlayscreen

	clickgui.Name = 'ClickGui'
	clickgui.BackgroundTransparency = 1
	clickgui.BorderSizePixel = 0
	clickgui.Size = UDim2.fromScale(1, 1)
	clickgui.Visible = false
	clickgui.Parent = scaledgui

	holder.Name = 'FiveroseTweakerHolder'
	holder.Parent = guiparent

	overlay.Name = 'Overlay'
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Active = false
	overlay.Parent = scaledgui

	local function slug(value)
		local name = tostring(value or ''):lower()
		name = name:gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
		return name ~= '' and name or 'item'
	end

	local function newid(...)
		local list = {...}
		local parts = {'vape'}

		for _, value in ipairs(list) do
			parts[#parts + 1] = slug(value)
		end

		local base = table.concat(parts, '_')
		local num = count[base] or 0
		local id = base

		repeat
			num = num + 1
			id = num == 1 and base or base..'_'..num
		until api.toggles[id] == nil and api.options[id] == nil and not owned[id]

		count[base] = num
		owned[id] = true
		api:own(id)
		return id
	end

	local function drop(obj)
		if obj == nil then
			return
		end

		if type(obj) == 'function' then
			return obj()
		end

		if typeof(obj) == 'thread' and type(task.cancel) == 'function' then
			return task.cancel(obj)
		end

		for _, name in ipairs({'Disconnect', 'Destroy', 'Remove', 'Cancel'}) do
			local ok, func = pcall(function()
				return obj[name]
			end)

			if ok and type(func) == 'function' then
				return func(obj)
			end
		end
	end

	local function safe(name, func, ...)
		if type(func) ~= 'function' then
			return true
		end

		local args = table.pack(...)
		local ok, err = xpcall(function()
			func(table.unpack(args, 1, args.n))
		end, function(value)
			if debug and type(debug.traceback) == 'function' then
				return debug.traceback(tostring(value), 2)
			end

			return tostring(value)
		end)

		if not ok then
			warn('[fiverosetweaker/vape] '..tostring(name)..': '..tostring(err))
			api:notify(tostring(name), 'Module error; check console', 5)
		end

		return ok
	end

	local function setvisible(item, value)
		if type(item) ~= 'table' then
			return
		end

		local ok, func = pcall(function()
			return item.SetVisible
		end)

		if ok and type(func) == 'function' then
			pcall(func, item, value)
		end
	end

	local function proxy(items, value)
		if type(items) ~= 'table' then
			items = {items}
		elseif type(rawget(items, 'SetVisible')) == 'function'
			or rawget(items, 'Type') ~= nil
			or rawget(items, 'Container') ~= nil then

			items = {items}
		end

		local state = {
			visible = value ~= false,
			Bind = {Visible = false},
			Position = UDim2.new(),
			Size = UDim2.new(),
			AbsolutePosition = Vector2.zero,
			AbsoluteSize = Vector2.zero
		}

		return setmetatable({}, {
			__index = function(_, key)
				if key == 'Visible' then
					return state.visible
				end

				return state[key]
			end,
			__newindex = function(_, key, val)
				if key == 'Visible' then
					state.visible = val == true

					for _, item in ipairs(items) do
						setvisible(item, state.visible)
					end

					return
				end

				state[key] = val
			end
		})
	end

	local function clean(list)
		for index = #list, 1, -1 do
			pcall(drop, list[index])
			list[index] = nil
		end
	end

	local function hold(obj)
		if obj == nil then
			return obj
		end

		if dead then
			pcall(drop, obj)
			return obj
		end

		stack[#stack + 1] = obj
		return obj
	end

	local function rounding(decimal)
		decimal = tonumber(decimal) or 1

		if decimal <= 1 then
			return 0
		end

		return math.max(0, math.floor(math.log10(decimal) + 0.5))
	end

	local function suffix(value, default)
		if type(value) == 'string' then
			return value
		end

		if type(value) == 'function' then
			local ok, result = pcall(value, default)
			return ok and tostring(result) or ''
		end

		return ''
	end

	local function addlabel(box, text)
		local ok, label = pcall(box.AddLabel, box, text)
		return ok and label or nil
	end

	local function visible(obj, value)
		if obj then
			obj.Object.Visible = value == nil or value == true
		end

		return obj
	end

	local function bindable()
		local event = Instance.new('BindableEvent')
		hold(event)
		return event
	end

	local names = {'Combat', 'Blatant', 'Utility', 'World', 'Render', 'Legit', 'Inventory', 'Minigames'}
	local icons = {
		Combat = 'swords',
		Blatant = 'flame',
		Utility = 'wrench',
		World = 'globe',
		Render = 'eye',
		Legit = 'shield',
		Inventory = 'backpack',
		Minigames = 'gamepad-2'
	}
	local hidden = {}
	local paused = {}
	local replacements = {}
	local keep = {
		info = true,
		settings = true,
		['ui settings'] = true
	}

	local function tabname(key, tab)
		local name = tostring(key):lower()

		if name ~= '' then
			return name
		end

		return type(tab) == 'table'
			and tostring(rawget(tab, 'Name') or ''):lower()
			or ''
	end

	local function intab(obj, tab)
		if typeof(obj) ~= 'Instance' or type(tab) ~= 'table' then
			return false
		end

		for _, side in ipairs(rawget(tab, 'Sides') or {}) do
			if typeof(side) == 'Instance'
				and (obj == side or obj:IsDescendantOf(side)) then

				return true
			end
		end

		return false
	end

	local function pause(tab)
		for id, toggle in pairs(api.toggles) do
			local container = type(toggle) == 'table' and rawget(toggle, 'Container')

			if rawget(toggle, 'Value') == true and intab(container, tab) then
				paused[#paused + 1] = {
					id = id,
					toggle = toggle
				}

				local set = rawget(toggle, 'SetValue')

				if type(set) == 'function' then
					pcall(set, toggle, false)
				end
			end
		end

		if api.backend == 'universal' then
			for _, toggle in ipairs(api.native_toggles or {}) do
				local items = type(toggle) == 'table' and rawget(toggle, 'Items')
				local container = type(items) == 'table' and rawget(items, 'Toggle')

				if type(rawget(toggle, 'Enabled')) == 'boolean'
					and rawget(toggle, 'Enabled') == true
					and type(rawget(toggle, 'Set')) == 'function'
					and intab(container, tab) then

					paused[#paused + 1] = {
						toggle = toggle,
						native = true
					}

					toggle.Enabled = false
					pcall(toggle.Set, false)
				end
			end
		end
	end

	local function hidetab(key, tab)
		if type(tab) ~= 'table' then
			return
		end

		local container = rawget(tab, 'Container')
		local button = rawget(tab, 'Button')
		local state = {
			key = key,
			tab = tab,
			visible = rawget(tab, 'Visible') ~= false,
			active = rawget(api.lib, 'ActiveTab') == tab
		}

		if typeof(container) == 'Instance' then
			state.parent = container.Parent
			state.pagevisible = container.Visible
		end

		if typeof(button) == 'Instance' then
			state.buttonvisible = button.Visible
		end

		pause(tab)

		if state.active then
			local hide = rawget(tab, 'Hide')

			if type(hide) == 'function' then
				pcall(hide, tab)
			end

			if rawget(api.lib, 'ActiveTab') == tab then
				api.lib.ActiveTab = nil
			end
		end

		local visible = rawget(tab, 'SetVisible')
		if type(visible) == 'function' then
			pcall(visible, tab, false)
		end

		hidden[#hidden + 1] = state

		if api.tabs[key] == tab then
			api.tabs[key] = nil
		end
	end

	local function showkept()
		if rawget(api.lib, 'ActiveTab') ~= nil then
			return
		end

		for _, wanted in ipairs({'ui settings', 'settings', 'info', 'fiverosetweaker'}) do
			for key, tab in pairs(api.tabs) do
				if tabname(key, tab) == wanted then
					local show = rawget(tab, 'Show')

					if type(show) == 'function' then
						pcall(show, tab)
					end

					return
				end
			end
		end
	end

	local function hidefeatures()
		local list = {}

		for key, tab in pairs(api.tabs) do
			list[#list + 1] = {key = key, tab = tab}
		end

		for _, item in ipairs(list) do
			if not keep[tabname(item.key, item.tab)] then
				hidetab(item.key, item.tab)
			end
		end

		showkept()
	end

	local function maketab(name)
		if replacements[name] then
			return replacements[name]
		end

		local tab = api.win:AddTab({
			Name = name,
			Icon = icons[name]
		})

		if type(api.own_tab) == 'function' then
			api:own_tab(tab)
		end

		replacements[name] = tab
		return tab
	end

	local function restoretabs()
		-- Do not hard-code Vape's category list here. Upstream can add categories at
		-- any time; every replacement tab we created must be torn down.
		local created = {}
		for name, tab in pairs(replacements) do
			created[#created + 1] = {name = name, tab = tab}
		end

		for _, data in ipairs(created) do
			local tab = data.tab

			if tab then
				if type(api.remove_tab) == 'function' then
					pcall(api.remove_tab, api, tab)
				elseif type(rawget(tab, 'Destroy')) == 'function' then
					pcall(tab.Destroy, tab)
				end
			end

			replacements[data.name] = nil
		end

		local active

		for index = #hidden, 1, -1 do
			local data = hidden[index]

			if type(data.tab) == 'table' then
				api.tabs[data.key] = data.tab
				local container = rawget(data.tab, 'Container')
				local button = rawget(data.tab, 'Button')

				if typeof(container) == 'Instance' and data.pagevisible ~= nil then
					pcall(function()
						container.Parent = data.parent
						container.Visible = data.pagevisible == true
					end)
				end

				if typeof(button) == 'Instance' and data.buttonvisible ~= nil then
					pcall(function()
						button.Visible = data.buttonvisible == true
					end)
				end

				pcall(function()
					data.tab.Visible = data.visible
				end)

				if data.active then
					active = data.tab
				end
			end

			hidden[index] = nil
		end

		for index = #paused, 1, -1 do
			local data = paused[index]
			local toggle = data.native and data.toggle or api.toggles[data.id]

			if data.native then
				if type(toggle) == 'table'
					and type(rawget(toggle, 'Set')) == 'function'
					and rawget(toggle, 'Enabled') ~= true then

					toggle.Enabled = true
					pcall(toggle.Set, true)
				end
			elseif toggle == data.toggle
				and rawget(toggle, 'Destroyed') ~= true
				and rawget(toggle, 'Value') ~= true then

				local set = rawget(toggle, 'SetValue')

				if type(set) == 'function' then
					pcall(set, toggle, true)
				end
			end

			paused[index] = nil
		end

		if active then
			local show = rawget(active, 'Show')

			if type(show) == 'function' then
				pcall(show, active)
			else
				api.lib.ActiveTab = active
			end
		end

		showkept()
	end

	bridge = {
		overlay = overlay,
		overlayscreen = overlayscreen,
		scaledgui = scaledgui,
		clickgui = clickgui,
		holder = holder,
		owned = owned,
		tabs = replacements
	}

	function bridge:destroy()
		if dead then
			return false
		end

		dead = true
		local current = self.vape or api.vape
		local libs = self.libs or api.vapelibs

		if current then
			current.Loaded = nil
		end

		for index = #modlist, 1, -1 do
			local item = modlist[index]

			if type(item) == 'table' and type(rawget(item, 'Destroy')) == 'function' then
				pcall(item.Destroy, item)
			end

			modlist[index] = nil
		end

		clean(stack)

		if libs and type(libs.entity) == 'table' and type(rawget(libs.entity, 'kill')) == 'function' then
			pcall(libs.entity.kill)
		end

		self.libs = nil
		restoretabs()

		if uimark and api.ui and type(api.ui.rollback) == 'function' then
			pcall(api.ui.rollback, api.ui, uimark)
			uimark = nil
		end

		if holder then
			pcall(holder.Destroy, holder)
			holder = nil
		end

		if overlayscreen then
			pcall(overlayscreen.Destroy, overlayscreen)
			overlayscreen = nil
			overlay = nil
		elseif overlay then
			pcall(overlay.Destroy, overlay)
			overlay = nil
		end

		for id in pairs(api.owned or {}) do
			if not prior[id] then
				api:disown(id)
			end
		end

		if current and shared.vape == current then
			shared.vape = priorvape
		end

		if current and api.vape == current then
			api.vape = nil
			api.vapelibs = nil
		end

		if api.vape_bridge == self then
			api.vape_bridge = nil
		end

		return true
	end

	api.vape_bridge = bridge
	api:clean(function()
		bridge:destroy()
	end)

	hidefeatures()

	local function makecategory(name)
		name = tostring(name or '')
		if name == '' then
			return
		end

		local current = rawget(cats, name)
		if current then
			return current
		end

		local category = {
			Name = name,
			Options = {},
			Modules = {},
			List = {},
			ListEnabled = {},
			Object = proxy(nil, true),
			Type = 'Category',
			_count = 0
		}

		function category:box(title)
			if dead then
				return
			end

			local tab = maketab(self.Name)
			self._count = self._count + 1

			if self._count % 2 == 1 then
				return tab:AddLeftGroupbox(title)
			end

			return tab:AddRightGroupbox(title)
		end

		rawset(cats, name, category)
		return category
	end

	for _, name in ipairs(names) do
		makecategory(name)
	end

	local function fake(value)
		local item = {
			Enabled = value == true,
			Value = value,
			Object = proxy(nil, true)
		}

		function item:Toggle()
			self.Enabled = not self.Enabled
			self.Value = self.Enabled
		end

		function item:SetValue(new)
			self.Value = new

			if type(new) == 'boolean' then
				self.Enabled = new
			end
		end

		return item
	end

	local main = {
		Name = 'Main',
		Options = {
			['Use team color'] = fake(true),
			['Teams by server'] = fake(true),
			['GUI bind indicator'] = fake(false)
		},
		List = {},
		ListEnabled = {},
		Type = 'Category'
	}
	local friends = {
		Name = 'Friends',
		Options = {
			['Use friends'] = fake(true),
			['Recolor visuals'] = fake(true),
			['Friends color'] = {
				Hue = 0.44,
				Sat = 1,
				Value = 1,
				Opacity = 1,
				Object = proxy(nil, true)
			}
		},
		List = {},
		ListEnabled = {},
		ColorUpdate = bindable(),
		Type = 'Category'
	}
	local targets = {
		Name = 'Targets',
		Options = {},
		List = {},
		ListEnabled = {},
		Type = 'Category'
	}

	local friendupdate = bindable()
	local targetupdate = bindable()

	main.Update = {Event = bindable().Event}
	friends.Update = {Event = friendupdate.Event}
	targets.Update = {Event = targetupdate.Event}

	function friends.Update:Fire(...)
		friendupdate:Fire(...)
	end

	function targets.Update:Fire(...)
		targetupdate:Fire(...)
	end

	local vape = {
		ActiveBinds = {},
		Categories = cats,
		Components = {},
		GUIColor = {Hue = 0.46, Sat = 0.96, Value = 0.52, Rainbow = false},
		HeldKeybinds = {},
		Keybind = {'RightShift'},
		Libraries = {},
		Loaded = true,
		Modules = mods,
		Place = tonumber(entry and entry.alias) or tonumber(entry and entry.id) or game.PlaceId,
		Profile = api.profile and api.profile.name or 'default',
		Profiles = {},
		RainbowMode = {Value = 'Normal'},
		RainbowSliders = {},
		RainbowSpeed = {Value = 1},
		RainbowUpdateSpeed = {Value = 60},
		RainbowTable = {},
		Settings = {},
		ThreadFix = type(setthreadidentity) == 'function',
		ToggleNotifications = fake(true),
		SettingToggleNotifications = fake(true),
		Notifications = fake(true),
		Windows = {},
		gui = overlayscreen,
		holder = holder,
		guiscale = guiscale,
		Version = '4.22/FiveroseTweaker'
	}

	bridge.vape = vape

	cats.Main = main
	cats.Friends = friends
	cats.Targets = targets
	vape.Settings.Modules = {Name = 'Modules', Options = main.Options}
	vape.Settings.GUI = {Name = 'GUI', Options = {}}
	vape.Scale = fake(false)
	vape.Scale.Value = 1
	vape.MultiKeybind = fake(true)
	vape.Legit = cats.Legit
	vape.Legit.Modules = vape.Legit.Modules or {}

	local color = {}

	function color.Light(value, amount)
		local h, s, v = value:ToHSV()
		return Color3.fromHSV(h, s, math.clamp(v + (tonumber(amount) or 0), 0, 1))
	end

	function color.Dark(value, amount)
		local h, s, v = value:ToHSV()
		return Color3.fromHSV(h, s, math.clamp(v - (tonumber(amount) or 0), 0, 1))
	end

	local tweens = {tweens = {}, tweenstwo = {}}

	function tweens:Cancel(obj)
		local current = self.tweens[obj] or self.tweenstwo[obj]

		if current then
			pcall(current.Cancel, current)
			self.tweens[obj] = nil
			self.tweenstwo[obj] = nil
		end
	end

	function tweens:Tween(obj, info, goal, store)
		store = store or self.tweens

		if store[obj] then
			pcall(store[obj].Cancel, store[obj])
		end

		local ok, tween = pcall(tweenservice.Create, tweenservice, obj, info, goal)

		if not ok then
			for key, value in pairs(goal) do
				pcall(function()
					obj[key] = value
				end)
			end

			return
		end

		store[obj] = tween
		tween:Play()
		return tween
	end

	local sizeparam = Instance.new('GetTextBoundsParams')
	sizeparam.Width = math.huge
	hold(sizeparam)

	local function getsize(text, size, font)
		sizeparam.Text = tostring(text or '')
		sizeparam.Size = tonumber(size) or 14

		if typeof(font) == 'Font' then
			sizeparam.Font = font
		end

		local ok, result = pcall(textservice.GetTextBoundsAsync, textservice, sizeparam)
		return ok and result or Vector2.new(#sizeparam.Text * sizeparam.Size * 0.5, sizeparam.Size)
	end

	local assets = {
		['newvape/assets/new/add.png'] = 'rbxassetid://121642387707174',
		['newvape/assets/new/aim.png'] = 'rbxassetid://122207028123421',
		['newvape/assets/new/allowedicon.png'] = 'rbxassetid://112336790299036',
		['newvape/assets/new/allowediconmini.png'] = 'rbxassetid://90142384730147',
		['newvape/assets/new/back.png'] = 'rbxassetid://80523803497740',
		['newvape/assets/new/backmini.png'] = 'rbxassetid://85859225495272',
		['newvape/assets/new/bind.png'] = 'rbxassetid://81399857677684',
		['newvape/assets/new/bindbkg.png'] = 'rbxassetid://101996225428926',
		['newvape/assets/new/blatant.png'] = 'rbxassetid://126929923309265',
		['newvape/assets/new/blur.png'] = 'rbxassetid://79246816170155',
		['newvape/assets/new/blurnoti.png'] = 'rbxassetid://124705876663719',
		['newvape/assets/new/close.png'] = 'rbxassetid://121816018671466',
		['newvape/assets/new/closemini.png'] = 'rbxassetid://108320409341289',
		['newvape/assets/new/closetiny.png'] = 'rbxassetid://71393233149714',
		['newvape/assets/new/colorpreview.png'] = 'rbxassetid://140438628568318',
		['newvape/assets/new/combat.png'] = 'rbxassetid://94762732349053',
		['newvape/assets/new/customtheme.png'] = 'rbxassetid://91756736022800',
		['newvape/assets/new/discord.png'] = 'rbxassetid://99871463341003',
		['newvape/assets/new/downexpand.png'] = 'rbxassetid://94197751291504',
		['newvape/assets/new/downexpandslider.png'] = 'rbxassetid://90289944682645',
		['newvape/assets/new/edit.png'] = 'rbxassetid://105801951237137',
		['newvape/assets/new/editlarge.png'] = 'rbxassetid://119233876755282',
		['newvape/assets/new/expandarrow.png'] = 'rbxassetid://86360332526471',
		['newvape/assets/new/friends.png'] = 'rbxassetid://92957214042038',
		['newvape/assets/new/inventory.png'] = 'rbxassetid://93264756888499',
		['newvape/assets/new/legit_mode_icon.png'] = 'rbxassetid://102858626075156',
		['newvape/assets/new/legit_switch.png'] = 'rbxassetid://127508881124779',
		['newvape/assets/new/min.png'] = 'rbxassetid://82175054487146',
		['newvape/assets/new/noti_alert.png'] = 'rbxassetid://82356478726846',
		['newvape/assets/new/noti_info.png'] = 'rbxassetid://102614825645099',
		['newvape/assets/new/noti_warning.png'] = 'rbxassetid://119631730212167',
		['newvape/assets/new/notification.png'] = 'rbxassetid://90300780458781',
		['newvape/assets/new/npcs.png'] = 'rbxassetid://104434365485227',
		['newvape/assets/new/overlaydots.png'] = 'rbxassetid://78012624671930',
		['newvape/assets/new/overlays.png'] = 'rbxassetid://136535637407545',
		['newvape/assets/new/overlayslarge.png'] = 'rbxassetid://127574141208160',
		['newvape/assets/new/pin.png'] = 'rbxassetid://92459145800579',
		['newvape/assets/new/players.png'] = 'rbxassetid://105137446428129',
		['newvape/assets/new/profiles.png'] = 'rbxassetid://126051451865127',
		['newvape/assets/new/radar.png'] = 'rbxassetid://97983828696086',
		['newvape/assets/new/rainbow_1.png'] = 'rbxassetid://101329996188554',
		['newvape/assets/new/rainbow_2.png'] = 'rbxassetid://72739074644654',
		['newvape/assets/new/rainbow_3.png'] = 'rbxassetid://100716555253397',
		['newvape/assets/new/rainbow_4.png'] = 'rbxassetid://133424174227092',
		['newvape/assets/new/range.png'] = 'rbxassetid://107794917650053',
		['newvape/assets/new/rangeindicator.png'] = 'rbxassetid://107038094175283',
		['newvape/assets/new/render.png'] = 'rbxassetid://125472576898654',
		['newvape/assets/new/search.png'] = 'rbxassetid://115611852955611',
		['newvape/assets/new/settingdots.png'] = 'rbxassetid://130896840048276',
		['newvape/assets/new/settings.png'] = 'rbxassetid://73820177347303',
		['newvape/assets/new/settingsmini.png'] = 'rbxassetid://115732118290997',
		['newvape/assets/new/targetinfo.png'] = 'rbxassetid://121604266095276',
		['newvape/assets/new/textgui.png'] = 'rbxassetid://99438663817412',
		['newvape/assets/new/theme.png'] = 'rbxassetid://111525258317113',
		['newvape/assets/new/utility.png'] = 'rbxassetid://108303206513893',
		['newvape/assets/new/vape.png'] = 'rbxassetid://92153855792786',
		['newvape/assets/new/vapelogo.png'] = 'rbxassetid://126205920310261',
		['newvape/assets/new/vapelogomini.png'] = 'rbxassetid://109041903452149',
		['newvape/assets/new/v4.png'] = 'rbxassetid://102549752760489',
		['newvape/assets/new/v4mini.png'] = 'rbxassetid://115213099001611',
		['newvape/assets/new/world.png'] = 'rbxassetid://118917453153459',
	}

	local function asset(path)
		return assets[path] or ''
	end

	vape.Libraries.color = color
	vape.Libraries.tween = tweens
	vape.Libraries.getfontsize = getsize
	vape.Libraries.getfontbounds = getsize
	vape.Libraries.getvapeasset = asset
	vape.Libraries.getcustomasset = asset
	vape.Libraries.uipallet = {
		Main = Color3.fromRGB(26, 25, 26),
		Text = Color3.fromRGB(200, 200, 200),
		Font = Font.fromEnum(Enum.Font.Arial),
		FontSemiBold = Font.fromEnum(Enum.Font.Arial),
		Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear)
	}
	vape.Libraries.targetinfo = {Targets = {}}

	local function optionbase(module, settings, item, id)
		local obj = {
			Type = item and rawget(item, 'Type') or 'Option',
			Object = proxy(item, settings.Visible),
			Item = item,
			Id = id,
			Name = settings.Name or id
		}

		function obj:SetVisible(value)
			self.Object.Visible = value == true
		end

		function obj:Destroy()
			if self._dead then return end
			self._dead = true
			if self._event then pcall(self._event.Destroy, self._event) end
			if self.Item and type(self.Item) == 'table' and type(rawget(self.Item, 'Destroy')) == 'function' then
				pcall(self.Item.Destroy, self.Item)
			end
		end

		module.Options[settings.Name or id] = obj
		if item ~= nil then
			module._items[#module._items + 1] = item
		end

		return obj
	end

	local function makeoption(module, method, settings)
		settings = settings or {}
		local name = settings.Name or method
		local id = newid(module.Category, module.Name, name)
		local box = module.Box

		if method == 'Toggle' then
			box:AddToggle(id, {
				Text = name,
				Default = settings.Default == true,
				Tooltip = settings.Tooltip,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.toggles[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'Toggle'
			obj.Enabled = item and item.Value == true or settings.Default == true
			api.nokey = api.nokey or {}
			api.nokey[id] = true

			function obj:Toggle()
				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(not item.Value)
				else
					self.Enabled = not self.Enabled
					safe(module.Name..'/'..name, settings.Function, self.Enabled)
				end
			end

			function obj:SetValue(value)
				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value == true)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Enabled = item.Value == true
					safe(module.Name..'/'..name, settings.Function, obj.Enabled)
				end)
			end

			if obj.Enabled then
				hold(task.defer(safe, module.Name..'/'..name, settings.Function, true))
			end

			return obj
		end

		if method == 'Slider' then
			local default = tonumber(settings.Default) or tonumber(settings.Min) or 0
			local sliderinfo = {
				Text = name,
				Default = default,
				Min = tonumber(settings.Min) or 0,
				Max = tonumber(settings.Max) or 100,
				Rounding = rounding(settings.Decimal),
				Tooltip = settings.Tooltip,
				Visible = settings.Visible == nil or settings.Visible
			}

			if type(settings.Suffix) == 'function' then
				sliderinfo.FormatDisplayValue = function(_, value)
					local ok, result = pcall(settings.Suffix, value)
					return tostring(value)..(ok and result ~= nil and ' '..tostring(result) or '')
				end
			elseif type(settings.Suffix) == 'string' then
				sliderinfo.Suffix = settings.Suffix
			end

			box:AddSlider(id, sliderinfo)

			local item = api.options[id]
			local obj = optionbase(module, settings, item, id)
			if type(api.guard_slider) == 'function' then api.guard_slider(item) end
			obj.Type = 'Slider'
			obj.Value = item and item.Value or default
			obj.Max = tonumber(settings.Max) or 100

			function obj:SetValue(value, _, final)
				value = tonumber(value)

				if value and item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value)
				elseif value then
					self.Value = value
					safe(module.Name..'/'..name, settings.Function, value, final)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Value = item.Value
					safe(module.Name..'/'..name, settings.Function, obj.Value, true)
				end)
			end

			return obj
		end

		if method == 'Dropdown' then
			local list = type(settings.List) == 'table' and table.clone(settings.List) or {}
			local default = settings.Default or list[1]
			box:AddDropdown(id, {
				Text = name,
				Values = list,
				Default = default,
				Tooltip = settings.Tooltip,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.options[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'Dropdown'
			obj.List = list
			obj.Value = item and item.Value or default or 'None'

			function obj:SetValue(value)
				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value)
				else
					self.Value = value
					safe(module.Name..'/'..name, settings.Function, value)
				end
			end

			function obj:Change(values)
				self.List = type(values) == 'table' and table.clone(values) or {}
				if item and type(rawget(item, 'SetValues')) == 'function' then
					item:SetValues(self.List)
				end
				if not table.find(self.List, self.Value) then
					self:SetValue(self.List[1] or 'None')
				end
			end

			function obj:ChangeValue()
				return self:Change(self.List)
			end

			if item then
				item:OnChanged(function()
					obj.Value = item.Value
					safe(module.Name..'/'..name, settings.Function, obj.Value)
				end)
			end

			return obj
		end

		if method == 'TextBox' then
			local default = tostring(settings.Default or '')
			box:AddInput(id, {
				Text = name,
				Default = default,
				Placeholder = settings.Placeholder or '',
				Finished = false,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.options[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'TextBox'
			obj.Value = item and item.Value or default

			function obj:SetValue(value, enter)
				value = tostring(value or '')

				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value)
				else
					self.Value = value
					safe(module.Name..'/'..name, settings.Function, enter)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Value = tostring(item.Value or '')
					safe(module.Name..'/'..name, settings.Function, false)
				end)
			end

			return obj
		end

		if method == 'ColorSlider' then
			local colorvalue

			if typeof(settings.Color) == 'Color3' then
				colorvalue = settings.Color
			elseif typeof(settings.DefaultValue) == 'Color3' then
				colorvalue = settings.DefaultValue
			else
				colorvalue = Color3.fromHSV(
					tonumber(settings.DefaultHue) or 0.44,
					tonumber(settings.DefaultSat) or 1,
					type(settings.DefaultValue) == 'number' and settings.DefaultValue or 1
				)
			end

			local label = addlabel(box, name)
			local item

			if label and type(rawget(label, 'AddColorPicker')) == 'function' then
				local info = {
					Default = colorvalue,
					Title = name
				}

				if settings.DefaultOpacity ~= nil then
					info.Transparency = 1 - settings.DefaultOpacity
				end

				label:AddColorPicker(id, info)
				item = api.options[id]
			end

			-- Keep the native FiveRose picker, but add a tiny hue strip under the
			-- row so ColorSlider still reads like Vape instead of a generic swatch.
			-- This is intentionally host-agnostic and works with both FiveRose UIs.
			local strip, stripmarker
			do
				local root
				for _, candidate in ipairs({label, item}) do
					if type(candidate) == 'table' then
						for _, key in ipairs({'Container', 'Holder'}) do
							local value = rawget(candidate, key)
							if typeof(value) == 'Instance' and value:IsA('GuiObject') then
								root = value
								break
							end
						end
					end
					if root then break end
				end

				if root then
					strip = Instance.new('TextButton')
					strip.Name = 'FiveRoseHueStrip'
					strip.AutoButtonColor = false
					strip.BackgroundColor3 = Color3.new(1, 1, 1)
					strip.BorderSizePixel = 0
					strip.Position = UDim2.new(0, 8, 1, -5)
					strip.Size = UDim2.new(1, -16, 0, 4)
					strip.Text = ''
					strip.ZIndex = root.ZIndex + 2
					strip.Parent = root

					local points = {}
					for index = 0, 10 do
						local hue = index / 10
						points[#points + 1] = ColorSequenceKeypoint.new(hue, Color3.fromHSV(hue, 1, 1))
					end
					local gradient = Instance.new('UIGradient')
					gradient.Color = ColorSequence.new(points)
					gradient.Parent = strip

					stripmarker = Instance.new('Frame')
					stripmarker.Name = 'Marker'
					stripmarker.AnchorPoint = Vector2.new(0.5, 0.5)
					stripmarker.BackgroundColor3 = Color3.new(1, 1, 1)
					stripmarker.BorderSizePixel = 0
					stripmarker.Position = UDim2.fromScale(math.clamp(select(1, colorvalue:ToHSV()), 0, 1), 0.5)
					stripmarker.Size = UDim2.fromOffset(2, 6)
					stripmarker.ZIndex = strip.ZIndex + 1
					stripmarker.Parent = strip
				end
			end

			-- Vape color sliders are more than a static color picker: they can opt
			-- into the shared rainbow animation. Expose that state natively in both
			-- FiveRose UI backends rather than silently dropping it.
			local rainbowid = newid(module.Category, module.Name, name, 'rainbow')
			box:AddToggle(rainbowid, {
				Text = name..' Rainbow',
				Default = false,
				Tooltip = 'Animate this color through the rainbow',
				Visible = settings.Visible == nil or settings.Visible
			})
			local rainbowitem = api.toggles[rainbowid]
			if rainbowitem then
				module._items[#module._items + 1] = rainbowitem
			end

			local obj = optionbase(module, settings, item or label, id)
			obj.Object = proxy({label, item, rainbowitem}, settings.Visible)
			obj.Type = 'ColorSlider'
			obj.Color = colorvalue
			obj.Hue, obj.Sat, obj.Value = colorvalue:ToHSV()
			obj.Opacity = tonumber(settings.DefaultOpacity) or 1
			obj.Rainbow = false

			local function rainbowstate(value)
				value = value == true
				if obj.Rainbow == value then return end
				obj.Rainbow = value
				local index = table.find(vape.RainbowSliders, obj)
				if value then
					if not index then vape.RainbowSliders[#vape.RainbowSliders + 1] = obj end
				elseif index then
					table.remove(vape.RainbowSliders, index)
				end
			end

			function obj:SetRainbow(value)
				value = value == true
				rainbowstate(value)
				if rainbowitem and rainbowitem.Value ~= value and type(rawget(rainbowitem, 'SetValue')) == 'function' then
					rainbowitem:SetValue(value)
				end
			end

			function obj:Toggle()
				self:SetRainbow(not self.Rainbow)
			end

			function obj:SetValue(hue, sat, value, opacity)
				if typeof(hue) == 'Color3' then
					self.Color = hue
					self.Hue, self.Sat, self.Value = hue:ToHSV()
				else
					self.Hue = tonumber(hue) or self.Hue
					self.Sat = tonumber(sat) or self.Sat
					self.Value = tonumber(value) or self.Value
					self.Color = Color3.fromHSV(self.Hue, self.Sat, self.Value)
				end

				self.Opacity = tonumber(opacity) or self.Opacity

				if stripmarker and stripmarker.Parent then
					stripmarker.Position = UDim2.fromScale(math.clamp(self.Hue, 0, 1), 0.5)
					stripmarker.BackgroundColor3 = self.Color
				end

				if item and type(rawget(item, 'SetValueRGB')) == 'function' then
					item:SetValueRGB(self.Color, 1 - self.Opacity)
				else
					safe(module.Name..'/'..name, settings.Function, self.Hue, self.Sat, self.Value, self.Opacity)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Color = item.Value
					obj.Hue, obj.Sat, obj.Value = item.Value:ToHSV()
					obj.Opacity = 1 - (tonumber(item.Transparency) or 0)
					if stripmarker and stripmarker.Parent then
						stripmarker.Position = UDim2.fromScale(math.clamp(obj.Hue, 0, 1), 0.5)
						stripmarker.BackgroundColor3 = obj.Color
					end
					safe(module.Name..'/'..name, settings.Function, obj.Hue, obj.Sat, obj.Value, obj.Opacity)
				end)
			end

			-- Vape's hue bar is directly draggable. Keep the native FiveRose color
			-- picker for full HSV/opacity editing, but make this gradient behave like
			-- the original slider instead of being decorative. Global input listeners
			-- exist only for the duration of an active drag.
			local stripconnection, stripmove, striprelease
			local function stopstripdrag()
				if stripmove then pcall(stripmove.Disconnect, stripmove); stripmove = nil end
				if striprelease then pcall(striprelease.Disconnect, striprelease); striprelease = nil end
			end

			local function setstripposition(position)
				if not strip or not strip.Parent or strip.AbsoluteSize.X <= 0 then return end
				local hue = math.clamp((position.X - strip.AbsolutePosition.X) / strip.AbsoluteSize.X, 0, 1)
				obj:SetRainbow(false)
				obj:SetValue(hue, nil, nil, nil)
			end

			if strip then
				stripconnection = strip.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1
						and input.UserInputType ~= Enum.UserInputType.Touch then return end

					stopstripdrag()
					setstripposition(input.Position)
					stripmove = inputservice.InputChanged:Connect(function(move)
						if move.UserInputType == Enum.UserInputType.MouseMovement
							or move.UserInputType == Enum.UserInputType.Touch then
							setstripposition(move.Position)
						end
					end)
					striprelease = input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then
							stopstripdrag()
						end
					end)
				end)
			end

			if rainbowitem then
				rainbowitem:OnChanged(function()
					rainbowstate(rainbowitem.Value == true)
				end)
			end

			local olddestroy = obj.Destroy
			function obj:Destroy()
				rainbowstate(false)
				stopstripdrag()
				if stripconnection then pcall(stripconnection.Disconnect, stripconnection); stripconnection = nil end
				if strip and strip.Parent then pcall(strip.Destroy, strip) end
				if label and type(label) == 'table' and type(rawget(label, 'Destroy')) == 'function' then
					pcall(label.Destroy, label)
				end
				return olddestroy(self)
			end

			return obj
		end

		if method == 'TextList' then
			local defaults = type(settings.Default) == 'table' and table.clone(settings.Default) or {}
			local default = table.concat(defaults, ', ')
			box:AddInput(id, {
				Text = name,
				Default = default,
				Placeholder = settings.Placeholder or 'comma separated',
				Finished = false,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.options[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'TextList'
			obj.List = defaults
			obj.ListEnabled = table.clone(defaults)

			local function parse(value)
				table.clear(obj.List)
				table.clear(obj.ListEnabled)

				for part in tostring(value or ''):gmatch('[^,\n]+') do
					local text = part:match('^%s*(.-)%s*$')

					if text ~= '' then
						obj.List[#obj.List + 1] = text
						obj.ListEnabled[#obj.ListEnabled + 1] = text
					end
				end

				safe(module.Name..'/'..name, settings.Function, obj.List)
			end

			function obj:ChangeValue(value)
				if value ~= nil then
					value = tostring(value)
					local index = table.find(self.List, value)

					if index then
						table.remove(self.List, index)
						local enabled = table.find(self.ListEnabled, value)

						if enabled then
							table.remove(self.ListEnabled, enabled)
						end
					else
						self.List[#self.List + 1] = value
						self.ListEnabled[#self.ListEnabled + 1] = value
					end
				end

				local text = table.concat(self.List, ', ')

				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(text)
				else
					parse(text)
				end
			end

			if item then
				item:OnChanged(function()
					parse(item.Value)
				end)
			end

			return obj
		end

		if method == 'TwoSlider' then
			local minid = id..'_min'
			local maxid = id..'_max'
			owned[minid] = true
			owned[maxid] = true
			api:own(minid)
			api:own(maxid)
			local minvalue = tonumber(settings.DefaultMin) or tonumber(settings.Min) or 0
			local maxvalue = tonumber(settings.DefaultMax) or tonumber(settings.Max) or 100

			box:AddSlider(minid, {
				Text = name..' min',
				Default = minvalue,
				Min = tonumber(settings.Min) or 0,
				Max = tonumber(settings.Max) or 100,
				Rounding = rounding(settings.Decimal),
				Visible = settings.Visible == nil or settings.Visible
			})
			box:AddSlider(maxid, {
				Text = name..' max',
				Default = maxvalue,
				Min = tonumber(settings.Min) or 0,
				Max = tonumber(settings.Max) or 100,
				Rounding = rounding(settings.Decimal),
				Visible = settings.Visible == nil or settings.Visible
			})

			local minitem = api.options[minid]
			local maxitem = api.options[maxid]
			if type(api.guard_slider) == 'function' then
				api.guard_slider(minitem)
				api.guard_slider(maxitem)
			end
			local obj = optionbase(module, settings, minitem, id)
			module._items[#module._items + 1] = maxitem
			obj.Type = 'TwoSlider'
			obj.Object = proxy({minitem, maxitem}, settings.Visible)
			obj.ValueMin = minitem and minitem.Value or minvalue
			obj.ValueMax = maxitem and maxitem.Value or maxvalue

			function obj:GetRandomValue()
				return Random.new():NextNumber(self.ValueMin, self.ValueMax)
			end

			function obj:SetValue(maximum, value)
				local item = maximum and maxitem or minitem

				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value)
				end
			end

			if minitem then
				minitem:OnChanged(function()
					obj.ValueMin = math.min(minitem.Value, obj.ValueMax)
				end)
			end

			if maxitem then
				maxitem:OnChanged(function()
					obj.ValueMax = math.max(maxitem.Value, obj.ValueMin)
				end)
			end

			return obj
		end

		if method == 'Bind' then
			local defaults = type(settings.Default) == 'table' and table.clone(settings.Default) or {}
			local label
			local item
			local pickerparent = settings.Module and module.ToggleObject or nil

			if not (pickerparent and type(rawget(pickerparent, 'AddKeyPicker')) == 'function') then
				label = addlabel(box, settings.Module and 'Keybind' or name)
				pickerparent = label
			end

			if pickerparent and type(rawget(pickerparent, 'AddKeyPicker')) == 'function' then
				pcall(pickerparent.AddKeyPicker, pickerparent, id, {
					Default = defaults[1] or 'None',
					Mode = settings.Hold and 'Hold' or 'Toggle',
					Text = name,
					NoUI = settings.Module == true
				})
				item = api.options[id]
			end

			local event = bindable()
			local obj = optionbase(module, settings, item or label, id)
			obj.Type = 'Bind'
			obj.Hold = settings.Hold == true
			obj.Keys = defaults
			obj.Triggered = event.Event
			obj._event = event
			obj.Object = proxy({label, item}, settings.Visible)

			local function active()
				local pos = table.find(vape.ActiveBinds, obj)
				if #obj.Keys > 0 and not pos then
					table.insert(vape.ActiveBinds, obj)
				elseif #obj.Keys == 0 and pos then
					table.remove(vape.ActiveBinds, pos)
				end
			end

			function obj:SetBind(keys)
				self.Keys = type(keys) == 'table' and table.clone(keys) or {}
				active()
				if item and type(rawget(item, 'SetValue')) == 'function' then
					pcall(item.SetValue, item, {self.Keys[1] or 'None', self.Hold and 'Hold' or 'Toggle'})
				end
			end

			local baseDestroy = obj.Destroy
			function obj:Destroy()
				local pos = table.find(vape.ActiveBinds, self)
				if pos then table.remove(vape.ActiveBinds, pos) end
				baseDestroy(self)
			end

			function obj:SetColor() end
			function obj:SetParent() end
			function obj:CreateMobileButton() end
			function obj:DestroyMobileButton() end
			function obj:Save(data)
				data[name] = {Keys = table.clone(self.Keys), Hold = self.Hold}
			end
			function obj:Load(data)
				data = data or {}
				self.Hold = data.Hold == true
				self:SetBind(type(data.Keys) == 'table' and data.Keys or defaults)
			end

			if item and type(rawget(item, 'OnChanged')) == 'function' then
				item:OnChanged(function()
					local value = rawget(item, 'Value')
					local mode = rawget(item, 'Mode')
					if type(value) == 'string' then
						obj.Keys = value ~= '' and value ~= 'None' and {value} or {}
					end
					if type(mode) == 'string' then obj.Hold = mode == 'Hold' end
					active()
				end)
			end

			active()
			if settings.Module then module.Options[name] = nil end
			return obj
		end

		if method == 'Font' then
			local list = {}
			local default = tostring(settings.Default or '')
			local obj

			for _, font in ipairs(Enum.Font:GetEnumItems()) do
				if font.Name ~= settings.Blacklist then
					list[#list + 1] = font.Name
				end
			end

			if not table.find(list, default) then
				default = settings.Blacklist == 'Arial' and 'Gotham' or 'Arial'
			end

			local drop = makeoption(module, 'Dropdown', {
				Name = name,
				List = list,
				Default = default,
				Visible = settings.Visible,
				Function = function(value)
					local font = Enum.Font[value]

					if font then
						local face = Font.fromEnum(font)

						if obj then
							obj.Value = face
						end

						settings.Function = settings.Function or function() end
						safe(module.Name..'/'..name, settings.Function, face)
					end
				end
			})
			obj = drop
			obj.Type = 'Font'
			obj.Value = Font.fromEnum(Enum.Font[drop.Value] or Enum.Font.Arial)

			local oldset = obj.SetValue
			function obj:SetValue(value)
				if typeof(value) == 'Font' then
					self.Value = value
					safe(module.Name..'/'..name, settings.Function, value)
					return
				end

				oldset(self, value)
				self.Value = Font.fromEnum(Enum.Font[value] or Enum.Font.Arial)
			end

			return obj
		end

		if method == 'Targets' then
			local obj = {
				Type = 'Targets',
				Object = proxy(nil, settings.Visible)
			}

			local function target(part, default)
				local option = makeoption(module, 'Toggle', {
					Name = (name ~= 'Targets' and name..' ' or '')..part,
					Default = default == true,
					Visible = settings.Visible,
					Function = function()
						safe(module.Name..'/'..name, settings.Function)
					end
				})
				return option
			end

			obj.Players = target('players', settings.Players)
			obj.NPCs = target('npcs', settings.NPCs)
			obj.Invisible = target('ignore invisible', settings.Invisible)
			obj.Walls = target('ignore walls', settings.Walls)
			obj.Object = proxy({obj.Players.Item, obj.NPCs.Item, obj.Invisible.Item, obj.Walls.Item}, settings.Visible)
			module.Options[name] = obj
			return obj
		end

		if method == 'Button' then
			local button
			local ok, result = pcall(box.AddButton, box, {
				Text = name,
				Func = function()
					safe(module.Name..'/'..name, settings.Function)
				end
			})

			if ok then
				button = result
			end

			local obj = optionbase(module, settings, button, id)
			obj.Type = 'Button'
			return obj
		end

		return optionbase(module, settings, addlabel(box, name), id)
	end

	local function module(category, settings, isoverlay)
		settings = settings or {}
		local name = tostring(settings.Name or 'Module')
		local islegit = category == vape.Legit

		-- This is intentionally unconditional. Vape's real Module.lua starts with
		-- `vape:Remove(props.Name)`, which is what makes a game-specific module
		-- replace a universal module with the same name (for example Prison Life's
		-- SilentAim) even when the game's base.lua does not explicitly remove it.
		vape:Remove(name)

		local box = category:box(name)

		if not box then
			return
		end
		local id = newid(category.Name, name)
		box:AddToggle(id, {
			Text = 'Enabled',
			Default = false,
			Tooltip = settings.Tooltip,
			Visible = settings.Visible == nil or settings.Visible
		})

		local toggle = api.toggles[id]
		local holder = Instance.new('Frame')
		holder.Name = slug(name)
		holder.Size = settings.Size or UDim2.fromOffset(220, 220)
		holder.Position = settings.Position or UDim2.fromOffset(20, 80)
		holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Visible = false
		holder.Parent = overlay

		local obj = {
			Name = name,
			Category = category.Name,
			Type = islegit and 'LegitModule' or 'Module',
			Legit = islegit or nil,
			Index = #modlist,
			Visible = settings.Visible == nil or settings.Visible == true,
			ExtraText = settings.ExtraText,
			Enabled = false,
			Options = {},
			Connections = {},
			Bind = {},
			Object = proxy(box, true),
			Children = holder,
			Button = nil,
			ToggleObject = toggle,
			Box = box,
			Id = id,
			_items = {toggle, holder},
			_overlay = isoverlay == true,
			_settings = settings
		}
		obj.Button = obj

		function obj:Clean(value)
			if value ~= nil then
				self.Connections[#self.Connections + 1] = value
			end

			return value
		end

		function obj:Drop()
			clean(self.Connections)
		end

		function obj:SetBind(value)
			self.Bind = type(value) == 'table' and table.clone(value) or {}
		end

		function obj:SetVisible(value)
			self.Visible = value == true
			if self.Object then
				self.Object.Visible = self.Visible
			end
			return self.Visible
		end

		function obj:GetExtraText()
			if type(settings.ExtraText) ~= 'function' then
				return ''
			end

			local ok, value = pcall(settings.ExtraText)
			return ok and tostring(value or '') or ''
		end

		function obj:Toggle()
			if toggle and type(rawget(toggle, 'SetValue')) == 'function' then
				toggle:SetValue(not toggle.Value)
			end
		end

		function obj:Destroy()
			if self._dead then
				return
			end

			self._dead = true
			if self.Object then self.Object.Visible = false end
			if self._bindConnection then pcall(drop, self._bindConnection); self._bindConnection = nil end
			if self.Bind and type(rawget(self.Bind, 'Destroy')) == 'function' then pcall(self.Bind.Destroy, self.Bind) end

			if self.Enabled then
				self.Enabled = false
				holder.Visible = false
				safe(name, settings.Function, false)
			end

			if toggle and toggle.Value == true and type(rawget(toggle, 'SetValue')) == 'function' then
				pcall(toggle.SetValue, toggle, false)
			end

			self:Drop()

			for index = #self._items, 1, -1 do
				local item = self._items[index]

				if type(item) == 'table' and type(rawget(item, 'Destroy')) == 'function' then
					pcall(item.Destroy, item)
				elseif typeof(item) == 'Instance' then
					pcall(item.Destroy, item)
				end
			end

			if type(box) == 'table' and type(rawget(box, 'Destroy')) == 'function' then
				pcall(box.Destroy, box)
			end

			if mods[self.Name] == self then
				mods[self.Name] = nil
			end

			if category.Modules[self.Name] == self then
				category.Modules[self.Name] = nil
			end

			if vape.Legit.Modules[self.Name] == self then
				vape.Legit.Modules[self.Name] = nil
			end
		end

		for _, method in ipairs({'Toggle', 'Slider', 'Dropdown', 'ColorSlider', 'Targets', 'TextBox', 'TextList', 'TwoSlider', 'Font', 'Button', 'Bind'}) do
			obj['Create'..method] = function(self, values)
				return makeoption(self, method, values)
			end
		end

		for componentName, callback in pairs(vape.Components) do
			if type(callback) == 'function' then
				obj['Create'..componentName] = function(self, values)
					return callback(values or {}, self.Children, self)
				end
			end
		end

		obj.Bind = makeoption(obj, 'Bind', {Name = 'Module Bind', Default = {}, Module = true, Visible = false})
		if obj.Bind and obj.Bind.Triggered then
			obj._bindConnection = hold(obj.Bind.Triggered:Connect(function(isDown)
				if obj.Bind.Hold then
					if obj.Enabled ~= isDown then obj:Toggle() end
				elseif isDown then
					obj:Toggle()
				end
			end))
		end

		local function changed()
			local value = toggle and toggle.Value == true or false
			obj.Enabled = value
			holder.Visible = value

			if not value then
				obj:Drop()
			end

			if type(vape.UpdateTextGUI) == 'function' then
				pcall(vape.UpdateTextGUI, vape)
			end

			if not obj._dead and not safe(name, settings.Function, value) and value then
				obj.Enabled = false
				holder.Visible = false
				obj:Drop()

				if toggle and toggle.Value == true and type(rawget(toggle, 'SetValue')) == 'function' then
					pcall(toggle.SetValue, toggle, false)
				end
			end
		end

		if toggle then
			toggle:OnChanged(changed)
		end

		-- Match Vape's two module registries. Normal modules live in vape.Modules;
		-- legit modules live in vape.Legit.Modules. Keeping these separate matters
		-- because vape:Remove(name) resolves normal -> legit -> category in that order.
		if islegit then
			vape.Legit.Modules[name] = obj
		else
			mods[name] = obj
			category.Modules[name] = obj
		end

		modlist[#modlist + 1] = obj

		hold(function()
			local registered = islegit and vape.Legit.Modules[name] or mods[name]
			if registered == obj then
				obj:Destroy()
			end
		end)

		return obj
	end

	setmetatable(vape.Components, {
		__newindex = function(components, index, callback)
			rawset(components, index, callback)
			if type(callback) ~= 'function' then return end

			-- Vape components can be registered by a game's base.lua before or after
			-- modules are created. Patch both module registries so future upstream
			-- components do not depend on load timing.
			for _, registry in ipairs({mods, vape.Legit.Modules}) do
				for _, current in pairs(registry) do
					current['Create'..index] = function(self, values)
						return callback(values or {}, self.Children, self)
					end
				end
			end
		end
	})

	local function enablecategory(category)
		if type(category) == 'table'
			and type(rawget(category, 'box')) == 'function'
			and type(rawget(category, 'CreateModule')) ~= 'function' then

			function category:CreateModule(settings)
				return module(self, settings, false)
			end
		end

		return category
	end

	for _, category in pairs(cats) do
		enablecategory(category)
	end

	-- New upstream categories should not require an adapter update. If Vape adds a
	-- category in a future source update, materialize a matching FiveRose tab on
	-- first access and give it the same CreateModule contract.
	setmetatable(cats, {
		__index = function(_, name)
			if type(name) ~= 'string' or name == '' then
				return nil
			end

			return enablecategory(makecategory(name))
		end
	})

	function vape:CreateOverlay(settings)
		return module(cats.Render, settings, true)
	end

	function vape:Clean(value)
		return hold(value)
	end

	function vape:CreateNotification(title, text, time, kind)
		api:notify(title, text, time, kind)
	end

	local function removeinstance(value)
		if typeof(value) == 'Instance' then
			pcall(value.Destroy, value)
			return
		end

		if type(value) == 'table' then
			local object = rawget(value, 'Object')
			if typeof(object) == 'Instance' then
				pcall(object.Destroy, object)
			end
		end
	end

	local function hidebox(box)
		if type(box) ~= 'table' then
			return
		end

		local hide = rawget(box, 'Hide')
		if type(hide) == 'function' then
			pcall(hide, box)
			return
		end

		local set = rawget(box, 'SetVisible')
		if type(set) == 'function' then
			pcall(set, box, false)
		end
	end

	function vape:Remove(name)
		-- Match Vape's actual container resolution: normal module, legit module,
		-- then category. Explicit upstream vape:Remove(...) calls therefore keep
		-- their meaning without a FiveroseTweaker-maintained removal list.
		local container = rawget(self.Modules, name) and self.Modules
			or (self.Legit and rawget(self.Legit.Modules or {}, name)) and self.Legit.Modules
			or self.Categories
		local item = container and rawget(container, name)

		if not item then
			return false
		end

		local ismodule = type(item) == 'table' and rawget(item, 'Type') == 'Module'
		local categoryname = type(item) == 'table' and rawget(item, 'Category')
		local category = categoryname and rawget(self.Categories, categoryname)
		local box = type(item) == 'table' and rawget(item, 'Box')
		local children = type(item) == 'table' and rawget(item, 'Children')
		local toggleobject = type(item) == 'table' and rawget(item, 'ToggleObject')
		local object = type(item) == 'table' and rawget(item, 'Object')
		local button = type(item) == 'table' and rawget(item, 'Button')

		-- Obsidian groupboxes intentionally do not expose Destroy(), so hide the
		-- old module container before tearing the wrapper down. This is the host-UI
		-- equivalent of Vape destroying component.Object and prevents duplicate
		-- universal/game-specific rows from surviving a replacement.
		hidebox(box)

		local destroy = type(item) == 'table' and rawget(item, 'Destroy')
		if type(destroy) == 'function' then
			pcall(destroy, item)
		end

		-- Vape additionally destroys Object/Children/Toggle/Button after calling
		-- component:Destroy(). Keep that second cleanup pass: it prevents stale
		-- FiveRose groupboxes from surviving a universal -> game replacement even
		-- if a wrapper's Destroy method changes or partially fails.
		removeinstance(object)
		removeinstance(children)
		removeinstance(toggleobject)
		removeinstance(button)

		if type(box) == 'table' and type(rawget(box, 'Destroy')) == 'function' then
			pcall(box.Destroy, box)
		end

		if container then
			rawset(container, name, nil)
		end

		-- Our adapter stores a few extra ownership references that real Vape does
		-- not. Clear every registry explicitly before invalidating the old object.
		if rawget(self.Modules, name) == item then
			rawset(self.Modules, name, nil)
		end

		if self.Legit and rawget(self.Legit.Modules or {}, name) == item then
			rawset(self.Legit.Modules, name, nil)
		end

		if category and type(rawget(category, 'Modules')) == 'table'
			and rawget(category.Modules, name) == item then
			rawset(category.Modules, name, nil)
		end

		-- Real Vape's loopClean recursively invalidates the removed component. A
		-- shallow clear is deliberate here: our wrapper points at shared FiveRose
		-- objects, so recursively clearing them would corrupt the host UI. Locals
		-- that still reference the removed module nevertheless see a dead table.
		if ismodule and type(item) == 'table' then
			table.clear(item)
		end

		return true
	end


	function vape:Save()
		if type(api.save) == 'function' then
			return api:save()
		end
	end

	function vape:Load(_, profile)
		if profile ~= nil and type(api.setprofile) == 'function' then
			local ok, result = pcall(api.setprofile, api, profile)

			if not ok or not result then
				return false, ok and 'profile was rejected' or result
			end

			self.Profile = api.profile and api.profile.name or tostring(profile)
		end

		self.Loaded = true
		return true
	end

	function vape:Uninject()
		if type(api.disable_vape) == 'function' then
			return api:disable_vape()
		end
	end

	-- Shared rainbow clock used by ported ColorSlider controls and the
	-- FiveRose-native text GUI below. This mirrors Vape's shared rainbow-state
	-- model without depending on Vape's own ClickGUI being present.
	vape.RainbowHue = 0
	local rainbowclock = 0
	local rainbowlast = 0

	hold(runservice.RenderStepped:Connect(function(delta)
		local speed = math.max(0.05, tonumber(vape.RainbowSpeed.Value) or 1)
		rainbowclock = (rainbowclock + delta * 0.12 * speed) % 1
		vape.RainbowHue = rainbowclock

		local rate = math.clamp(tonumber(vape.RainbowUpdateSpeed.Value) or 60, 1, 240)
		local now = os.clock()
		if now - rainbowlast < 1 / rate then return end
		rainbowlast = now

		for index = #vape.RainbowSliders, 1, -1 do
			local slider = vape.RainbowSliders[index]
			if type(slider) ~= 'table' or slider._dead or slider.Rainbow ~= true then
				table.remove(vape.RainbowSliders, index)
			elseif type(rawget(slider, 'SetValue')) == 'function' then
				pcall(slider.SetValue, slider, rainbowclock, nil, nil, nil)
			end
		end
	end))

	local textgui = {
		Enabled = false,
		Rainbow = true,
		Background = true,
		Watermark = true,
		BackgroundOpacity = 78,
		FontSize = 14,
		Sort = 'Length',
		Rows = {},
		LastUpdate = 0
	}

	local textroot = Instance.new('Frame')
	textroot.Name = 'FiveRoseTextGUI'
	textroot.AnchorPoint = Vector2.new(1, 0)
	textroot.Position = UDim2.new(1, -14, 0, 54)
	textroot.Size = UDim2.fromOffset(360, 600)
	textroot.BackgroundTransparency = 1
	textroot.BorderSizePixel = 0
	textroot.Visible = false
	textroot.Parent = overlay
	hold(textroot)

	local textlayout = Instance.new('UIListLayout')
	textlayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	textlayout.SortOrder = Enum.SortOrder.LayoutOrder
	textlayout.Padding = UDim.new(0, 3)
	textlayout.Parent = textroot

	local textheader = Instance.new('TextButton')
	textheader.Name = 'Watermark'
	textheader.AutoButtonColor = false
	textheader.AutomaticSize = Enum.AutomaticSize.X
	textheader.Size = UDim2.fromOffset(0, 26)
	textheader.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
	textheader.BorderSizePixel = 0
	textheader.LayoutOrder = -1000
	textheader.FontFace = vape.Libraries.uipallet.FontSemiBold
	textheader.Text = '  FiveroseTweaker  '
	textheader.TextColor3 = Color3.new(1, 1, 1)
	textheader.TextSize = 14
	textheader.TextXAlignment = Enum.TextXAlignment.Right
	textheader.Parent = textroot

	local headercorner = Instance.new('UICorner')
	headercorner.CornerRadius = UDim.new(0, 4)
	headercorner.Parent = textheader

	local headeraccent = Instance.new('Frame')
	headeraccent.AnchorPoint = Vector2.new(1, 0)
	headeraccent.Position = UDim2.new(1, 0, 0, 0)
	headeraccent.Size = UDim2.new(0, 3, 1, 0)
	headeraccent.BorderSizePixel = 0
	headeraccent.Parent = textheader

	-- The watermark is also the drag handle. Global input listeners are created
	-- only during an active drag, so this does not undo the shared-input-dispatch
	-- performance work used by the rest of the adapter.
	do
		local moveconnection, releaseconnection
		local function stopdrag()
			if moveconnection then pcall(moveconnection.Disconnect, moveconnection); moveconnection = nil end
			if releaseconnection then pcall(releaseconnection.Disconnect, releaseconnection); releaseconnection = nil end
		end

		hold(function() stopdrag() end)
		hold(textheader.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then return end

			stopdrag()
			local dragstart = Vector2.new(input.Position.X, input.Position.Y)
			local startposition = textroot.Position

			moveconnection = inputservice.InputChanged:Connect(function(move)
				if move.UserInputType ~= Enum.UserInputType.MouseMovement
					and move.UserInputType ~= Enum.UserInputType.Touch then return end
				local delta = Vector2.new(move.Position.X, move.Position.Y) - dragstart
				textroot.Position = UDim2.new(
					startposition.X.Scale, startposition.X.Offset + delta.X,
					startposition.Y.Scale, startposition.Y.Offset + delta.Y
				)
			end)

			releaseconnection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					stopdrag()
				end
			end)
		end))
	end

	local function textguiaccent(index)
		if textgui.Rainbow then
			return Color3.fromHSV((vape.RainbowHue - ((index - 1) * 0.035)) % 1, 0.82, 1)
		end

		local scheme = api.lib and rawget(api.lib, 'Scheme')
		if type(scheme) == 'table' and typeof(rawget(scheme, 'AccentColor')) == 'Color3' then
			return scheme.AccentColor
		end

		return Color3.fromHSV(vape.GUIColor.Hue or 0.46, vape.GUIColor.Sat or 0.96, vape.GUIColor.Value or 0.52)
	end

	local function cleartextrows(from)
		from = tonumber(from) or 1
		for index = #textgui.Rows, from, -1 do
			local row = textgui.Rows[index]
			if type(row) == 'table' and typeof(row.Frame) == 'Instance' then
				pcall(row.Frame.Destroy, row.Frame)
			elseif typeof(row) == 'Instance' then
				pcall(row.Destroy, row)
			end
			textgui.Rows[index] = nil
		end
	end

	local function maketextrow(index)
		local frame = Instance.new('Frame')
		frame.AutomaticSize = Enum.AutomaticSize.X
		frame.Size = UDim2.fromOffset(0, textgui.FontSize + 8)
		frame.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
		frame.BorderSizePixel = 0
		frame.LayoutOrder = index
		frame.Parent = textroot

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame

		local accent = Instance.new('Frame')
		accent.AnchorPoint = Vector2.new(1, 0)
		accent.Position = UDim2.new(1, 0, 0, 0)
		accent.Size = UDim2.new(0, 2, 1, 0)
		accent.BorderSizePixel = 0
		accent.Parent = frame

		local label = Instance.new('TextLabel')
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.FontFace = vape.Libraries.uipallet.Font
		label.RichText = true
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Parent = frame

		local row = {Frame = frame, Accent = accent, Label = label}
		textgui.Rows[index] = row
		return row
	end

	function vape:UpdateTextGUI()
		textroot.Visible = textgui.Enabled == true
		textheader.Visible = textgui.Watermark == true
		local backgroundTransparency = textgui.Background
			and (1 - math.clamp(textgui.BackgroundOpacity, 0, 100) / 100) or 1
		textheader.BackgroundTransparency = backgroundTransparency
		headeraccent.BackgroundColor3 = textguiaccent(1)
		if not textgui.Enabled then
			cleartextrows()
			return
		end

		local enabled = {}
		for _, registry in ipairs({self.Modules, self.Legit and self.Legit.Modules or {}}) do
			for name, current in pairs(registry) do
				if type(current) == 'table' and current.Enabled and name ~= 'FiveRose Text GUI' then
					local extra = type(rawget(current, 'GetExtraText')) == 'function' and current:GetExtraText() or ''
					local display = tostring(name)
					if extra ~= '' then display ..= '  <font transparency=\"0.28\">'..extra..'</font>' end
					enabled[#enabled + 1] = {Name = name, Text = display}
				end
			end
		end

		table.sort(enabled, function(a, b)
			if textgui.Sort == 'Alphabetical' then
				return a.Name:lower() < b.Name:lower()
			end

			local asize = getsize(a.Name, textgui.FontSize, vape.Libraries.uipallet.Font).X
			local bsize = getsize(b.Name, textgui.FontSize, vape.Libraries.uipallet.Font).X
			if asize == bsize then return a.Name < b.Name end
			return asize > bsize
		end)

		for index, data in ipairs(enabled) do
			local row = textgui.Rows[index]
			if type(row) ~= 'table' or typeof(row.Frame) ~= 'Instance' then
				row = maketextrow(index)
			end

			local accent = textguiaccent(index)
			row.Frame.Name = slug(data.Name)
			row.Frame.LayoutOrder = index
			row.Frame.Size = UDim2.fromOffset(0, textgui.FontSize + 8)
			row.Frame.BackgroundTransparency = backgroundTransparency
			row.Accent.BackgroundColor3 = accent
			row.Label.Text = '  '..data.Text..'  '
			row.Label.TextColor3 = accent
			row.Label.TextSize = textgui.FontSize
		end

		if #textgui.Rows > #enabled then
			cleartextrows(#enabled + 1)
		end
	end

	function vape:BlurCheck() end
	function vape:Color(value)
		return (self.RainbowHue - (tonumber(value) or 0)) % 1
	end
	function vape:TextColor()
		return Color3.new(1, 1, 1)
	end

	local textguimodule = module(cats.Render, {
		Name = 'FiveRose Text GUI',
		Tooltip = 'Compact enabled-module list built for the FiveRose UI',
		Function = function(enabled)
			textgui.Enabled = enabled == true
			vape:UpdateTextGUI()
		end
	}, true)

	if textguimodule then
		textguimodule:CreateDropdown({
			Name = 'Sort',
			List = {'Length', 'Alphabetical'},
			Default = 'Length',
			Function = function(value)
				textgui.Sort = value == 'Alphabetical' and 'Alphabetical' or 'Length'
				vape:UpdateTextGUI()
			end
		})
		textguimodule:CreateToggle({
			Name = 'Rainbow',
			Default = true,
			Function = function(value)
				textgui.Rainbow = value == true
				vape:UpdateTextGUI()
			end
		})
		textguimodule:CreateToggle({
			Name = 'Background',
			Default = true,
			Function = function(value)
				textgui.Background = value == true
				vape:UpdateTextGUI()
			end
		})
		textguimodule:CreateToggle({
			Name = 'Watermark',
			Default = true,
			Function = function(value)
				textgui.Watermark = value == true
				vape:UpdateTextGUI()
			end
		})
		textguimodule:CreateSlider({
			Name = 'Background Opacity',
			Min = 0,
			Max = 100,
			Default = 78,
			Decimal = 1,
			Suffix = '%',
			Function = function(value)
				textgui.BackgroundOpacity = math.clamp(tonumber(value) or 78, 0, 100)
				vape:UpdateTextGUI()
			end
		})
		textguimodule:CreateSlider({
			Name = 'Text Size',
			Min = 10,
			Max = 22,
			Default = 14,
			Decimal = 1,
			Function = function(value)
				textgui.FontSize = math.clamp(tonumber(value) or 14, 10, 22)
				vape:UpdateTextGUI()
			end
		})
	end

	hold(runservice.Heartbeat:Connect(function()
		if not textgui.Enabled then return end
		local now = os.clock()
		if now - textgui.LastUpdate < 0.12 then return end
		textgui.LastUpdate = now
		vape:UpdateTextGUI()
	end))

	api.vape_errors = {}
	function api:vape_module_error(source, err)
		local item = {source = tostring(source or 'unknown'), error = tostring(err), time = os.clock()}
		table.insert(self.vape_errors, item)
		warn('[fiverosetweaker/vape] '..item.source..': '..item.error)
		if #self.vape_errors <= 3 then
			self:notify('Vape compatibility', item.source:match('([^/]+)%.lua$') or item.source, 4)
		end
		return item
	end

	local upstreamCommit = 'unknown'
	do
		-- build_vape.py owns upstream.json. Reading the commit from the generated
		-- manifest keeps this bridge valid when the Vape snapshot is regenerated.
		local ok, source = pcall(api.source, api, 'src/vape/upstream.json')
		if ok and type(source) == 'string' then
			local decoded, data = pcall(httpservice.JSONDecode, httpservice, source)
			if decoded and type(data) == 'table'
				and type(data.upstream_commit) == 'string'
				and data.upstream_commit ~= '' then

				upstreamCommit = data.upstream_commit
			end
		end
	end

	function api:vape_virtual_read(path)
		path = tostring(path or ''):gsub('\\', '/')
		if path == 'newvape/profiles/commit.txt' then
			return true, upstreamCommit
		end
		local library = path:match('^newvape/libraries/([%w_%-]+%.lua)$')
		if library then
			local ok, value = pcall(self.source, self, 'src/vape/libraries/'..library)
			if ok and type(value) == 'string' then return true, value end
		end
		return false
	end

	function api:vape_virtual_write()
		return false
	end

	local function bindmatches(bind, key)
		if type(bind) ~= 'table' or type(bind.Keys) ~= 'table' or not table.find(bind.Keys, key) then return false end
		for _, required in ipairs(bind.Keys) do
			if not table.find(vape.HeldKeybinds, required) then return false end
		end
		return true
	end

	hold(inputservice.InputBegan:Connect(function(input)
		if inputservice:GetFocusedTextBox() or input.KeyCode == Enum.KeyCode.Unknown then return end
		local key = input.KeyCode.Name
		if not table.find(vape.HeldKeybinds, key) then table.insert(vape.HeldKeybinds, key) end
		for _, bind in ipairs(vape.ActiveBinds) do
			if bindmatches(bind, key) then bind._event:Fire(true) end
		end
	end))

	hold(inputservice.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Unknown then return end
		local key = input.KeyCode.Name
		for _, bind in ipairs(vape.ActiveBinds) do
			if bind.Hold and bindmatches(bind, key) then bind._event:Fire(false) end
		end
		local index = table.find(vape.HeldKeybinds, key)
		if index then table.remove(vape.HeldKeybinds, index) end
	end))

	api.vape = vape
	api.vapelibs = vape.Libraries
	bridge.libs = api.vapelibs
	shared.vape = vape

	return bridge
end
