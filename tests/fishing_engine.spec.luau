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



test("cast strength grades and authored lane depth have safe inclusive boundaries", function()
	for _, row in {
		{0, "Clean", 0}, {.51999, "Clean", 0}, {.52, "Precise", 5}, {.71999, "Precise", 5},
		{.72, "Perfect", 10}, {.8, "Perfect", 10}, {.88, "Perfect", 10}, {.88001, "Precise", 5},
		{.95, "Precise", 5}, {.95001, "Clean", 0}, {1, "Clean", 0},
	} do
		local grade, percent = Rules.castGradeAt(row[1])
		assert(grade == row[2] and percent == row[3])
	end
	for _, power in { -1, 2, 0/0, math.huge, -math.huge } do
		local grade, percent = Rules.castGradeAt(power)
		assert(grade == "Clean" and percent == 0)
		assert(Rules.castDepthFor(power) >= 12 and Rules.castDepthFor(power) <= 15.4)
	end
	assert(Rules.castDepthFor(.65) == 14 and Rules.castDepthFor(0) == 12 and Rules.castDepthFor(1) == 15.4)
	assert(Rules.castDepthFor(nil) == 14 and Rules.castDepthFor(0/0) == 14)
	assert(Rules.castProgressAt({castChargeAt=10,castChargeDuration=1},9) == 0)
	assert(Rules.castProgressAt({castChargeAt=10,castChargeDuration=1},10.8) > .79)
	assert(Rules.castProgressAt({castChargeAt=10,castChargeDuration=1},12) == 1)
end)

test("wind-up is server approved, binds an ID and does not select or award a fish", function()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local rolls = 0
	local progression = Progression.new(Catalog, function() rolls += 1; return .5 end)
	local e = Engine.new(Config, Rules, progression)
	e:addPlayer(1, 0)
	local winding = assert(e:command(1, "BeginCast", nil, 4, true, "forest"))
	assert(winding.phase == "ChargingCast" and winding.castChargeAt == 4 and winding.castChargeDuration == 1)
	assert(winding.expiresAt == 6.2 and winding.castAt == nil and winding.readyAt == nil and winding.castPower == nil)
	assert(winding.profile.coins == 0 and winding.profile.catches == 0 and winding.result == nil and rolls == 0)
	local retry = assert(e:command(1, "BeginCast", nil, 4.05, true, "cove"))
	assert(retry.attemptId == winding.attemptId and rolls == 0)
	local cancelled = assert(e:command(1, "Cancel", winding.attemptId, 4.1, true))
	assert(cancelled.phase == "Idle" and cancelled.catches == 0 and rolls == 0)
end)

test("quick tap remains a valid plain cast even when its acknowledgement was delayed", function()
	for _, delay in {.01, .12, .45, 1.6} do
		local e = setup()
		local wind = assert(e:command(1, "BeginCast", nil, 10, true))
		local cast = assert(e:command(1, "QuickCast", wind.attemptId, 10+delay, true))
		assert(cast.phase == "Waiting" and cast.attemptId == wind.attemptId and cast.castAt == 10+delay)
		assert(cast.castPower == .65 and cast.castGrade == "Clean" and cast.castBonusPercent == 0)
		assert(cast.catches == 0 and cast.readyAt > cast.castAt + cast.castDuration)
	end
end)

test("held cast power and reward grade come only from elapsed server time", function()
	for _, row in {{.2,"Clean",0},{.6,"Precise",5},{.8,"Perfect",10},{1.3,"Clean",0}} do
		local e = setup()
		local wind = assert(e:command(1, "BeginCast", nil, 10, true))
		local cast = assert(e:command(1, "Cast", wind.attemptId, 10+row[1], true))
		assert(cast.castGrade == row[2] and cast.castBonusPercent == row[3])
		assert(math.abs(cast.castPower - math.clamp(row[1],0,1)) < 1e-8)
		assert(cast.result == nil and cast.catches == 0)
		local reel = assert(e:command(1, "Hold", cast.attemptId, cast.readyAt, true))
		local result = assert(e:command(1, "Release", reel.attemptId, reel.chargeAt+reel.duration*reel.timingCenter, true))
		assert(result.result.castPower == cast.castPower and result.result.castGrade == row[2])
		assert(result.result.castBonusPercent == row[3] and result.catches == 1)
	end
end)

