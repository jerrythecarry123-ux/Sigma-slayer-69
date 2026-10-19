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
	profile: any?,
}
type Packet = { [string]: any }
local Engine = {}
Engine.__index = Engine
type EngineData = {
	config: Config,
	rules: { read qualityAt: (number) -> string? },
	sessions: { [number]: Session },
	sequence: number,
	progression: any?,
}
export type FishingEngine = typeof(setmetatable({} :: EngineData, Engine))

function Engine.new(config: Config, rules: { read qualityAt: (number) -> string? }, progression: any?): FishingEngine
	return setmetatable({ config = config, rules = rules, sessions = {}, sequence = 0, progression = progression }, Engine)
end

function Engine.addPlayer(self: FishingEngine, userId: number, now: number, initialProfile: any?)
	if self.sessions[userId] then return end
	self.sessions[userId] = {
		attempt = nil, catches = 0, nextStart = now,
		tokens = self.config.RequestCapacity, tokenTime = now,
		profile = if self.progression then (if initialProfile then self.progression.copy(initialProfile) else self.progression.create()) else nil,
	}
	if initialProfile then self.sessions[userId].catches = initialProfile.catches end
end

function Engine.exportProfile(self: FishingEngine, userId: number): any?
	local session = self.sessions[userId]
	return if session and session.profile and self.progression then self.progression.copy(session.profile) else nil
end

function Engine.removePlayer(self: FishingEngine, userId: number)
	self.sessions[userId] = nil
end

function Engine.snapshot(self: FishingEngine, userId: number): Packet?
	local session = self.sessions[userId]
	if not session then return nil end
	local packet: Packet = { phase = "Idle", catches = session.catches, nextStart = session.nextStart }
	if self.progression and session.profile then packet.profile = self.progression.snapshot(session.profile) end
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
	if action == "Upgrade" and self.progression and session.profile then
		local packet = self:snapshot(userId) :: Packet
		if session.attempt then
			packet.message = "Finish your cast before changing rods."
			return packet
		end
		if type(attemptId) ~= "number" or attemptId ~= session.profile.level then
			packet.message = "Your rod changed. Check the workshop again."
			return packet
		end
		local purchase = self.progression.upgrade(session.profile)
		packet = self:snapshot(userId) :: Packet
		packet.purchase = purchase
		packet.message = purchase.message
		return packet
	end
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
		local reward = if self.progression and session.profile then self.progression.catch(session.profile, quality)
			else { species = self.config.SpeciesName, quality = quality }
		local packet = self:finish(userId, now, "You caught a " .. self.config.SpeciesName .. "!")
		packet.message = "You caught a " .. reward.species .. "!"
		packet.result = reward
		return packet
	end
	return nil
end

return Engine
