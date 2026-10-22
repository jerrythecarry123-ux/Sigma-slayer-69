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

print(string.format("%d tests passed; 0 skipped", passed))
