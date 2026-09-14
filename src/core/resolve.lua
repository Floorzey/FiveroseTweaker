local function copy(value, seen)
	if type(value) ~= 'table' then
		return value
	end

	seen = seen or {}

	if seen[value] then
		return seen[value]
	end

	local result = {}
	seen[value] = result

	for key, item in pairs(value) do
		result[copy(key, seen)] = copy(item, seen)
	end

	return result
end

local function id(value, label)
	local number = tonumber(value)

	if not number or number < 1 or number % 1 ~= 0 then
		error('invalid '..label..' id', 3)
	end

	return number
end

local function lookup(value)
	local number = tonumber(value)

	if not number or number < 1 or number % 1 ~= 0 then
		return
	end

	return number
end

return function(api, registry)
	if type(registry) ~= 'table' then
		error('invalid registry', 2)
	end

	if type(registry.families) ~= 'table' then
		error('invalid registry families', 2)
	end

	local places = {}
	local games = {}

	local function add(map, route, label)
		if type(route) ~= 'table' then
			error('invalid '..label..' route', 3)
		end

		local number = id(route.id, label)
		local family = registry.families[route.family]

		if not family then
			error('unknown family '..tostring(route.family), 3)
		end

		if map[number] then
			error('duplicate '..label..' id '..number, 3)
		end

		map[number] = {
			family = route.family,
			route = route
		}
	end

	for _, route in ipairs(registry.places or {}) do
		add(places, route, 'place')
	end

	for _, route in ipairs(registry.games or {}) do
		add(games, route, 'game')
	end

	for _, entry in pairs(places) do
		if entry.route.alias then
			local target = places[id(entry.route.alias, 'alias')]

			if not target then
				error('unknown place alias '..entry.route.alias, 2)
			end

			if target.family ~= entry.family then
				error('place alias family mismatch '..entry.route.alias, 2)
			end
		end
	end

	local resolver = {}

	function resolver:resolve(placeid, gameid)
		local place = lookup(placeid)
		local game = lookup(gameid)

		if (place and registry.blocked_places and registry.blocked_places[place])
			or (game and registry.blocked_games and registry.blocked_games[game]) then

			return
		end

		local entry = places[place]
		local match = 'place'

		if not entry then
			entry = games[game]
			match = 'game'
		end

		if not entry then
			local familyid = registry.fallback
			local family = familyid and registry.families[familyid]

			if not family then
				return
			end

			local route = {
				id = place or 1,
				name = family.name,
				variant = 'universal'
			}

			return {
				id = route.id,
				name = family.name,
				family_id = familyid,
				family = copy(family),
				match = 'universal',
				route = route,
				variant = route.variant
			}
		end

		local route = copy(entry.route)
		local family = copy(registry.families[entry.family])

		return {
			id = route.id,
			name = route.name or family.name,
			family_id = entry.family,
			family = family,
			match = match,
			route = route,
			alias = route.alias,
			variant = route.variant,
			standalone = route.standalone
		}
	end

	return resolver
end