test("forged cast powers, timestamps, old IDs and another player's wind-up cannot launch", function()
	local e = setup();e:addPlayer(2,0)
	local wind = assert(e:command(1, "BeginCast", nil, 0, true))
	local other = assert(e:command(2, "BeginCast", nil, 0, true))
	for _, id in { {}, {id=wind.attemptId,power=.8,time=0.8}, "1", wind.attemptId+100, other.attemptId, 0/0, math.huge } do
		assert(e:command(1, "Cast", id, .1, true) == nil)
	end
	local snapshot = assert(e:snapshot(1))
	assert(snapshot.phase == "ChargingCast" and snapshot.castAt == nil and snapshot.catches == 0)
	snapshot.castChargeAt, snapshot.castChargeDuration = -1000, .001
	local actual = assert(e:command(1, "Cast", wind.attemptId, .2, true))
	assert(actual.castGrade == "Clean" and math.abs(actual.castPower-.2)<1e-8)
	assert(assert(e:snapshot(2)).phase == "ChargingCast")
end)

test("cast release is accepted once and cannot alter an already-launched target or bonus", function()
	local e = setup()
	local wind = assert(e:command(1, "BeginCast", nil, 0, true))
	assert(e:command(1, "Hold", wind.attemptId, .1, true).phase == "ChargingCast")
	assert(e:command(1, "Release", wind.attemptId, .2, true) == nil)
	local cast = assert(e:command(1, "Cast", wind.attemptId, .8, true))
	assert(cast.castGrade == "Perfect")
	assert(e:command(1, "Cast", wind.attemptId, .9, true) == nil)
	assert(e:command(1, "QuickCast", wind.attemptId, 1, true) == nil)
	local stored = assert(e:snapshot(1))
	assert(stored.castAt == .8 and stored.castPower == .8 and stored.castGrade == "Perfect")
end)

test("a lost or overlong wind-up launches a plain cast without leaving the player stuck", function()
	local e = setup()
	local wind = assert(e:command(1, "BeginCast", nil, 0, true))
	assert(e:tick(1, wind.expiresAt-.01, true) == nil)
	local cast = assert(e:tick(1, wind.expiresAt, true))
	assert(cast.phase == "Waiting" and cast.attemptId == wind.attemptId and cast.castAt == wind.expiresAt)
	assert(cast.castPower == .65 and cast.castGrade == "Clean" and cast.castBonusPercent == 0 and cast.catches == 0)
	assert(e:command(1, "Cast", wind.attemptId, wind.expiresAt+.01, true) == nil)
	assert(e:tick(1, cast.readyAt, true) == nil)
end)

test("movement death and cancellation stop charging without a fish roll or payout", function()
	local e = setup()
	local wind = assert(e:command(1, "BeginCast", nil, 0, true))
	local ended = assert(e:tick(1, .1, false))
	assert(ended.phase == "Idle" and ended.catches == 0)
	assert(e:command(1, "Cast", wind.attemptId, .8, true) == nil)
	wind = assert(e:command(1, "BeginCast", nil, 2, true))
	assert(e:interrupt(1,2.1,"Respawn").phase == "Idle")
	assert(e:command(1, "QuickCast", wind.attemptId, 2.2, true) == nil)
	assert(e:command(1, "BeginCast", nil, 4, false).phase == "Idle")
end)

