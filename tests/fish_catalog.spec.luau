--!strict
-- Data contract and save-compatibility checks, without Roblox services.
local Catalog = require("../src/shared/FishCatalog")
local Rarity = require("../src/shared/FishRarity")
local passed = 0
local function test(name: string, fn: () -> ())
	local ok, message = pcall(fn)
	if not ok then error("FAIL " .. name .. ": " .. tostring(message), 0) end
	passed += 1
	print("PASS " .. name)
end

test("seven ordered immutable rarity identities have readable presentation bounds", function()
	assert(#Rarity.Order == 7 and table.isfrozen(Rarity) and table.isfrozen(Rarity.All))
	for rank, name in Rarity.Order do
		local definition = Rarity.get(name)
		assert(definition.Rank == rank and definition.Title == name)
		assert(table.isfrozen(definition) and table.isfrozen(definition.Color))
		assert(#definition.Color == 3 and definition.RevealDuration >= .5 and definition.RevealDuration <= 4)
		for _, channel in definition.Color do assert(channel >= 0 and channel <= 255) end
		assert(#definition.Effect > 0 and #definition.Description > 10)
	end
	assert(Rarity.get(nil) == Rarity.get("Common") and Rarity.get("forged") == Rarity.get("Common"))
end)

test("all species have complete compatible gameplay and renderer contracts", function()
	local ids, represented = {}, {}
	local behaviors = { Drift = true, Dart = true, Glide = true, Surge = true }
	local effects = {}
	for _, name in Rarity.Order do effects[Rarity.get(name).Effect] = true end
	for _, species in Catalog.Species do
		assert(not ids[species.Id] and Catalog.get(species.Id) == species and Catalog.zone(species.Zone))
		ids[species.Id], represented[species.Rarity] = true, true
		assert(Rarity.All[species.Rarity] and species.Model == species.Id and #species.Shape > 0 and #species.Animation > 0)
		assert(species.Level == species.Requirements.RodLevel and species.Level >= 0 and species.Level < #Catalog.Rods)
		assert(species.Difficulty >= 0 and species.Difficulty <= .6 and behaviors[species.Behavior])
		assert(effects[species.Effects.Style] and type(species.DiscoveryProtection) == "boolean")
		assert(species.Weight > 0 and species.Coins > 0 and species.WeightMin > 0 and species.WeightMax > species.WeightMin)
	end
	assert(#Catalog.Species == 17)
	for _, name in Rarity.Order do assert(represented[name], "unpopulated rarity: " .. name) end
end)

test("fifteen original saved IDs retain their rarity, habitat, unlock and base reward", function()
	local originals = {
		pufflet = { "Common", "harbor", 0, 8 }, mintfin = { "Common", "harbor", 0, 9 }, emberfin = { "Uncommon", "harbor", 0, 12 },
		starwhisker = { "Rare", "blossom", 1, 22 }, moonray = { "Rare", "forest", 1, 24 }, aurorafin = { "Epic", "summit", 2, 38 },
		petalperch = { "Common", "blossom", 0, 10 }, ribbonkoi = { "Uncommon", "blossom", 0, 14 }, mossback = { "Common", "forest", 0, 11 },
		pinepike = { "Uncommon", "forest", 0, 15 }, bubblesquid = { "Common", "cove", 0, 11 }, sunskipper = { "Uncommon", "cove", 0, 16 },
		coralcrown = { "Epic", "cove", 2, 34 }, cloudmoth = { "Uncommon", "summit", 0, 14 }, crownwhale = { "Legendary", "summit", 3, 65 },
	}
	for id, old in originals do
		local species = Catalog.get(id)
		assert(species.Id == id and species.Rarity == old[1] and species.Zone == old[2] and species.Level == old[3] and species.Coins == old[4])
		assert(species.DiscoveryProtection, "an existing discovery guarantee was removed")
	end
	assert(not Catalog.get("veilfin").DiscoveryProtection and not Catalog.get("eclipse").DiscoveryProtection)
end)

test("every free pond retains starter catches and exceptional odds remain relative", function()
	for _, zone in Catalog.Zones do
		local starters, weight = 0, 0
		for _, species in Catalog.Species do
			if species.Zone == zone.Id then
				weight += species.Weight
				if species.Level == 0 then starters += 1 end
			end
		end
		assert(starters >= 1 and weight > 0)
	end
	local veil, eclipse = Catalog.get("veilfin"), Catalog.get("eclipse")
	assert(veil.Weight == 2 and eclipse.Weight == 1 and veil.Level == 3 and eclipse.Level == 3)
end)

test("original milestone positions stay compatible and journal extension is appended", function()
	local targets = { 1, 3, 1, 1, 6, 5, 2, 10, 1, 15 }
	local rewards = { 10, 20, 20, 25, 50, 75, 40, 80, 100, 150 }
	for index, target in targets do
		assert(Catalog.Goals[index].Target == target and Catalog.Goals[index].Reward == rewards[index])
	end
	assert(#Catalog.Goals == 11 and Catalog.Goals[11].Target == #Catalog.Species)
	assert(Catalog.Goals[11].Title == "Complete your field journal")
end)

print(string.format("%d fish catalog tests passed; 0 skipped", passed))
