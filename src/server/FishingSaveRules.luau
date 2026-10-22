--!strict
-- Atomic record transitions. UpdateAsync may retry its callback; no side effects here.
local SaveRules = {}
SaveRules.LeaseSeconds = 120
SaveRules.MaxOfflineSeconds = 8 * 60 * 60
SaveRules.MaxOfflineCoins = 120

local function uint(value: any, maximum: number): boolean
	return type(value) == "number" and value == value and value >= 0 and value <= maximum and value % 1 == 0
end

function SaveRules.new(catalog: any, progression: any)
	local speciesById: { [string]: any } = {}
	for _, species in catalog.Species do speciesById[species.Id] = species end
	local zones: { [string]: boolean } = {}
	for _, zone in catalog.Zones or {} do zones[zone.Id] = true end
	local styles: { [string]: boolean } = { lagoon = true }
	for _, style in catalog.AquariumStyles or {} do styles[style.Id] = true end
	local function validate(profile: any): boolean
		if type(profile) ~= "table" or type(profile.best) ~= "table" then return false end
		if not uint(profile.coins, 1000000000) or not uint(profile.level, #catalog.Rods - 1)
			or not uint(profile.catches, 1000000000) or not uint(profile.brilliant, profile.catches)
			or not uint(profile.duplicateCount, 1000000000) or not uint(profile.goalIndex, #catalog.Goals + 1)
			or profile.goalIndex < 1 then return false end
		for id, rank in profile.best do
			if not speciesById[id] or not uint(rank, 3) or rank < 1 then return false end
		end
		-- Optional extension fields allow version-1 saves from before aquariums to
		-- migrate through progression.copy. Present fields must be fully valid.
		if profile.records ~= nil then
			if type(profile.records) ~= "table" then return false end
			for id, kg in profile.records do
				local species = speciesById[id]
				if not species or not profile.best[id] or type(kg) ~= "number" or kg ~= kg
					or kg < (species.WeightMin or .4) or kg > (species.WeightMax or 4) then return false end
			end
		end
		if profile.variants ~= nil then
			if type(profile.variants) ~= "table" then return false end
			for id, owned in profile.variants do
				if not speciesById[id] or not profile.best[id] or type(owned) ~= "table" then return false end
				for variant, found in owned do
					if (variant ~= "Golden" and variant ~= "Prismatic") or found ~= true then return false end
				end
			end
		end
		if profile.display ~= nil then
			if type(profile.display) ~= "table" then return false end
			local seen, count = {}, 0
			for slot, id in profile.display do
				if not uint(slot, 3) or slot < 1 or type(id) ~= "string" or not profile.best[id] or seen[id] then return false end
				seen[id] = true
				count += 1
			end
			for slot = 1, count do if not profile.display[slot] then return false end end
		end
		if profile.styles ~= nil then
			if type(profile.styles) ~= "table" or profile.styles.lagoon ~= true then return false end
			for id, owned in profile.styles do if not styles[id] or owned ~= true then return false end end
		end
		if profile.equippedStyle ~= nil then
			if type(profile.equippedStyle) ~= "string" or not styles[profile.equippedStyle]
				or (profile.equippedStyle ~= "lagoon" and (not profile.styles or not profile.styles[profile.equippedStyle])) then return false end
		end
		if profile.combo ~= nil and not uint(profile.combo, 100) then return false end
		if profile.zoneDuplicates ~= nil then
			if type(profile.zoneDuplicates) ~= "table" then return false end
			for id, count in profile.zoneDuplicates do if not zones[id] or not uint(count, 1000000000) then return false end end
		end
		return true
	end
	local function recordValid(record: any): boolean
		if type(record) ~= "table" or record.version ~= 1 or not validate(record.profile)
			or not uint(record.lastSeen, 100000000000) then return false end
		local lease = record.lease
		local award = record.offlineAward
		if award ~= nil and (type(award) ~= "table" or type(award.leaseId) ~= "string"
			or not uint(award.coins, SaveRules.MaxOfflineCoins)
			or not uint(award.seconds, SaveRules.MaxOfflineSeconds)) then return false end
		return lease == nil or (type(lease) == "table" and type(lease.id) == "string"
			and uint(lease.expires, 100000000000))
	end
	local function acquire(old: any, leaseId: string, now: number): (any?, string?)
		if old == nil then
			return { version = 1, profile = progression.create(), lastSeen = now,
				lease = { id = leaseId, expires = now + SaveRules.LeaseSeconds } }, nil
		end
		if not recordValid(old) then return nil, "invalid_data" end
		if old.lease and old.lease.id == leaseId then
			return { version = 1, profile = progression.copy(old.profile), lastSeen = now,
				lease = { id = leaseId, expires = now + SaveRules.LeaseSeconds }, offlineAward = old.offlineAward }, nil
		end
		if old.lease and old.lease.expires > now then return nil, "active_session" end
		local profile = progression.copy(old.profile)
		local found = 0
		for _ in profile.best do found += 1 end
		local lastActive = if old.lease then math.max(old.lastSeen, old.lease.expires) else old.lastSeen
		local elapsed = math.clamp(now - lastActive, 0, SaveRules.MaxOfflineSeconds)
		local earned = math.min(SaveRules.MaxOfflineCoins, 1000000000 - profile.coins,
			math.floor(elapsed / 60 * found * 0.25))
		profile.coins = math.min(1000000000, profile.coins + earned)
		return {
			version = 1, profile = profile, lastSeen = now,
			lease = { id = leaseId, expires = now + SaveRules.LeaseSeconds },
			offlineAward = { leaseId = leaseId, coins = earned, seconds = elapsed },
		}, nil
	end
	local function save(old: any, profile: any, leaseId: string, now: number, release: boolean): (any?, string?)
		if not recordValid(old) or not validate(profile) then return nil, "invalid_data" end
		if not old.lease or old.lease.id ~= leaseId then return nil, "lost_lease" end
		return {
			version = 1, profile = progression.copy(profile), lastSeen = now,
			lease = if release then nil else { id = leaseId, expires = now + SaveRules.LeaseSeconds },
		}, nil
	end
	return { acquire = acquire, save = save, validate = validate }
end
return SaveRules
