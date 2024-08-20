local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local CurrentCamera = workspace.CurrentCamera

local Bullets = {}

local Effects = {}

function Effects:CreateBullet(startPosition: Vector3, endPosition: Vector3, speed: number)
	local bullet = Assets.Bullet:Clone()
	bullet.CFrame = CFrame.new(startPosition, endPosition)
	bullet.Parent = CurrentCamera

	local bulletObject = {
		Part = bullet,
		StartPosition = startPosition,
		EndPosition = endPosition,
		Speed = speed,
	}

	local durationOfBullet = (endPosition - startPosition).Magnitude / speed
	local tweenInfo = TweenInfo.new(durationOfBullet, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local tween = TweenService:Create(bullet.Beam, tweenInfo, {
		Brightness = 0,
	})
	tween:Play()

	task.defer(function()
		table.insert(Bullets, bulletObject)
	end)
end

function Effects:EmitParticles(particleEmitter: ParticleEmitter)
	particleEmitter:Emit(1)
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
		local width = 0.2 + distanceFromCamera / 200
		bullet.Beam.Width0 = width

		if (distance <= speed * deltaTime) then
			bullet:Destroy()
			table.remove(Bullets, i)
		else
			bullet.CFrame = CFrame.lookAlong(newPosition, newPosition + direction, CurrentCamera.CFrame.UpVector)
			bullet.Tail.WorldPosition = startPosition
		end
	end
end

return Effects
