local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = require(script.Parent.Camera)
local Spring = require(script.Parent.Spring)
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Viewmodels = Assets:WaitForChild("Viewmodels")

local CurrentCamera = workspace.CurrentCamera

local Viewmodel = {}
Viewmodel.__index = Viewmodel

function Viewmodel.new(toolName: string)
	local self = setmetatable({}, Viewmodel)
	self.Viewmodel = Viewmodels:FindFirstChild(toolName):Clone()
	self.Equipped = false
	self.Animations = {}
	self._animationsLoaded = false
	self.RecoilSpring = Spring.new(0.1, 10)

	local animationController = self.Viewmodel:FindFirstChild("AnimationController")
	if (not animationController) then
		animationController = Instance.new("AnimationController")
		animationController.Parent = self.Viewmodel
	end

	return self
end

function Viewmodel:Update(deltaTime)
	if (not self.Viewmodel) then return end

	self.RecoilSpring:Step(Vector3.zero, deltaTime)

	local cameraCFrame = self.Viewmodel:FindFirstChild("Camera").CFrame
	cameraCFrame = self.Viewmodel.PrimaryPart.CFrame:ToObjectSpace(cameraCFrame)
	cameraCFrame = CurrentCamera.CFrame:ToWorldSpace(cameraCFrame)

	cameraCFrame = cameraCFrame * CFrame.Angles(self.RecoilSpring._current.X, 0, 0)
	Camera:UpdateCustomCFrame(cameraCFrame)

	local viewmodelCFrame = if self.Equipped then CurrentCamera.CFrame else CFrame.new(0, 0, 0)
	viewmodelCFrame = viewmodelCFrame * CFrame.new(0, 0, self.RecoilSpring._current.X * 5)
	viewmodelCFrame = viewmodelCFrame * CFrame.Angles(self.RecoilSpring._current.X / 10, 0, 0)
	self.Viewmodel:SetPrimaryPartCFrame(viewmodelCFrame)
end

function Viewmodel:SetCFrame(cframe: CFrame)
	self.Viewmodel:SetPrimaryPartCFrame(self.Viewmodel.PrimaryPart.CFrame * cframe)
end

function Viewmodel:GetCFrame()
	return self.Viewmodel.PrimaryPart.CFrame
end

function Viewmodel:Fire()
	if (not self.Equipped) then return end

	self.RecoilSpring:Impulse(Vector3.new(0.5, 0, 0))
end

function Viewmodel:Equip()
	if (self.Equipped) then return end

	self.Viewmodel.Parent = CurrentCamera

	if (not self._animationsLoaded) then
		self:LoadAnimations(self.Viewmodel:FindFirstChild("Animations"))
		self._animationsLoaded = true
	end

	self.Animations.Equip:Play(0.001, 1, 1)
	self.Animations.Idle:Play(1, 1, 1)
	self.Viewmodel:SetPrimaryPartCFrame(CurrentCamera.CFrame)
	self.Equipped = true
end

function Viewmodel:Unequip()
	if (not self.Equipped) then return end

	self.Equipped = false
	self.Animations.Equip:Play(0.001, 1, 0.0000001)

	self.Viewmodel:SetPrimaryPartCFrame(CFrame.new(0, 0, 0))
end

function Viewmodel:LoadAnimations(animations: Folder)
	local animationController = self.Viewmodel:FindFirstChild("AnimationController")
	local animator = animationController:WaitForChild("Animator")

	for _, animation in ipairs(animations:GetChildren()) do
		local animationTrack = animator:LoadAnimation(animation)
		self.Animations[animation.Name] = animationTrack
	end
end

return Viewmodel
