--!strict
local Rules = require("../src/shared/IslandTravelRules")
local passed = 0
local function test(name: string, callback: () -> ())
	local ok, reason = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(reason), 0) end
	passed += 1
	print("PASS " .. name)
end

test("only the five authored destinations are accepted", function()
	assert(#Rules.Destinations == 5)
	for _, item in Rules.Destinations do assert(Rules.isDestination(item.Id)) end
	for _, invalid in { "", "Harbor", "other_game", "../harbor", string.rep("a", 1000), 1, true, {}, 0 / 0 } do
		assert(not Rules.isDestination(invalid))
	end
	assert(not Rules.isDestination(nil))
end)

test("clients cannot request travel without a server-opened menu", function()
	local state = Rules.new()
	assert(state:take(1, "cove", 1, 0) == nil)
	assert(state:source(1) == nil)
end)

test("menus require a known source and a nearby living-character distance", function()
	local state = Rules.new()
	assert(not state:open(1, "unknown", 1, 0))
	for _, distance in { -1, 18.01, math.huge, -math.huge, 0 / 0 } do
		assert(not state:open(1, "harbor", 1, distance))
	end
	assert(state:open(1, "harbor", 1, Rules.MaxDistance))
end)

test("proximity is checked again when a destination is selected", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 3))
	assert(state:take(1, "summit", 2, 19) == nil)
	assert(state:take(1, "summit", 2, math.huge) == nil)
	assert(state:take(1, "summit", 2, 0 / 0) == nil)
	assert(state:take(1, "summit", 2, -1) == nil)
	assert(state:take(1, "summit", 2, Rules.MaxDistance) ~= nil)
end)

test("the current island cannot be selected", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2))
	assert(state:take(1, "harbor", 2, 2) == nil)
	assert(state:take(1, "forest", 2, 2) ~= nil)
end)

test("malformed destination payloads never consume a menu", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2))
	for _, invalid in { false, 5, {}, "missing", string.rep("cove", 1000) } do
		assert(state:take(1, invalid, 2, 2) == nil)
		assert(state:source(1) == "harbor")
	end
	assert(state:take(1, nil, 2, 2) == nil)
end)

test("expired menus cannot authorize travel", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2))
	assert(state:take(1, "cove", 1 + Rules.MenuLifetime, 2) == nil)
	assert(state:open(1, "harbor", 40, 2))
	assert(state:take(1, "cove", 40 + Rules.MenuLifetime - 0.01, 2) ~= nil)
end)

test("non-finite clocks cannot open or consume menus", function()
	local state = Rules.new()
	for _, now in { math.huge, -math.huge, 0 / 0 } do assert(not state:open(1, "harbor", now, 2)) end
	assert(state:open(1, "harbor", 1, 2))
	for _, now in { math.huge, -math.huge, 0 / 0 } do assert(state:take(1, "cove", now, 2) == nil) end
end)

test("prompt spam cannot replace a fresh menu", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2))
	assert(not state:open(1, "forest", 1.1, 2))
	assert(state:source(1) == "harbor")
	assert(state:open(1, "forest", 1.5, 2))
	assert(state:source(1) == "forest")
end)

test("an accepted request consumes the menu and preserves server source", function()
	local state = Rules.new()
	assert(state:open(1, "blossom", 1, 2))
	local ticket = assert(state:take(1, "summit", 2, 2))
	assert(ticket.source == "blossom" and ticket.destination == "summit")
	assert(state:source(1) == nil and state:isPending(1, ticket))
end)

test("a pending stream request blocks duplicate requests and new menus", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2))
	local ticket = assert(state:take(1, "forest", 2, 2))
	assert(state:take(1, "summit", 3, 2) == nil)
	assert(not state:open(1, "forest", 9, 2))
	assert(state:isPending(1, ticket))
end)

test("finishing the exact pending ticket permits the next trip after cooldown", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2))
	local ticket = assert(state:take(1, "forest", 2, 2))
	assert(state:finish(1, ticket))
	assert(not state:isPending(1, ticket))
	assert(not state:open(1, "forest", 2.5, 2))
	assert(state:open(1, "forest", 2 + Rules.Cooldown, 2))
	assert(state:take(1, "cove", 2 + Rules.Cooldown, 2) ~= nil)
end)

test("a copied or stale ticket cannot finish a current request", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2))
	local first = assert(state:take(1, "forest", 2, 2))
	assert(not state:finish(1, { source = first.source, destination = first.destination }))
	assert(state:isPending(1, first))
	state:remove(1)
	assert(state:open(1, "harbor", 3, 2))
	local second = assert(state:take(1, "cove", 4, 2))
	assert(not state:isPending(1, first) and not state:finish(1, first))
	assert(state:isPending(1, second))
end)

test("leaving invalidates pending work and releases per-player state", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2))
	local ticket = assert(state:take(1, "forest", 2, 2))
	state:remove(1)
	assert(not state:isPending(1, ticket) and state:source(1) == nil)
	assert(not state:finish(1, ticket))
	assert(state:open(1, "harbor", 2.1, 2))
end)

test("different players travel independently", function()
	local state = Rules.new()
	assert(state:open(1, "harbor", 1, 2) and state:open(2, "cove", 1, 2))
	local one = assert(state:take(1, "forest", 2, 2))
	local two = assert(state:take(2, "blossom", 2, 2))
	assert(not state:finish(1, two))
	assert(state:isPending(1, one) and state:isPending(2, two))
	state:remove(1)
	assert(state:isPending(2, two))
end)

print(string.format("%d island travel tests passed", passed))
