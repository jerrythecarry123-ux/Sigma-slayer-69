--!strict
local Catalog = require("../src/shared/FishCatalog")
local Progression = require("../src/server/FishingProgression")
local SaveRules = require("../src/server/FishingSaveRules")
local Engine = require("../src/server/FishingEngine")
local Config = require("../src/shared/FishingConfig")
local Rules = require("../src/shared/FishingRules")
local progression = Progression.new(Catalog, function() return 0 end)
local saves = SaveRules.new(Catalog, progression)
local passed = 0
local function test(name: string, fn: () -> ())
	local ok, message = pcall(fn)
	if not ok then error("FAIL " .. name .. ": " .. tostring(message), 0) end
	passed += 1
	print("PASS " .. name)
end
local function firstThree()
	local p = progression.create()
	for _ = 1, 3 do progression.catch(p, "Normal") end
	return p
end
local function populatedRecord()
	local record = assert(saves.acquire(nil, "first", 1000))
	record.profile = firstThree()
	return assert(saves.save(record, record.profile, "first", 1000, true))
end
local function catchWithEngine(e: Engine.FishingEngine, time: number)
	local waitPacket = assert(e:command(1, "Start", nil, time, true))
	local reel = assert(e:command(1, "Hold", waitPacket.attemptId, waitPacket.readyAt, true))
	local releaseAt = reel.chargeAt + Config.ChargeDuration * 0.68
	return assert(e:command(1, "Release", reel.attemptId, releaseAt, true)), releaseAt, reel.attemptId
end

test("first three catches teach three species and pay goals exactly once", function()
	local p = progression.create()
	local a = progression.catch(p, "Normal")
	local b = progression.catch(p, "Normal")
	local c = progression.catch(p, "Normal")
	assert(a.speciesId == "pufflet" and b.speciesId == "mintfin" and c.speciesId == "emberfin")
	assert(a.goalBonus == 10 and b.goalBonus == 0 and c.goalBonus == 20)
	assert(p.coins == 59 and progression.snapshot(p).species == 3)
	assert(progression.catch(p, "Normal").goalBonus == 0)
end)

test("unaffordable and maximum upgrades never consume money", function()
	local p = progression.create()
	assert(not progression.upgrade(p).success and p.coins == 0 and p.level == 0)
	p.coins = 1000
	for _ = 1, 3 do assert(progression.upgrade(p).success) end
	local before = p.coins
	assert(not progression.upgrade(p).success and p.coins == before and p.level == 3)
end)

test("upgrades unlock species and bounded duplicates guarantee discovery", function()
	local p = firstThree()
	for _ = 1, 6 do assert(Catalog.get(progression.catch(p, "Normal").speciesId).Level == 0) end
	assert(progression.upgrade(p).success and p.level == 1)
	for _ = 1, 6 do progression.catch(p, "Normal") end
	assert(progression.snapshot(p).species == 5 and not p.best.aurorafin)
	assert(progression.upgrade(p).success and p.level == 2)
	for _ = 1, 3 do progression.catch(p, "Normal") end
	assert(p.best.aurorafin and progression.snapshot(p).species == 6)
end)

test("better grades replace rather than accumulate collection points", function()
	local p = firstThree()
	assert(progression.snapshot(p).points == 3)
	local result = progression.catch(p, "Brilliant")
	assert(result.speciesId == "pufflet" and result.improved and not result.newDiscovery)
	assert(progression.snapshot(p).points == 5)
	progression.catch(p, "Normal")
	assert(p.best.pufflet == 3 and progression.snapshot(p).points == 5)
end)

test("goals earned before they are displayed are retained", function()
	local p = progression.create()
	progression.catch(p, "Brilliant")
	progression.catch(p, "Normal")
	progression.catch(p, "Normal")
	local purchase = progression.upgrade(p)
	assert(purchase.success and purchase.goalBonus == 45)
	assert(progression.snapshot(p).goal.title == "Complete your field journal")
end)

test("snapshots and exported profiles never expose mutable server collection", function()
	local p = firstThree()
	local snap = progression.snapshot(p)
	snap.best.pufflet = 3
	local copy = progression.copy(p)
	copy.best.mintfin = nil
	assert(p.best.pufflet == 1 and p.best.mintfin == 1)
end)

test("engine rewards are not repeated by replayed release messages", function()
	local e = Engine.new(Config, Rules, progression)
	e:addPlayer(1, 0)
	local result, time, id = catchWithEngine(e, 0)
	assert(result.profile.coins > 0 and result.result.newDiscovery)
	assert(e:command(1, "Release", id, time, true) == nil)
	assert(assert(e:snapshot(1)).profile.coins == result.profile.coins)
end)

test("engine purchases require the current level and reject duplicate requests", function()
	local e = Engine.new(Config, Rules, progression)
	e:addPlayer(1, 0)
	catchWithEngine(e, 0)
	catchWithEngine(e, 5)
	catchWithEngine(e, 10)
	local bought = assert(e:command(1, "Upgrade", 0, 15, false))
	assert(bought.purchase.success and bought.profile.level == 1)
	local duplicate = assert(e:command(1, "Upgrade", 0, 16, false))
	assert(duplicate.purchase == nil and duplicate.profile.level == 1 and duplicate.profile.coins == bought.profile.coins)
	assert(e:exportProfile(1).coins == bought.profile.coins)
end)

