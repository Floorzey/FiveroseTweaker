return function(boot)
	local env = getgenv()
	local api = {
		name = 'FiveroseTweaker',
		state = 'loading',
		version = boot.version,
		branch = boot.branch,
		repo = boot.repo,
		dev = boot.dev,
		path = boot.root,
		boot_token = boot.token,
		token = {},
		loaded = {}
	}

	local clean = boot:load('src/core/clean.lua')
	local cache = boot:load('src/core/cache.lua')
	local imports = boot:load('src/core/import.lua')

	clean(api, env)
	cache(api, boot)
	imports.setup(api)

	function api:isactive()
		return (self.state == 'loading' or self.state == 'loaded')
			and rawget(env, 'fiverosetweaker') == self
			and rawget(env, 'fiverosetweaker_boot_token') == self.boot_token
	end

	function api:active()
		if not self:isactive() then

			error('load cancelled')
		end

		return true
	end

	if rawget(env, 'fiverosetweaker_boot_token') ~= boot.token then
		error('load cancelled')
	end

	env.fiverosetweaker = api

	local function use(path, ...)
		api:active()
		local module = api:import(path)
		local result = module

		if type(module) == 'function' then
			result = module(api, ...)
		end

		api:active()
		api.loaded[#api.loaded + 1] = path
		return result
	end

	local function start()
		local registry = api:import('src/games/registry.lua')
		local build = api:import('src/core/resolve.lua')
		local resolver = build(api, registry)
		local entry = resolver:resolve(game.PlaceId, game.GameId)

		api.registry = registry
		api.resolver = resolver
		api.place = game.PlaceId
		api.gameid = game.GameId
		api.game = entry

		if not entry then
			warn('[fiverosetweaker] unsupported game | place='..tostring(api.place)..' game='..tostring(api.gameid))
			api:unload(true)
			return
		end

		if api.cache.fileapi and not api.dev then
			local paths = {
				'main.lua',
				'src/loader.lua',
				'src/core/attach.lua',
				'src/core/cache.lua',
				'src/core/clean.lua',
				'src/core/import.lua',
				'src/core/profile.lua',
				'src/core/resolve.lua',
				'src/core/teleport.lua',
				'src/core/ui_universal.lua',
				'src/games/registry.lua'
			}
			local seen = {}

			for _, path in ipairs(registry.shared) do
				paths[#paths + 1] = path
			end

			for _, path in ipairs(registry.files or {}) do
				paths[#paths + 1] = path
			end

			for _, family in pairs(registry.families) do
				paths[#paths + 1] = family.base

				for _, path in ipairs(family.modules) do
					paths[#paths + 1] = path
				end
			end

			table.sort(paths)

			for _, path in ipairs(paths) do
				if not seen[path] then
					api:active()
					seen[path] = true
					api:source(path)
				end
			end

			api:complete(paths)
		end

		use('src/core/attach.lua')
		use('src/core/profile.lua')

		for _, path in ipairs(registry.shared) do
			use(path, entry)
		end

		use(entry.family.base, entry)

		for _, path in ipairs(entry.family.modules) do
			use(path, entry)
		end

		if type(api.restoremode) == 'function' then
			api:restoremode()
		end

		if type(api.finish_keybinds) == 'function' then
			api:finish_keybinds()
		end

		api:restore(true)
		use('src/core/teleport.lua')

		api:active()
		api.state = 'loaded'
		api:notify('FiveroseTweaker', entry.name, 3)
		return api
	end

	local ok, result = xpcall(start, function(err)
		if debug and type(debug.traceback) == 'function' then
			return debug.traceback(tostring(err), 2)
		end

		return tostring(err)
	end)

	if not ok then
		api.error = result
		api:unload(true)

		if not boot.retry_requested then
			warn('[fiverosetweaker] '..tostring(result))
		end

		return
	end

	return result
end
