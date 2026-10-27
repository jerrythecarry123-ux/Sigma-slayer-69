--!strict
-- Pure rules: usable in Roblox and the standalone Luau test runner.
local Rules = {
	NormalMin = 0.22,
	NormalMax = 0.95,
	FineMin = 0.48,
	FineMax = 0.84,
	BrilliantMin = 0.61,
	BrilliantMax = 0.75,
	CastPreciseMin = 0.52,
	CastPreciseMax = 0.95,
	CastPerfectMin = 0.72,
	CastPerfectMax = 0.88,
}

-- Cast strength is a separate, optional skill beat. A quick/default launch is
-- always valid; these grades only grant a small bounded bonus after a catch.
function Rules.castProgressAt(packet: any, now: number): number
	return math.clamp((now - (packet.castChargeAt or now)) / (packet.castChargeDuration or 1), 0, 1)
end

function Rules.castGradeAt(power: number): (string, number)
	if power ~= power or power < 0 or power > 1 then return "Clean", 0 end
	if power >= Rules.CastPerfectMin and power <= Rules.CastPerfectMax then return "Perfect", 10 end
	if power >= Rules.CastPreciseMin and power <= Rules.CastPreciseMax then return "Precise", 5 end
	return "Clean", 0
end

-- The adapter offsets the water target only along its already-authored lane.
-- A standard .65 cast retains the exact existing 14-stud target.
function Rules.castDepthFor(power: number?): number
	local value = if type(power) == "number" and power == power and math.abs(power) < math.huge then power else .65
	return math.clamp(14 + (math.clamp(value, 0, 1) - .65) * 4, 12, 15.4)
end

-- The gold target changes between casts, keeping timing readable rather than
-- turning every fish into the same memorized hold. Both sides use this center.
function Rules.centerFor(attemptId: number): number
	local centers = { 0.68, 0.52, 0.75, 0.60, 0.70 }
	return centers[(attemptId - 1) % #centers + 1]
end

-- Server and client evaluate the same modest, predictable fish resistance.
-- Metadata contains no fish identity and never supplies a client timestamp.
function Rules.centerAt(packet: any, now: number): number
	local center = packet.timingCenter or 0.68
	local motion = packet.timingMotion
	if motion and packet.chargeAt then
		local elapsed = math.max(0, now - packet.chargeAt)
		center += math.sin(elapsed * motion.speed + motion.phase) * motion.amplitude
	end
	-- The complete Fine band stays inside the catchable section of the track.
	return math.clamp(center, 0.45, 0.79)
end

function Rules.progressAt(packet: any, now: number): number
	return math.clamp((now - (packet.chargeAt or now)) / (packet.duration or 2.8), 0, 1)
end

function Rules.qualityAt(progress: number, center: number?, width: number?): string?
	if progress ~= progress or progress < Rules.NormalMin or progress > Rules.NormalMax then
		return nil
	end
	local brilliantMin, brilliantMax, fineMin, fineMax = Rules.BrilliantMin, Rules.BrilliantMax, Rules.FineMin, Rules.FineMax
	local span = if type(width) == "number" and width == width and math.abs(width) < math.huge then math.clamp(width, .08, .22) else .14
	local target = (Rules.BrilliantMin + Rules.BrilliantMax) / 2
	if center and center == center and center >= 0.45 and center <= 0.8 then
		target, fineMin, fineMax = center, center - 0.20, center + 0.16
	end
	brilliantMin, brilliantMax = target - span / 2, target + span / 2
	if progress >= brilliantMin and progress <= brilliantMax then
		return "Brilliant"
	end
	if progress >= fineMin and progress <= fineMax then
		return "Fine"
	end
	return "Normal"
end

return table.freeze(Rules)
