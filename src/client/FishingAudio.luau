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
function Audio.new(startMuted: boolean?)
	-- The controller can yield while remotes and saved preferences load. Own
	-- the initial mute before starting any loop, rather than silencing it later.
	local muted, reeling = startMuted == true, false
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "CloudAnglersSounds", SoundService
	local group = Instance.new("SoundGroup")
	group.Name, group.Volume, group.Parent = "CloudAnglersMix", if muted then 0 else 0.75, SoundService
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name, eq.HighGain, eq.MidGain, eq.LowGain, eq.Parent = "SoftenUpperFrequencies", -7, -1, -2, group
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Name, compressor.Threshold, compressor.Ratio = "GentlePeakControl", -14, 3
	compressor.Attack, compressor.Release, compressor.GainMakeup, compressor.Parent = 0.1, 0.15, 0, group
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
	local function updateReeling(progress: number, difficulty: number?, deltaTime: number)
		local sound = reel
		if not reeling or not sound or not sound.Parent then return end
		-- A small continuous pitch change reinforces the existing reel motion.
		-- It owns no extra voice or volume tween and cannot make the mix louder.
		local p = if progress == progress then math.clamp(progress, 0, 1) else 0
		local strength = if difficulty and difficulty == difficulty then math.clamp(difficulty, 0, .6) else 0
		local dt = if deltaTime == deltaTime then math.clamp(deltaTime, 0, .1) else 0
		local target = .98 + p * .16 + strength * .10
		sound.PlaybackSpeed += (target - sound.PlaybackSpeed) * (1 - math.exp(-dt * 8))
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
	local function setEnabled(enabled: boolean)
		if muted == not enabled then return end
		muted = not enabled
		group.Volume = if muted then 0 else 0.75
		-- Muting also invalidates scheduled notes. Turning sound back on must not
		-- replay the tail of an old reward or a still-alive one-shot voice.
		rewardGeneration += 1
		melodyUntil = 0
		for _, voice in voices do voice:Destroy() end
		table.clear(voices)
		ambience(if reeling then 0.006 else 0.018)
	end
	return {
		play = play, setReeling = setReeling, updateReeling = updateReeling,
		setEnabled = setEnabled,
		isEnabled = function(): boolean return not muted end,
		catch = function(quality: string, rarity: string?, _discovery: boolean?)
			-- Distinct, restrained phrases share the same shipped chime. They do
			-- not depend on unlicensed uploads or louder high-rarity samples.
			if rarity == "Secret" then phrase({ 0.74, 0.99, 1.32 }, 0.30)
			elseif rarity == "Mythical" then phrase({ 0.82, 1.03, 1.38 }, 0.30)
			elseif rarity == "Legendary" then phrase({ 0.88, 1.11, 1.32 }, 0.31)
			elseif rarity == "Epic" then phrase({ 0.94, 1.18, 1.40 }, 0.30)
			elseif rarity == "Rare" then phrase({ 0.94, 1.25 }, 0.30)
			else
				local pitch = if quality == "Brilliant" then 1 else 0.88
				phrase({ pitch, pitch * 1.25 }, 0.28)
			end
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
			setEnabled(muted)
			return muted
		end,
	}
end
return Audio
