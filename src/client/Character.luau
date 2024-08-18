local Players = game:GetService("Players")

local CurrentCharacter = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
task.delay(1, function()
	for _, child in ipairs(CurrentCharacter:GetDescendants()) do
		if (child:IsA("BasePart")) then
			child.Massless = true
			child.LocalTransparencyModifier = 1
		end
	end
end)

local IsCollidersReady = false
local IsSupposedToBeStuckToGround = true

local BOTTOM_COLLIDER_OFFSET = Vector3.new(0, -1.5, 0)
local TOP_COLLIDER_OFFSET = Vector3.new(0, 1.5, 0)

local WALK_SPEED = 50
local CROUCH_SPEED = 20
local WALK_RESPONSE = 25
local CROUCH_RESPONSE = 20

local AIR_SPEED = 40
local AIR_ACCELERATION = 200

local SLIDE_START_SPEED = 70
local SLIDE_END_SPEED = 20
local SLIDE_FRICTION = 0.8
local SLIDE_STEER_ACCELERATION = 50
local SLIDE_GRAVITY = -200

local JUMP_FORCE = 50
local JUMP_SUSTAIN_GRAVITY = 0.5
local GRAVITY = -200

local STAND_HEIGHT = 0
local CROUCH_HEIGHT = -1.5
local CROUCH_HEIGHT_RESPONSE = 15

local CurrentVelocity = Vector3.new()

local RequestedRotation = CFrame.new()
local RequestedMovement = Vector3.new()
local RequestedJump = false
local RequestedJumpSustain = false
local RequestedCrouch = false

local NormalDisplay = Instance.new("Part")
NormalDisplay.Anchored = true
NormalDisplay.Size = Vector3.new(1, 1, 1)
NormalDisplay.Transparency = 0.5
NormalDisplay.CanCollide = false
NormalDisplay.CanQuery = false
NormalDisplay.Parent = workspace
local MoveVelocityDisplay = Instance.new("Part")
MoveVelocityDisplay.Anchored = true
MoveVelocityDisplay.Size = Vector3.new(0.125, 0.125, 5)
MoveVelocityDisplay.Material = Enum.Material.Neon
MoveVelocityDisplay.CanCollide = false
MoveVelocityDisplay.CanQuery = false
MoveVelocityDisplay.Parent = workspace

local function CreateColliders(root: Part)
	local Bottom = Instance.new("Part")
	Bottom.Size = Vector3.new(3, 3, 3)
	Bottom.Shape = Enum.PartType.Ball
	Bottom.Massless = true
	Bottom.CanCollide = false
	Bottom.Transparency = 1
	Bottom.Name = "Bottom"

	local Top = Instance.new("Part")
	Top.Size = Vector3.new(3, 3, 3)
	Top.Shape = Enum.PartType.Ball
	Top.Massless = true
	Top.CanCollide = false
	Top.Transparency = 1
	Top.Name = "Top"

	Bottom.Parent = root
	Top.Parent = root

	Bottom.CFrame = root.CFrame * CFrame.new(BOTTOM_COLLIDER_OFFSET)
	Top.CFrame = root.CFrame * CFrame.new(TOP_COLLIDER_OFFSET)

	-- weld the colliders to the root
	local BottomWeld = Instance.new("WeldConstraint")
	BottomWeld.Parent = Bottom
	BottomWeld.Part0 = root
	BottomWeld.Part1 = Bottom

	local TopWeld = Instance.new("WeldConstraint")
	TopWeld.Parent = Top
	TopWeld.Part0 = root
	TopWeld.Part1 = Top
end

local function ProjectToPlane(v: Vector3, n: Vector3)
	return v - n * (v:Dot(n))
end

local function Lerp(a: number, b: number, t: number)
	return a + (b - a) * t
end

local function ClampMagnitude(v: Vector3, max: number)
	if (v.Magnitude > max) then
		return v.Unit * max
	end
	return v
end

local function CheckGround(): RaycastResult?
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {CurrentCharacter}
	return workspace:Raycast(
		CurrentCharacter.HumanoidRootPart.Position - CurrentCharacter.Humanoid.HipHeight * Vector3.new(0, 1, 0),
		Vector3.new(0, -4, 0),
		Params
	)
end

local Character = {}
Character.__index = Character

Character.CrouchInput = {
	None = 0,
	Toggle = 1,
}
export type CrouchInput = typeof(Character.CrouchInput)

Character.Stance = {
	Stand = 0,
	Crouch = 1,
	Slide = 2,
}
export type Stance = typeof(Character.Stance)

local CharacterState = {
	Grounded = false,
	Stance = Character.Stance.Stand,
}
export type CharacterState = typeof(CharacterState)

local CharacterInput = {
	Rotation = CFrame.new(),
	Movement = Vector2.new(),
	Jump = false,
	JumpSustain = false,
	Crouch = Character.CrouchInput.None,
}
export type CharacterInput = typeof(CharacterInput)

