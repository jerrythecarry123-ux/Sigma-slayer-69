--!strict
-- Pure server state machine. Roblox services are kept in FishingService.
type Config = {
	read PreparationTime: number, read BiteTimeout: number, read ChargeLeadTime: number,
	read ChargeDuration: number, read StartCooldown: number, read RequestCapacity: number,
	read RequestsPerSecond: number, read SpeciesName: string,
	read DynamicTiming: boolean?, read DynamicBites: boolean?, read CastDuration: number?,
	read BiteDelayMin: number?, read BiteDelayMax: number?,
}
type Attempt = {
	id: number, phase: string, readyAt: number, expiresAt: number, chargeAt: number?, zoneId: string?, timingCenter: number?,
	castAt: number, castDuration: number, duration: number, difficulty: number, behavior: string,
	timingMotion: { amplitude: number, speed: number, phase: number }?, reservedId: string?,
}
type Session = {
	attempt: Attempt?, catches: number, nextStart: number, tokens: number,
	tokenTime: number,
	profile: any?,
	reservations: { [string]: any },
}
type Packet = { [string]: any }
type TimingRules = {
	read qualityAt: (number, number?) -> string?, read centerFor: ((number) -> number)?,
	read centerAt: ((any, number) -> number)?,
}
local Engine = {}
Engine.__index = Engine
type EngineData = {
	config: Config,
	rules: TimingRules,
	sessions: { [number]: Session },
	sequence: number,
	progression: any?,
	randomRoll: () -> number,
}
export type FishingEngine = typeof(setmetatable({} :: EngineData, Engine))

function Engine.new(config: Config, rules: TimingRules, progression: any?, randomRoll: (() -> number)?): FishingEngine
	return setmetatable({ config = config, rules = rules, sessions = {}, sequence = 0, progression = progression,
		randomRoll = randomRoll or function() return 0.5 end }, Engine)
end

function Engine.addPlayer(self: FishingEngine, userId: number, now: number, initialProfile: any?)
	if self.sessions[userId] then return end
	self.sessions[userId] = {
		attempt = nil, catches = 0, nextStart = now,
		tokens = self.config.RequestCapacity, tokenTime = now,
		reservations = {},
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
		packet.castAt = attempt.castAt
		packet.castDuration = attempt.castDuration
		packet.expiresAt = attempt.expiresAt
		packet.chargeAt = attempt.chargeAt
		packet.duration = attempt.duration
		packet.timingCenter = attempt.timingCenter
		packet.difficulty, packet.behavior = attempt.difficulty, attempt.behavior
		if attempt.timingMotion then
			local motion = attempt.timingMotion
			packet.timingMotion = { amplitude = motion.amplitude, speed = motion.speed, phase = motion.phase }
		end
	end
	return packet
end

function Engine.finish(self: FishingEngine, userId: number, now: number, message: string): Packet
	local session = self.sessions[userId]
	local miss = if self.progression then self.progression.miss else nil
	if session.profile and type(miss) == "function" then miss(session.profile) end
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
	self: FishingEngine, userId: number, action: any, attemptId: any, now: number, canFish: boolean, zoneId: string?
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
	if (action == "Display" or action == "Style") and self.progression and session.profile then
		local packet = self:snapshot(userId) :: Packet
		if session.attempt then packet.message = "Finish your cast before changing your aquarium."; return packet end
		local result
		if action == "Display" and type(attemptId) == "table" then
			result = self.progression.display(session.profile, attemptId.id, attemptId.slot)
		elseif action == "Style" then result = self.progression.style(session.profile, attemptId) end
		if not result then return nil end
		packet = self:snapshot(userId) :: Packet
		packet.purchase, packet.message = result, result.message
		return packet
	end
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
		local reservationKey = zoneId or "*"
		local candidate = session.reservations[reservationKey]
		local prepare = if self.progression then self.progression.prepare else nil
		if not candidate and session.profile and type(prepare) == "function" then
			candidate = prepare(session.profile, zoneId)
			session.reservations[reservationKey] = candidate
		end
		-- Failed attempts cannot reroll a suspected rare fish. Reservations are
		-- private, per pond, and survive movement, Cancel, timeout and upgrades.
		-- They are transient session state; only successful rewards are saved.
		local novice = not session.profile or session.profile.catches < 3
		local difficulty = if candidate and not novice then math.clamp(candidate.Difficulty or 0, 0, 0.6) else 0
		local behavior = if candidate then candidate.Behavior or "Drift" else "Drift"
		local duration = self.config.ChargeDuration - difficulty * 0.6
		local delay = 0
		if self.config.DynamicBites then
			local value = self.randomRoll()
			local roll = if type(value) == "number" and value == value then math.clamp(value, 0, 1) else 0.5
			local low, high = self.config.BiteDelayMin or 0.35, self.config.BiteDelayMax or 1.05
			delay = low + (high - low) * roll + difficulty * 0.18
		end
		local readyAt = now + self.config.PreparationTime + delay
		local motion = nil
		if self.config.DynamicTiming and difficulty > 0.15 then
			local speed = if behavior == "Dart" then 3.1 elseif behavior == "Surge" then 2.5 elseif behavior == "Glide" then 1.6 else 2
			motion = { amplitude = difficulty * 0.07, speed = speed, phase = (self.sequence % 7) * 0.53 }
		end
		session.attempt = {
			id = self.sequence, phase = "Waiting", readyAt = readyAt,
			castAt = now, castDuration = self.config.CastDuration or 0.65,
			duration = duration, difficulty = difficulty, behavior = behavior,
			timingMotion = motion, reservedId = if candidate then candidate.Id else nil,
			expiresAt = readyAt + self.config.BiteTimeout,
			zoneId = zoneId,
			timingCenter = if self.config.DynamicTiming and self.rules.centerFor then self.rules.centerFor(self.sequence) else nil,
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
		attempt.expiresAt = chargeAt + attempt.duration
		return self:snapshot(userId)
	elseif action == "Release" and attempt.phase == "Reeling" then
		-- Receipt-time scoring: no client-supplied quality, timestamp, species or
		-- reward is trusted. Forgiving bands remain; native high-latency play still
		-- needs device testing before any bounded lag compensation is introduced.
		local progress = (now - (attempt.chargeAt :: number)) / attempt.duration
		local center = if self.rules.centerAt then self.rules.centerAt(attempt, now) else attempt.timingCenter
		local quality = self.rules.qualityAt(progress, center)
		if not quality then return self:finish(userId, now, "It got away! Release inside the colored zone.") end
		session.catches += 1
		local reward = if self.progression and session.profile then self.progression.catch(session.profile, quality, attempt.zoneId, attempt.reservedId)
			else { species = self.config.SpeciesName, quality = quality }
		session.reservations[attempt.zoneId or "*"] = nil
		-- A successful catch ends its attempt without resetting the quality chain.
		session.attempt = nil
		session.nextStart = now + self.config.StartCooldown
		local packet = self:snapshot(userId) :: Packet
		packet.message = "You caught a " .. reward.species .. "!"
		packet.result = reward
		return packet
	end
	return nil
end

return Engine
