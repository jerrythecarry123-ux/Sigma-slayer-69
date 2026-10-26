--!strict
local Config = require("../src/shared/FishingConfig")
local Rules = require("../src/shared/FishingRules")
local Engine = require("../src/server/FishingEngine")
local passed = 0

local function test(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
	passed += 1
	print("PASS " .. name)
end

local function setup()
	local engine = Engine.new(Config, Rules)
	engine:addPlayer(1, 0)
	return engine
end

local function charge(engine: Engine.FishingEngine, userId: number, startTime: number)
	local waiting = assert(engine:command(userId, "Start", nil, startTime, true))
	assert(waiting.phase == "Waiting")
	local reeling = assert(engine:command(userId, "Hold", waiting.attemptId, waiting.readyAt, true))
	assert(reeling.phase == "Reeling")
	return reeling
end

test("quality boundaries, invalid and non-finite values", function()
	assert(Rules.qualityAt(0) == nil)
	assert(Rules.qualityAt(Rules.NormalMin) == "Normal")
	assert(Rules.qualityAt(Rules.FineMin) == "Fine")
	assert(Rules.qualityAt(Rules.BrilliantMin) == "Brilliant")
	assert(Rules.qualityAt(Rules.BrilliantMax) == "Brilliant")
	assert(Rules.qualityAt(Rules.NormalMax) == "Normal")
	assert(Rules.qualityAt(1) == nil)
	assert(Rules.qualityAt(0 / 0) == nil)
	assert(Rules.qualityAt(math.huge) == nil)
end)

test("one completed catch is awarded exactly once", function()
	local e = setup()
	local attempt = charge(e, 1, 0)
	local releaseAt = attempt.chargeAt + Config.ChargeDuration * 0.68
	local result = assert(e:command(1, "Release", attempt.attemptId, releaseAt, true))
	assert(result.phase == "Idle" and result.catches == 1)
	assert(result.result.quality == "Brilliant" and result.result.species == "Pufflet")
	assert(e:command(1, "Release", attempt.attemptId, releaseAt, true) == nil)
	assert(assert(e:snapshot(1)).catches == 1)
end)

test("distant or dead player cannot start", function()
	local e = setup()
	local result = assert(e:command(1, "Start", nil, 0, false))
	assert(result.phase == "Idle" and result.attemptId == nil and result.catches == 0)
end)

test("a second Start cannot replace an active attempt", function()
	local e = setup()
	local first = assert(e:command(1, "Start", nil, 0, true))
	local second = assert(e:command(1, "Start", nil, 0.1, true))
	assert(first.attemptId == second.attemptId and second.phase == "Waiting")
end)

test("Hold before the bite cannot start the meter", function()
	local e = setup()
	local a = assert(e:command(1, "Start", nil, 0, true))
	local result = assert(e:command(1, "Hold", a.attemptId, a.readyAt - 0.1, true))
	assert(result.phase == "Waiting" and result.chargeAt == nil)
end)

test("Release without Hold cannot award a fish", function()
	local e = setup()
	local a = assert(e:command(1, "Start", nil, 0, true))
	assert(e:command(1, "Release", a.attemptId, 1, true) == nil)
	assert(assert(e:snapshot(1)).catches == 0)
end)

test("early and late releases fail without awarding", function()
	for _, progress in { -0.01, 0.1, 0.99, 1.1 } do
		local e = setup()
		local a = charge(e, 1, 0)
		local result = assert(e:command(1, "Release", a.attemptId,
			a.chargeAt + Config.ChargeDuration * progress, true))
		assert(result.phase == "Idle" and result.catches == 0 and result.result == nil)
	end
end)

test("forged, missing, malformed and other-player IDs cannot finish a catch", function()
	local e = setup()
	local a = charge(e, 1, 0)
	for _, id in { a.attemptId + 1, -1, math.huge, 0 / 0, "1", {} } do
		assert(e:command(1, "Release", id, a.chargeAt + 1, true) == nil)
	end
	assert(e:command(1, "Release", nil, a.chargeAt + 1, true) == nil)
	assert(assert(e:snapshot(1)).catches == 0)
end)

test("moving away aborts an attempt immediately on the next request", function()
	local e = setup()
	local a = charge(e, 1, 0)
	local result = assert(e:command(1, "Release", a.attemptId, a.chargeAt + 1.9, false))
	assert(result.phase == "Idle" and result.catches == 0)
end)

test("heartbeat aborts on death or leaving the spot without another request", function()
	local e = setup()
	charge(e, 1, 0)
	assert(assert(e:tick(1, 1.5, false)).phase == "Idle")
	assert(assert(e:snapshot(1)).catches == 0)
	assert(e:tick(1, 2, false) == nil)
end)

test("avatar replacement invalidates attempts before the next heartbeat", function()
	local e = setup()
	local a = charge(e, 1, 0)
	assert(assert(e:interrupt(1, 1, "Respawn")).phase == "Idle")
	assert(e:command(1, "Release", a.attemptId, a.chargeAt + 1.9, true) == nil)
	assert(e:interrupt(1, 2, "Respawn") == nil)
	assert(e:interrupt(999, 2, "Left") == nil)
	assert(assert(e:snapshot(1)).catches == 0)
end)

test("waiting and reeling attempts time out", function()
	local e = setup()
	local a = assert(e:command(1, "Start", nil, 0, true))
	assert(assert(e:tick(1, a.expiresAt + 0.1, true)).phase == "Idle")
	local reeling = charge(e, 1, 20)
	assert(assert(e:tick(1, reeling.expiresAt + 0.1, true)).phase == "Idle")
	assert(assert(e:snapshot(1)).catches == 0)
end)

test("Cancel and a new attempt invalidate old messages", function()
	local e = setup()
	local a = charge(e, 1, 0)
	local cancelled = assert(e:command(1, "Cancel", a.attemptId, 1, true))
	assert(cancelled.phase == "Idle")
	local b = charge(e, 1, cancelled.nextStart)
	assert(b.attemptId ~= a.attemptId)
	assert(e:command(1, "Release", a.attemptId, b.chargeAt + 1.9, true) == nil)
	assert(assert(e:snapshot(1)).attemptId == b.attemptId)
end)

test("a cooldown prevents immediate restart after finishing", function()
	local e = setup()
	local a = charge(e, 1, 0)
	local time = a.chargeAt + 1.9
	local result = assert(e:command(1, "Release", a.attemptId, time, true))
	assert(assert(e:command(1, "Start", nil, time, true)).phase == "Idle")
	assert(assert(e:command(1, "Start", nil, result.nextStart, true)).phase == "Waiting")
end)

test("spam is limited and requests recover after refill", function()
	local e = setup()
	for _ = 1, Config.RequestCapacity do assert(e:command(1, "Sync", nil, 0, true)) end
	assert(e:command(1, "Start", nil, 0, true) == nil)
	assert(assert(e:snapshot(1)).phase == "Idle")
	assert(assert(e:command(1, "Start", nil, 1, true)).phase == "Waiting")
end)

test("malformed actions also consume the request budget", function()
	local e = setup()
	for _ = 1, Config.RequestCapacity do assert(e:command(1, {}, nil, 0, true) == nil) end
	assert(e:command(1, "Sync", nil, 0, true) == nil)
end)

test("two players have independent attempts, limits and rewards", function()
	local e = setup()
	e:addPlayer(2, 0)
	local a = charge(e, 1, 0)
	local b = charge(e, 2, 0)
	assert(a.attemptId ~= b.attemptId)
	assert(e:command(2, "Release", a.attemptId, b.chargeAt + 1.9, true) == nil)
	e:command(1, "Release", a.attemptId, a.chargeAt + 1.9, true)
	assert(assert(e:snapshot(1)).catches == 1 and assert(e:snapshot(2)).catches == 0)
	e:command(2, "Release", b.attemptId, b.chargeAt + 0.9, true)
	assert(assert(e:snapshot(2)).catches == 1)
end)

test("removed sessions cannot receive rewards or retain data", function()
	local e = setup()
	local a = charge(e, 1, 0)
	e:removePlayer(1)
	assert(e:snapshot(1) == nil)
	assert(e:command(1, "Release", a.attemptId, a.chargeAt + 1.9, true) == nil)
	e:addPlayer(1, 4)
	assert(assert(e:snapshot(1)).catches == 0)
end)

test("snapshots cannot mutate authoritative attempt state", function()
	local e = setup()
	local a = charge(e, 1, 0)
	a.phase = "Idle"
	a.catches = 100
	assert(assert(e:snapshot(1)).phase == "Reeling" and assert(e:snapshot(1)).catches == 0)
end)

test("every changing target agrees with server quality and remains within the safe track", function()
	local seen = {}
	for id = 1, 20 do
		local center = Rules.centerFor(id)
		assert(center - .2 >= Rules.NormalMin and center + .16 <= Rules.NormalMax)
		assert(Rules.qualityAt(center, center) == "Brilliant")
		assert(Rules.qualityAt(center - .15, center) == "Fine")
		seen[center] = true
	end
	local count = 0
	for _ in seen do count += 1 end
	assert(count >= 4, "all fish use the same memorized target")
end)

test("a later cast scores its own server target instead of the previous gold zone", function()
	local e = setup()
	local first = charge(e, 1, 0)
	local landed = assert(e:command(1, "Release", first.attemptId, first.chargeAt + Config.ChargeDuration * first.timingCenter, true))
	local second = charge(e, 1, landed.nextStart)
	assert(first.timingCenter ~= second.timingCenter)
	local result = assert(e:command(1, "Release", second.attemptId, second.chargeAt + Config.ChargeDuration * first.timingCenter, true))
	assert(result.result.quality ~= "Brilliant", "client could reuse an old gold timing")
end)

test("species stay locked to the server zone accepted at the start of a cast", function()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local e = Engine.new(Config, Rules, Progression.new(Catalog, function() return .5 end))
	e:addPlayer(1, 0)
	local waiting = assert(e:command(1, "Start", nil, 0, true, "blossom"))
	local reeling = assert(e:command(1, "Hold", waiting.attemptId, waiting.readyAt, true, "summit"))
	local caught = assert(e:command(1, "Release", reeling.attemptId, reeling.chargeAt + Config.ChargeDuration * reeling.timingCenter, true, "cove"))
	assert(Catalog.get(caught.result.speciesId).Zone == "blossom")
	assert(#caught.profile.display == 1 and caught.profile.display[1] == caught.result.speciesId)
	assert(caught.profile.records[caught.result.speciesId] == caught.result.weightKg)
end)

test("successful catches preserve the skill chain and a cancelled cast clears it", function()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local e = Engine.new(Config, Rules, Progression.new(Catalog, function() return .5 end))
	e:addPlayer(1, 0)
	local time = 0
	for index = 1, 4 do
		local a = charge(e, 1, time)
		local landed = assert(e:command(1, "Release", a.attemptId, a.chargeAt + Config.ChargeDuration * a.timingCenter, true))
		assert(landed.profile.combo == index and landed.result.combo == index)
		time = landed.nextStart
	end
	local waiting = assert(e:command(1, "Start", nil, time, true))
	local cancelled = assert(e:command(1, "Cancel", waiting.attemptId, time + .3, true))
	assert(cancelled.profile.combo == 0)
end)

test("aquarium commands cannot display unowned fish or buy unaffordable themes", function()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local e = Engine.new(Config, Rules, Progression.new(Catalog, function() return .5 end))
	e:addPlayer(1, 0)
	local rejected = assert(e:command(1, "Display", {id="crownwhale",slot=1}, 0, true))
	assert(not rejected.purchase.success and #rejected.profile.display == 0)
	local style = assert(e:command(1, "Style", "observatory", .3, true))
	assert(not style.purchase.success and style.profile.coins == 0 and style.profile.equippedStyle == "lagoon")
	assert(e:command(1, "Display", "forged", .6, true) == nil)
end)

local function resistanceSetup()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local source = table.clone(Catalog)
	local species = table.clone(Catalog.get("pufflet"))
	species.Difficulty, species.Behavior = .6, "Surge"
	source.Species = { species }
	local progression = Progression.new(source, function() return .5 end)
	local profile = progression.create()
	profile.catches, profile.best.pufflet, profile.level = 5, 1, 0
	local engine = Engine.new(Config, Rules, progression, function() return .75 end)
	engine:addPlayer(1, 0, profile)
	return engine, progression, source
end

test("cast flight and seeded bite delay are separate, bounded server timings", function()
	for _, value in { 0, .5, 1, 0 / 0, math.huge } do
		local e = Engine.new(Config, Rules, nil, function() return value end)
		e:addPlayer(1, 10)
		local a = assert(e:command(1, "Start", nil, 10, true))
		assert(a.castAt == 10 and a.castDuration == Config.CastDuration)
		assert(a.readyAt >= 10 + Config.PreparationTime + Config.BiteDelayMin)
		assert(a.readyAt <= 10 + Config.PreparationTime + Config.BiteDelayMax)
		assert(a.castAt + a.castDuration < a.readyAt)
	end
end)

test("difficult fish have bounded resistance evaluated identically by server rules", function()
	local e = resistanceSetup()
	local a = charge(e, 1, 0)
	assert(a.difficulty == .6 and a.behavior == "Surge" and a.duration < Config.ChargeDuration)
	assert(a.timingMotion and a.timingMotion.amplitude <= .0421)
	local releaseAt = a.chargeAt
	local bestDistance = math.huge
	for index = 0, 10000 do
		local time = a.chargeAt + a.duration * index / 10000
		local center = Rules.centerAt(a, time)
		assert(center - .2 >= Rules.NormalMin and center + .16 <= Rules.NormalMax)
		local distance = math.abs(Rules.progressAt(a, time) - center)
		if distance < bestDistance then bestDistance, releaseAt = distance, time end
	end
	local result = assert(e:command(1, "Release", a.attemptId, releaseAt, true))
	assert(result.result.quality == "Brilliant" and result.result.speciesId == "pufflet")
end)

test("first three successful catches retain the static beginner timing window", function()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local source = table.clone(Catalog)
	local species = table.clone(Catalog.get("pufflet")); species.Difficulty = .6
	source.Species = { species }
	local progression = Progression.new(source, function() return .5 end)
	local e = Engine.new(Config, Rules, progression)
	e:addPlayer(1, 0)
	local time = 0
	for _ = 1, 3 do
		local a = charge(e, 1, time)
		assert(a.duration == Config.ChargeDuration and a.difficulty == 0 and a.timingMotion == nil)
		local result = assert(e:command(1, "Release", a.attemptId, a.chargeAt + a.duration * a.timingCenter, true))
		time = result.nextStart
	end
	assert(charge(e, 1, time).timingMotion ~= nil)
end)

test("private fish reservation survives cancel, miss, travel, timeout and rod upgrades", function()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local selections = 0
	local progression = Progression.new(Catalog, function() selections += 1; return .99 end)
	local p = progression.create(); p.level, p.catches, p.coins = 0, 10, 1000
	for _, species in Catalog.Species do if species.Level == 0 then p.best[species.Id] = 1 end end
	local e = Engine.new(Config, Rules, progression)
	e:addPlayer(1, 0, p)
	local first = assert(e:command(1, "Start", nil, 0, true, "harbor"))
	assert(selections == 1 and first.reservedId == nil and first.speciesId == nil and first.result == nil)
	assert(first.profile.catches == 10 and first.profile.coins == 1000)
	local ended = assert(e:command(1, "Cancel", first.attemptId, .1, true))
	assert(e:command(1, "Upgrade", 0, ended.nextStart, true).purchase.success)
	local a = assert(e:command(1, "Start", nil, 2, true, "harbor"))
	local reel = assert(e:command(1, "Hold", a.attemptId, a.readyAt, true))
	ended = assert(e:command(1, "Release", a.attemptId, reel.chargeAt, true))
	assert(ended.result == nil and selections == 1)
	local elsewhere = assert(e:command(1, "Start", nil, ended.nextStart, true, "blossom"))
	assert(selections == 2)
	ended = assert(e:tick(1, elsewhere.expiresAt + .1, false))
	local retried = assert(e:command(1, "Start", nil, ended.nextStart, true, "harbor"))
	assert(selections == 2, "switching ponds or upgrading rerolled the pending fish")
	reel = assert(e:command(1, "Hold", retried.attemptId, retried.readyAt, true))
	local result = assert(e:command(1, "Release", reel.attemptId, reel.chargeAt + reel.duration * Rules.centerAt(reel, reel.chargeAt + reel.duration * .6), true))
	assert(result.result.speciesId == "emberfin" and result.profile.catches == 11)
	-- Reward rolls occur only now; a later successful cast may select afresh.
	local before = selections
	assert(e:command(1, "Start", nil, result.nextStart, true, "harbor"))
	assert(selections == before + 1)
end)

test("snapshots cannot mutate resistance or reveal the private reserved fish", function()
	local e = resistanceSetup()
	local a = charge(e, 1, 0)
	assert(a.reservedId == nil and a.speciesId == nil)
	local amplitude = a.timingMotion.amplitude
	a.timingMotion.amplitude, a.difficulty, a.duration = 1000, 1000, .01
	local stored = assert(e:snapshot(1))
	assert(stored.timingMotion.amplitude == amplitude and stored.difficulty == .6 and stored.duration > 2)
end)

test("Sync and stale releases never select or reward an extra fish", function()
	local e = resistanceSetup()
	local a = charge(e, 1, 0)
	local cancelled = assert(e:command(1, "Cancel", a.attemptId, a.chargeAt + .1, true))
	assert(e:command(1, "Release", a.attemptId, a.chargeAt + 1.8, true) == nil)
	local sync = assert(e:command(1, "Sync", nil, cancelled.nextStart, true))
	assert(sync.phase == "Idle" and sync.catches == 5 and sync.profile.catches == 5)
	assert(sync.result == nil and sync.reservedId == nil and sync.timingMotion == nil)
end)

print(string.format("%d tests passed; 0 skipped", passed))
