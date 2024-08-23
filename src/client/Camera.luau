local UserInputService = game:GetService("UserInputService")

--[[
	A singleton class that controls the camera in the game.
]]
local Camera = {}
Camera.__index = Camera

local CurrentCamera = workspace.CurrentCamera

local PureCFrame = CurrentCamera.CFrame

function Camera:UpdatePosition(vec3: Vector3)
	CurrentCamera.CFrame = CFrame.lookAlong(vec3, CurrentCamera.CFrame.LookVector)
end

--[[
	Updates the rotation of the camera.
	Takes in a unit vector3.
]]
function Camera:UpdateRotation(deltaTime: number)
	CurrentCamera.CFrame = PureCFrame
	local Delta = UserInputService:GetMouseDelta() * UserSettings().GameSettings.MouseSensitivity
	local CameraCFrame = Camera:GetCameraCFrame().Rotation
	* CFrame.fromEulerAnglesYXZ(-Delta.Y / (math.pi * 2 * 1.33), -Delta.X / (math.pi * 2 * 1.33), 0)
	if (CameraCFrame.UpVector.Y <= 0.01) then
		CameraCFrame = Camera:GetCameraCFrame().Rotation * CFrame.fromEulerAnglesYXZ(0, -Delta.X / (math.pi * 2 * 1.33), 0)
	end
	CurrentCamera.CFrame = CFrame.lookAlong(CurrentCamera.CFrame.Position, CameraCFrame.LookVector)
	PureCFrame = CurrentCamera.CFrame
end

function Camera:GetCameraCFrame()
	return CurrentCamera.CFrame
end

--[[
	This function adds in custom cframe stuff without changing the camera's original cframe.
]]
function Camera:UpdateCustomCFrame(cframe: CFrame)
	CurrentCamera.CFrame = cframe
end

return Camera
