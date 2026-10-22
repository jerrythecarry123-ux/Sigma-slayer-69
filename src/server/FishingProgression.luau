--!strict
-- Authoritative progression. Pure functions let rewards and save migration be tested.
type Profile = {
	coins: number, level: number, catches: number, brilliant: number, goalIndex: number,
	best: { [string]: number }, duplicateCount: number,
	records: { [string]: number }, variants: { [string]: { [string]: boolean } },
	display: { string }, styles: { [string]: boolean }, equippedStyle: string,
	combo: number, zoneDuplicates: { [string]: number },
}
local Progression = {}
local ranks = { Normal = 1, Fine = 2, Brilliant = 3 }
local MAX_COINS = 1000000000

function Progression.new(catalog: any, randomRoll: () -> number)
	local function roll(): number
		local value = randomRoll()
		return if type(value) == "number" and value == value then math.clamp(value, 0, .999999) else .5
	end
	local function normalize(profile: Profile)
		profile.records = profile.records or {}
		profile.variants = profile.variants or {}
		profile.styles = profile.styles or { lagoon = true }
		profile.equippedStyle = profile.equippedStyle or "lagoon"
		profile.combo = profile.combo or 0
		profile.zoneDuplicates = profile.zoneDuplicates or {}
		if not profile.display then
			profile.display = {}
			for _, species in catalog.Species do
				if profile.best[species.Id] and #profile.display < 3 then table.insert(profile.display, species.Id) end
			end
		end
	end
	local function create(): Profile
		return {
			coins = 0, level = 0, catches = 0, brilliant = 0, goalIndex = 1, best = {}, duplicateCount = 0,
			records = {}, variants = {}, display = {}, styles = { lagoon = true }, equippedStyle = "lagoon",
			combo = 0, zoneDuplicates = {},
		}
	end
	local function collection(profile: Profile): (number, number)
		local count, points = 0, 0
		for _, species in catalog.Species do
			local best = profile.best[species.Id]
			if best then count += 1; points += best end
		end
		return count, points
	end
	local function zoneProgress(profile: Profile): {any}
		local zones = {}
		for _, zone in catalog.Zones or {} do
			local count, total = 0, 0
			for _, species in catalog.Species do
				if species.Zone == zone.Id then
					total += 1
					if profile.best[species.Id] then count += 1 end
				end
			end
			table.insert(zones, { id = zone.Id, name = zone.Name, count = count, total = total })
		end
		return zones
	end
	local function goalValue(profile: Profile, kind: string): number
		if kind == "Catches" then return profile.catches end
		if kind == "Rod" then return profile.level end
		if kind == "Brilliant" then return profile.brilliant end
		if kind == "Crownwhale" then return if profile.best.crownwhale then 1 else 0 end
		if kind == "Zones" then
			local count = 0
			for _, zone in zoneProgress(profile) do if zone.count > 0 then count += 1 end end
			return count
		end
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
		profile.coins = math.min(MAX_COINS, profile.coins + reward)
		return reward, names
	end
	local function copy(profile: Profile): Profile
		local out = create()
		out.coins, out.level, out.catches, out.brilliant = profile.coins, profile.level, profile.catches, profile.brilliant
		out.goalIndex, out.duplicateCount = profile.goalIndex, profile.duplicateCount
		for id, rank in profile.best do out.best[id] = rank end
		for id, kg in profile.records or {} do out.records[id] = kg end
		for id, variants in profile.variants or {} do
			local owned = {}
			for variant, found in variants do owned[variant] = found end
			out.variants[id] = owned
		end
		out.display = {}
		if profile.display then
			for _, id in profile.display do table.insert(out.display, id) end
		else
			for _, species in catalog.Species do
				if out.best[species.Id] and #out.display < 3 then table.insert(out.display, species.Id) end
			end
		end
		for id, owned in profile.styles or {} do out.styles[id] = owned end
		out.equippedStyle, out.combo = profile.equippedStyle or "lagoon", profile.combo or 0
		for id, count in profile.zoneDuplicates or {} do out.zoneDuplicates[id] = count end
		return out
	end
	local function snapshot(profile: Profile)
		local safe = copy(profile)
		local found, points = collection(profile)
		local goal = catalog.Goals[profile.goalIndex]
		local nextRod = catalog.Rods[profile.level + 2]
		return {
			coins = profile.coins, level = profile.level, species = found, points = points, best = safe.best,
			records = safe.records, variants = safe.variants, display = safe.display,
			styles = safe.styles, equippedStyle = safe.equippedStyle, combo = safe.combo,
			catches = profile.catches, zoneProgress = zoneProgress(profile),
			rod = catalog.Rods[profile.level + 1].Name,
			nextUpgrade = if nextRod then {
				name = nextRod.Name, cost = nextRod.Cost, description = nextRod.Description,
			} else nil,
			goal = if goal then {
				title = goal.Title, progress = math.min(goalValue(profile, goal.Kind), goal.Target),
				target = goal.Target, reward = goal.Reward,
			} else { title = "Journal complete! Show your finest fish and chase records.", progress = 1, target = 1, reward = 0 },
		}
	end
	local function catch(profile: Profile, quality: string, zoneId: string?)
		assert(ranks[quality], "Unknown catch quality")
		normalize(profile)
		local zoneKnown = zoneId == nil
		for _, zone in catalog.Zones or {} do if zone.Id == zoneId then zoneKnown = true end end
		assert(zoneKnown, "Unknown fishing zone")
		local available: { any } = {}
		local unseen: { any } = {}
		local totalWeight = 0
		for _, species in catalog.Species do
			if species.Level <= profile.level and (zoneId == nil or species.Zone == zoneId) then
				table.insert(available, species)
				totalWeight += species.Weight
				if not profile.best[species.Id] then table.insert(unseen, species) end
			end
		end
		assert(#available > 0, "Every accessible zone needs an available species")
		local duplicates = if zoneId then profile.zoneDuplicates[zoneId] or 0 else profile.duplicateCount
		local picked = available[1]
		-- Teach the first three catches; afterwards an unlocked discovery is never
		-- more than two duplicates away in the player's current island pool.
		if #unseen > 0 and (profile.catches < 3 or duplicates >= 2) then
			picked = unseen[1]
		else
			local choice = roll() * totalWeight
			for _, species in available do
				choice -= species.Weight
				if choice < 0 then picked = species; break end
			end
		end
		local previous = profile.best[picked.Id]
		local discovery = previous == nil
		profile.best[picked.Id] = math.max(previous or 0, ranks[quality])
		profile.duplicateCount = if discovery then 0 else math.min(MAX_COINS, profile.duplicateCount + 1)
		if zoneId then profile.zoneDuplicates[zoneId] = if discovery then 0 else math.min(MAX_COINS, duplicates + 1) end
		local sizeRoll = roll() ^ 2
		local minimum, maximum = picked.WeightMin or .4, picked.WeightMax or 4
		local weightKg = math.floor((minimum + (maximum - minimum) * sizeRoll) * 100 + .5) / 100
		local oldWeight = profile.records[picked.Id]
		local newRecord = oldWeight == nil or weightKg > oldWeight
		profile.records[picked.Id] = math.max(oldWeight or 0, weightKg)
		local variant = "Normal"
		if profile.catches >= 3 then
			local variantRoll = roll()
			variant = if variantRoll >= .995 then "Prismatic" elseif variantRoll >= .97 then "Golden" else "Normal"
		end
		if variant ~= "Normal" then
			local owned = profile.variants[picked.Id] or {}
			owned[variant] = true
			profile.variants[picked.Id] = owned
		end
		if discovery and #profile.display < 3 then table.insert(profile.display, picked.Id) end
		profile.catches = math.min(MAX_COINS, profile.catches + 1)
		if quality == "Brilliant" then profile.brilliant = math.min(profile.catches, profile.brilliant + 1) end
		profile.combo = if quality == "Normal" then 0 else math.min(100, profile.combo + 1)
		local comboBonus = if profile.combo > 1 then math.min(20, (profile.combo - 1) * 2) else 0
		local multiplier = 1 + catalog.Rods[profile.level + 1].Bonus / 100
		local coins = math.floor(picked.Coins * multiplier
			* (if quality == "Brilliant" then 1.6 elseif quality == "Fine" then 1.25 else 1)
			* (if variant == "Prismatic" then 2.5 elseif variant == "Golden" then 1.8 else 1)
			* (1 + sizeRoll * .25)) + comboBonus
		profile.coins = math.min(MAX_COINS, profile.coins + coins)
		local bonus, goals = resolveGoals(profile)
		return {
			species = picked.Name, speciesId = picked.Id, rarity = picked.Rarity, quality = quality,
			coins = coins, goalBonus = bonus, milestones = goals, newDiscovery = discovery,
			improved = previous ~= nil and ranks[quality] > previous,
			weightKg = weightKg, variant = variant, newRecord = newRecord, combo = profile.combo, comboBonus = comboBonus,
			zoneId = picked.Zone,
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
	local function display(profile: Profile, speciesId: any, slot: any)
		normalize(profile)
		if type(speciesId) ~= "string" or not profile.best[speciesId] then return { success = false, message = "Discover this fish before displaying it." } end
		if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > 3 or slot > #profile.display + 1 then
			return { success = false, message = "Choose one of your three aquarium slots." }
		end
		local previousSlot = table.find(profile.display, speciesId)
		if previousSlot == slot then return { success = true, message = "This fish is already on display." } end
		if previousSlot then
			local replaced = profile.display[slot]
			if not replaced then return { success = false, message = "This fish is already on display. Discover another fish for the empty slot." } end
			profile.display[previousSlot] = replaced
		end
		profile.display[slot] = speciesId
		return { success = true, message = catalog.get(speciesId).Name .. " is on display!" }
	end
	local function style(profile: Profile, styleId: any)
		normalize(profile)
		local selected = nil
		for _, candidate in catalog.AquariumStyles or {} do if candidate.Id == styleId then selected = candidate end end
		if not selected then return { success = false, message = "Choose an aquarium style from the shop." } end
		if not profile.styles[styleId] then
			if profile.coins < selected.Cost then return { success = false, message = "Catch more fish to afford this aquarium style." } end
			profile.coins -= selected.Cost
			profile.styles[styleId] = true
		end
		profile.equippedStyle = styleId
		return { success = true, message = selected.Name .. " aquarium equipped!" }
	end
	local function miss(profile: Profile)
		normalize(profile)
		profile.combo = 0
	end
	return { create = create, snapshot = snapshot, catch = catch, upgrade = upgrade, copy = copy,
		display = display, style = style, miss = miss }
end

return Progression
