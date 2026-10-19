--!strict
-- Pure server state machine. Roblox services are kept in FishingService.
type Config = {
	read PreparationTime: number, read BiteTimeout: number, read ChargeLeadTime: number,
	read ChargeDuration: number, read StartCooldown: number, read RequestCapacity: number,
	read RequestsPerSecond: number, read SpeciesName: string,
}
type Attempt = {
	id: number, phase: string, readyAt: number, expiresAt: number, chargeAt: number?,
}
type Session = {
	attempt: Attempt?, catches: number, nextStart: number, tokens: number,
	tokenTime: number,
}
type Packet = { [string]: any }
local Engine = {}
Engine.__index = Engine
type EngineData = {
	config: Config,
	rules: { read qualityAt: (number) -> string? },
	sessions: { [number]: Session },
	sequence: number,
}
export type FishingEngine = typeof(setmetatable({} :: EngineData, Engine))

function Engine.new(config: Config, rules: { read qualityAt: (number) -> string? }): FishingEngine
	return setmetatable({ config = config, rules = rules, sessions = {}, sequence = 0 }, Engine)
end

function Engine.addPlayer(self: FishingEngine, userId: number, now: number)
	if self.sessions[userId] then return end
	self.sessions[userId] = {
		attempt = nil, catches = 0, nextStart = now,
		tokens = self.config.RequestCapacity, tokenTime = now,
	}
end

function Engine.removePlayer(self: FishingEngine, userId: number)
	self.sessions[userId] = nil
end

function Engine.snapshot(self: FishingEngine, userId: number): Packet?
	local session = self.sessions[userId]
	if not session then return nil end
	local packet: Packet = { phase = "Idle", catches = session.catches, nextStart = session.nextStart }
	local attempt = session.attempt
	if attempt then
		packet.phase = attempt.phase
		packet.attemptId = attempt.id
		packet.readyAt = attempt.readyAt
		packet.expiresAt = attempt.expiresAt
		packet.chargeAt = attempt.chargeAt
		packet.duration = self.config.ChargeDuration
	end
	return packet
end

function Engine.finish(self: FishingEngine, userId: number, now: number, message: string): Packet
	local session = self.sessions[userId]
	session.attempt = nil
	session.nextStart = now + self.config.StartCooldown
	local packet = self:snapshot(userId) :: Packet
	packet.message = message
	return packet
end

function Engine.interrupt(self: FishingEngine, userId: number, now: number, message: string): Packet?
	local session = self.sessions[userId]
	if not session or not session.attempt then return nil end
	return self:finish(userId, now, message)
end

function Engine.tick(self: FishingEngine, userId: number, now: number, canFish: boolean): Packet?
	local session = self.sessions[userId]
	local attempt = if session then session.attempt else nil
	if not attempt then return nil end
	if not canFish then
		return self:finish(userId, now, "Fishing stopped. Return to the glowing spot on the dock.")
	end
	if now > attempt.expiresAt then
		return self:finish(userId, now, "It swam away. Cast again!")
	end
	return nil
end

function Engine.command(
	self: FishingEngine, userId: number, action: any, attemptId: any, now: number, canFish: boolean
): Packet?
	local session = self.sessions[userId]
	if not session then return nil end
	-- Rate-limit all requests, including malformed and unknown actions.
	session.tokens = math.min(self.config.RequestCapacity,
		session.tokens + math.max(0, now - session.tokenTime) * self.config.RequestsPerSecond)
	session.tokenTime = now
	if session.tokens < 1 then return nil end
	session.tokens -= 1
	if type(action) ~= "string" then return nil end
	if action == "Sync" then return self:snapshot(userId) end
	local aborted = self:tick(userId, now, canFish)
	if aborted then return aborted end
	if action == "Start" then
		if session.attempt or now < session.nextStart then return self:snapshot(userId) end
		if not canFish then
			local packet = self:snapshot(userId) :: Packet
			packet.message = "Walk to the glowing spot at the end of the dock."
			return packet
		end
		self.sequence += 1
		local readyAt = now + self.config.PreparationTime
		session.attempt = {
			id = self.sequence, phase = "Waiting", readyAt = readyAt,
			expiresAt = readyAt + self.config.BiteTimeout,
		}
		return self:snapshot(userId)
	end
	local attempt = session.attempt
	if not attempt or type(attemptId) ~= "number" or attemptId ~= attempt.id then return nil end
	if action == "Cancel" then
		return self:finish(userId, now, "Cast cancelled. Ready when you are.")
	elseif action == "Hold" then
		if attempt.phase ~= "Waiting" or now < attempt.readyAt then return self:snapshot(userId) end
		attempt.phase = "Reeling"
		local chargeAt = now + self.config.ChargeLeadTime
		attempt.chargeAt = chargeAt
		attempt.expiresAt = chargeAt + self.config.ChargeDuration
		return self:snapshot(userId)
	elseif action == "Release" and attempt.phase == "Reeling" then
		-- No client-supplied quality, timestamp, species or reward is trusted.
		local progress = (now - (attempt.chargeAt :: number)) / self.config.ChargeDuration
		local quality = self.rules.qualityAt(progress)
		if not quality then return self:finish(userId, now, "It got away! Release inside the colored zone.") end
		session.catches += 1
		local packet = self:finish(userId, now, "You caught a " .. self.config.SpeciesName .. "!")
		packet.result = { species = self.config.SpeciesName, quality = quality }
		return packet
	end
	return nil
end

return Engine