test("charging attempts preserve the chosen pond and the existing private reservation", function()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local choices = 0
	local progression = Progression.new(Catalog, function() choices+=1;return .99 end)
	local profile=progression.create();profile.level,profile.catches=3,10
	for _,species in Catalog.Species do profile.best[species.Id]=1 end
	local e=Engine.new(Config,Rules,progression);e:addPlayer(1,0,profile)
	local first=assert(e:command(1,"Start",nil,0,true,"harbor"))
	assert(choices==1);local ended=assert(e:command(1,"Cancel",first.attemptId,.1,true))
	local wind=assert(e:command(1,"BeginCast",nil,ended.nextStart,true,"harbor"))
	local cast=assert(e:command(1,"Cast",wind.attemptId,ended.nextStart+.8,true,"summit"))
	assert(choices==1 and cast.reservedId==nil)
	local reel=assert(e:command(1,"Hold",cast.attemptId,cast.readyAt,true,"cove"))
	local result=assert(e:command(1,"Release",reel.attemptId,reel.chargeAt+reel.duration*Rules.centerAt(reel,reel.chargeAt+reel.duration*.6),true,"forest"))
	assert(result.result.speciesId=="emberfin" and result.result.zoneId=="harbor")
end)

test("concurrent charging players do not change an already-assigned resistance phase", function()
	local e, progression = resistanceSetup()
	e:addPlayer(2,0,progression.create())
	local first=assert(e:command(1,"BeginCast",nil,0,true))
	assert(e:command(2,"BeginCast",nil,.1,true))
	local cast=assert(e:command(1,"Cast",first.attemptId,.8,true))
	assert(cast.timingMotion.phase == (first.attemptId%7)*.53)
end)



