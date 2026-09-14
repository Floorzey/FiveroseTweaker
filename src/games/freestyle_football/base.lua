return function(api, entry)
	local status = api:import('src/games/shared/base.lua')
	status(api, entry)

	local players = game:GetService('Players')
	local storage = game:GetService('ReplicatedStorage')
	local run = game:GetService('RunService')
	local player = players.LocalPlayer
	local world = workspace
	local context = {
		players = players,
		storage = storage,
		run = run,
		player = player,
		world = world,
		floor = 9.6,
		radius = 1
	}

	function context:knit()
		if self._knit then
			return self._knit
		end

		local packages = storage:FindFirstChild('Packages')
		local module = packages and packages:FindFirstChild('Knit')

		if not module then
			return
		end

		local ok, knit = pcall(require, module)

		if not ok or not knit then
			return
		end

		pcall(function()
			local started = knit.OnStart and knit.OnStart()

			if started and started.await then
				started:await()
			end
		end)

		if type(api.isactive) == 'function' and not api:isactive() then
			return
		end

		self._knit = knit
		return knit
	end

	function context:stamina()
		local character = player.Character
		local stats = character and character:FindFirstChild('Stats')

		return stats and stats:FindFirstChild('Stamina')
	end

	function context:ball()
		local temp = world:FindFirstChild('Temp')
		local ball = temp and temp:FindFirstChild('Ball')

		if not ball or not ball:IsA('BasePart') then
			ball = world:FindFirstChild('Ball')
		end

		if ball and ball:IsA('BasePart') then
			return ball
		end
	end

	api.freestyle = context
	return context
end