-- local State.Stance = Character.Stance.Stand
local State = CharacterState
local LastState = CharacterState
local TempState = CharacterState

function Character:UpdateBody(deltaTime: number)
	local HipTargetHeight = State.Stance == Character.Stance.Stand and STAND_HEIGHT or CROUCH_HEIGHT

	CurrentCharacter.Humanoid.HipHeight = Lerp(
		CurrentCharacter.Humanoid.HipHeight,
		HipTargetHeight,
		1 - math.exp(-CROUCH_HEIGHT_RESPONSE * deltaTime)
	)
end

function Character:UpdateInput(input: CharacterInput)
	if (not IsCollidersReady) then
		IsCollidersReady = true
		CreateColliders(CurrentCharacter:WaitForChild("HumanoidRootPart"))
	end

	CharacterInput = input
	RequestedRotation = CharacterInput.Rotation
	RequestedMovement = Vector3.new(CharacterInput.Movement.X, 0, -CharacterInput.Movement.Y)
	RequestedMovement = RequestedMovement.Unit
	RequestedMovement = CharacterInput.Rotation * RequestedMovement
	if (CharacterInput.Movement == Vector2.new()) then
		RequestedMovement = Vector3.new()
	end
	RequestedJump = RequestedJump or CharacterInput.Jump
	RequestedJumpSustain = CharacterInput.JumpSustain
	if (CharacterInput.Crouch == Character.CrouchInput.Toggle) then
		RequestedCrouch = not RequestedCrouch
	elseif (CharacterInput.Crouch == Character.CrouchInput.None) then
		RequestedCrouch = RequestedCrouch
	else
		RequestedCrouch = RequestedCrouch
	end
end

