local env = getgenv()
local branch = tostring(env.fiverosetweaker_branch or 'main')
local repo = tostring(env.fiverosetweaker_repo or 'https://raw.githubusercontent.com/Floorzey/FiveroseTweaker')
local dev = env.fiverosetweaker_dev == true
local root = tostring(env.fiverosetweaker_path or 'FiveroseTweaker')
local source

repo = repo:gsub('/+$', '')
root = root:gsub('[\\/]+$', '')

if dev and type(readfile) == 'function' then
	local ok, body = pcall(readfile, root..'/main.lua')

	if ok then
		source = body
	end
end

if not source then
	local ok, body = pcall(function()
		return game:HttpGet(repo..'/'..branch..'/main.lua', true)
	end)

	if ok then
		source = body
	end
end

if type(source) ~= 'string' or not source:match('%S') then
	return warn('[fiverosetweaker] main.lua unavailable')
end

local chunk, err = loadstring(source, '@fiverosetweaker/main.lua')

if not chunk then
	return warn('[fiverosetweaker] '..tostring(err))
end

return chunk()
