--!strict
-- Plain data. Every island has its own catches; all islands are free to visit.
export type Species = {
	Id: string, Name: string, Rarity: string, Level: number, Weight: number,
	Coins: number, Body: { number }, Fin: { number }, Shape: string, Hint: string,
	Zone: string, WeightMin: number, WeightMax: number,
	Difficulty: number, Behavior: string, Animation: string, Model: string,
	Requirements: { RodLevel: number }, Effects: { Style: string }, DiscoveryProtection: boolean,
}
local Catalog = {}
Catalog.Zones = {
	{ Id = "harbor", Name = "Sundrift Harbor", Hint = "Sunny starter fish and your first aquarium." },
	{ Id = "blossom", Name = "Petalwind Grove", Hint = "Petal-colored fish beneath the blossom trees." },
	{ Id = "forest", Name = "Evergreen Reach", Hint = "Woodland swimmers and the elusive Moonray." },
	{ Id = "cove", Name = "Tideglass Cove", Hint = "Tropical oddballs in a sheltered lagoon." },
	{ Id = "summit", Name = "Starfall Lookout", Hint = "Sky fish and a legendary Crownwhale." },
}
-- Weight is a relative spawn weight among eligible species in this pond, not a
-- percentage or a mass. WeightMin/WeightMax are kilograms. These are earned fish;
-- no paid rolls are involved. All original fifteen IDs and rewards remain valid.
Catalog.Species = {
	{ Id = "pufflet", Name = "Pufflet", Rarity = "Common", Level = 0, Weight = 40, Coins = 8, Zone = "harbor", WeightMin = .4, WeightMax = 2.2,
		Body = {255, 206, 99}, Fin = {247, 146, 107}, Shape = "Round", Hint = "Sundrift Harbor · A sunny little cloud drifter.",
		Difficulty = 0.05, Behavior = "Drift", Animation = "Paddle", Model = "pufflet", Requirements = { RodLevel = 0 }, Effects = { Style = "Ripple" }, DiscoveryProtection = true },
	{ Id = "mintfin", Name = "Mintfin", Rarity = "Common", Level = 0, Weight = 35, Coins = 9, Zone = "harbor", WeightMin = .6, WeightMax = 3.4,
		Body = {96, 221, 192}, Fin = {54, 157, 163}, Shape = "Long", Hint = "Sundrift Harbor · Follows the coolest cloud currents.",
		Difficulty = 0.10, Behavior = "Dart", Animation = "Dart", Model = "mintfin", Requirements = { RodLevel = 0 }, Effects = { Style = "Ripple" }, DiscoveryProtection = true },
	{ Id = "emberfin", Name = "Emberfin", Rarity = "Uncommon", Level = 0, Weight = 25, Coins = 12, Zone = "harbor", WeightMin = .8, WeightMax = 4.2,
		Body = {255, 139, 123}, Fin = {255, 212, 120}, Shape = "Spiky", Hint = "Sundrift Harbor · A warm glow beneath the mist.",
		Difficulty = 0.17, Behavior = "Surge", Animation = "Flick", Model = "emberfin", Requirements = { RodLevel = 0 }, Effects = { Style = "Wake" }, DiscoveryProtection = true },
	{ Id = "starwhisker", Name = "Starwhisker", Rarity = "Rare", Level = 1, Weight = 13, Coins = 22, Zone = "blossom", WeightMin = 1.2, WeightMax = 6.5,
		Body = {182, 164, 249}, Fin = {255, 220, 139}, Shape = "Whiskers", Hint = "Petalwind Grove · Breeze Rod · A shy stargazer.",
		Difficulty = 0.25, Behavior = "Drift", Animation = "Hover", Model = "starwhisker", Requirements = { RodLevel = 1 }, Effects = { Style = "Starlight" }, DiscoveryProtection = true },
	{ Id = "moonray", Name = "Moonray", Rarity = "Rare", Level = 1, Weight = 11, Coins = 24, Zone = "forest", WeightMin = 2, WeightMax = 9,
		Body = {124, 184, 249}, Fin = {192, 223, 255}, Shape = "Ray", Hint = "Evergreen Reach · Breeze Rod · A quiet woodland glider.",
		Difficulty = 0.28, Behavior = "Glide", Animation = "Glide", Model = "moonray", Requirements = { RodLevel = 1 }, Effects = { Style = "Starlight" }, DiscoveryProtection = true },
	{ Id = "aurorafin", Name = "Aurorafin", Rarity = "Epic", Level = 2, Weight = 7, Coins = 38, Zone = "summit", WeightMin = 2.5, WeightMax = 12,
		Body = {218, 146, 245}, Fin = {110, 241, 226}, Shape = "Lure", Hint = "Starfall Lookout · Nimbus Rod · A living aurora.",
		Difficulty = 0.36, Behavior = "Surge", Animation = "Pulse", Model = "aurorafin", Requirements = { RodLevel = 2 }, Effects = { Style = "Petals" }, DiscoveryProtection = true },
	{ Id = "petalperch", Name = "Petalperch", Rarity = "Common", Level = 0, Weight = 43, Coins = 10, Zone = "blossom", WeightMin = .3, WeightMax = 2.5,
		Body = {232, 157, 183}, Fin = {171, 104, 159}, Shape = "Round", Hint = "Petalwind Grove · Its fins look like floating petals.",
		Difficulty = 0.06, Behavior = "Drift", Animation = "Flutter", Model = "petalperch", Requirements = { RodLevel = 0 }, Effects = { Style = "Ripple" }, DiscoveryProtection = true },
	{ Id = "ribbonkoi", Name = "Ribbon Koi", Rarity = "Uncommon", Level = 0, Weight = 29, Coins = 14, Zone = "blossom", WeightMin = 1, WeightMax = 5.2,
		Body = {239, 223, 187}, Fin = {222, 117, 104}, Shape = "Ribbon", Hint = "Petalwind Grove · Dances through fallen blossoms.",
		Difficulty = 0.16, Behavior = "Glide", Animation = "Flow", Model = "ribbonkoi", Requirements = { RodLevel = 0 }, Effects = { Style = "Wake" }, DiscoveryProtection = true },
	{ Id = "mossback", Name = "Mossback", Rarity = "Common", Level = 0, Weight = 43, Coins = 11, Zone = "forest", WeightMin = .8, WeightMax = 4.8,
		Body = {121, 164, 99}, Fin = {219, 192, 116}, Shape = "Turtle", Hint = "Evergreen Reach · A little floating forest of its own.",
		Difficulty = 0.08, Behavior = "Drift", Animation = "Paddle", Model = "mossback", Requirements = { RodLevel = 0 }, Effects = { Style = "Ripple" }, DiscoveryProtection = true },
	{ Id = "pinepike", Name = "Pinepike", Rarity = "Uncommon", Level = 0, Weight = 28, Coins = 15, Zone = "forest", WeightMin = 1.5, WeightMax = 7.4,
		Body = {85, 152, 135}, Fin = {174, 209, 141}, Shape = "Long", Hint = "Evergreen Reach · A quick shadow under the pines.",
		Difficulty = 0.20, Behavior = "Dart", Animation = "Dart", Model = "pinepike", Requirements = { RodLevel = 0 }, Effects = { Style = "Wake" }, DiscoveryProtection = true },
	{ Id = "bubblesquid", Name = "Bubble Squid", Rarity = "Common", Level = 0, Weight = 42, Coins = 11, Zone = "cove", WeightMin = .3, WeightMax = 3.2,
		Body = {132, 197, 224}, Fin = {208, 179, 226}, Shape = "Squid", Hint = "Tideglass Cove · Thinks every bubble is a new friend.",
		Difficulty = 0.09, Behavior = "Surge", Animation = "Pulse", Model = "bubblesquid", Requirements = { RodLevel = 0 }, Effects = { Style = "Ripple" }, DiscoveryProtection = true },
	{ Id = "sunskipper", Name = "Sunskipper", Rarity = "Uncommon", Level = 0, Weight = 28, Coins = 16, Zone = "cove", WeightMin = .6, WeightMax = 4.7,
		Body = {229, 180, 89}, Fin = {103, 184, 192}, Shape = "Wings", Hint = "Tideglass Cove · Skips across the warm lagoon.",
		Difficulty = 0.19, Behavior = "Dart", Animation = "Skip", Model = "sunskipper", Requirements = { RodLevel = 0 }, Effects = { Style = "Wake" }, DiscoveryProtection = true },
	{ Id = "coralcrown", Name = "Coralcrown", Rarity = "Epic", Level = 2, Weight = 8, Coins = 34, Zone = "cove", WeightMin = 1.3, WeightMax = 8.6,
		Body = {221, 133, 130}, Fin = {229, 196, 149}, Shape = "Crown", Hint = "Tideglass Cove · Nimbus Rod · Wears its own coral reef.",
		Difficulty = 0.34, Behavior = "Glide", Animation = "Hover", Model = "coralcrown", Requirements = { RodLevel = 2 }, Effects = { Style = "Petals" }, DiscoveryProtection = true },
	{ Id = "cloudmoth", Name = "Cloudmoth", Rarity = "Uncommon", Level = 0, Weight = 47, Coins = 14, Zone = "summit", WeightMin = .2, WeightMax = 2.9,
		Body = {211, 219, 232}, Fin = {152, 173, 210}, Shape = "Wings", Hint = "Starfall Lookout · A tiny sky traveler with enormous fins.",
		Difficulty = 0.18, Behavior = "Glide", Animation = "Flutter", Model = "cloudmoth", Requirements = { RodLevel = 0 }, Effects = { Style = "Wake" }, DiscoveryProtection = true },
	{ Id = "crownwhale", Name = "Crownwhale", Rarity = "Legendary", Level = 3, Weight = 3, Coins = 65, Zone = "summit", WeightMin = 8, WeightMax = 28,
		Body = {119, 148, 207}, Fin = {222, 190, 108}, Shape = "Whale", Hint = "Starfall Lookout · Aurora Rod · The gentle king of the sky.",
		Difficulty = 0.44, Behavior = "Surge", Animation = "Heavy", Model = "crownwhale", Requirements = { RodLevel = 3 }, Effects = { Style = "Crown" }, DiscoveryProtection = true },
	{ Id = "veilfin", Name = "Veilfin", Rarity = "Mythical", Level = 3, Weight = 2, Coins = 55, Zone = "forest", WeightMin = 3, WeightMax = 16,
		Body = {104, 115, 167}, Fin = {207, 166, 218}, Shape = "Veil", Hint = "Evergreen Reach · Aurora Rod · A ribbon of dusk beneath the pines.",
		Difficulty = .50, Behavior = "Glide", Animation = "Undulate", Model = "veilfin", Requirements = { RodLevel = 3 }, Effects = { Style = "Aurora" }, DiscoveryProtection = false },
	{ Id = "eclipse", Name = "Eclipse", Rarity = "Secret", Level = 3, Weight = 1, Coins = 85, Zone = "summit", WeightMin = 5, WeightMax = 22,
		Body = {54, 62, 94}, Fin = {169, 210, 222}, Shape = "Eclipse", Hint = "Starfall Lookout · Aurora Rod · A crescent with a wandering comet tail.",
		Difficulty = .60, Behavior = "Surge", Animation = "Orbit", Model = "eclipse", Requirements = { RodLevel = 3 }, Effects = { Style = "Eclipse" }, DiscoveryProtection = false },
} :: { Species }
Catalog.Rods = {
	{ Name = "Driftwood Rod", Cost = 0, Bonus = 0, Description = "Catch starter species on all five islands." },
	{ Name = "Breeze Rod", Cost = 32, Bonus = 15, Description = "Find Starwhisker and Moonray. Earn 15% more coins." },
	{ Name = "Nimbus Rod", Cost = 90, Bonus = 30, Description = "Find Aurorafin and Coralcrown. Earn 30% more coins." },
	{ Name = "Aurora Rod", Cost = 160, Bonus = 45, Description = "Seek Crownwhale, Veilfin and Eclipse. Earn 45% more coins." },
}
-- Preserve all original ten goal positions/targets/rewards so saves retain earned
-- milestones; the extended collection goal is appended rather than inserted.
Catalog.Goals = {
	{ Title = "Land your first fish", Kind = "Catches", Target = 1, Reward = 10 },
	{ Title = "Discover 3 different species", Kind = "Species", Target = 3, Reward = 20 },
	{ Title = "Upgrade to the Breeze Rod", Kind = "Rod", Target = 1, Reward = 20 },
	{ Title = "Land a Brilliant catch", Kind = "Brilliant", Target = 1, Reward = 25 },
	{ Title = "Discover 6 different species", Kind = "Species", Target = 6, Reward = 50 },
	{ Title = "Catch fish on all 5 islands", Kind = "Zones", Target = 5, Reward = 75 },
	{ Title = "Upgrade to the Nimbus Rod", Kind = "Rod", Target = 2, Reward = 40 },
	{ Title = "Discover 10 different species", Kind = "Species", Target = 10, Reward = 80 },
	{ Title = "Find the legendary Crownwhale", Kind = "Crownwhale", Target = 1, Reward = 100 },
	{ Title = "Discover 15 different species", Kind = "Species", Target = 15, Reward = 150 },
	{ Title = "Complete your field journal", Kind = "Species", Target = 17, Reward = 75 },
}
Catalog.AquariumStyles = {
	{ Id = "lagoon", Name = "Lagoon", Cost = 0, Colors = { Base = {75, 134, 143}, Trim = {204, 188, 139}, Accent = {106, 187, 191} } },
	{ Id = "blossom", Name = "Blossom Garden", Cost = 65, Colors = { Base = {157, 112, 139}, Trim = {220, 193, 173}, Accent = {216, 155, 183} } },
	{ Id = "observatory", Name = "Star Observatory", Cost = 140, Colors = { Base = {91, 109, 157}, Trim = {211, 182, 111}, Accent = {148, 167, 220} } },
	{ Id = "coral", Name = "Coral Reef", Cost = 110, Colors = { Base = {163, 116, 92}, Trim = {225, 200, 142}, Accent = {212, 136, 124} } },
}

function Catalog.get(id: string?): Species
	for _, species in Catalog.Species do
		if species.Id == id then return species end
	end
	return Catalog.Species[1]
end

function Catalog.zone(id: string?): any?
	for _, zone in Catalog.Zones do if zone.Id == id then return zone end end
	return nil
end

function Catalog.style(id: string?): any?
	for _, style in Catalog.AquariumStyles do if style.Id == id then return style end end
	return nil
end

return Catalog
