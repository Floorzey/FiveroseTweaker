local env = getgenv()
local token = {}

env.fiverosetweaker_boot_token = token

repeat
	if rawget(env, 'fiverosetweaker_boot_token') ~= token then
		return
	end

	task.wait()
until game:IsLoaded()

if rawget(env, 'fiverosetweaker_boot_token') ~= token then
	return
end

local old = rawget(env, 'fiverosetweaker')

if type(old) == 'table' and type(rawget(old, 'unload')) == 'function' then
	local toggles = rawget(old, 'toggles')
	local stamina = type(toggles) == 'table' and rawget(toggles, 'stamina_multiplier')

	if rawget(old, 'version') == nil and type(stamina) == 'table' and rawget(stamina, 'Value') == true then
		local ok, set = pcall(function()
			return stamina.SetValue
		end)

		if ok and type(set) == 'function' then
			pcall(set, stamina, false)
		end
	end

	local ok, err = pcall(old.unload, old)

	if not ok then
		warn('[fiverosetweaker] previous unload failed: '..tostring(err))
	end
end

local oldfix = rawget(env, 'fiverose_ball_predictor_fix')

if type(oldfix) == 'table' and type(rawget(oldfix, 'unload')) == 'function' then
	pcall(oldfix.unload, oldfix)
end

local http = game:GetService('HttpService')
local branch = tostring(env.fiverosetweaker_branch or 'main')
local repo = tostring(env.fiverosetweaker_repo or 'https://raw.githubusercontent.com/Floorzey/FiveroseTweaker')
local dev = env.fiverosetweaker_dev == true
local root = tostring(env.fiverosetweaker_path or 'FiveroseTweaker')
local cache
local fileapi = type(readfile) == 'function' and type(writefile) == 'function'
local boot = {}

repo = repo:gsub('/+$', '')
root = root:gsub('[\\/]+$', '')
cache = 'fiverosetweaker/cache/'..http:UrlEncode(repo..'\n'..branch):gsub('/', '%%2F')

local function validpath(path)
	if type(path) ~= 'string' or not path:match('%S') then
		return false
	end

	path = path:gsub('\\', '/')

	if path:sub(1, 1) == '/' or path:match('^%a:/') or path:find('://', 1, true) then
		return false
	end

	if path:find('//', 1, true) then
		return false
	end

	if path:sub(-1) == '/' then
		return false
	end

	if path:find('[^%w%._%-%/]') then
		return false
	end

	for part in path:gmatch('[^/]+') do
		if part == '..' or part == '.' or part == '' then
			return false
		end
	end

	return not path:find('%c')
end

local function validsource(source)
	if type(source) ~= 'string' or not source:match('%S') then
		return false
	end

	local head = source:sub(1, 512):lower()

	return not head:find('<!doctype', 1, true)
		and not head:find('<html', 1, true)
		and not head:find('404: not found', 1, true)
end

local function read(path)
	if type(readfile) ~= 'function' then
		return
	end

	local ok, source = pcall(readfile, path)

	if ok and validsource(source) then
		return source
	end
end

local function folders(path)
	if type(makefolder) ~= 'function' then
		return
	end

	local current = ''

	for part in path:gsub('\\', '/'):gmatch('[^/]+') do
		current = current == '' and part or current..'/'..part
		pcall(makefolder, current)
	end
end

local function write(path, source)
	if not fileapi or not validsource(source) then
		return false
	end

	local parent = path:match('^(.*)/[^/]+$')

	if parent then
		folders(parent)
	end

	return pcall(writefile, path, source)
end

local function request(url)
	local ok, source = pcall(function()
		return game:HttpGet(url, true)
	end)

	if ok and validsource(source) then
		return source
	end
end

local function current()
	if type(readfile) ~= 'function' then
		return
	end

	local ok, value = pcall(readfile, cache..'/current.txt')

	if ok and type(value) == 'string' then
		value = value:match('^%s*(.-)%s*$')

		if value and value ~= '' and #value <= 256 and not value:find('%c') then
			return value
		end
	end
end

local function key(version)
	return http:UrlEncode(tostring(version)):gsub('/', '%%2F')
end

local function cached(version, path)
	local source = read(cache..'/'..key(version)..'/'..path)

	if not source then
		return
	end

	if path:sub(-4) == '.lua' and not loadstring(source, '@fiverosetweaker/cache/'..path) then
		return
	end

	return source
end

local function store(version, path, source)
	if path:sub(-4) == '.lua' and not loadstring(source, '@fiverosetweaker/cache/'..path) then
		return false
	end

	return write(cache..'/'..key(version)..'/'..path, source)
end

local function complete(version)
	local marker = read(cache..'/'..key(version)..'/complete.txt')

	return marker == 'complete:'..tostring(version)
