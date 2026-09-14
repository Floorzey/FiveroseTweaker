return function(boot, env)
	if rawget(env, 'fiverosetweaker_fastboot') == false then
		return
	end

	local signature = 'fiverosetweaker-fastboot-v1'
	local existing = rawget(env, 'fiverosetweaker_fastboot_session')

	if type(existing) == 'table'
		and rawget(existing, '_signature') == signature
		and type(rawget(existing, 'reset')) == 'function' then

		local ok, result = pcall(existing.reset, existing, boot)

		if ok then
			return result or existing
		end
	end

	local runservice = game:GetService('RunService')
	local defaultloader = 'https://api.jnkie.com/api/v1/luascripts/public/4d158afc6a06b4850944ecb0c53a62ff1f1159b5bb869a242689fe5b147d22e2/download'
	local loaderurl = tostring(rawget(env, 'fiverosetweaker_fiverose_loader_url') or defaultloader)
	local staticurls = {
		'https://jnkie.com/sdk/library.lua',
		'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua',
		'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/ThemeManager.lua',
		'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua'
	}

	if loaderurl:match('^https://') then
		table.insert(staticurls, 1, loaderurl)
	end
	local session = {
		_signature = signature,
		active = false,
		boot = boot,
		urls = staticurls,
		slots = {},
		_original = nil,
		_target = nil,
		_hook = 'none',
		_heartbeat = nil,
		_generation = 0
	}

	local function sourceok(source)
		if type(source) ~= 'string' or not source:match('%S') then
			return false
		end

		local head = source:sub(1, 512):lower()
		local trimmed = head:match('^%s*(.*)') or head
		local jsonerror = (trimmed:sub(1, 1) == '{' or trimmed:sub(1, 1) == '[')
			and (head:find('\"error\"', 1, true) or head:find('\"message\"', 1, true))

		return not head:find('<!doctype', 1, true)
			and not head:find('<html', 1, true)
			and not head:find('404: not found', 1, true)
			and not jsonerror
	end

	local function disconnect(connection)
		if connection then
			pcall(connection.Disconnect, connection)
		end
	end

	function session:_register(url, preload)
		if type(url) ~= 'string' or not url:match('^https://') then
			return
		end

		if not self.slots[url] then
			self.slots[url] = {
				url = url,
				loading = false,
				ok = false
			}

			local found = false
			for _, value in ipairs(self.urls) do
				if value == url then
					found = true
					break
				end
			end

			if not found then
				self.urls[#self.urls + 1] = url
			end

			if preload and self.active then
				local generation = self._generation
				task.spawn(function()
					if self.active and self._generation == generation then
						self:_fetch(url)
					end
				end)
			end
		end

		return self.slots[url]
	end

	function session:_discover(source)
		if type(source) ~= 'string' then
			return
		end

		-- Obsidian downloads a few UI assets during Library.lua startup. Discover
		-- them from the library source instead of hard-coding today's asset list,
		-- so future additions are automatically prefetched as long as Obsidian
		-- keeps the same simple BaseURL + relative-path pattern.
		local base = source:match('[Ll]ocal%s+[Bb]aseURL%s*=%s*[\"\']([^\"\']+)[\"\']')
		if not base then
			return
		end

		for path in source:gmatch('URL%s*=%s*BaseURL%s*%.%.%s*[\"\']([^\"\']+)[\"\']') do
			self:_register(base..path, true)
		end
	end

	function session:_fetch(url)
		local slot = self.slots[url]

		if not slot then
			return
		end

		if slot.source then
			return slot.source
		end

		if slot.loading then
			local started = os.clock()

			while slot.loading and not slot.source and self.active do
				task.wait()
			end

			if self.stats then
				self.stats.wait_time = (self.stats.wait_time or 0) + (os.clock() - started)
			end

			return slot.source
		end

		local original = self._original
		if type(original) ~= 'function' then
			return
		end

		slot.loading = true
		slot.started = os.clock()
		-- When interception is available we want a fresh copy because that exact
		-- source is returned from memory later. In prefetch-only mode, allow the
		-- executor/engine HTTP cache to retain the request as a best-effort fallback.
		local nocache = self._hook == 'hookfunction'
		local ok, source = pcall(original, game, url, nocache)
		slot.elapsed = os.clock() - slot.started
		slot.loading = false
		slot.ok = ok and sourceok(source)

		if slot.ok then
			slot.source = source

			if url:find('raw.githubusercontent.com/deividcomsono/Obsidian/', 1, true)
				and url:sub(-12) == '/Library.lua' then
				self:_discover(source)
			end

			if self.stats then
				self.stats.preloaded = (self.stats.preloaded or 0) + 1
				self.stats.bytes = (self.stats.bytes or 0) + #source
			end
		else
			slot.error = ok and 'invalid response' or tostring(source)
		end

		return slot.source
	end

	function session:_intercept(selfobj, url, ...)
		local original = self._original

		if type(original) ~= 'function' then
			error('HttpGet unavailable', 2)
		end

		if not self.active or selfobj ~= game or type(url) ~= 'string' or not self.slots[url] then
			return original(selfobj, url, ...)
		end

		local stats = self.stats
		if stats then
			stats.intercepts = (stats.intercepts or 0) + 1
		end

		local slot = self.slots[url]
		if slot.source then
			if stats then
				stats.hits = (stats.hits or 0) + 1
			end
			return slot.source
		end

		local source = self:_fetch(url)
		if source then
			if stats then
				stats.hits = (stats.hits or 0) + 1
			end
			return source
		end

		if stats then
			stats.misses = (stats.misses or 0) + 1
		end

		return original(selfobj, url, ...)
	end

	function session:_install()
		if self._original then
			return
		end

		local ok, httpget = pcall(function()
			return game.HttpGet
		end)

		if not ok or type(httpget) ~= 'function' then
			self._hook = 'unavailable'
			return
		end

		self._target = httpget
		self._original = httpget

		if type(hookfunction) ~= 'function' or rawget(env, 'fiverosetweaker_fastboot_hook') == false then
			self._hook = 'prefetch-only'
			return
		end

		local replacement = function(selfobj, url, ...)
			return session:_intercept(selfobj, url, ...)
		end

		if type(newcclosure) == 'function' then
			local wrappedok, wrapped = pcall(newcclosure, replacement)
			if wrappedok and type(wrapped) == 'function' then
				replacement = wrapped
			end
		end

		local hookok, original = pcall(hookfunction, httpget, replacement)

		if hookok and type(original) == 'function' then
			self._original = original
			self._hook = 'hookfunction'
		else
			self._hook = 'prefetch-only'
		end
	end

	function session:_monitor(generation)
		disconnect(self._heartbeat)
		self._heartbeat = nil

		local last = os.clock()
		local ok, connection = pcall(function()
			return runservice.Heartbeat:Connect(function()
				if self._generation ~= generation or not self.active then
					return
				end

				local now = os.clock()
				local gap = now - last
				last = now
				local stats = self.stats

				if stats and gap > (stats.max_frame_gap or 0) then
					stats.max_frame_gap = gap
				end

				if stats and gap >= 0.25 then
					stats.stalls = (stats.stalls or 0) + 1
				end
			end)
		end)

		if ok then
			self._heartbeat = connection
		end
	end

	function session:_preload(generation)
		for _, url in ipairs(self.urls) do
			task.spawn(function()
				if self._generation ~= generation or not self.active then
					return
				end

				self:_fetch(url)
			end)
		end
	end

	function session:mark(name)
		local stats = self.stats
		if stats and type(name) == 'string' then
			stats.marks[name] = os.clock() - stats.started
		end
	end

	function session:finish(reason)
		if not self.active then
			return self.stats
		end

		self:mark('finish')
		self.active = false
		disconnect(self._heartbeat)
		self._heartbeat = nil

		local stats = self.stats
		if stats then
			stats.finished = os.clock()
			stats.total = stats.finished - stats.started
			stats.reason = tostring(reason or 'finished')
			stats.hook = self._hook
		end

		if rawget(env, 'fiverosetweaker_fastboot_report') ~= false and type(print) == 'function' and stats then
			print(string.format(
				'[fiverosetweaker/fastboot] preload %d/%d | cache hits %d | max frame gap %.2fs | %.2fs to attach',
				tonumber(stats.preloaded) or 0,
				#self.urls,
				tonumber(stats.hits) or 0,
				tonumber(stats.max_frame_gap) or 0,
				tonumber(stats.total) or 0
			))
		end

		return stats
	end

	function session:stop(reason)
		return self:finish(reason or 'stopped')
	end

	function session:reset(newboot)
		self.boot = newboot or self.boot
		self._generation = self._generation + 1
		local generation = self._generation
		self.active = true
		self.slots = {}

		for _, url in ipairs(self.urls) do
			self:_register(url, false)
		end

		self.stats = {
			started = os.clock(),
			urls = self.slots,
			preloaded = 0,
			bytes = 0,
			intercepts = 0,
			hits = 0,
			misses = 0,
			wait_time = 0,
			max_frame_gap = 0,
			stalls = 0,
			marks = {},
			hook = self._hook
		}
		env.fiverosetweaker_fastboot_stats = self.stats
		self:_install()
		self.stats.hook = self._hook
		self:_monitor(generation)
		self:_preload(generation)
		return self
	end

	env.fiverosetweaker_fastboot_session = session
	return session:reset(boot)
end
