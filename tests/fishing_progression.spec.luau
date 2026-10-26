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
	for _ = 1, #Catalog.Species * 3 do progression.catch(p, "Normal") end
	local unlocked = 0
	for _, species in Catalog.Species do if species.Level <= 1 then unlocked += 1 end end
	assert(progression.snapshot(p).species == unlocked and not p.best.aurorafin)
	assert(progression.upgrade(p).success and p.level == 2)
	for _ = 1, #Catalog.Species * 3 do progression.catch(p, "Normal") end
	assert(p.best.aurorafin and p.best.coralcrown and not p.best.crownwhale)
	local unlockedAtNimbus = 0
	for _, species in Catalog.Species do if species.Level <= 2 then unlockedAtNimbus += 1 end end
	assert(progression.snapshot(p).species == unlockedAtNimbus)
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
	assert(progression.snapshot(p).goal.title == "Discover 6 different species")
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

test("every free island has a distinct species pool and an available starter fish", function()
	assert(#Catalog.Species == 17 and #Catalog.Zones == 5)
	local ids = {}
	for _, species in Catalog.Species do
		assert(not ids[species.Id] and species.WeightMin > 0 and species.WeightMax >= species.WeightMin)
		ids[species.Id] = true
	end
	for _, zone in Catalog.Zones do
		local count, starters = 0, 0
		for _, species in Catalog.Species do
			if species.Zone == zone.Id then count += 1; if species.Level == 0 then starters += 1 end end
		end
		assert(count >= 3 and starters >= 1)
	end
end)

test("server-selected island restricts catches and rod requirements", function()
	for _, zone in Catalog.Zones do
		local p = progression.create()
		for _ = 1, 30 do
			local result = progression.catch(p, "Normal", zone.Id)
			local species = Catalog.get(result.speciesId)
			assert(species.Zone == zone.Id and species.Level == 0)
		end
	end
	local p = progression.create()
	assert(not pcall(function() progression.catch(p, "Normal", "forged-zone") end))
	assert(p.catches == 0 and p.coins == 0)
end)

test("island discovery guarantee survives catches on other islands", function()
	local p = progression.create()
	for _ = 1, 3 do progression.catch(p, "Normal", "harbor") end
	progression.catch(p, "Normal", "blossom")
	assert(p.best.petalperch and not p.best.ribbonkoi)
	for _ = 1, 2 do
		progression.catch(p, "Normal", "blossom")
		progression.catch(p, "Normal", "harbor")
	end
	assert(progression.catch(p, "Normal", "blossom").speciesId == "ribbonkoi")
end)

test("first catches are ordinary and variants use server rolls after teaching", function()
	local value = .999
	local variantProgression = Progression.new(Catalog, function() return value end)
	local p = variantProgression.create()
	for _ = 1, 3 do assert(variantProgression.catch(p, "Normal", "harbor").variant == "Normal") end
	local prism = variantProgression.catch(p, "Fine", "harbor")
	assert(prism.variant == "Prismatic" and p.variants[prism.speciesId].Prismatic)
	value = .98
	local gold = variantProgression.catch(p, "Fine", "harbor")
	assert(gold.variant == "Golden" and p.variants[gold.speciesId].Golden)
	value = .5
	assert(variantProgression.catch(p, "Fine", "harbor").variant == "Normal")
	assert(saves.validate(p))
end)

test("weight records are bounded, improve once and survive smaller catches", function()
	local value = 0
	local measured = Progression.new(Catalog, function() return value end)
	local p = measured.create()
	local first = measured.catch(p, "Normal", "harbor")
	assert(first.weightKg == Catalog.get(first.speciesId).WeightMin and first.newRecord)
	measured.catch(p, "Normal", "harbor"); measured.catch(p, "Normal", "harbor")
	value = .3
	local larger = measured.catch(p, "Normal", "harbor")
	assert(larger.speciesId == first.speciesId and larger.newRecord and larger.weightKg > first.weightKg)
	value = 0
	local smaller = measured.catch(p, "Normal", "harbor")
	assert(not smaller.newRecord and p.records[first.speciesId] == larger.weightKg)
	for _, species in Catalog.Species do
		p.level = 3
		local caught = measured.catch(p, "Brilliant", species.Zone)
		local data = Catalog.get(caught.speciesId)
		assert(caught.weightKg >= data.WeightMin and caught.weightKg <= data.WeightMax)
	end
end)

test("skill chains reward good catches with a cap and misses reset the chain", function()
	local p = progression.create()
	assert(progression.catch(p, "Fine", "harbor").comboBonus == 0)
	assert(progression.catch(p, "Brilliant", "harbor").comboBonus == 2)
	for _ = 1, 30 do assert(progression.catch(p, "Fine", "harbor").comboBonus <= 20) end
	assert(progression.snapshot(p).combo == 32)
	progression.miss(p)
	assert(progression.snapshot(p).combo == 0)
	progression.catch(p, "Fine", "harbor")
	assert(progression.catch(p, "Normal", "harbor").combo == 0)
end)

test("new discoveries fill three display slots and explicit changes swap owned fish", function()
	local p = firstThree()
	assert(table.concat(p.display, ",") == "pufflet,mintfin,emberfin")
	assert(progression.display(p, "emberfin", 1).success)
	assert(p.display[1] == "emberfin" and p.display[3] == "pufflet")
	progression.catch(p, "Normal", "blossom")
	assert(progression.display(p, "petalperch", 2).success and p.display[2] == "petalperch")
	assert(saves.validate(p))
end)

test("display changes reject undiscovered fish, invalid slots and forged values", function()
	local p = firstThree()
	local before = table.concat(p.display, ",")
	for _, id in { "crownwhale", "forged" } do assert(not progression.display(p, id, 1).success) end
	for _, slot in { 0, 4, 1.5, 0/0, math.huge, "1" } do assert(not progression.display(p, "pufflet", slot).success) end
	assert(not progression.display(p, {}, 1).success and table.concat(p.display, ",") == before)
	local empty = progression.create()
	assert(not progression.display(empty, "pufflet", 1).success)
	progression.catch(empty, "Normal", "harbor")
	assert(not progression.display(empty, "pufflet", 2).success and #empty.display == 1)
end)

test("cosmetic aquarium purchases charge once and equip without affecting fishing power", function()
	local p = progression.create()
	assert(not progression.style(p, "blossom").success and p.coins == 0)
	p.coins = 200
	assert(progression.style(p, "blossom").success and p.coins == 135 and p.styles.blossom)
	assert(progression.style(p, "lagoon").success and p.coins == 135)
	assert(progression.style(p, "blossom").success and p.coins == 135 and p.equippedStyle == "blossom")
	assert(not progression.style(p, "forged").success and not progression.style(p, {}).success)
	assert(p.level == 0 and p.catches == 0 and saves.validate(p))
end)

test("extended snapshots and copies do not alias aquarium, variants or records", function()
	local p = firstThree()
	p.variants.pufflet = { Golden = true }
	p.styles.blossom = true
	local snap, copy = progression.snapshot(p), progression.copy(p)
	snap.display[1] = "mintfin"; snap.variants.pufflet.Golden = nil; snap.records.pufflet = 99; snap.styles.blossom = nil
	copy.display[2] = "pufflet"; copy.variants.pufflet.Golden = nil
	assert(p.display[1] == "pufflet" and p.display[2] == "mintfin" and p.variants.pufflet.Golden and p.styles.blossom)
	assert(p.records.pufflet == .4)
end)

test("legacy saves migrate aquarium fields without changing earned progress", function()
	local old = populatedRecord()
	old.profile.records, old.profile.variants, old.profile.display = nil, nil, nil
	old.profile.styles, old.profile.equippedStyle, old.profile.combo, old.profile.zoneDuplicates = nil, nil, nil, nil
	old.profile.goalIndex = 6
	local migrated = assert(saves.acquire(old, "migrated", 1000)).profile
	assert(migrated.coins == old.profile.coins and migrated.level == old.profile.level and migrated.catches == 3)
	assert(migrated.goalIndex == 6 and migrated.best.pufflet == 1 and migrated.styles.lagoon and migrated.equippedStyle == "lagoon")
	assert(#migrated.display == 3 and next(migrated.records) == nil and saves.validate(migrated))
	assert(old.profile.display == nil and old.profile.styles == nil, "migration changed UpdateAsync input")
end)

test("save validation rejects invalid records, variant ownership and display holes", function()
	local p = firstThree()
	p.records.pufflet = math.huge; assert(not saves.validate(p))
	p.records.pufflet = 0/0; assert(not saves.validate(p))
	p.records.pufflet = .1; assert(not saves.validate(p))
	p = firstThree(); p.records.crownwhale = 20; assert(not saves.validate(p))
	p = firstThree(); p.variants.pufflet = { Mythic = true }; assert(not saves.validate(p))
	p = firstThree(); p.variants.crownwhale = { Golden = true }; assert(not saves.validate(p))
	p = firstThree(); p.display = {[1]="pufflet", [3]="mintfin"}; assert(not saves.validate(p))
	p = firstThree(); p.display = {"pufflet", "pufflet"}; assert(not saves.validate(p))
	p = firstThree(); p.display = {"crownwhale"}; assert(not saves.validate(p))
	p = firstThree(); p.styles.forged = true; assert(not saves.validate(p))
	p = firstThree(); p.equippedStyle = "blossom"; assert(not saves.validate(p))
	p = firstThree(); p.combo = -1; assert(not saves.validate(p))
	p = firstThree(); p.zoneDuplicates.forged = 1; assert(not saves.validate(p))
end)

test("zone collection progress uses actual discoveries and earned coins stay capped", function()
	local p = firstThree()
	local zones = progression.snapshot(p).zoneProgress
	assert(#zones == 5 and zones[1].id == "harbor" and zones[1].count == 3 and zones[1].total == 3)
	for i = 2, 5 do assert(zones[i].count == 0) end
	p.coins = 1000000000 - 1
	progression.catch(p, "Brilliant", "harbor")
	assert(p.coins == 1000000000 and saves.validate(p))
end)

test("preparing a fish never awards progress or consumes discovery protection", function()
	local p = firstThree()
	p.level, p.zoneDuplicates.forest = 3, 2
	local before = progression.copy(p)
	local candidate = progression.prepare(p, "forest")
	assert(candidate.Zone == "forest" and candidate.Id == "moonray")
	assert(p.coins == before.coins and p.catches == before.catches and p.goalIndex == before.goalIndex)
	assert(p.zoneDuplicates.forest == 2 and not p.best.moonray and not p.records.moonray)
	assert(table.concat(p.display, ",") == table.concat(before.display, ","))
end)

test("a reserved server species is rewarded without rolling a replacement", function()
	local p = firstThree(); p.level = 3
	local result = progression.catch(p, "Fine", "forest", "veilfin")
	assert(result.speciesId == "veilfin" and result.rarity == "Mythical" and p.best.veilfin == 2)
	assert(result.weightKg == Catalog.get("veilfin").WeightMin and saves.validate(p))
end)

test("invalid, locked and wrong-pond reservations cannot change rewards", function()
	local p = firstThree()
	for _, entry in { {"forged", "harbor"}, {"crownwhale", "summit"}, {"pufflet", "forest"}, {"pufflet", "forged"} } do
		local before = progression.copy(p)
		assert(not pcall(function() progression.catch(p, "Brilliant", entry[2], entry[1]) end))
		assert(p.coins == before.coins and p.catches == before.catches and p.goalIndex == before.goalIndex)
		assert(progression.snapshot(p).species == 3)
	end
end)

test("Mythical and Secret catches are eligible through weights, never forced by pity", function()
	local value = 0
	local rolls = Progression.new(Catalog, function() return value end)
	local p = rolls.create(); p.level, p.catches, p.duplicateCount = 3, 30, 99
	for _, species in Catalog.Species do if species.DiscoveryProtection then p.best[species.Id] = 1 end end
	p.zoneDuplicates.forest, p.zoneDuplicates.summit = 99, 99
	assert(rolls.prepare(p, "forest").Id ~= "veilfin")
	assert(rolls.prepare(p, "summit").Id ~= "eclipse")
	value = .999999
	assert(rolls.prepare(p, "forest").Id == "veilfin")
	assert(rolls.prepare(p, "summit").Id == "eclipse")
	assert(not p.best.veilfin and not p.best.eclipse and p.catches == 30)
end)

test("existing completed milestone records receive only the appended journal goal", function()
	local p = progression.create(); p.level, p.catches, p.goalIndex = 3, 30, 11
	for _, species in Catalog.Species do if species.DiscoveryProtection then p.best[species.Id] = 1 end end
	local oldCoins = p.coins
	assert(progression.snapshot(p).goal.target == #Catalog.Species and progression.snapshot(p).goal.progress == 15)
	local veilfin = progression.catch(p, "Fine", "forest", "veilfin")
	assert(veilfin.goalBonus == 0 and p.goalIndex == 11)
	local eclipse = progression.catch(p, "Fine", "summit", "eclipse")
	assert(eclipse.goalBonus == 75 and p.goalIndex == 12)
	assert(p.coins == oldCoins + veilfin.coins + eclipse.coins + 75 and saves.validate(p))
	assert(progression.catch(p, "Normal", "harbor").goalBonus == 0)
end)

print(string.format("%d progression/save tests passed; 0 skipped", passed))
