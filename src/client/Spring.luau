local Spring = {}
Spring.__index = Spring

function Spring:Calculate(current: Vector3, velocity: Vector3, target: Vector3, halfLife: number, frequency: number, deltaTime: number): (Vector3, Vector3)
	local dampingRatio = -math.log(0.5) / (halfLife * frequency)
	local f = 1 + 2 * deltaTime * dampingRatio * frequency
	local oo = frequency * frequency
	local hoo = deltaTime * oo
	local hhoo = deltaTime * hoo
	local detInv = 1 / (f + hhoo)
	local detX = f * current + deltaTime * velocity + hhoo * target
	local detV = velocity + hoo * (target - current)
	return detX * detInv, detV * detInv
end

function Spring.new(halfLife: number, frequency: number): Spring
	local self = setmetatable({
		_halfLife = halfLife,
		_frequency = frequency,
		_current = Vector3.new(),
		_velocity = Vector3.new(),
	}, Spring)

	return self
end

function Spring:Step(target: Vector3, deltaTime: number)
	self._current, self._velocity = self:Calculate(self._current, self._velocity, target, self._halfLife, self._frequency, deltaTime)
end

function Spring:Impulse(impulse: Vector3)
	self._velocity = self._velocity + impulse
end

export type Spring = typeof(Spring.new(0, 0))
return Spring
