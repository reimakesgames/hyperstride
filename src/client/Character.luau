local Players = game:GetService("Players")

local CurrentCharacter = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local RootPart: Part = CurrentCharacter:WaitForChild("HumanoidRootPart")
local Humanoid: Humanoid = CurrentCharacter:WaitForChild("Humanoid")
task.delay(1, function()
	for _, child in ipairs(CurrentCharacter:GetDescendants()) do
		if (child:IsA("BasePart")) then
			child.Massless = true
			child.LocalTransparencyModifier = 1
		end
	end
end)

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
		RootPart.Position - Humanoid.HipHeight * Vector3.new(0, 1, 0),
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
	Velocity = Vector3.new(),
	Acceleration = Vector3.new(),
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

local _isStickingToGround = true

local WalkSpeed = 50
local CrouchSpeed = 20
local WalkResponse = 25
local CrouchResponse = 20

local AirSpeed = 40
local AirAcceleration = 200

local SlideStartSpeed = 70
local SlideEndSpeed = 30
local SlideFriction = 0.8
local SlideSteerAcceleration = 50
local SlideGravity = -200

local JumpForce = 50
local CoyoteTime = 0.2
local Gravity = -200
local JumpSustainGravity = 0.5

local StandHeight = 0
local CrouchHeight = -1
local SlideHeight = -2
local CrouchHeightResponse = 15

local _currentVelocity = Vector3.new()

local _requestedRotation = CFrame.new()
local _requestedMovement = Vector3.new()
local _requestedJump = false
local _requestedJumpSustain = false
local _requestedCrouch = false
local _requestedCrouchInAir = false

local _timeSinceUngrounded = 0
local _timeSinceJumpRequest = 0
local _ungroundedDueToJump = false

local _state = CharacterState
local _lastState = CharacterState
local _tempState = CharacterState

function Character:UpdateBody(deltaTime: number)
	local hipTargetHeight = StandHeight
	if (_state.Stance == Character.Stance.Crouch) then
		hipTargetHeight = CrouchHeight
	elseif (_state.Stance == Character.Stance.Slide) then
		hipTargetHeight = SlideHeight
	end

	Humanoid.HipHeight = Lerp(
		Humanoid.HipHeight,
		hipTargetHeight,
		1 - math.exp(-CrouchHeightResponse * deltaTime)
	)
end

function Character:UpdateInput(input: CharacterInput)
	CharacterInput = input

	_requestedRotation = CharacterInput.Rotation

	_requestedMovement = Vector3.new(CharacterInput.Movement.X, 0, -CharacterInput.Movement.Y)
	_requestedMovement = _requestedMovement.Unit
	_requestedMovement = CharacterInput.Rotation * _requestedMovement
	if (CharacterInput.Movement == Vector2.new()) then
		_requestedMovement = Vector3.new()
	end

	local wasRequestingJump = _requestedJump
	_requestedJump = _requestedJump or CharacterInput.Jump
	if (_requestedJump and not wasRequestingJump) then
		_timeSinceJumpRequest = 0
	end

	_requestedJumpSustain = CharacterInput.JumpSustain

	local wasRequestingCrouch = _requestedCrouch

	if (CharacterInput.Crouch == Character.CrouchInput.Toggle) then
		_requestedCrouch = not _requestedCrouch
	elseif (CharacterInput.Crouch == Character.CrouchInput.None) then
		_requestedCrouch = _requestedCrouch
	else
		_requestedCrouch = _requestedCrouch
	end

	if (_requestedCrouch and not wasRequestingCrouch) then
		_requestedCrouchInAir = not _state.Grounded
	elseif (not _requestedCrouch and wasRequestingCrouch) then
		_requestedCrouchInAir = false
	end
end

