--!strict
local Config = require("../src/shared/FishingConfig")
local Rules = require("../src/shared/FishingRules")
local Engine = require("../src/server/FishingEngine")
local Locations = require("../src/server/FishingLocations")
local Catalog = require("../src/shared/FishCatalog")
local Progression = require("../src/server/FishingProgression")
local passed = 0
local function test(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
	passed += 1
	print("PASS " .. name)
end

local harbor = { name = "Harbor", x = 0, target = "harbor-water" }
local grove = { name = "Grove", x = 100, target = "grove-water" }
local overlap = { name = "Nearby dock", x = 10, target = "nearby-water" }

local function setup()
	local engine = Engine.new(Config, Rules)
	local locations = Locations.new()
	engine:addPlayer(1, 0)
	return engine, locations
end

local function command(engine: Engine.FishingEngine, locations: Locations.LocationState,
	userId: number, verb: string, attemptId: number?, now: number, x: number?, available: { any }?)
	local before = engine:snapshot(userId)
	local beforeId = if before then before.attemptId else nil
	local location = locations:forAttempt(userId, beforeId)
	if verb == "Start" and before and beforeId == nil and x ~= nil then
		local candidates = {}
		for _, item in available or { harbor, grove } do
			table.insert(candidates, { location = item, distance = math.abs(x - item.x) })
		end
		location = Locations.nearest(candidates, Config.MaxDistance)
	end
	local inRange = x ~= nil and location ~= nil and math.abs(x - location.x) <= Config.MaxDistance
	local packet = engine:command(userId, verb, attemptId, now, inRange)
	if verb == "Start" and packet then locations:acceptStart(userId, beforeId, packet, location) end
	return packet
end

test("nearest available casting area is selected across the map", function()
	assert(Locations.nearest({
		{ location = harbor, distance = 103 }, { location = grove, distance = 3 },
	}, Config.MaxDistance) == grove)
	assert(Locations.nearest({ { location = harbor, distance = 17 } }, Config.MaxDistance) == nil)
	assert(Locations.nearest({}, Config.MaxDistance) == nil)
end)

test("distance boundary is inclusive and ties remain stable", function()
	assert(Locations.nearest({ { location = harbor, distance = 16 } }, 16) == harbor)
	assert(Locations.nearest({
		{ location = harbor, distance = 5 }, { location = grove, distance = 5 },
	}, 16) == harbor)
end)

test("invalid distances cannot create a fishing location", function()
	for _, distance in { -1, math.huge, -math.huge, 0 / 0 } do
		assert(Locations.nearest({ { location = harbor, distance = distance } }, 16) == nil)
	end
	for _, limit in { -1, math.huge, 0 / 0 } do
		assert(Locations.nearest({ { location = harbor, distance = 0 } }, limit) == nil)
	end
end)

test("a successful Start binds only its server-selected location", function()
	local engine, locations = setup()
	assert(locations:last(1) == nil)
	local packet = assert(command(engine, locations, 1, "Start", nil, 0, 102))
	assert(packet.phase == "Waiting")
	assert(locations:last(1) == grove)
	assert(locations:forAttempt(1, packet.attemptId) == grove)
	assert(locations:forAttempt(1, packet.attemptId + 1) == nil)
end)

test("charging binds the accepted server location and its launch cannot retarget", function()
	local locations = Locations.new()
	assert(locations:acceptStart(1, nil, { phase = "ChargingCast", attemptId = 71 }, grove))
	assert(locations:forAttempt(1, 71) == grove)
	assert(not locations:acceptStart(1, 71, { phase = "Waiting", attemptId = 71 }, harbor))
	assert(not locations:acceptStart(1, 71, { phase = "ChargingCast", attemptId = 72 }, harbor))
	assert(locations:forAttempt(1, 71) == grove and locations:last(1) == grove)
end)

test("rejected phases and malformed attempt IDs cannot overwrite a binding", function()
	local locations = Locations.new()
	assert(locations:acceptStart(1, nil, { phase = "Waiting", attemptId = 1 }, harbor))
	for _, phase in { "Idle", "Reeling", "Connecting", "forged" } do
		assert(not locations:acceptStart(1, nil, { phase = phase, attemptId = 2 }, grove))
	end
	for _, id in { 0, -1, .5, math.huge, -math.huge, 0/0, "2", {} } do
		assert(not locations:acceptStart(1, nil, { phase = "ChargingCast", attemptId = id }, grove))
	end
	assert(not locations:acceptStart(1, nil, { phase = "ChargingCast" }, grove))
	assert(locations:last(1) == harbor and locations:forAttempt(1, 1) == harbor)
end)

test("walking to a nearby dock cannot retarget an active cast", function()
	local engine, locations = setup()
	local packet = assert(command(engine, locations, 1, "Start", nil, 0, 0, { harbor, overlap }))
	local retried = assert(command(engine, locations, 1, "Start", nil, 0.2, 10, { harbor, overlap }))
	assert(retried.attemptId == packet.attemptId)
	assert(locations:last(1) == harbor and locations:last(1).target == "harbor-water")
	assert(not locations:acceptStart(1, packet.attemptId, retried, overlap))
end)

test("entering another zone aborts instead of moving the active target", function()
	local engine, locations = setup()
	local packet = assert(command(engine, locations, 1, "Start", nil, 0, 0))
	local aborted = assert(command(engine, locations, 1, "Hold", packet.attemptId, 1, 100))
	assert(aborted.phase == "Idle" and aborted.catches == 0)
	assert(locations:last(1) == harbor)
	local nextPacket = assert(command(engine, locations, 1, "Start", nil, aborted.nextStart, 100))
	assert(nextPacket.phase == "Waiting" and nextPacket.attemptId ~= packet.attemptId)
	assert(locations:last(1) == grove)
end)

test("finished catch and idle Sync retain the real water target", function()
	local engine, locations = setup()
	local waiting = assert(command(engine, locations, 1, "Start", nil, 0, 100))
	local reeling = assert(command(engine, locations, 1, "Hold", waiting.attemptId, waiting.readyAt, 100))
	local time = reeling.chargeAt + Config.ChargeDuration * 0.68
	local result = assert(command(engine, locations, 1, "Release", waiting.attemptId, time, 100))
	assert(result.phase == "Idle" and result.catches == 1)
	assert(locations:last(1).target == "grove-water")
	assert(assert(command(engine, locations, 1, "Sync", nil, time, 0)).phase == "Idle")
	assert(locations:last(1) == grove)
end)

test("cooldown and out-of-range Start preserve the previous location", function()
	local engine, locations = setup()
	local waiting = assert(command(engine, locations, 1, "Start", nil, 0, 0))
	local ended = assert(command(engine, locations, 1, "Cancel", waiting.attemptId, 1, 0))
	assert(assert(command(engine, locations, 1, "Start", nil, 1.1, 100)).phase == "Idle")
	assert(locations:last(1) == harbor)
	assert(assert(command(engine, locations, 1, "Start", nil, ended.nextStart, 50)).phase == "Idle")
	assert(locations:last(1) == harbor)
end)

test("a workshop purchase cannot teleport the last cast back to the harbor", function()
	local progression = Progression.new(Catalog, function() return 0 end)
	local profile = progression.create()
	profile.coins = 100
	local engine = Engine.new(Config, Rules, progression)
	local locations = Locations.new()
	engine:addPlayer(1, 0, profile)
	local waiting = assert(command(engine, locations, 1, "Start", nil, 0, 100))
	assert(command(engine, locations, 1, "Cancel", waiting.attemptId, 1, 100))
	local purchase = assert(command(engine, locations, 1, "Upgrade", 0, 2, 0))
	assert(purchase.profile.level == 1)
	assert(locations:last(1) == grove and locations:last(1).target == "grove-water")
end)

test("rate-limited Start cannot replace the previous location", function()
	local engine, locations = setup()
	local waiting = assert(command(engine, locations, 1, "Start", nil, 0, 0))
	assert(command(engine, locations, 1, "Cancel", waiting.attemptId, 1, 0))
	for _ = 1, Config.RequestCapacity do command(engine, locations, 1, "Sync", nil, 2, 100) end
	assert(command(engine, locations, 1, "Start", nil, 2, 100) == nil)
	assert(locations:last(1) == harbor)
end)

test("death cannot bind a location and leaving clears all retained state", function()
	local engine, locations = setup()
	assert(assert(command(engine, locations, 1, "Start", nil, 0, nil)).phase == "Idle")
	assert(locations:last(1) == nil)
	local waiting = assert(command(engine, locations, 1, "Start", nil, 1, 0))
	assert(assert(command(engine, locations, 1, "Hold", waiting.attemptId, 2, nil)).phase == "Idle")
	locations:remove(1)
	engine:removePlayer(1)
	assert(locations:last(1) == nil and locations:forAttempt(1, waiting.attemptId) == nil)
end)

test("different players retain independent zones and attempt targets", function()
	local engine, locations = setup()
	engine:addPlayer(2, 0)
	local first = assert(command(engine, locations, 1, "Start", nil, 0, 0))
	local second = assert(command(engine, locations, 2, "Start", nil, 0, 100))
	assert(locations:forAttempt(1, first.attemptId) == harbor)
	assert(locations:forAttempt(2, second.attemptId) == grove)
	assert(locations:forAttempt(1, second.attemptId) == nil)
	locations:remove(1)
	assert(locations:last(2) == grove)
end)

print(string.format("%d tests passed; 0 skipped", passed))
