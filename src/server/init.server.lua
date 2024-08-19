local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("Events")

local FireRemoteEvent: RemoteEvent = RemoteEvents:WaitForChild("Fire")

FireRemoteEvent.OnServerEvent:Connect(function(player: Player, startPosition: Vector3, endPosition: Vector3, speed: number)
	for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
		if (otherPlayer ~= player) then
			FireRemoteEvent:FireClient(otherPlayer, startPosition, endPosition, speed)
		end
	end
end)