function Character:UpdateVelocity(deltaTime)
	_state.Acceleration = Vector3.new()

	local ground = CheckGround()
	if (ground and _isStickingToGround) then
		RootPart.CFrame = CFrame.new(ground.Position + Vector3.new(0, 3 + Humanoid.HipHeight, 0))

		_timeSinceUngrounded = 0
		_ungroundedDueToJump = false

		local groundedMovement = ProjectToPlane(_requestedMovement, ground.Normal) * _requestedMovement.Magnitude

		local moving = groundedMovement.Magnitude > 0
		local crouching = _state.Stance == Character.Stance.Crouch
		local wasStanding = _lastState.Stance == Character.Stance.Stand
		local wasInAir = not _lastState.Grounded
		if (moving and crouching and (wasStanding or wasInAir)) then
			print("sliding")
			_state.Stance = Character.Stance.Slide

			local effectiveSlideStartSpeed = SlideStartSpeed
			if (not _lastState.Grounded and not _requestedCrouchInAir) then
				effectiveSlideStartSpeed = 0
				_requestedCrouchInAir = false
			end
			local slideSpeed = math.max(effectiveSlideStartSpeed, _currentVelocity.Magnitude)
			_currentVelocity = ProjectToPlane(_currentVelocity, ground.Normal).Unit * slideSpeed
		end

		if (_state.Stance == Character.Stance.Stand or _state.Stance == Character.Stance.Crouch) then
			local speed = _state.Stance == Character.Stance.Stand and WalkSpeed or CrouchSpeed
			local response = _state.Stance == Character.Stance.Stand and WalkResponse or CrouchResponse
			local targetVelocity = Vector3.new()
			if (groundedMovement.Magnitude > 0) then
				targetVelocity = groundedMovement * speed
			end
			local moveVelocity = _currentVelocity:Lerp(targetVelocity, 1 - math.exp(-response * deltaTime))
			_state.Acceleration = (moveVelocity - _currentVelocity) / deltaTime
			_currentVelocity = moveVelocity
		else
			_currentVelocity -= _currentVelocity * (SlideFriction * deltaTime)

			local force = ProjectToPlane(-RootPart.CFrame.UpVector, ground.Normal) * SlideGravity
			_currentVelocity -= force * deltaTime

			local currentSpeed = _currentVelocity.Magnitude
			local targetVelocity = groundedMovement * currentSpeed
			local steerVelocity = _currentVelocity
			local steerForce = (targetVelocity - steerVelocity) * SlideSteerAcceleration * deltaTime
			steerVelocity += steerForce
			steerVelocity = ClampMagnitude(steerVelocity, currentSpeed)
			_state.Acceleration = (steerVelocity - _currentVelocity) / deltaTime
			_currentVelocity = steerVelocity

			if (_currentVelocity.Magnitude < SlideEndSpeed) then
				print("slide end")
				_state.Stance = Character.Stance.Crouch
			end
		end
	else
		_timeSinceUngrounded += deltaTime

		if (_requestedMovement.Magnitude > 0) then
			local planarMovement = ProjectToPlane(_requestedMovement, RootPart.CFrame.UpVector) * _requestedMovement.Magnitude
			local currentPlanarVelocity = ProjectToPlane(_currentVelocity, RootPart.CFrame.UpVector)
			local movementForce = planarMovement * AirAcceleration * deltaTime
			if (currentPlanarVelocity.Magnitude < AirSpeed) then
				local targetPlanarVelocity = currentPlanarVelocity + movementForce
				targetPlanarVelocity = ClampMagnitude(targetPlanarVelocity, AirSpeed)
				movementForce = targetPlanarVelocity - currentPlanarVelocity
			elseif (currentPlanarVelocity:Dot(movementForce) > 0) then
				local constrainedMovementForce = ProjectToPlane(
					movementForce,
					currentPlanarVelocity.Unit
				)
				movementForce = constrainedMovementForce
			end

			if (ground) then
				-- prevents air climbing when on very steep slopes
				if (movementForce:Dot(_currentVelocity + movementForce) > 0) then
					local obstructionNormal = RootPart.CFrame.UpVector:Cross(
						RootPart.CFrame.UpVector:Cross(
							ground.Normal
						)
					).Unit
					-- if obstruction normal is NaN, reset it to the up vector
					if (obstructionNormal.Magnitude ~= obstructionNormal.Magnitude) then
						obstructionNormal = RootPart.CFrame.UpVector
					end

					movementForce = ProjectToPlane(movementForce, obstructionNormal)
				end
			end

			_currentVelocity += movementForce
		end

		local effectiveGravity = Gravity
		local verticalSpeed = _currentVelocity:Dot(RootPart.CFrame.UpVector)
		if (_requestedJumpSustain and verticalSpeed > 0) then
			effectiveGravity *= JumpSustainGravity
		end
		_currentVelocity += RootPart.CFrame.UpVector * effectiveGravity * deltaTime
	end

	if (_requestedJump) then
		local canCoyoteJump = _timeSinceUngrounded < CoyoteTime and not _ungroundedDueToJump

		if (_state.Grounded or canCoyoteJump) then
			print("jumping")
			_requestedJump = false
			_requestedCrouch = false
			_requestedCrouchInAir = false
			_isStickingToGround = false
			_ungroundedDueToJump = true

			local currentVerticalSpeed = _currentVelocity:Dot(RootPart.CFrame.UpVector)
			local targetVerticalSpeed = math.max(currentVerticalSpeed, JumpForce)
			_currentVelocity += RootPart.CFrame.UpVector * (targetVerticalSpeed - currentVerticalSpeed)

			task.delay(0.05, function()
				_isStickingToGround = true
			end)
		else
			_timeSinceJumpRequest += deltaTime

			local canJumpLater = _timeSinceJumpRequest < CoyoteTime
			_requestedJump = canJumpLater
		end
	end

	if (not ground and _state.Stance == Character.Stance.Slide) then
		print("cancelled sliding because of air")
		_state.Stance = Character.Stance.Crouch
	end

	RootPart.AssemblyLinearVelocity = _currentVelocity
end

function Character:UpdateRotation()
	local forward = ProjectToPlane(_requestedRotation.LookVector, RootPart.CFrame.UpVector)

	RootPart.CFrame = CFrame.lookAlong(RootPart.Position, forward)
end

function Character:BeforeCharacterUpdate()
	_tempState = table.clone(_state)

	if (_requestedCrouch and _state.Stance == Character.Stance.Stand) then
		print("crouching")
		_state.Stance = Character.Stance.Crouch
	end
end

function Character:AfterCharacterUpdate()
	if (not _requestedCrouch and _state.Stance ~= Character.Stance.Stand) then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {CurrentCharacter}
		local blockedHead = workspace:Spherecast(RootPart.Position - Vector3.new(0, 2, 0), 3, Vector3.new(0, 4.5, 0), raycastParams)
		if (not blockedHead) then
			print("standing")
			_state.Stance = Character.Stance.Stand
		else
			print("can't stand up")
			_requestedCrouch = true
			_state.Stance = Character.Stance.Crouch
		end
	end

	_state.Grounded = CheckGround() and true or false
	_state.Velocity = _currentVelocity
	_lastState = _tempState
end

function Character:GetState(): CharacterState
	return _state
end

function Character:GetLastState(): CharacterState
	return _lastState
end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	CurrentCharacter = character
	RootPart = CurrentCharacter:WaitForChild("HumanoidRootPart")

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
