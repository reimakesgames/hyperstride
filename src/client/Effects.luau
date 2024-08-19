local CurrentCamera = workspace.CurrentCamera

local Bullets = {}

local Effects = {}

function Effects:CreateBullet(startPosition: Vector3, endPosition: Vector3, speed: number)
	-- create a part at the start position
	local bullet = Instance.new("Part")
	bullet.Size = Vector3.new(0.1, 0.1, 20)
	bullet.CFrame = CFrame.new(startPosition, endPosition) * CFrame.new(0, 0, -bullet.Size.Z / 2)
	bullet.Anchored = true
	bullet.CanCollide = false
	bullet.CastShadow = false
	bullet.Material = Enum.Material.Neon
	bullet.Color = Color3.fromRGB(255, 191, 127)
	bullet.Parent = workspace

	-- add the bullet to the list
	local bulletObject = {
		Part = bullet,
		StartPosition = startPosition,
		EndPosition = endPosition,
		Speed = speed,
	}

	task.defer(function()
		table.insert(Bullets, bulletObject)
	end)
end

function Effects:Update(deltaTime)
	for i, bulletObject in ipairs(Bullets) do
		local bullet = bulletObject.Part
		local startPosition = bulletObject.StartPosition
		local endPosition = bulletObject.EndPosition
		local speed = bulletObject.Speed

		local direction = (endPosition - startPosition).Unit
		local distance = (endPosition - bullet.Position).Magnitude

		local velocity = direction * speed
		local newPosition = bullet.Position + velocity * deltaTime

		-- make width of the bullet increase as it gets farther away from the camera
		local distanceFromCamera = (bullet.Position - CurrentCamera.CFrame.Position).Magnitude
		local width = 0.1 + distanceFromCamera / 200
		bullet.Size = Vector3.new(width, width, deltaTime * speed * 2)

		if (distance <= speed * deltaTime) then
			bullet:Destroy()
			table.remove(Bullets, i)
		else
			bullet.Position = newPosition
		end
	end
end

return Effects
