local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Camera = require(script.Parent.Camera)
local Character = require(script.Parent.Character)
local SmoothDamp = require(script.Parent.SmoothDamp)
local Spring = require(script.Parent.Spring)

local CurrentCamera = workspace.CurrentCamera
local CurrentCharacter = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()

for _, child in ipairs(CurrentCharacter:GetDescendants()) do
	if (child:IsA("BasePart")) then
		child.Massless = true
		child.LocalTransparencyModifier = 1
	end
end
CurrentCharacter.DescendantAdded:Connect(function(child)
	if (child:IsA("BasePart")) then
		child.Massless = true
		child.LocalTransparencyModifier = 1
	end
end)

local SoundsFolder = StarterGui:WaitForChild("Sounds")

local JumpSpring = Spring.new(0.075, 20)
local WalkSpring = Spring.new(0.05, 10)

local LeanDamper = SmoothDamp.new()

local FieldOfViewResponsiveness = 10
local NormalFieldOfView = 70
local SlideFieldOfView = 75

local AttackDamping = 0.5
local DecayDamping = 0.3
local WalkStrength = 0.03
local SlideStrength = 0.1
local StrengthResponse = 5

local AngularDisplacement = -1
local LinearDisplacement = 0.1

local DampedAcceleration = Vector3.new()
local SmoothStrength = WalkStrength

local CAMERA_OFFSET_FROM_ROOT = Vector3.new(0, 1.5, 0)

local function Eerp(a: number, b: number, t: number): number
	return a * math.exp(t * math.log(b / a))
end

local function PlaySound(sound: Sound, volume: number, pitch: number, pitchRange: number)
	sound:Play()
	sound.Volume = volume
	sound.PlaybackSpeed = Eerp(-pitchRange + pitch, pitchRange + pitch, math.random())
end

local function GetMovementVector2()
	local Movement = Vector2.new()
	if (UserInputService:IsKeyDown(Enum.KeyCode.W)) then
		Movement = Movement + Vector2.new(0, 1)
	end
	if (UserInputService:IsKeyDown(Enum.KeyCode.A)) then
		Movement = Movement + Vector2.new(-1, 0)
	end
	if (UserInputService:IsKeyDown(Enum.KeyCode.S)) then
		Movement = Movement + Vector2.new(0, -1)
	end
	if (UserInputService:IsKeyDown(Enum.KeyCode.D)) then
		Movement = Movement + Vector2.new(1, 0)
	end
	return Movement
end

local function ProjectOnPlane(v: Vector3, n: Vector3): Vector3
	return v - v:Dot(n) * n
end

local function Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local Inputs = {}
UserInputService.InputBegan:Connect(function(input)
	Inputs[input.KeyCode] = true
end)

function Update(deltaTime)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	CurrentCamera.CameraType = Enum.CameraType.Scriptable


	if (CurrentCharacter) then
		Character:BeforeCharacterUpdate()

		Camera:UpdateRotation(deltaTime)

		local Crouch = if Inputs[Enum.KeyCode.LeftControl] then Character.CrouchInput.Toggle else Character.CrouchInput.None
		local Input: Character.CharacterInput = {
			Rotation = Camera:GetCameraCFrame().Rotation,
			Movement = GetMovementVector2(),
			Jump = Inputs[Enum.KeyCode.Space],
			JumpSustain = UserInputService:IsKeyDown(Enum.KeyCode.Space),
			Crouch = Crouch,
		}
		Character:UpdateInput(Input)
		Character:UpdateBody(deltaTime)

		Character:AfterCharacterUpdate()
	end

	for key, _ in pairs(Inputs) do
		-- turn off the key
		Inputs[key] = nil
	end
end

