--!strict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local SaveRules = require(script.Parent:WaitForChild("FishingSaveRules"))
local Store = {}

function Store.new(catalog: any, progression: any, studio: boolean)
	-- Test saves never share the production namespace.
	local dataStore = DataStoreService:GetDataStore(if studio then "CloudAnglers_Test_v03" else "CloudAnglers_Player_v03")
	local rules = SaveRules.new(catalog, progression)
	local function update(key: string, transform: any): (any?, string?)
		local rejection: string? = nil
		for attempt = 1, 3 do
			local ok, value = pcall(function()
				return dataStore:UpdateAsync(key, function(old)
					local record, reason = transform(old)
					rejection = reason
					return record
				end)
			end)
			if ok then return value, rejection end
			if attempt < 3 then task.wait(attempt) end
		end
		return nil, "unavailable"
	end
	local function load(userId: number): (any?, string?)
		local id = HttpService:GenerateGUID(false)
		local key = "player_" .. userId
		local record, reason = update(key, function(old) return rules.acquire(old, id, os.time()) end)
		for _ = 1, 3 do
			if reason ~= "active_session" then break end
			task.wait(2)
			record, reason = update(key, function(old) return rules.acquire(old, id, os.time()) end)
		end
		if not record or not record.lease or record.lease.id ~= id then return nil, reason or "lost_lease" end
		return {
			key = key, id = id, profile = record.profile, expires = record.lease.expires,
			lastSave = os.clock(), busy = false, closed = false, offline = record.offlineAward,
		}, nil
	end
	local function save(session: any, profile: any, release: boolean): (boolean, string?)
		if session.closed or session.busy then return false, "busy" end
		session.busy = true
		-- Keep a single snapshot across UpdateAsync retries.
		local copy = progression.copy(profile)
		local record, reason = update(session.key, function(old)
			return rules.save(old, copy, session.id, os.time(), release)
		end)
		session.busy = false
		if not record then return false, reason or "unavailable" end
		session.lastSave = os.clock()
		session.expires = if record.lease then record.lease.expires else 0
		if release then session.closed = true end
		return true, nil
	end
	return { load = load, save = save }
end
return Store
