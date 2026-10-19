--!strict
-- Pure location selection and attempt binding. Distances and world validity are
-- supplied by the server adapter; clients never choose their fishing location.
type Candidate = { location: any, distance: number }
type Binding = { attemptId: number, location: any }
local Locations = {}
Locations.__index = Locations
type Data = { bindings: { [number]: Binding } }
export type LocationState = typeof(setmetatable({} :: Data, Locations))

function Locations.nearest(candidates: { Candidate }, maxDistance: number): any?
	if maxDistance ~= maxDistance or maxDistance < 0 or maxDistance == math.huge then return nil end
	local nearest, distance = nil, maxDistance
	for _, candidate in candidates do
		local d = candidate.distance
		if candidate.location ~= nil and d == d and d >= 0 and d < math.huge
			and d <= maxDistance and (nearest == nil or d < distance) then
			nearest, distance = candidate.location, d
		end
	end
	return nearest
end

function Locations.new(): LocationState
	return setmetatable({ bindings = {} }, Locations)
end

function Locations.forAttempt(self: LocationState, userId: number, attemptId: number?): any?
	local binding = self.bindings[userId]
	return if binding and binding.attemptId == attemptId then binding.location else nil
end

function Locations.last(self: LocationState, userId: number): any?
	local binding = self.bindings[userId]
	return if binding then binding.location else nil
end

function Locations.acceptStart(
	self: LocationState, userId: number, previousAttemptId: number?, packet: any, location: any
): boolean
	-- Commit only after the state machine accepts a new Start. Rejected requests,
	-- retries, cooldowns and completed casts must preserve the last visual target.
	if previousAttemptId ~= nil or location == nil or packet == nil or packet.phase ~= "Waiting"
		or type(packet.attemptId) ~= "number" or packet.attemptId ~= packet.attemptId
		or packet.attemptId <= 0 or packet.attemptId == math.huge then return false end
	self.bindings[userId] = { attemptId = packet.attemptId, location = location }
	return true
end

function Locations.remove(self: LocationState, userId: number)
	self.bindings[userId] = nil
end

return Locations
