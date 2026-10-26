--!strict
-- Shared presentation identity. Rank is presentation order, never a paid roll.
-- RGB triples keep the catalog usable by server rules and standalone tooling.
export type Definition = {
	Rank: number, Color: { number }, RevealDuration: number, Title: string,
	Effect: string, Description: string,
}

local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret" }
local all: { [string]: Definition } = {
	Common = { Rank = 1, Color = {143, 167, 156}, RevealDuration = .8, Title = "Common", Effect = "Ripple",
		Description = "Natural shapes and a quick, quiet reveal." },
	Uncommon = { Rank = 2, Color = {109, 182, 135}, RevealDuration = 1, Title = "Uncommon", Effect = "Wake",
		Description = "Distinctive fins and brighter fitted markings." },
	Rare = { Rank = 3, Color = {97, 168, 225}, RevealDuration = 1.35, Title = "Rare", Effect = "Starlight",
		Description = "Unusual silhouettes and a restrained star accent." },
	Epic = { Rank = 4, Color = {176, 135, 221}, RevealDuration = 1.9, Title = "Epic", Effect = "Petals",
		Description = "An individual crest or lure and a short staged reveal." },
	Legendary = { Rank = 5, Color = {231, 190, 92}, RevealDuration = 2.7, Title = "Legendary", Effect = "Crown",
		Description = "A regal silhouette, heavier movement and a golden reveal." },
	Mythical = { Rank = 6, Color = {220, 132, 183}, RevealDuration = 3.1, Title = "Mythical", Effect = "Aurora",
		Description = "Flowing segmented movement and a celestial veil." },
	Secret = { Rank = 7, Color = {139, 207, 221}, RevealDuration = 3.5, Title = "Secret", Effect = "Eclipse",
		Description = "A crescent silhouette and an asymmetric comet wake." },
}

for _, definition in all do
	table.freeze(definition.Color)
	table.freeze(definition)
end

local Rarity = { Order = table.freeze(order), All = table.freeze(all) }

function Rarity.get(name: string?): Definition
	return all[name or "Common"] or all.Common
end

return table.freeze(Rarity)