function Character:UpdateVelocity(deltaTime)
	local StickResult = CheckGround()
	if (StickResult and IsSupposedToBeStuckToGround) then
		CurrentCharacter.HumanoidRootPart.CFrame = CFrame.new(StickResult.Position + Vector3.new(0, 3 + CurrentCharacter.Humanoid.HipHeight, 0))
		NormalDisplay.CFrame = CFrame.new(StickResult.Position, StickResult.Position + StickResult.Normal)

		local Ground = CheckGround() or {Normal = Vector3.new(0, 1, 0)}
		local GroundedMovement = ProjectToPlane(RequestedMovement, Ground.Normal) * RequestedMovement.Magnitude

		local Moving = GroundedMovement.Magnitude > 0
		local Crouching = State.Stance == Character.Stance.Crouch
		local WasStanding = LastState.Stance == Character.Stance.Stand
		local WasInAir = not LastState.Grounded
		if (Moving and Crouching and (WasStanding or WasInAir)) then
			print("sliding")
			State.Stance = Character.Stance.Slide

			local SlideSpeed = math.max(SLIDE_START_SPEED, CurrentVelocity.Magnitude)
			CurrentVelocity = ProjectToPlane(CurrentVelocity, Ground.Normal).Unit * SlideSpeed
		end

		if (State.Stance == Character.Stance.Stand or State.Stance == Character.Stance.Crouch) then
			local Speed = State.Stance == Character.Stance.Stand and WALK_SPEED or CROUCH_SPEED
			local Response = State.Stance == Character.Stance.Stand and WALK_RESPONSE or CROUCH_RESPONSE
			local TargetVelocity = Vector3.new()
			if (GroundedMovement.Magnitude > 0) then
				TargetVelocity = GroundedMovement * Speed
				MoveVelocityDisplay.CFrame = CFrame.lookAlong(CurrentCharacter.HumanoidRootPart.Position, GroundedMovement)
			end
			CurrentVelocity = CurrentVelocity:Lerp(TargetVelocity, 1 - math.exp(-Response * deltaTime))
		else
			CurrentVelocity -= CurrentVelocity * (SLIDE_FRICTION * deltaTime)

			local Force = ProjectToPlane(-CurrentCharacter.HumanoidRootPart.CFrame.UpVector, Ground.Normal) * SLIDE_GRAVITY

			CurrentVelocity -= Force * deltaTime

			local CurrentSpeed = CurrentVelocity.Magnitude
			local TargetVelocity = GroundedMovement * CurrentSpeed
			local SteerForce = (TargetVelocity - CurrentVelocity) * SLIDE_STEER_ACCELERATION * deltaTime
			CurrentVelocity += SteerForce
			CurrentVelocity = ClampMagnitude(CurrentVelocity, CurrentSpeed)

			if (CurrentVelocity.Magnitude < SLIDE_END_SPEED) then
				print("slide end")
				State.Stance = Character.Stance.Crouch
			end
		end
	else
		if (RequestedMovement.Magnitude > 0) then
			local PlanarMovement = ProjectToPlane(RequestedMovement, CurrentCharacter.HumanoidRootPart.CFrame.UpVector) * RequestedMovement.Magnitude
			local CurrentPlanarVelocity = ProjectToPlane(CurrentVelocity, CurrentCharacter.HumanoidRootPart.CFrame.UpVector)
			local MovementForce = PlanarMovement * AIR_ACCELERATION * deltaTime
			if (CurrentPlanarVelocity.Magnitude < AIR_SPEED) then
				local TargetPlanarVelocity = CurrentPlanarVelocity + MovementForce
				TargetPlanarVelocity = ClampMagnitude(TargetPlanarVelocity, AIR_SPEED)
				MovementForce = TargetPlanarVelocity - CurrentPlanarVelocity
			elseif (CurrentPlanarVelocity:Dot(MovementForce) > 0) then
				local ConstrainedMovementForce = ProjectToPlane(
					MovementForce,
					CurrentPlanarVelocity.Unit
				)
				MovementForce = ConstrainedMovementForce
			end

			if (StickResult) then
				-- prevents air climbing when on very steep slopes
				if (MovementForce:Dot(CurrentVelocity + MovementForce) > 0) then
					local ObstructionNormal = CurrentCharacter.HumanoidRootPart.CFrame.UpVector:Cross(
						CurrentCharacter.HumanoidRootPart.CFrame.UpVector:Cross(
							StickResult.Normal
						)
					).Unit
					-- if obstruction normal is NaN, reset it to the up vector
					if (ObstructionNormal.Magnitude ~= ObstructionNormal.Magnitude) then
						ObstructionNormal = CurrentCharacter.HumanoidRootPart.CFrame.UpVector
					end

					MovementForce = ProjectToPlane(MovementForce, ObstructionNormal)
				end
			end
			CurrentVelocity += MovementForce
		end

		local EffectiveGravity = GRAVITY
		local VerticalSpeed = CurrentVelocity:Dot(CurrentCharacter.HumanoidRootPart.CFrame.UpVector)
		if (RequestedJumpSustain and VerticalSpeed > 0) then
			EffectiveGravity *= JUMP_SUSTAIN_GRAVITY
		end
		CurrentVelocity += CurrentCharacter.HumanoidRootPart.CFrame.UpVector * EffectiveGravity * deltaTime
	end

	if (RequestedJump) then
		RequestedJump = false
		RequestedCrouch = false
		IsSupposedToBeStuckToGround = false

		local CurrentVerticalSpeed = CurrentVelocity:Dot(CurrentCharacter.HumanoidRootPart.CFrame.UpVector)
		local TargetVerticalSpeed = math.max(CurrentVerticalSpeed, JUMP_FORCE)
		CurrentVelocity += CurrentCharacter.HumanoidRootPart.CFrame.UpVector * (TargetVerticalSpeed - CurrentVerticalSpeed)

		task.delay(0.05, function()
			IsSupposedToBeStuckToGround = true
		end)
	end

	if (not StickResult and State.Stance == Character.Stance.Slide) then
		print("cancelled sliding because of air")
		State.Stance = Character.Stance.Crouch
	end

	CurrentCharacter.HumanoidRootPart.Velocity = CurrentVelocity
end

function Character:UpdateRotation()
	-- project the rotation to the Y axis
	local Forward = ProjectToPlane(RequestedRotation.LookVector, CurrentCharacter.HumanoidRootPart.CFrame.UpVector)

	-- set the rotation
	CurrentCharacter.HumanoidRootPart.CFrame = CFrame.lookAlong(CurrentCharacter.HumanoidRootPart.Position, Forward)
end

function Character:BeforeCharacterUpdate()
	TempState = table.clone(State)

	if (RequestedCrouch and State.Stance == Character.Stance.Stand) then
		print("crouching")
		State.Stance = Character.Stance.Crouch
	end
end

function Character:AfterCharacterUpdate()
	if (not RequestedCrouch and State.Stance ~= Character.Stance.Stand) then
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {CurrentCharacter}
		local Result = workspace:Spherecast(CurrentCharacter.HumanoidRootPart.Position - Vector3.new(0, 2, 0), 3, Vector3.new(0, 4.5, 0), Params)
		if (not Result) then
			print("standing")
			State.Stance = Character.Stance.Stand
		else
			print("can't stand up")
			RequestedCrouch = true
			State.Stance = Character.Stance.Crouch
		end
	end

	State.Grounded = CheckGround() and true or false
	LastState = TempState
end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	CurrentCharacter = character
	IsCollidersReady = false

	task.delay(1, function()
		for _, child in ipairs(CurrentCharacter:GetDescendants()) do
			if (child:IsA("BasePart")) then
				child.Massless = true
				child.LocalTransparencyModifier = 1
			end
		end
	end)
end)

return Character
