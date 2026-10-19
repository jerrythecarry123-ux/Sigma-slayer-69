--!strict
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Audio = {}

-- Roblox client content, not community audio IDs with experience-specific permissions.
local clips = {
	Cast = "rbxasset://sounds/action_jump.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Chime = "rbxasset://sounds/electronicpingshort.wav",
	Reel = "rbxasset://sounds/action_swim.mp3",
	Miss = "rbxasset://sounds/action_jump_land.mp3",
}

function Audio.new()
	local folder = Instance.new("Folder")
	folder.Name = "CloudAnglersSounds"
	folder.Parent = SoundService
	local group = Instance.new("SoundGroup")
	group.Name = "CloudAnglersMix"
	group.Volume = 0.8
	group.Parent = SoundService
	local templates: { [string]: Sound } = {}
	local preload: { Instance } = {}
	for name, path in clips do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = path
		sound.SoundGroup = group
		sound.Volume = 0.35
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = 85
		sound.Parent = folder
		templates[name] = sound
		table.insert(preload, sound)
	end
	task.spawn(function()
		local ok, err = pcall(function() ContentProvider:PreloadAsync(preload) end)
		if not ok then warn("Cloud Anglers: sound preload failed: " .. tostring(err)) end
	end)
	local reel: Sound? = nil
	local muted = false
	local function play(name: string, pitch: number?, parent: Instance?, volume: number?)
		local template = templates[name]
		if not template or muted then return end
		local sound = template:Clone()
		sound.PlaybackSpeed = pitch or 1
		sound.Volume = volume or 0.35
		sound.Parent = parent or folder
		sound:Play()
		Debris:AddItem(sound, 6)
	end
	local function setReeling(enabled: boolean)
		if enabled and not reel then
			local sound = templates.Reel:Clone()
			sound.Looped = true
			sound.PlaybackSpeed = 1.7
			sound.Volume = 0
			sound.Parent = folder
			sound:Play()
			TweenService:Create(sound, TweenInfo.new(0.15), { Volume = 0.14 }):Play()
			reel = sound
		elseif not enabled and reel then
			TweenService:Create(reel, TweenInfo.new(0.12), { Volume = 0 }):Play()
			Debris:AddItem(reel, 0.16)
			reel = nil
		end
	end
	local function catchSound(quality: string)
		local pitch = if quality == "Brilliant" then 1.25 else 1
		play("Chime", pitch, nil, 0.4)
		task.delay(0.1, function() play("Chime", pitch * 1.25, nil, 0.3) end)
		task.delay(0.2, function() play("Chime", pitch * 1.5, nil, 0.24) end)
	end
	return {
		play = play,
		setReeling = setReeling,
		catch = catchSound,
		toggle = function(): boolean
			muted = not muted
			group.Volume = if muted then 0 else 0.8
			return muted
		end,
	}
end

return Audio
