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
	local function validate(profile: any): boolean
		if type(profile) ~= "table" or type(profile.best) ~= "table" then return false end
		if not uint(profile.coins, 1000000000) or not uint(profile.level, #catalog.Rods - 1)
			or not uint(profile.catches, 1000000000) or not uint(profile.brilliant, profile.catches)
			or not uint(profile.duplicateCount, 1000000000) or not uint(profile.goalIndex, #catalog.Goals + 1)
			or profile.goalIndex < 1 then return false end
		for id, rank in profile.best do
			local exists = false
			for _, species in catalog.Species do if species.Id == id then exists = true; break end end
			if not exists or not uint(rank, 3) or rank < 1 then return false end
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