function LateUpdate(deltaTime)
	local RootCFrame: CFrame = CurrentCharacter:WaitForChild("HumanoidRootPart").CFrame
	Camera:UpdatePosition(RootCFrame.Position + CAMERA_OFFSET_FROM_ROOT)

	local characterState = Character:GetState()

	local PlanarAcceleration = ProjectOnPlane(characterState.Acceleration, Vector3.yAxis)
	local Damping = if PlanarAcceleration.Magnitude > DampedAcceleration.Magnitude then AttackDamping else DecayDamping
	DampedAcceleration = LeanDamper:Update(DampedAcceleration, PlanarAcceleration, Damping)
	local LeanAxis = DampedAcceleration:Cross(Vector3.yAxis).Unit
	local EffectiveStrength = characterState.Stance == Character.Stance.Slide and SlideStrength or WalkStrength
	SmoothStrength = Lerp(SmoothStrength, EffectiveStrength, 1 - math.exp(-StrengthResponse * deltaTime))

	local LeanCFrame = CFrame.fromAxisAngle(LeanAxis, math.rad(-DampedAcceleration.Magnitude * SmoothStrength))
	* Camera:GetCameraCFrame().Rotation

	JumpSpring:Step(RootCFrame.Position, deltaTime)

	local LocalSpringPosition = JumpSpring._current - RootCFrame.Position
	local SpringHeight = LocalSpringPosition:Dot(RootCFrame.UpVector)

	local JumpCFrame = CFrame.fromEulerAnglesYXZ(math.rad(-SpringHeight * AngularDisplacement), 0, 0)

	local WalkSpeed = characterState.Velocity.Magnitude / 50
	local PlaybackSpeed = Eerp(1, 4, characterState.Velocity.Magnitude / 100)
	local EffectiveWalkSpeed = (characterState.Grounded and characterState.Stance ~= Character.Stance.Slide) and 1 or 0

	local XSine = math.sin(SoundsFolder.Footsteps.TimePosition * math.pi * 2 * (62 / 60) * PlaybackSpeed)
	local YSine = math.sin(SoundsFolder.Footsteps.TimePosition * math.pi * (62 / 60) * PlaybackSpeed)

	WalkSpring:Step(Vector3.new(XSine, YSine, 0) * EffectiveWalkSpeed * math.clamp(WalkSpeed, 0, 1), deltaTime)

	local WalkCFrame = CFrame.fromEulerAnglesYXZ(math.rad(WalkSpring._current.X * AngularDisplacement), math.rad(WalkSpring._current.Y * AngularDisplacement), 0)

	local CameraCFrame = CFrame.new(LocalSpringPosition * LinearDisplacement)
	* CFrame.new(Camera:GetCameraCFrame().Position)
	* WalkCFrame
	* LeanCFrame
	* JumpCFrame

	Camera:UpdateCustomCFrame(CameraCFrame)

	SoundsFolder.Wind.Volume = math.clamp((characterState.Velocity.Magnitude / 500) - 0.1, 0, 0.5)
	SoundsFolder.Wind.PlaybackSpeed = Eerp(0.5, 4, characterState.Velocity.Magnitude / 500)

	local effectiveFootstepVolume = (characterState.Grounded and characterState.Stance ~= Character.Stance.Slide) and 1 or 0
	SoundsFolder.Footsteps.Volume = effectiveFootstepVolume * math.clamp(WalkSpeed, 0, 1) * 2
	SoundsFolder.Footsteps.PlaybackSpeed = PlaybackSpeed

	local effectiveFieldOfView = characterState.Stance == Character.Stance.Slide and SlideFieldOfView or NormalFieldOfView
	effectiveFieldOfView += characterState.Velocity.Magnitude / 20
	CurrentCamera.FieldOfView = Lerp(CurrentCamera.FieldOfView, effectiveFieldOfView, 1 - math.exp(-FieldOfViewResponsiveness * deltaTime))
end

function Step(deltaTime)
	Character:UpdateVelocity(deltaTime)
	Character:UpdateRotation()
end

function onStateChanged(state: Character.CharacterState)
end

function onJump()
	PlaySound(SoundsFolder.Jump, 0.2, 1.5, 0.2)
end

function onLand(landingVelocity: number)
	local characterState = Character:GetState()
	-- sliding doesn't trigger hard landing sounds
	if (landingVelocity > 150 and not (characterState.Stance == Character.Stance.Crouch)) then
		PlaySound(SoundsFolder.Land, 0.6, 1.5, 0.1)
		PlaySound(SoundsFolder.LandBig, 0.3, 1, 0.1)
	else
		PlaySound(SoundsFolder.Land, 0.3, 1, 0.1)
	end
end

function onStand()
	TweenService:Create(SoundsFolder.Slide, TweenInfo.new(0.1), {Volume = 0}):Play()
end

function onCrouch()
end

function onSlideStart()
	PlaySound(SoundsFolder.Slide, 1, 1, 0.1)
	PlaySound(SoundsFolder.SlideStart, 0.5, 3, 0.1)
	SoundsFolder.Slide.TimePosition = 1.1
end

function onSlideEnd()
	TweenService:Create(SoundsFolder.Slide, TweenInfo.new(0.1), {Volume = 0}):Play()
end

function onSlideInterrupt()
	TweenService:Create(SoundsFolder.Slide, TweenInfo.new(0.1), {Volume = 0}):Play()
end

RunService:BindToRenderStep("HYPERZTRIDE_Update", Enum.RenderPriority.Input.Value, Update)
RunService:BindToRenderStep("HYPERZTRIDE_LateUpdate", Enum.RenderPriority.Camera.Value, LateUpdate)
RunService.RenderStepped:Connect(Step)

Character.StateChanged:Connect(onStateChanged)
Character.Jump:Connect(onJump)
Character.Land:Connect(onLand)
Character.Stand:Connect(onStand)
Character.Crouch:Connect(onCrouch)
Character.SlideStarted:Connect(onSlideStart)
Character.SlideEnded:Connect(onSlideEnd)
Character.SlideInterrupt:Connect(onSlideInterrupt)

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	CurrentCharacter = character

	for _, child in ipairs(character:GetDescendants()) do
		if (child:IsA("BasePart")) then
			child.Massless = true
			child.LocalTransparencyModifier = 1
		end
	end
	character.DescendantAdded:Connect(function(child)
		if (child:IsA("BasePart")) then
			child.Massless = true
			child.LocalTransparencyModifier = 1
		end
	end)
end)
