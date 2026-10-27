--!strict
-- Player-owned preferences share the existing profile/save path. No UI or
-- native persistence is emulated by these state and migration tests.
local Catalog = require("../src/shared/FishCatalog")
local Progression = require("../src/server/FishingProgression")
local Engine = require("../src/server/FishingEngine")
local Config = require("../src/shared/FishingConfig")
local Rules = require("../src/shared/FishingRules")
local SaveRules = require("../src/server/FishingSaveRules")
local progression = Progression.new(Catalog, function() return 0 end)
local saves = SaveRules.new(Catalog, progression)
local passed = 0
local function test(name: string, run: () -> ())
	local ok, reason = pcall(run)
	if not ok then error("FAIL " .. name .. ": " .. tostring(reason), 0) end
	passed += 1
	print("PASS " .. name)
end
local function preferences(sound: boolean, reduced: boolean)
	return { soundEnabled = sound, reducedEffects = reduced }
end

test("new profiles have independent sound-on and effects-normal preferences", function()
	local a, b = progression.create(), progression.create()
	assert(a.preferences.soundEnabled and not a.preferences.reducedEffects)
	a.preferences.soundEnabled, a.preferences.reducedEffects = false, true
	assert(b.preferences.soundEnabled and not b.preferences.reducedEffects)
	assert(saves.validate(a) and saves.validate(b))
end)

test("legacy version-one profiles migrate defaults without changing earned values", function()
	local old = assert(saves.acquire(nil, "legacy", 1000))
	old.profile.coins, old.profile.preferences, old.lease = 77, nil, nil
	assert(saves.validate(old.profile))
	local copy = progression.copy(old.profile)
	local snapshot = progression.snapshot(old.profile)
	local loaded = assert(saves.acquire(old, "new-owner", 1000))
	assert(copy.preferences.soundEnabled and not copy.preferences.reducedEffects)
	assert(snapshot.preferences.soundEnabled and not snapshot.preferences.reducedEffects)
	assert(loaded.profile.preferences.soundEnabled and not loaded.profile.preferences.reducedEffects)
	assert(copy.coins == 77 and loaded.profile.coins == 77 and loaded.version == 1)
	assert(old.profile.preferences == nil and old.profile.coins == 77,
		"migration mutated its UpdateAsync input")
end)

test("preference updates copy both booleans and do not change gameplay progress", function()
	local p = progression.create()
	progression.catch(p, "Brilliant", "harbor")
	local before = progression.copy(p)
	for _, value in { preferences(false, true), preferences(false, false), preferences(true, true), preferences(true, false) } do
		local sound, reduced = value.soundEnabled, value.reducedEffects
		assert(progression.setPreferences(p, value))
		value.soundEnabled, value.reducedEffects = not sound, not reduced
		assert(p.preferences.soundEnabled == sound and p.preferences.reducedEffects == reduced)
	end
	assert(p.coins == before.coins and p.catches == before.catches and p.level == before.level
		and p.goalIndex == before.goalIndex and p.best.pufflet == before.best.pufflet
		and p.records.pufflet == before.records.pufflet and p.display[1] == before.display[1])
end)

test("malformed preference payloads leave previous settings intact", function()
	local p = progression.create()
	assert(progression.setPreferences(p, preferences(false, true)))
	local previous = p.preferences
	for _, payload in { false, true, 1, "off", {}, { soundEnabled = false }, { reducedEffects = true },
		{ soundEnabled = 0, reducedEffects = true }, { soundEnabled = true, reducedEffects = {} },
		{ soundEnabled = true, reducedEffects = false, coins = 999999 },
		{ soundEnabled = true, reducedEffects = false, [1] = true },
		{ soundEnabled = true, reducedEffects = false, preferences = preferences(false, true) } } do
		assert(not progression.setPreferences(p, payload))
		assert(p.preferences == previous and not p.preferences.soundEnabled and p.preferences.reducedEffects)
	end
	assert(not progression.setPreferences(p, nil))
end)

test("copy and snapshot preferences cannot alias server-owned values", function()
	local p = progression.create()
	assert(progression.setPreferences(p, preferences(false, true)))
	local copied, snapshot = progression.copy(p), progression.snapshot(p)
	copied.preferences.soundEnabled = true
	snapshot.preferences.reducedEffects = false
	assert(not p.preferences.soundEnabled and p.preferences.reducedEffects)
	assert(snapshot.preferences.soundEnabled == false and copied.preferences.reducedEffects == true)
end)

