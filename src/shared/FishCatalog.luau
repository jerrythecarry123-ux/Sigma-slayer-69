--!strict
-- Plain data so server progression can be tested without Roblox services.
export type Species = {
	Id: string, Name: string, Rarity: string, Level: number, Weight: number,
	Coins: number, Body: { number }, Fin: { number }, Shape: string, Hint: string,
}
local Catalog = {}
Catalog.Species = {
	{ Id = "pufflet", Name = "Pufflet", Rarity = "Common", Level = 0, Weight = 40, Coins = 8,
		Body = {255, 206, 99}, Fin = {247, 146, 107}, Shape = "Round", Hint = "A sunny little cloud drifter." },
	{ Id = "mintfin", Name = "Mintfin", Rarity = "Common", Level = 0, Weight = 35, Coins = 9,
		Body = {96, 221, 192}, Fin = {54, 157, 163}, Shape = "Long", Hint = "Follows the coolest cloud currents." },
	{ Id = "emberfin", Name = "Emberfin", Rarity = "Uncommon", Level = 0, Weight = 25, Coins = 12,
		Body = {255, 139, 123}, Fin = {255, 212, 120}, Shape = "Spiky", Hint = "A warm glow beneath the mist." },
	{ Id = "starwhisker", Name = "Starwhisker", Rarity = "Rare", Level = 1, Weight = 16, Coins = 18,
		Body = {182, 164, 249}, Fin = {255, 220, 139}, Shape = "Whiskers", Hint = "Breeze Rod unlocks this stargazer." },
	{ Id = "moonray", Name = "Moonray", Rarity = "Rare", Level = 1, Weight = 12, Coins = 22,
		Body = {124, 184, 249}, Fin = {192, 223, 255}, Shape = "Ray", Hint = "Breeze Rod reaches its quiet current." },
	{ Id = "aurorafin", Name = "Aurorafin", Rarity = "Epic", Level = 2, Weight = 7, Coins = 35,
		Body = {218, 146, 245}, Fin = {110, 241, 226}, Shape = "Lure", Hint = "Nimbus Rod reveals a living aurora." },
} :: { Species }
Catalog.Rods = {
	{ Name = "Driftwood Rod", Cost = 0, Bonus = 0, Description = "Your first three species await." },
	{ Name = "Breeze Rod", Cost = 32, Bonus = 15, Description = "Unlock 2 rare species. Earn 15% more coins." },
	{ Name = "Nimbus Rod", Cost = 90, Bonus = 30, Description = "Unlock Aurorafin. Earn 30% more coins." },
	{ Name = "Aurora Rod", Cost = 160, Bonus = 45, Description = "A golden rod. Earn 45% more coins." },
}
Catalog.Goals = {
	{ Title = "Land your first fish", Kind = "Catches", Target = 1, Reward = 10 },
	{ Title = "Discover 3 different species", Kind = "Species", Target = 3, Reward = 20 },
	{ Title = "Upgrade to the Breeze Rod", Kind = "Rod", Target = 1, Reward = 20 },
	{ Title = "Land a Brilliant catch", Kind = "Brilliant", Target = 1, Reward = 25 },
	{ Title = "Complete your field journal", Kind = "Species", Target = 6, Reward = 50 },
}

function Catalog.get(id: string?): Species
	for _, species in Catalog.Species do
		if species.Id == id then return species end
	end
	return Catalog.Species[1]
end

return Catalog
