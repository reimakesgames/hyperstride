local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local goodsignal = require(ReplicatedStorage.Packages.goodsignal)
local Effects = require(script.Parent.Effects)
local Viewmodel = require(script.Parent.Viewmodel)

local RemoteEvents = ReplicatedStorage:WaitForChild("Events")

local FireRemoteEvent = RemoteEvents:WaitForChild("Fire")
local DamageRemoteEvent = RemoteEvents:WaitForChild("Damage")

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

Weapon.Equipped = goodsignal.new()
Weapon.Unequipped = goodsignal.new()

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

	while (self.Shooting and not self.Tool.Parent:IsA("Backpack")) do
		-- shoot
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {self.Tool.Parent, Players.LocalPlayer.Character}
		raycastParams.IgnoreWater = true

		local result = workspace:Raycast(CurrentCamera.CFrame.Position, CurrentCamera.CFrame.LookVector * 1024, raycastParams)
		local endPosition = result and result.Position or CurrentCamera.CFrame.Position + CurrentCamera.CFrame.LookVector * 1024

		self.Viewmodel:Fire()
		Effects:CreateBullet(self.Viewmodel.Viewmodel.default.Muzzle.WorldPosition, endPosition, 2048)
		Effects:EmitParticles(self.Viewmodel.Viewmodel.default.Muzzle.Flash)
		Effects:EmitParticles(self.Viewmodel.Viewmodel.default.Muzzle.Smoke)
		PlaySound(self.Viewmodel.Viewmodel.default.Muzzle.Fire, 0.2, 1, 0.1)

		local hitPlayer = result and result.Instance.Parent
		while (hitPlayer and not hitPlayer:IsA("Model") and hitPlayer.Parent ~= workspace) do
			hitPlayer = hitPlayer.Parent
		end
		if (hitPlayer and hitPlayer:IsA("Model") and not hitPlayer:IsA("Terrain")) then
			local humanoid = hitPlayer:FindFirstChildOfClass("Humanoid")
			if (humanoid) then
				humanoid:TakeDamage(14)
			end

			DamageRemoteEvent:FireServer(hitPlayer, 14)
		end

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
	self.Viewmodel = Viewmodel.new("v" .. tool.Name)
	self.Tool.Equipped:Connect(function()
		self.Viewmodel:Equip()
		self.Equipped:Fire(self)
	end)
	self.Tool.Unequipped:Connect(function()
		self.Viewmodel:Unequip()
		self.Unequipped:Fire(self)
	end)
	-- RunService:BindToRenderStep("HYPERSTRIDE_ViewmodelUpdate", Enum.RenderPriority.Last.Value, function(deltaTime)
	-- 	self.Viewmodel:Update(deltaTime)
	-- end)

	WeaponsList[tool] = self

	return self
end

FireRemoteEvent.OnClientEvent:Connect(function(startPosition, endPosition, speed)
	Effects:CreateBullet(startPosition, endPosition, speed)

	local sound = ReplicatedStorage.Fire:Clone()
	-- new part
	local soundPart = Instance.new("Part")
	soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
	soundPart.Position = startPosition
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Transparency = 1
	soundPart.Parent = workspace
	sound.Parent = soundPart
	PlaySound(sound, 1, 1, 0.1)
	Debris:AddItem(soundPart, sound.TimeLength + 1)
end)

return Weapon
