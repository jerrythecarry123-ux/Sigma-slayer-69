--!strict
-- Pure rules: usable in Roblox and the standalone Luau test runner.
local Rules = {
	NormalMin = 0.22,
	NormalMax = 0.95,
	FineMin = 0.48,
	FineMax = 0.84,
	BrilliantMin = 0.61,
	BrilliantMax = 0.75,
}

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

function Rules.qualityAt(progress: number, center: number?): string?
	if progress ~= progress or progress < Rules.NormalMin or progress > Rules.NormalMax then
		return nil
	end
	local brilliantMin, brilliantMax, fineMin, fineMax = Rules.BrilliantMin, Rules.BrilliantMax, Rules.FineMin, Rules.FineMax
	if center and center == center and center >= 0.45 and center <= 0.8 then
		brilliantMin, brilliantMax, fineMin, fineMax = center - 0.07, center + 0.07, center - 0.20, center + 0.16
	end
	if progress >= brilliantMin and progress <= brilliantMax then
		return "Brilliant"
	end
	if progress >= fineMin and progress <= fineMax then
		return "Fine"
	end
	return "Normal"
end

return table.freeze(Rules)