test("save validation accepts legacy absence but rejects partial or extra settings", function()
	local p = progression.create()
	for _, value in { false, "bad", {}, { soundEnabled = true }, { reducedEffects = false },
		{ soundEnabled = true, reducedEffects = 0 }, { soundEnabled = true, reducedEffects = false, extra = true } } do
		p.preferences = value
		assert(not saves.validate(p))
	end
	p.preferences = nil; assert(saves.validate(p))
	p.preferences = preferences(false, true); assert(saves.validate(p))
end)

test("Idle requests acknowledge only the requesting player's detached preferences", function()
	local engine = Engine.new(Config, Rules, progression)
	engine:addPlayer(1, 0); engine:addPlayer(2, 0)
	local input = preferences(false, true)
	local packet = assert(engine:command(1, "Preferences", input, 1, false))
	assert(packet.phase == "Idle" and packet.preferencesChanged == true and packet.purchase == nil and packet.result == nil)
	assert(packet.profile.coins == 0 and packet.catches == 0 and packet.attemptId == nil)
	assert(not packet.profile.preferences.soundEnabled and packet.profile.preferences.reducedEffects)
	input.soundEnabled = true; packet.profile.preferences.reducedEffects = false
	local stored = assert(engine:exportProfile(1))
	assert(not stored.preferences.soundEnabled and stored.preferences.reducedEffects)
	assert(assert(engine:exportProfile(2)).preferences.soundEnabled)
	local repeated = assert(engine:command(1, "Preferences", preferences(false, true), 2, false))
	assert(repeated.preferencesChanged == true, "an unchanged valid request must acknowledge its client")
end)

test("active attempts reject settings without launch, reward, cancellation or reroll", function()
	for _, phase in { "ChargingCast", "Waiting", "Reeling" } do
		local engine = Engine.new(Config, Rules, progression)
		engine:addPlayer(1, 0)
		local packet = assert(engine:command(1, if phase == "ChargingCast" then "BeginCast" else "Start", nil, 1, true, "harbor"))
		if phase == "Reeling" then packet = assert(engine:command(1, "Hold", packet.attemptId, packet.readyAt, true)) end
		local time = if phase == "ChargingCast" then packet.expiresAt + 1 else packet.readyAt + .1
		local rejected = assert(engine:command(1, "Preferences", preferences(false, true), time, true, "harbor"))
		assert(rejected.phase == phase and rejected.attemptId == packet.attemptId and rejected.preferencesChanged == nil)
		assert(rejected.purchase == nil and rejected.result == nil and rejected.catches == 0)
		assert(rejected.profile.preferences.soundEnabled and not rejected.profile.preferences.reducedEffects)
		assert(engine:command(1, "Preferences", { soundEnabled = true, reducedEffects = false, extra = true }, time + .1, true) == nil)
	end
end)

test("malformed settings consume the existing request budget without changing profiles", function()
	local engine = Engine.new(Config, Rules, progression)
	engine:addPlayer(1, 0)
	for _ = 1, Config.RequestCapacity do
		assert(engine:command(1, "Preferences", {}, 0, false) == nil)
	end
	assert(engine:command(1, "Preferences", preferences(false, true), 0, false) == nil)
	assert(assert(engine:exportProfile(1)).preferences.soundEnabled)
	assert(assert(engine:command(1, "Preferences", preferences(false, true), 1, false)).preferencesChanged)
	local plain = Engine.new(Config, Rules)
	plain:addPlayer(2, 0)
	assert(plain:command(2, "Preferences", preferences(false, true), 1, false) == nil)
end)

test("a lost final-save response retains committed preferences instead of stale defaults", function()
	local old = assert(saves.acquire(nil, "owner", 1000))
	local current = progression.create()
	assert(progression.setPreferences(current, preferences(false, true)))
	local operation = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
	local committed = assert(saves.save(old, current, "owner", 1010, true, operation))
	local retried = assert(saves.save(committed, progression.create(), "owner", 1012, true, operation))
	assert(not retried.profile.preferences.soundEnabled and retried.profile.preferences.reducedEffects)
	local loaded = assert(saves.acquire(retried, "next-owner", 1012))
	assert(not loaded.profile.preferences.soundEnabled and loaded.profile.preferences.reducedEffects)
	assert(loaded.profile.coins == 0 and loaded.profile.catches == 0)
end)

print(string.format("%d preference state/migration tests passed; 0 skipped", passed))
