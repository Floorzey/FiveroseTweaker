local shared = {
	'src/modules/shared/keybinds.lua',
	'src/modules/shared/gui_bind.lua',
	'src/modules/shared/vape_mode.lua'
}

local files = {
	'src/vape/api.lua',
	'src/vape/games/universal.lua',
	'src/vape/games/arena.lua',
	'src/vape/games/blockwars.lua',
	'src/vape/games/flee.lua',
	'src/vape/games/bedwars_lobby.lua',
	'src/vape/games/bedwars.lua',
	'src/vape/games/blocktales.lua',
	'src/vape/games/bridge.lua',
	'src/vape/games/frontlines.lua',
	'src/vape/games/jailbreak.lua',
	'src/vape/games/prison.lua',
	'src/vape/games/redliner.lua',
	'src/vape/games/skywars.lua',
	'src/vape/games/skywars_lobby.lua',
	'src/vape/libraries/entity.lua',
	'src/vape/libraries/prediction.lua',
	'src/vape/libraries/hash.lua',
	'src/vape/libraries/vm.lua',
	'src/vape/libraries/drawing.lua',
	'src/vape/libraries/getvapeasset.lua'
}

local registry = {
	shared = shared,
	files = files,
	fallback = 'universal',
	families = {},
	places = {},
	games = {},
	upstream = {
		repo = '7GrandDadPGN/VapeV4ForRoblox',
		commit = '4204f30808488572ea36729e56b1032eaae66de0',
		version = '4.22'
	}
}

local function family(id, name, bundle, count, base, native)
	registry.families[id] = {
		name = name,
		base = base or 'src/games/shared/base.lua',
		modules = {},
		vape = bundle,
		features = count or 0,
		native = native == true
	}
end

local function place(id, familyid, name, variant, alias, standalone)
	registry.places[#registry.places + 1] = {
		id = id,
		family = familyid,
		name = name,
		variant = variant,
		alias = alias,
		standalone = standalone == true
	}
end

local function universe(id, familyid)
	registry.games[#registry.games + 1] = {id = id, family = familyid}
end

family('universal', 'Universal', nil, 69)
family('arena_1_8', '1.8 Arena', 'src/vape/games/arena.lua', 15)
family('blockwars', 'BlockWars', 'src/vape/games/blockwars.lua', 11)
family('flee_the_facility', 'Flee the Facility', 'src/vape/games/flee.lua', 7)
family('bedwars_lobby', 'BedWars Lobby', 'src/vape/games/bedwars_lobby.lua', 2)
family('bedwars', 'BedWars', 'src/vape/games/bedwars.lua', 69)
family('blocktales', 'Block Tales', 'src/vape/games/blocktales.lua', 14)
family('bridge_duel', 'Bridge Duel', 'src/vape/games/bridge.lua', 13)
family('frontlines', 'Frontlines', 'src/vape/games/frontlines.lua', 15)
family('jailbreak', 'Jailbreak', 'src/vape/games/jailbreak.lua', 24)
family('prison_life', 'Prison Life', 'src/vape/games/prison.lua', 35)
family('redliner', 'Redliner', 'src/vape/games/redliner.lua', 12)
family('skywars_voxel', 'SkyWars Voxel', 'src/vape/games/skywars.lua', 16)
family('skywars_lobby', 'SkyWars Voxel Lobby', 'src/vape/games/skywars_lobby.lua', 1)
family('freestyle_football', 'Freestyle Football', nil, 2, 'src/games/freestyle_football/base.lua', true)

registry.families.freestyle_football.profile = 15133985014
registry.families.freestyle_football.modules = {
	'src/modules/freestyle_football/stamina.lua',
	'src/modules/freestyle_football/ball.lua'
}

place(77790193039862, 'arena_1_8', '1.8 Arena', 'game')
place(80041634734121, 'arena_1_8', '1.8 Arena Duel', 'duel', 77790193039862)
place(132768098780837, 'blockwars', 'BlockWars', 'game')
place(893973440, 'flee_the_facility', 'Flee the Facility', 'main')
place(6872265039, 'bedwars_lobby', 'BedWars Lobby', 'lobby')
place(6872274481, 'bedwars', 'BedWars', 'game')
place(8444591321, 'bedwars', 'BedWars Mega', 'mega', 6872274481)
place(8560631822, 'bedwars', 'BedWars Micro', 'micro', 6872274481)
place(16483433878, 'blocktales', 'Block Tales', 'main')
place(106431012459431, 'blocktales', 'Block Tales Battle Simulator', 'battle_sim', 16483433878)
place(139566161526375, 'bridge_duel', 'Bridge Duel', 'game')
place(5938036553, 'frontlines', 'Frontlines', 'game')
place(123804558118054, 'frontlines', 'Frontlines Versus', 'versus', 5938036553)
place(131465939650733, 'frontlines', 'Frontlines Versus FFA', 'versus_ffa', 5938036553)
place(83413351472244, 'frontlines', 'Frontlines Versus FFA 2', 'versus_ffa_2', 5938036553)
place(606849621, 'jailbreak', 'Jailbreak', 'main')
place(17190407811, 'jailbreak', 'Jailbreak VC Servers', 'vc', 606849621)
place(155615604, 'prison_life', 'Prison Life', 'main')
place(135564683255158, 'prison_life', 'Prison Life VC', 'vc', 155615604)
place(115875349872417, 'redliner', 'Redliner', 'game')
place(126691165749976, 'redliner', 'Redliner 1v1', '1v1', 115875349872417)
place(94987506187454, 'redliner', 'Redliner Lobby', 'lobby', 115875349872417)
place(8768229691, 'skywars_voxel', 'SkyWars', 'game')
place(8542259458, 'skywars_lobby', 'SkyWars Lobby', 'lobby', nil, true)
place(8542275097, 'skywars_voxel', 'SkyWars Solo', 'solo', 8768229691)
place(8592115909, 'skywars_voxel', 'SkyWars Duos', 'duos', 8768229691)
place(8951451142, 'skywars_voxel', 'SkyWars Egg Squad', 'egg_squad', 8768229691)
place(13246639586, 'skywars_voxel', 'SkyWars Bridge', 'bridge', 8768229691)
place(15133985014, 'freestyle_football', 'Freestyle Football', 'main')
place(18124732355, 'freestyle_football', 'Freestyle Football', 'alternate_1')
place(18935841239, 'freestyle_football', 'Freestyle Football', 'alternate_2')
place(18972674759, 'freestyle_football', 'Freestyle Football', 'alternate_3')
place(78336452877060, 'freestyle_football', 'Freestyle Football', 'alternate_4')

universe(9984669476, 'arena_1_8')
universe(372226183, 'flee_the_facility')
universe(2619619496, 'bedwars')
universe(5678284602, 'blocktales')
universe(8907796617, 'blocktales')
universe(9137416017, 'bridge_duel')
universe(2132866904, 'frontlines')
universe(7521877734, 'frontlines')
universe(245662005, 'jailbreak')
universe(73885730, 'prison_life')
universe(7265339759, 'redliner')
universe(3258873704, 'skywars_voxel')
universe(5215846239, 'freestyle_football')

return registry
