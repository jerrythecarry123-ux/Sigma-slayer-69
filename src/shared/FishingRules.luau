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

function Rules.qualityAt(progress: number): string?
	if progress ~= progress or progress < Rules.NormalMin or progress > Rules.NormalMax then
		return nil
	end
	if progress >= Rules.BrilliantMin and progress <= Rules.BrilliantMax then
		return "Brilliant"
	end
	if progress >= Rules.FineMin and progress <= Rules.FineMax then
		return "Fine"
	end
	return "Normal"
end

return table.freeze(Rules)
