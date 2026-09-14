local module = {}

function module.valid(path)
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

function module.setup(api)
	local loaded = {}
	local none = {}

	function api:import(path)
		if not module.valid(path) then
			error('invalid import path: '..tostring(path), 2)
		end

		path = path:gsub('\\', '/')

		if loaded[path] ~= nil then
			return loaded[path] == none and nil or loaded[path]
		end

		local source = self:source(path)
		local chunk, err = loadstring(source, '@fiverosetweaker/'..path)

		if not chunk then
			error(err, 2)
		end

		local ok, result = xpcall(chunk, function(value)
			local trace = debug and debug.traceback
			return type(trace) == 'function' and trace(tostring(value), 2) or tostring(value)
		end)

		if not ok then
			error(path..': '..tostring(result), 2)
		end

		loaded[path] = result == nil and none or result
		return result
	end

	api.imports = loaded
	return api
end

return module
