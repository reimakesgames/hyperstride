local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Effects = require(script.Parent.Effects)

local RemoteEvents = ReplicatedStorage:WaitForChild("Events")

local FireRemoteEvent = RemoteEvents:WaitForChild("Fire")

local CurrentCamera = workspace.CurrentCamera

local function Eerp(a: number, b: number, t: number): number
	return a * math.exp(t * math.log(b / a))
end

local function PlaySound(sound: Sound, volume: number, pitch: number, pitchRange: number)
	-- duplicate the sound
	local newSound = sound:Clone()
	Debris:AddItem(newSound, newSound.TimeLength + 1)
	newSound.Parent = sound.Parent or workspace
	newSound:Play()
	newSound.Volume = volume
	newSound.PlaybackSpeed = Eerp(-pitchRange + pitch, pitchRange + pitch, math.random())
end

local WeaponsList = {}

local Weapon = {}
Weapon.__index = Weapon

function Weapon.new()
	local self = setmetatable({}, Weapon)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if (gameProcessed) then return end

		if (input.UserInputType == Enum.UserInputType.MouseButton1) then
			self:Fire()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1) then
			self.Shooting = false
		end
	end)

	return self
end

function Weapon:Fire()
	if (not self.Tool) then return end
	if (self.Shooting) then return end
	if (self.Tool.Parent:IsA("Backpack")) then return end

	self.Shooting = true

	while (self.Shooting) do
		-- shoot
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {self.Tool.Parent}
		raycastParams.IgnoreWater = true

		local result = workspace:Raycast(CurrentCamera.CFrame.Position, CurrentCamera.CFrame.LookVector * 1024, raycastParams)
		local endPosition = result and result.Position or CurrentCamera.CFrame.Position + CurrentCamera.CFrame.LookVector * 1024

		Effects:CreateBullet(self.Tool.default.Muzzle.WorldPosition, endPosition, 1024)
		PlaySound(self.Tool.default.Muzzle.Fire, 1, 1, 0.1)

		FireRemoteEvent:FireServer(CurrentCamera.CFrame.Position, endPosition, 1024)

		task.wait(60 / self.RoundsPerMinute)
	end
end

function Weapon.newFromTool(tool)
	if (WeaponsList[tool]) then
		return WeaponsList[tool]
	end

	local self = Weapon.new()
	self.Tool = tool
	self.Shooting = false
	self.RoundsPerMinute = 1200

	WeaponsList[tool] = self

	return self
end

return Weapon