test("failed fishing never earns coins, species or goal rewards", function()
	local e = Engine.new(Config, Rules, progression)
	e:addPlayer(1, 0)
	local a = assert(e:command(1, "Start", nil, 0, true))
	local reel = assert(e:command(1, "Hold", a.attemptId, a.readyAt, true))
	local failed = assert(e:command(1, "Release", a.attemptId, reel.chargeAt, true))
	assert(failed.profile.coins == 0 and failed.profile.species == 0 and failed.profile.goal.progress == 0)
end)

test("new players receive no fictional offline earnings", function()
	local record = assert(saves.acquire(nil, "new", 1000))
	assert(record.profile.coins == 0 and record.offlineAward == nil)
	assert(record.lease.expires == 1000 + SaveRules.LeaseSeconds)
end)

test("offline earnings use elapsed server time and respect the cap", function()
	local old = populatedRecord()
	local coins = old.profile.coins
	local returned = assert(saves.acquire(old, "return", 1000 + 60 * 10))
	assert(returned.offlineAward.coins == 7)
	assert(returned.profile.coins == coins + 7)
	local long = assert(saves.acquire(old, "long", 1000 + 60 * 60 * 48))
	assert(long.offlineAward.coins == 120 and long.offlineAward.seconds == 8 * 60 * 60)
	assert(old.profile.coins == coins, "UpdateAsync input must remain untouched")
end)

test("retrying the same successful load cannot pay offline income twice", function()
	local first = assert(saves.acquire(populatedRecord(), "same", 2000))
	local second = assert(saves.acquire(first, "same", 2010))
	assert(first.profile.coins == second.profile.coins)
	assert(second.offlineAward.coins == first.offlineAward.coins)
	assert(second.lease.expires == 2010 + SaveRules.LeaseSeconds)
end)

test("active sessions exclude other servers; expired leases allow recovery", function()
	local locked = assert(saves.acquire(populatedRecord(), "serverA", 2000))
	local rejected, reason = saves.acquire(locked, "serverB", 2010)
	assert(rejected == nil and reason == "active_session")
	local recovered = assert(saves.acquire(locked, "serverB", locked.lease.expires + 600))
	assert(recovered.lease.id == "serverB" and recovered.offlineAward.coins == 7)
end)

test("a stale server cannot overwrite progress after another acquires the lease", function()
	local first = assert(saves.acquire(nil, "serverA", 1000))
	local replacement = assert(saves.acquire(first, "serverB", 1200))
	local bad, reason = saves.save(replacement, first.profile, "serverA", 1201, true)
	assert(bad == nil and reason == "lost_lease" and replacement.lease.id == "serverB")
end)

test("clean saves persist the latest snapshot and release only the owned lease", function()
	local old = assert(saves.acquire(nil, "owner", 1000))
	local profile = firstThree()
	local saved = assert(saves.save(old, profile, "owner", 1010, false))
	assert(saved.profile.coins == 59 and saved.lease.expires == 1130)
	profile.coins = 100
	local released = assert(saves.save(saved, profile, "owner", 1020, true))
	assert(released.lease == nil and released.lastSeen == 1020 and released.profile.coins == 100)
	assert(saved.profile.coins == 59)
end)

test("corrupt or newer data is rejected rather than replaced with defaults", function()
	for _, corrupt in { {version=2}, {version=1,profile={}}, {version=1,profile=progression.create(),lastSeen=-1} } do
		local record, reason = saves.acquire(corrupt, "owner", 2000)
		assert(record == nil and reason == "invalid_data")
	end
	local p = progression.create()
	p.coins = 0 / 0
	assert(not saves.validate(p))
	p = progression.create(); p.level = 99; assert(not saves.validate(p))
	p = progression.create(); p.best.unknown = 1; assert(not saves.validate(p))
end)

test("zero discoveries, future timestamps and balance limits cannot mint extra coins", function()
	local empty = assert(saves.acquire(nil, "old", 1000))
	empty = assert(saves.save(empty, empty.profile, "old", 1000, true))
	assert(saves.acquire(empty, "new", 5000).offlineAward.coins == 0)
	local old = populatedRecord()
	assert(saves.acquire(old, "future", 900).offlineAward.coins == 0)
	old.profile.coins = 1000000000 - 2
	assert(saves.acquire(old, "cap", 10000).offlineAward.coins == 2)
end)

test("loaded profiles restore currency, goals, grades and catches without aliasing", function()
	local initial = firstThree()
	local e = Engine.new(Config, Rules, progression)
	e:addPlayer(1, 0, initial)
	initial.coins = 0
	local snap = assert(e:snapshot(1))
	assert(snap.profile.coins == 59 and snap.catches == 3 and snap.profile.species == 3)
	local copy = assert(e:exportProfile(1)); copy.best.pufflet = 3
	assert(assert(e:snapshot(1)).profile.best.pufflet == 1)
end)

print(string.format("%d progression/save tests passed; 0 skipped", passed))
