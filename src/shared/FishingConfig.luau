--!strict
-- Shared presentation/tuning values. The server still owns every attempt.
return table.freeze({
	PreparationTime = 0.8,
	BiteTimeout = 12,
	ChargeLeadTime = 0.3,
	ChargeDuration = 2.8,
	StartCooldown = 0.6,
	MaxDistance = 16,
	RequestCapacity = 12,
	RequestsPerSecond = 5,
	SpeciesName = "Pufflet",
	CreatePrototypeWorld = true,
})