test("mixed multi-player action traffic preserves exactly-once rewards and valid profiles", function()
	local Catalog = require("../src/shared/FishCatalog")
	local Progression = require("../src/server/FishingProgression")
	local SaveRules = require("../src/server/FishingSaveRules")
	local value=7409
	local function roll()
		value=value*48271%2147483647
		return value/2147483647
	end
	local progression=Progression.new(Catalog,roll)
	local validator=SaveRules.new(Catalog,progression)
	local e=Engine.new(Config,Rules,progression,roll)
	for id=1,3 do e:addPlayer(id,0) end
	local time,rewards,total=0,{},0
	local zones={"harbor","blossom","forest","cove","summit"}
	for _=1,6000 do
		time+=.04+roll()*.20
		local id=math.floor(roll()*3)+1
		local before=e:snapshot(id)
		local verb,argument="Sync",before.attemptId
		local choose=roll()
		if before.phase=="Idle" then verb=if choose<.7 then "BeginCast" else "Start"
		elseif before.phase=="ChargingCast" then
			verb=if choose<.52 then "Cast" elseif choose<.68 then "QuickCast" elseif choose<.8 then "Cancel" else "Hold"
		elseif before.phase=="Waiting" then verb=if choose<.78 then "Hold" elseif choose<.9 then "Cancel" else "BeginCast"
		elseif before.phase=="Reeling" then verb=if choose<.82 then "Release" else "Cancel" end
		local invalid=roll()
		if invalid<.07 then argument={power=.8,quality="Brilliant",timestamp=time}
		elseif invalid<.14 then argument=(argument or 0)+10000
		elseif invalid<.17 then verb={grade="Perfect"} end
		local canFish=roll()>.09
		local result=e:command(id,verb,argument,time,canFish,zones[math.floor(roll()*#zones)+1])
		local after=e:snapshot(id)
		assert(after.profile.catches==after.catches and validator.validate(e:exportProfile(id)))
		assert(after.catches==before.catches or after.catches==before.catches+1)
		assert(after.profile.coins>=before.profile.coins and after.profile.coins<=1000000000)
		if result and result.result then
			assert(verb=="Release" and before.phase=="Reeling" and argument==before.attemptId and canFish)
			local key=id..":"..tostring(before.attemptId)
			assert(not rewards[key],"an old attempt received a second reward")
			rewards[key],total=true,total+1
			assert(after.profile.coins-before.profile.coins==result.result.coins+result.result.goalBonus)
			assert(result.result.castBonusPercent==0 or result.result.castBonusPercent==5 or result.result.castBonusPercent==10)
		else assert(after.catches==before.catches,"count changed without a successful result") end
	end
	assert(total>=15,"traffic did not exercise enough successful completions")
end)



test("explicit charging cancellation wins over the auto-launch deadline", function()
	local Catalog=require("../src/shared/FishCatalog")
	local Progression=require("../src/server/FishingProgression")
	local selections=0
	local progression=Progression.new(Catalog,function()selections+=1;return.5 end)
	local profile=progression.create();profile.catches,profile.goalIndex=10,#Catalog.Goals+1
	for _,species in Catalog.Species do if species.Level==0 then profile.best[species.Id]=1 end end
	local e=Engine.new(Config,Rules,progression);e:addPlayer(1,0,profile)
	local wind=assert(e:command(1,"BeginCast",nil,0,true))
	local ended=assert(e:command(1,"Cancel",wind.attemptId,wind.expiresAt+.01,true))
	assert(ended.phase=="Idle" and ended.catches==10 and selections==0)
	assert(e:command(1,"QuickCast",wind.attemptId,wind.expiresAt+.02,true)==nil)
end)



test("earned rod widths grade their exact gold edges and retain the original Fine band", function()
	local Catalog=require("../src/shared/FishCatalog")
	for _,rod in Catalog.Rods do
		local width,center=rod.TimingWidth,.68
		assert(Rules.qualityAt(center-width/2,center,width)=="Brilliant")
		assert(Rules.qualityAt(center+width/2,center,width)=="Brilliant")
		assert(Rules.qualityAt(center-width/2-.000001,center,width)=="Fine")
		assert(Rules.qualityAt(center+width/2+.000001,center,width)=="Fine")
		assert(Rules.qualityAt(center-.19,center,width)=="Fine" and Rules.qualityAt(center+.159,center,width)=="Fine")
		assert(Rules.qualityAt(center+.161,center,width)=="Normal")
	end
	assert(Rules.qualityAt(.755,.68)=="Fine" and Rules.qualityAt(.755,.68,.156)=="Brilliant")
	for _,bad in {0/0,math.huge,-math.huge} do assert(Rules.qualityAt(.755,.68,bad)=="Fine") end
	assert(Rules.qualityAt(.725,.68,-100)=="Fine") -- Clamped to the minimum width.
	assert(Rules.qualityAt(.789,.68,100)=="Brilliant" and Rules.qualityAt(.791,.68,100)=="Fine")
end)

test("each equipped earned rod binds its own gold width at actual cast launch", function()
	local Catalog=require("../src/shared/FishCatalog")
	local Progression=require("../src/server/FishingProgression")
	for level=0,3 do
		local progression=Progression.new(Catalog,function()return.5 end)
		local p=progression.create();p.level,p.catches,p.goalIndex=level,10,#Catalog.Goals+1
		for _,species in Catalog.Species do if species.Level<=level then p.best[species.Id]=1 end end
		local e=Engine.new(Config,Rules,progression);e:addPlayer(1,0,p)
		local wind=assert(e:command(1,"BeginCast",nil,0,true,"harbor"))
		assert(wind.timingWidth==nil,"wind-up leaked a not-yet-bound fish window")
		local cast=assert(e:command(1,"QuickCast",wind.attemptId,.1,true))
		assert(cast.timingWidth==Catalog.Rods[level+1].TimingWidth)
		local reel=assert(e:command(1,"Hold",cast.attemptId,cast.readyAt,true))
		local result=assert(e:command(1,"Release",reel.attemptId,reel.chargeAt+reel.duration*(reel.timingCenter+.075),true))
		assert(result.result.quality==(if level==0 then "Fine" else "Brilliant"))
	end
end)

test("first three successful catches keep the intro width even with an advanced equipped rod", function()
	local Catalog=require("../src/shared/FishCatalog")
	local Progression=require("../src/server/FishingProgression")
	local progression=Progression.new(Catalog,function()return.5 end)
	local p=progression.create();p.level=3
	local e=Engine.new(Config,Rules,progression);e:addPlayer(1,0,p)
	local time=0
	for index=1,4 do
		local cast=assert(e:command(1,"Start",nil,time,true,"harbor"))
		assert(cast.timingWidth==(if index<=3 then .14 else .188))
		local reel=assert(e:command(1,"Hold",cast.attemptId,cast.readyAt,true))
		local landed=assert(e:command(1,"Release",reel.attemptId,reel.chargeAt+reel.duration*reel.timingCenter,true))
		time=landed.nextStart
	end
end)

test("client-edited widths cannot widen an active server window or grant a grade", function()
	local Catalog=require("../src/shared/FishCatalog")
	local Progression=require("../src/server/FishingProgression")
	local progression=Progression.new(Catalog,function()return.5 end)
	local p=progression.create();p.catches,p.coins=10,1000;p.best.pufflet=1
	local e=Engine.new(Config,Rules,progression);e:addPlayer(1,0,p)
	local cast=assert(e:command(1,"Start",nil,0,true,"harbor"))
	cast.timingWidth,cast.profile.level,cast.profile.timingWidth=1,3,1
	local reel=assert(e:command(1,"Hold",cast.attemptId,cast.readyAt,true))
	assert(reel.timingWidth==.14 and reel.profile.level==0)
	assert(e:command(1,"Release",{id=reel.attemptId,timingWidth=.22},reel.chargeAt+1,true)==nil)
	local result=assert(e:command(1,"Release",reel.attemptId,reel.chargeAt+reel.duration*(reel.timingCenter+.09),true))
	assert(result.result.quality=="Fine" and result.profile.level==0)
end)

test("an earned upgrade takes effect on the next cast and cannot replace an active width", function()
	local Catalog=require("../src/shared/FishCatalog")
	local Progression=require("../src/server/FishingProgression")
	local progression=Progression.new(Catalog,function()return.5 end)
	local p=progression.create();p.coins,p.catches,p.goalIndex=1000,10,#Catalog.Goals+1;p.best.pufflet=1
	local e=Engine.new(Config,Rules,progression);e:addPlayer(1,0,p)
	local wind=assert(e:command(1,"BeginCast",nil,0,true,"harbor"))
	assert(e:command(1,"Upgrade",0,.05,true).profile.level==0)
	local cast=assert(e:command(1,"QuickCast",wind.attemptId,.1,true))
	assert(e:command(1,"Upgrade",0,.2,true).timingWidth==.14)
	local reel=assert(e:command(1,"Hold",cast.attemptId,cast.readyAt,true))
	assert(e:command(1,"Upgrade",0,reel.chargeAt,true).timingWidth==.14)
	local result=assert(e:command(1,"Release",reel.attemptId,reel.chargeAt+reel.duration*reel.timingCenter,true))
	local upgraded=assert(e:command(1,"Upgrade",0,result.nextStart,true))
	assert(upgraded.purchase.success and upgraded.profile.level==1 and upgraded.profile.timingWidth==.156)
	local nextCast=assert(e:command(1,"Start",nil,result.nextStart+.3,true,"harbor"))
	assert(nextCast.timingWidth==.156 and e:exportProfile(1).level==1)
end)

test("feedback distinguishes a missed fish from intentional cancellation and interruption", function()
	local e = setup()
	local a = charge(e, 1, 0)
	local ended = assert(e:command(1, "Cancel", a.attemptId, a.chargeAt, true))
	assert(ended.outcome == "Cancelled" and ended.result == nil and ended.catches == 0)
	a = charge(e, 1, ended.nextStart)
	ended = assert(e:interrupt(1, a.chargeAt, "A different menu or character owns play now."))
	assert(ended.outcome == "Interrupted" and ended.result == nil)
	a = charge(e, 1, ended.nextStart)
	ended = assert(e:tick(1, a.chargeAt, false))
	assert(ended.outcome == "Interrupted")
	a = charge(e, 1, ended.nextStart)
	ended = assert(e:command(1, "Release", a.attemptId, a.chargeAt + a.duration * .1, true))
	assert(ended.outcome == "Missed" and ended.catches == 0)
	a = charge(e, 1, ended.nextStart)
	ended = assert(e:tick(1, a.expiresAt + .01, true))
	assert(ended.outcome == "Missed" and ended.catches == 0)
	a = charge(e, 1, ended.nextStart)
	ended = assert(e:command(1, "Release", a.attemptId, a.chargeAt + a.duration * .68, true))
	assert(ended.outcome == "Caught" and ended.catches == 1 and ended.result)
end)

print(string.format("%d tests passed; 0 skipped", passed))
