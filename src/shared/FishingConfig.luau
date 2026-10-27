--!strict
-- Shared presentation/tuning values. The server still owns every attempt.
return table.freeze({
	PreparationTime = 0.8,
	CastDuration = 0.65,
	CastChargeDuration = 1.0,
	CastChargeTimeout = 2.2,
	DynamicBites = true,
	BiteDelayMin = 0.35,
	BiteDelayMax = 1.05,
	BiteTimeout = 12,
	ChargeLeadTime = 0.3,
	ChargeDuration = 2.8,
	DynamicTiming = true,
	StartCooldown = 0.6,
	MaxDistance = 16,
	RequestCapacity = 12,
	RequestsPerSecond = 5,
	SpeciesName = "Pufflet",
	CreatePrototypeWorld = true,
	EnableSaving = true,
	SaveInStudio = false,
})
