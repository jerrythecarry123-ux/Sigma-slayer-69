--!strict
-- Session progression; no persistence is implied. All rewards are server-owned.
type Profile = {
	coins: number, level: number, catches: number, brilliant: number, goalIndex: number,
	best: { [string]: number }, duplicateCount: number,
}
local Progression = {}
local ranks = { Normal = 1, Fine = 2, Brilliant = 3 }

function Progression.new(catalog: any, randomRoll: () -> number)
	local function create(): Profile
		return { coins = 0, level = 0, catches = 0, brilliant = 0, goalIndex = 1, best = {}, duplicateCount = 0 }
	end
	local function collection(profile: Profile): (number, number)
		local count, points = 0, 0
		for _, species in catalog.Species do
			local best = profile.best[species.Id]
			if best then count += 1; points += best end
		end
		return count, points
	end
	local function goalValue(profile: Profile, kind: string): number
		if kind == "Catches" then return profile.catches end
		if kind == "Rod" then return profile.level end
		if kind == "Brilliant" then return profile.brilliant end
		local count = collection(profile)
		return count
	end
	local function resolveGoals(profile: Profile): (number, { string })
		local reward = 0
		local names: { string } = {}
		while true do
			local goal = catalog.Goals[profile.goalIndex]
			if not goal or goalValue(profile, goal.Kind) < goal.Target then break end
			reward += goal.Reward
			table.insert(names, goal.Title)
			profile.goalIndex += 1
		end
		profile.coins += reward
		return reward, names
	end
	local function snapshot(profile: Profile)
		local found, points = collection(profile)
		local goal = catalog.Goals[profile.goalIndex]
		local nextRod = catalog.Rods[profile.level + 2]
		local best: { [string]: number } = {}
		for id, quality in profile.best do best[id] = quality end
		return {
			coins = profile.coins, level = profile.level, species = found, points = points, best = best,
			rod = catalog.Rods[profile.level + 1].Name,
			nextUpgrade = if nextRod then {
				name = nextRod.Name, cost = nextRod.Cost, description = nextRod.Description,
			} else nil,
			goal = if goal then {
				title = goal.Title, progress = math.min(goalValue(profile, goal.Kind), goal.Target),
				target = goal.Target, reward = goal.Reward,
			} else { title = "Journal complete! Improve your catch grades.", progress = 1, target = 1, reward = 0 },
		}
	end
	local function catch(profile: Profile, quality: string)
		assert(ranks[quality], "Unknown catch quality")
		local available: { any } = {}
		local unseen: { any } = {}
		local totalWeight = 0
		for _, species in catalog.Species do
			if species.Level <= profile.level then
				table.insert(available, species)
				totalWeight += species.Weight
				if not profile.best[species.Id] then table.insert(unseen, species) end
			end
		end
		local picked = available[1]
		-- Teach variety early; afterwards, at most two duplicates before an unseen unlocked fish.
		if #unseen > 0 and (profile.catches < 3 or profile.duplicateCount >= 2) then
			picked = unseen[1]
		else
			local roll = math.clamp(randomRoll(), 0, 0.999999) * totalWeight
			for _, species in available do
				roll -= species.Weight
				if roll < 0 then picked = species; break end
			end
		end
		local previous = profile.best[picked.Id]
		local discovery = previous == nil
		profile.best[picked.Id] = math.max(previous or 0, ranks[quality])
		profile.duplicateCount = if discovery then 0 else profile.duplicateCount + 1
		profile.catches += 1
		if quality == "Brilliant" then profile.brilliant += 1 end
		local multiplier = 1 + catalog.Rods[profile.level + 1].Bonus / 100
		local coins = math.floor(picked.Coins * multiplier * (if quality == "Brilliant" then 1.6 elseif quality == "Fine" then 1.25 else 1))
		profile.coins += coins
		local bonus, goals = resolveGoals(profile)
		return {
			species = picked.Name, speciesId = picked.Id, rarity = picked.Rarity, quality = quality,
			coins = coins, goalBonus = bonus, milestones = goals, newDiscovery = discovery,
			improved = previous ~= nil and ranks[quality] > previous,
		}
	end
	local function upgrade(profile: Profile): { success: boolean, message: string, goalBonus: number?, milestones: { string }? }
		local nextRod = catalog.Rods[profile.level + 2]
		if not nextRod then return { success = false, message = "Your rod is fully upgraded." } end
		if profile.coins < nextRod.Cost then
			return { success = false, message = "Catch more fish to afford " .. nextRod.Name .. "." }
		end
		profile.coins -= nextRod.Cost
		profile.level += 1
		local bonus, goals = resolveGoals(profile)
		return { success = true, message = nextRod.Name .. " equipped!", goalBonus = bonus, milestones = goals }
	end
	local function copy(profile: Profile): Profile
		local best: { [string]: number } = {}
		for id, rank in profile.best do best[id] = rank end
		return {
			coins = profile.coins, level = profile.level, catches = profile.catches, brilliant = profile.brilliant,
			goalIndex = profile.goalIndex, duplicateCount = profile.duplicateCount, best = best,
		}
	end
	return { create = create, snapshot = snapshot, catch = catch, upgrade = upgrade, copy = copy }
end

return Progression
