--!strict
-- Final-save retry/ownership regressions. These are datastore record transitions,
-- not native DataStoreService transport or availability measurements.
local Catalog = require("../src/shared/FishCatalog")
local Progression = require("../src/server/FishingProgression")
local SaveRules = require("../src/server/FishingSaveRules")
local progression = Progression.new(Catalog, function() return 0 end)
local saves = SaveRules.new(Catalog, progression)
local operation = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
local otherOperation = "cccccccc-1111-2222-3333-dddddddddddd"
local passed = 0
local function test(name: string, run: () -> ())
	local ok, reason = pcall(run)
	if not ok then error("FAIL " .. name .. ": " .. tostring(reason), 0) end
	passed += 1
	print("PASS " .. name)
end
local function owned()
	local record = assert(saves.acquire(nil, "owner", 1000))
	local profile = progression.create()
	for _ = 1, 3 do progression.catch(profile, "Normal", "harbor") end
	return record, profile
end

test("final release receipt acknowledges a committed write after a lost response", function()
	local old, profile = owned()
	local released = assert(saves.save(old, profile, "owner", 1010, true, operation))
	assert(released.lease == nil and released.releaseReceipt.leaseId == "owner")
	assert(released.releaseReceipt.operationId == operation and released.profile.coins == profile.coins)
	local retry = assert(saves.save(released, profile, "owner", 1013, true, operation))
	assert(retry.lease == nil and retry.profile.coins == released.profile.coins)
	assert(retry.lastSeen == 1010, "acknowledgement moved the actual final activity time")
end)

test("retry never rewrites the committed profile with a stale or different snapshot", function()
	local old, profile = owned()
	local released = assert(saves.save(old, profile, "owner", 1010, true, operation))
	local stale = progression.create()
	local retry = assert(saves.save(released, stale, "owner", 1013, true, operation))
	assert(retry.profile.coins == released.profile.coins and retry.profile.catches == 3)
	assert(retry.lastSeen == released.lastSeen and stale.catches == 0)
	retry.profile.best.pufflet = 3
	retry.releaseReceipt.operationId = otherOperation
	assert(released.profile.best.pufflet == 1 and released.releaseReceipt.operationId == operation,
		"receipt acknowledgement aliases its UpdateAsync input")
end)

test("an unrelated release cannot claim an already unlocked record", function()
	local old, profile = owned()
	local released = assert(saves.save(old, profile, "owner", 1010, true, operation))
	local value, reason = saves.save(released, profile, "owner", 1013, true, otherOperation)
	assert(value == nil and reason == "lost_lease")
	value, reason = saves.save(released, profile, "someone-else", 1013, true, operation)
	assert(value == nil and reason == "lost_lease")
	value, reason = saves.save(released, profile, "owner", 1013, false)
	assert(value == nil and reason == "lost_lease")
end)

test("new acquisition clears an old receipt and rejects the former owner's retry", function()
	local old, profile = owned()
	local released = assert(saves.save(old, profile, "owner", 1010, true, operation))
	local acquired = assert(saves.acquire(released, "next-owner", 1011))
	assert(acquired.releaseReceipt == nil and acquired.lease.id == "next-owner")
	local value, reason = saves.save(acquired, profile, "owner", 1013, true, operation)
	assert(value == nil and reason == "lost_lease" and acquired.profile.catches == 3)
end)

test("receipt retries do not delay or duplicate the next offline award", function()
	local old, profile = owned()
	local released = assert(saves.save(old, profile, "owner", 1010, true, operation))
	local retry = assert(saves.save(released, profile, "owner", 1310, true, operation))
	local acquired = assert(saves.acquire(retry, "next-owner", 1610))
	assert(acquired.offlineAward.seconds == 600 and acquired.offlineAward.coins == 7)
	assert(acquired.profile.coins == released.profile.coins + 7)
	local repeated = assert(saves.acquire(acquired, "next-owner", 1620))
	assert(repeated.profile.coins == acquired.profile.coins)
end)

test("malformed release receipts reject corrupt records rather than replacing progress", function()
	local old, profile = owned()
	local released = assert(saves.save(old, profile, "owner", 1010, true, operation))
	for _, receipt in { false, "bad", {}, { leaseId = "owner" }, { operationId = operation },
		{ leaseId = "", operationId = operation }, { leaseId = string.rep("x", 129), operationId = operation },
		{ leaseId = "owner", operationId = "not-a-guid" }, { leaseId = "owner", operationId = string.rep("a", 36) },
		{ leaseId = "owner", operationId = "aaaaaaaa-1111-2222-3333-gggggggggggg" } } do
		local corrupt = table.clone(released)
		corrupt.releaseReceipt = receipt
		local value, reason = saves.acquire(corrupt, "next-owner", 1100)
		assert(value == nil and reason == "invalid_data")
	end
	assert(released.profile.catches == 3 and released.releaseReceipt.operationId == operation)
end)

test("an active record cannot carry a release receipt", function()
	local old, profile = owned()
	old.releaseReceipt = { leaseId = "owner", operationId = operation }
	local value, reason = saves.acquire(old, "owner", 1010)
	assert(value == nil and reason == "invalid_data")
	value, reason = saves.save(old, profile, "owner", 1010, false)
	assert(value == nil and reason == "invalid_data")
end)

test("bad operation identities do not change a valid owned record", function()
	local old, profile = owned()
	for _, id in { "", "not-a-guid", "aaaaaaaaa-111-2222-3333-bbbbbbbbbbbb", "aaaaaaaa-1111-2222-3333-bbbbbbbbbbb" } do
		local value, reason = saves.save(old, profile, "owner", 1010, true, id)
		assert(value == nil and reason == "invalid_operation")
	end
	local value, reason = saves.save(old, profile, "owner", 1010, false, operation)
	assert(value == nil and reason == "invalid_operation")
	assert(old.lease.id == "owner" and old.profile.catches == 0 and old.lastSeen == 1000)
end)

test("legacy version-one records still release and acquire without receipt metadata", function()
	local old, profile = owned()
	local released = assert(saves.save(old, profile, "owner", 1010, true))
	assert(released.version == 1 and released.releaseReceipt == nil)
	local acquired = assert(saves.acquire(released, "next-owner", 1010))
	assert(acquired.profile.catches == 3 and acquired.profile.coins == profile.coins)
	assert(acquired.releaseReceipt == nil and acquired.lease.id == "next-owner")
end)

print(string.format("%d final-save transition tests passed; 0 skipped", passed))
