return function(api)
	local context = api.freestyle
	local toggles = api.toggles
	local world = context.world
	local run = context.run

	local function alive(obj)
		return typeof(obj) == 'Instance' and obj.Parent ~= nil
	end

	local function has(root, wanted)
		if not alive(root) then
			return false
		end

		wanted = wanted:lower()

		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA('TextLabel') or obj:IsA('TextButton') or obj:IsA('TextBox') then
				if tostring(obj.Text):lower() == wanted then
					return true
				end
			end
		end

		return false
	end

	local function findtoggle()
		local ids = {}

		for id in pairs(toggles) do
			ids[#ids + 1] = id
		end

		table.sort(ids, function(a, b)
			return tostring(a) < tostring(b)
		end)

		for _, id in ipairs(ids) do
			local toggle = toggles[id]
			local container = type(toggle) == 'table' and rawget(toggle, 'Container')

			if has(container, 'Enable Prediction') then
				return toggle
			end
		end
	end

	local toggle = findtoggle()
	local started = os.clock()

	while not toggle and os.clock() - started < 2 do
		api:active()
		task.wait(0.2)
		toggle = findtoggle()
	end

	api:active()

	if not toggle then
		warn('[fiverosetweaker] Enable Prediction toggle not found')
		return
	end

	local state = {
		enabled = false,
		connection = nil,
		folder = nil,
		points = {},
		attachments = {},
		beams = {},
		marker = nil,
		accumulator = 0
	}

	local settings = {
		prediction_time = 2,
		path_points = 30,
		update_rate = 60,
		bounce_limit = 0,
		floor_height = context.floor,
		ball_radius = context.radius,
		elasticity = 0.7,
		line_width = 0.15,
		line_color = Color3.fromRGB(255, 50, 50),
		landing_color = Color3.fromRGB(255, 50, 50)
	}

	local function destroy(obj)
		if alive(obj) then
			obj:Destroy()
		end
	end

	local function clear()
		if state.connection then
			state.connection:Disconnect()
			state.connection = nil
		end

		destroy(state.folder)
		state.folder = nil
		state.marker = nil
		state.accumulator = 0
		table.clear(state.points)
		table.clear(state.attachments)
		table.clear(state.beams)
	end

	local function hide()
		for _, beam in ipairs(state.beams) do
			if alive(beam) then
				beam.Enabled = false
			end
		end

		if alive(state.marker) then
			state.marker.Transparency = 1
		end
	end

	local function build()
		if alive(state.folder) and #state.points == settings.path_points then
			return
		end

		destroy(state.folder)

		local stale = world:FindFirstChild('FiveroseBallPredictor')

		if stale and stale ~= state.folder and stale:IsA('Folder') then
			destroy(stale)
		end

		table.clear(state.points)
		table.clear(state.attachments)
		table.clear(state.beams)

		local folder = Instance.new('Folder')
		folder.Name = 'FiveroseBallPredictor'
		folder.Parent = world
		state.folder = folder

		for index = 1, settings.path_points do
			local point = Instance.new('Part')
			point.Name = 'Point'..index
			point.Anchored = true
			point.CanCollide = false
			point.CanTouch = false
			point.CanQuery = false
			point.CastShadow = false
			point.Transparency = 1
			point.Size = Vector3.one * 0.1
			point.Parent = folder

			local attachment = Instance.new('Attachment')
			attachment.Parent = point
			state.points[index] = point
			state.attachments[index] = attachment
		end

		for index = 1, settings.path_points - 1 do
			local beam = Instance.new('Beam')
			beam.Attachment0 = state.attachments[index]
			beam.Attachment1 = state.attachments[index + 1]
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Segments = 2
			beam.Width0 = settings.line_width
			beam.Width1 = settings.line_width
			beam.Color = ColorSequence.new(settings.line_color)
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 0.45)
			})
			beam.Enabled = false
			beam.Parent = state.points[index]
			state.beams[index] = beam
		end

		local marker = Instance.new('Part')
		marker.Name = 'Landing'
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.CastShadow = false
		marker.Shape = Enum.PartType.Cylinder
		marker.Material = Enum.Material.Neon
		marker.Size = Vector3.new(0.08, 3, 3)
		marker.Color = settings.landing_color
		marker.Transparency = 1
		marker.Parent = folder
		state.marker = marker
	end

	local function acceleration(ball)
		local value = Vector3.new(0, -world.Gravity, 0)

		for _, force in ipairs(ball:GetDescendants()) do
			if force:IsA('VectorForce') and force.Enabled then
				local current = force.Force

				if force.RelativeTo == Enum.ActuatorRelativeTo.Attachment0 and force.Attachment0 then
					current = force.Attachment0.WorldCFrame:VectorToWorldSpace(current)
				elseif force.RelativeTo == Enum.ActuatorRelativeTo.Attachment1 and force.Attachment1 then
					current = force.Attachment1.WorldCFrame:VectorToWorldSpace(current)
				end

				value = value + current / math.max(ball.AssemblyMass, 0.001)
			end
		end

		return value
	end

	local function simulate(ball)
		local count = settings.path_points
		local step = math.clamp(settings.prediction_time / math.max(count, 1), 0.005, 0.08)
		local position = ball.Position
		local velocity = ball.AssemblyLinearVelocity
		local force = acceleration(ball)
		local first
		local bounces = 0

		for index = 1, count do
			local oldposition = position
			local oldvelocity = velocity
			velocity = velocity + force * step
			position = position + velocity * step

			if position.Y - settings.ball_radius <= settings.floor_height then
				local oldheight = oldposition.Y - settings.ball_radius
				local newheight = position.Y - settings.ball_radius
				local distance = oldheight - newheight
				local alpha = math.abs(distance) > 0.0001
					and math.clamp((oldheight - settings.floor_height) / distance, 0, 1)
					or 0
				local impact = oldposition:Lerp(position, alpha)
				impact = Vector3.new(impact.X, settings.floor_height + settings.ball_radius, impact.Z)
				first = first or impact

				if bounces < settings.bounce_limit then
					bounces = bounces + 1
					position = impact
					velocity = Vector3.new(oldvelocity.X, -velocity.Y * settings.elasticity, oldvelocity.Z)
				else
					position = impact
					velocity = Vector3.new(velocity.X, 0, velocity.Z)
				end
			end

			if alive(state.points[index]) then
				state.points[index].Position = position
			end
		end

		return first
	end

	local function update()
		build()

		local ball = context:ball()

		if not ball or ball.Position.Y - settings.ball_radius <= settings.floor_height + 1 then
			hide()
			return
		end

		local landing = simulate(ball)

		for _, beam in ipairs(state.beams) do
			if alive(beam) then
				beam.Enabled = true
			end
		end

		if alive(state.marker) then
			if landing then
				state.marker.CFrame = CFrame.new(landing.X, settings.floor_height + 0.03, landing.Z)
					* CFrame.Angles(0, 0, math.rad(90))
				state.marker.Transparency = 0.35
			else
				state.marker.Transparency = 1
			end
		end
	end

	local function set(enabled)
		state.enabled = enabled == true

		if state.connection then
			state.connection:Disconnect()
			state.connection = nil
		end

		state.accumulator = 0

		if not state.enabled then
			clear()
			return
		end

		build()
		update()

		state.connection = run.Heartbeat:Connect(function(delta)
			local interval = 1 / math.max(settings.update_rate, 1)
			state.accumulator = state.accumulator + delta

			if state.accumulator < interval then
				return
			end

			state.accumulator = state.accumulator % interval
			update()
		end)
	end

	local original = rawget(toggle, 'Changed')
	local changed

	api:clean(function()
		state.enabled = false
		clear()

		if changed and rawget(toggle, 'Changed') == changed then
			toggle.Changed = original
		end
	end)

	api:active()
	api:addkey(toggle, 'fiverose_tweaker_ball_predictor_key', 'Ball Predictor', 'None')

	changed = function()
		if api.state ~= 'unloading' and api.state ~= 'unloaded' then
			set(toggle.Value == true)
		end
	end

	local ok, err = pcall(toggle.OnChanged, toggle, changed)

	if not ok then
		error('Ball Predictor bind failed: '..tostring(err))
	end

	changed()

	api.ball = state
	return state
end
