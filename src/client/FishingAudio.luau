--!strict
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Audio = {}
-- Same six shipped clips as v0.3. This release changes their mix, not the library.
local clips = {
	Cast = "rbxasset://sounds/action_jump.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Chime = "rbxasset://sounds/electronicpingshort.wav",
	Reel = "rbxasset://sounds/action_swim.mp3",
	Miss = "rbxasset://sounds/action_jump_land.mp3",
	Wind = "rbxasset://sounds/action_falling.mp3",
}
local trim = { Cast = 0.62, Splash = 0.65, Chime = 0.52, Reel = 0.5, Miss = 0.55, Wind = 0.5 }
function Audio.new()
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "CloudAnglersSounds", SoundService
	local group = Instance.new("SoundGroup")
	group.Name, group.Volume, group.Parent = "CloudAnglersMix", 0.75, SoundService
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name, eq.HighGain, eq.MidGain, eq.LowGain, eq.Parent = "SoftenUpperFrequencies", -7, -1, -2, group
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Name, compressor.Threshold, compressor.Ratio = "GentlePeakControl", -14, 3
	compressor.Attack, compressor.Release, compressor.GainMakeup, compressor.Parent = 0.02, 0.15, 0, group
	local templates: { [string]: Sound } = {}
	local preload: { Instance } = {}
	for name, path in clips do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.SoundGroup = name, path, group
		sound.Volume, sound.RollOffMinDistance, sound.RollOffMaxDistance = 0.2, 7, 48
		sound.RollOffMode, sound.Parent = Enum.RollOffMode.InverseTapered, folder
		templates[name] = sound
		table.insert(preload, sound)
	end
	task.spawn(function()
		local ok, err = pcall(function() ContentProvider:PreloadAsync(preload) end)
		if not ok then warn("Cloud Anglers: sound preload failed: " .. tostring(err)) end
	end)
	local muted, reeling = false, false
	local reel: Sound? = nil
	local voices: { Sound } = {}
	local lastUi = -math.huge
	local melodyUntil = 0
	local rewardGeneration = 0
	local wind = templates.Wind:Clone()
	wind.Looped, wind.Volume, wind.PlaybackSpeed, wind.Parent = true, 0, 0.62, folder
	wind:Play()
	local windTween: Tween? = TweenService:Create(wind, TweenInfo.new(2), { Volume = 0.018 })
	windTween:Play()
	local function ambience(volume: number)
		if windTween then windTween:Cancel() end
		windTween = TweenService:Create(wind, TweenInfo.new(0.45), { Volume = volume })
		windTween:Play()
	end
	local function play(name: string, pitch: number?, parent: Instance?, volume: number?)
		local template = templates[name]
		if not template or muted then return end
		for i = #voices, 1, -1 do if not voices[i].Parent then table.remove(voices, i) end end
		-- Multiplayer casts cannot create an unlimited pile of overlapping sounds.
		if #voices >= 10 then voices[1]:Destroy(); table.remove(voices, 1) end
		local sound = template:Clone()
		sound.PlaybackSpeed = math.clamp(pitch or 1, 0.7, 1.45)
		sound.Volume = math.clamp((volume or 0.25) * (trim[name] or 0.6), 0, 0.3)
		sound.Parent = parent or folder
		table.insert(voices, sound)
		sound.Ended:Once(function() sound:Destroy() end)
		sound:Play()
		Debris:AddItem(sound, 5)
	end
	local function setReeling(enabled: boolean)
		if reeling == enabled then return end
		reeling = enabled
		ambience(if enabled then 0.006 elseif os.clock() < melodyUntil then 0.005 else 0.018)
		if enabled then
			local sound = templates.Reel:Clone()
			sound.Looped, sound.PlaybackSpeed, sound.Volume, sound.Parent = true, 1.08, 0, folder
			sound:Play()
			TweenService:Create(sound, TweenInfo.new(0.25), { Volume = 0.055 }):Play()
			reel = sound
		elseif reel then
			TweenService:Create(reel, TweenInfo.new(0.18), { Volume = 0 }):Play()
			Debris:AddItem(reel, 0.22)
			reel = nil
		end
	end
	-- One short reward phrase owns the foreground, so goals do not stack on catches.
	local function phrase(pitches: { number }, volume: number)
		rewardGeneration += 1
		local generation = rewardGeneration
		melodyUntil = os.clock() + 0.8
		ambience(0.005)
		for i, pitch in pitches do
			task.delay((i - 1) * 0.18, function()
				if generation == rewardGeneration then play("Chime", pitch, nil, volume * (1 - (i - 1) * 0.16)) end
			end)
		end
		task.delay(0.85, function()
			if generation == rewardGeneration then ambience(if reeling then 0.006 else 0.018) end
		end)
	end
	return {
		play = play, setReeling = setReeling,
		catch = function(quality: string, rarity: string?, _discovery: boolean?)
			local pitch = if rarity == "Epic" then 1.08 elseif quality == "Brilliant" then 1 else 0.88
			phrase({ pitch, pitch * 1.25 }, 0.36)
		end,
		ui = function(success: boolean?)
			if os.clock() - lastUi < 0.14 then return end
			lastUi = os.clock()
			play(if success == false then "Miss" else "Chime", if success == false then 0.88 else 1.12, nil, 0.09)
		end,
		coins = function() phrase({ 1, 1.25 }, 0.24) end,
		goal = function()
			if os.clock() < melodyUntil then return end
			phrase({ 0.94, 1.18 }, 0.26)
		end,
		upgrade = function() phrase({ 0.82, 1, 1.25 }, 0.34) end,
		toggle = function(): boolean
			muted = not muted
			group.Volume = if muted then 0 else 0.75
			return muted
		end,
	}
end
return Audio
