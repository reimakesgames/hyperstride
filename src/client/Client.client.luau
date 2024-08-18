local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Camera = require(script.Parent.Camera)
local Character = require(script.Parent.Character)

local CurrentCamera = workspace.CurrentCamera
local CurrentCharacter = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()

local CAMERA_OFFSET_FROM_ROOT = Vector3.new(0, 1.5, 0)

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

local Inputs = {}
UserInputService.InputBegan:Connect(function(input)
	Inputs[input.KeyCode] = true
end)

function Update()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	CurrentCamera.CameraType = Enum.CameraType.Scriptable


	if (CurrentCharacter) then
		Character:BeforeCharacterUpdate()

		Camera:UpdateRotation()

		local Crouch = if Inputs[Enum.KeyCode.LeftControl] then Character.CrouchInput.Toggle else Character.CrouchInput.None
		local Input: Character.CharacterInput = {
			Rotation = Camera:GetCameraCFrame().Rotation,
			Movement = GetMovementVector2(),
			Jump = Inputs[Enum.KeyCode.Space],
			Crouch = Crouch,
		}
		Character:UpdateInput(Input)

		Character:AfterCharacterUpdate()
	end

	for key, _ in pairs(Inputs) do
		-- turn off the key
		Inputs[key] = nil
	end
end

function LateUpdate()
	local RootCFrame = CurrentCharacter:WaitForChild("HumanoidRootPart").CFrame
	Camera:UpdatePosition(RootCFrame.Position + CAMERA_OFFSET_FROM_ROOT)
end

function Step(deltaTime)
	Character:UpdateVelocity(deltaTime)
	Character:UpdateRotation()
end

RunService:BindToRenderStep("HYPERSTRIDE_Update", Enum.RenderPriority.Input.Value, Update)
RunService:BindToRenderStep("HYPERSTRIDE_LateUpdate", Enum.RenderPriority.Camera.Value, LateUpdate)
RunService.RenderStepped:Connect(Step)

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	CurrentCharacter = character
end)