end

local function resolve()
	if dev then
		return 'dev'
	end

	if branch:match('^[%da-fA-F]+$') and #branch == 40 then
		return branch:lower()
	end

	local owner, name = repo:match('^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)$')

	if owner and name then
		local body = request('https://api.github.com/repos/'..owner..'/'..name..'/commits/'..http:UrlEncode(branch))

		if body then
			local ok, data = pcall(http.JSONDecode, http, body)
			local sha = ok and type(data) == 'table' and data.sha

			if type(sha) == 'string' and sha:match('^[%da-fA-F]+$') and #sha == 40 then
				return sha:lower()
			end
		end
	end

	local marker = request(repo..'/'..branch..'/commit.txt')

	if marker then
		marker = marker:match('^%s*([%da-fA-F]+)%s*$')

		if marker and #marker == 40 then
			return marker:lower()
		end
	end

	local last = current()

	if last and complete(last) and cached(last, 'src/loader.lua') then
		return last
	end

	return branch
end

boot.branch = branch
boot.repo = repo
boot.dev = dev
boot.root = root
boot.version = resolve()
boot.token = token
boot.fileapi = fileapi
boot.locked = false
boot.fallback = current()

if not boot.fallback or not complete(boot.fallback) or boot.fallback == boot.version then
	boot.fallback = nil
end

boot.validpath = validpath
boot.validsource = validsource

function boot:complete(paths)
	if not fileapi then
		return false
	end

	for _, path in ipairs(paths) do
		if not cached(self.version, path) then
			return false
		end
	end

	local marker = 'complete:'..tostring(self.version)
	local path = cache..'/'..key(self.version)..'/complete.txt'

	if not write(path, marker) then
		return false
	end

	self.completed = read(path) == marker
	return self.completed
end

function boot:promote()
	if fileapi and self.completed then
		folders(cache)
		pcall(writefile, cache..'/current.txt', tostring(self.version))
	end
end

function boot:read(path)
	if not validpath(path) then
		error('invalid import path: '..tostring(path), 2)
	end

	path = path:gsub('\\', '/')

	if self.dev then
		local source = read(self.root..'/'..path)

		if source then
			return source
		end

		error('local file unavailable: '..path, 2)
	end

	local source = cached(self.version, path)

	if source then
		return source
	end

	source = request(self.repo..'/'..self.version..'/'..path)

	if source and (path:sub(-4) ~= '.lua' or loadstring(source, '@fiverosetweaker/cache/'..path)) then
		store(self.version, path, source)
		return source
	end

	if not self.locked and self.version ~= self.branch then
		self.version = self.branch
		source = cached(self.version, path) or request(self.repo..'/'..self.version..'/'..path)

		if source and (path:sub(-4) ~= '.lua' or loadstring(source, '@fiverosetweaker/cache/'..path)) then
			store(self.version, path, source)
			return source
		end
	end

	if not self.locked then
		local last = current()

		if last and complete(last) and last ~= self.version then
			source = cached(last, path)

			if source then
				self.version = last
				return source
			end
		end
	end

	if self.locked and self.fallback and not self.retried then
		self.retry_requested = true
	end

	error('file unavailable: '..path, 2)
end

function boot:load(path)
	local source = self:read(path)
	local chunk, err = loadstring(source, '@fiverosetweaker/'..path)

	if not chunk then
		error(err, 2)
	end

	return chunk()
end

local ok, result = pcall(function()
	if rawget(env, 'fiverosetweaker_boot_token') ~= token then
		error('load cancelled')
	end

	local function execute()
		local loader = boot:load('src/loader.lua')
		boot.locked = true

		if rawget(env, 'fiverosetweaker_boot_token') ~= token then
			error('load cancelled')
		end

		if type(loader) ~= 'function' then
			error('src/loader.lua did not return a loader')
		end

		local success, value = pcall(loader, boot)

		if boot.retry_requested and boot.fallback and not boot.retried then
			local currenttoken = rawget(env, 'fiverosetweaker_boot_token')

			if currenttoken == nil then
				env.fiverosetweaker_boot_token = token
			elseif currenttoken ~= token then
				error('load cancelled')
			end

			boot.version = boot.fallback
			boot.fallback = nil
			boot.retry_requested = false
			boot.retried = true
			boot.locked = true
			return execute()
		end

		if not success then
			error(value)
		end

		return value
	end

	return execute()
end)

if not ok then
	if rawget(env, 'fiverosetweaker_boot_token') == token then
		env.fiverosetweaker_boot_token = nil
	end

	warn('[fiverosetweaker] '..tostring(result))
	return
end

if type(result) == 'table' and result.state == 'loaded' then
	boot:promote()
end

return result
