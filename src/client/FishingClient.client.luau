--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Rules = require(Shared:WaitForChild("FishingRules"))
-- Remote/profile/UI readiness can yield. Keep the mix quiet from construction,
-- before those waits, until a loaded preference or explicit local choice exists.
local audio = require(script.Parent:WaitForChild("FishingAudio")).new(true)
local presentation = require(script.Parent:WaitForChild("FishingPresentation")).new(audio)
local Interface = require(script.Parent:WaitForChild("FishingInterface"))
local AquariumInterface = require(script.Parent:WaitForChild("AquariumInterface"))
local TravelInterface = require(script.Parent:WaitForChild("IslandTravelInterface"))
local CatchCinematic = require(script.Parent:WaitForChild("CatchCinematic"))
local remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local action = remotes:WaitForChild("FishingAction") :: RemoteEvent
local state = remotes:WaitForChild("FishingState") :: RemoteEvent
local visual = remotes:WaitForChild("FishingVisual") :: RemoteEvent
local player = Players.LocalPlayer
local cinematic = CatchCinematic.new(player:WaitForChild("PlayerGui"), audio)
local packet: any = { phase = "Connecting", catches = 0, nextStart = 0 }
local ui: any = nil
local aquariumUI: any = nil
local preferences = { reducedEffects = false, soundEnabled = true }
local profileReady, preferencesTouched, preferencesDirty = false, false, false
local preferencesPersistent = false
local preferenceSendAt = 0
local preferenceSentAt: number? = nil
local preferenceWriteId = 0
local preferenceInFlightId: number? = nil
local revealGeneration = 0
local characterAlive = false
local deathConnection: RBXScriptConnection? = nil
local humanoidConnection: RBXScriptConnection? = nil
local pendingSince: number? = nil
local pendingVerb: string? = nil
local heldInput: InputObject? = nil
local heldStage: string? = nil
local heldAt = 0
local heldConnection: RBXScriptConnection? = nil
local releasedBeforeAck = false
local queuedCastVerb: string? = nil
local visiblePrompts: {[ProximityPrompt]: boolean} = {}
local message = "Tap to cast. Hold and release on gold for a precision cast."
local function keyHint(): string
	local preferred = UserInputService.PreferredInput
	return if preferred == Enum.PreferredInput.Touch then ""
		elseif preferred == Enum.PreferredInput.Gamepad then "  [RT]" else "  [E]"
end
local function now(): number return workspace:GetServerTimeNow() end
local function travelling(): boolean
	return player:GetAttribute("IslandTravelMenuOpen")==true or player:GetAttribute("IslandTravelBusy")==true
end
local function applyPreferences()
	local systemReducedMotion = GuiService.ReducedMotionEnabled
	local reduced = preferences.reducedEffects or systemReducedMotion
	-- Loading a returning player's saved mute choice must not begin with an
	-- audible default mix. An explicit local choice can take effect immediately.
	audio.setEnabled(preferences.soundEnabled and (profileReady or preferencesTouched))
	presentation.setReducedEffects(reduced)
	cinematic.setReducedEffects(reduced)
	if ui then ui.setPreferences({
		reducedEffects = preferences.reducedEffects, soundEnabled = preferences.soundEnabled,
		systemReducedMotion = systemReducedMotion,
		persistent = if profileReady then preferencesPersistent else nil,
		savePending = preferencesDirty,
	}) end
end
local function preferencesMatch(profile: any): boolean
	local raw = if type(profile) == "table" then profile.preferences else nil
	return type(raw) == "table" and raw.soundEnabled == preferences.soundEnabled
		and raw.reducedEffects == preferences.reducedEffects
end
local function receivePreferences(profile: any)
	if type(profile) ~= "table" then return end
	local raw = profile.preferences
	local remoteSound = if type(raw) == "table" and type(raw.soundEnabled) == "boolean" then raw.soundEnabled else true
	local remoteReduced = type(raw) == "table" and raw.reducedEffects == true
	if not profileReady and not preferencesTouched then
		preferences.soundEnabled, preferences.reducedEffects = remoteSound, remoteReduced
	end
	profileReady, preferencesPersistent = true, profile.persistent == true
	applyPreferences()
end
local function dismissResult()
	revealGeneration += 1
	cinematic.stop("dismissed")
	if ui then ui.hideResult() end
end
local function clearHeld()
	heldInput, heldStage, heldAt = nil, nil, 0
	if heldConnection then heldConnection:Disconnect() end
	heldConnection = nil
	if ui then
		if preferences.reducedEffects or GuiService.ReducedMotionEnabled then ui.buttonScale.Scale = 1
		else TweenService:Create(ui.buttonScale, TweenInfo.new(0.12), { Scale = 1 }):Play() end
	end
end
local function request(verb: string, argument: any?)
	pendingSince, pendingVerb = now(), verb
	action:FireServer(verb, if verb == "Upgrade" or verb == "Display" or verb == "Style" then argument else packet.attemptId)
end
local function cancel()
	dismissResult()
	clearHeld()
	audio.setReeling(false)
	releasedBeforeAck = false
	queuedCastVerb = nil
	if packet.attemptId and pendingVerb ~= "Cancel" then request("Cancel") end
end
local function stopWatchingCharacter()
	if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
	if humanoidConnection then humanoidConnection:Disconnect(); humanoidConnection = nil end
	characterAlive = false
end
local function watchCharacter(character: Model)
	-- Replacing Character normally emits CharacterRemoving first, but the
	-- binding itself also owns cancellation so it never depends on that order.
	cancel()
	stopWatchingCharacter()
	local function watchHumanoid(humanoid: Instance)
		if not humanoid:IsA("Humanoid") or player.Character ~= character then return end
		if humanoidConnection then humanoidConnection:Disconnect(); humanoidConnection = nil end
		characterAlive = humanoid.Health > 0
		deathConnection = humanoid.Died:Connect(function()
			if player.Character ~= character then return end
			characterAlive = false
			cancel()
		end)
		if not characterAlive then cancel() end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then watchHumanoid(humanoid)
	else humanoidConnection = character.ChildAdded:Connect(watchHumanoid) end
end
local function openAquarium()
	if travelling() then return end
	cancel()
	ui.closeJournal()
	ui.closeSettings()
	aquariumUI.open()
end
aquariumUI = AquariumInterface.new(player:WaitForChild("PlayerGui"), {
	display = function(id: string, slot: number)
		if packet.profile and not pendingSince then request("Display", { id = id, slot = slot }) end
	end,
	style = function(id: string)
		if packet.profile and not pendingSince then request("Style", id) end
	end,
	visit = function()
		aquariumUI.close()
		cancel()
		ui.closeJournal()
		ui.closeSettings()
		if not TravelInterface.visitGallery() then ui.notify("Your gallery is getting ready. Try again in a moment.") end
	end,
	close = function() end,
})
ui = Interface.new(player:WaitForChild("PlayerGui"), audio, {
	openJournal = function() cancel(); aquariumUI.close() end,
	openAquarium = openAquarium,
	openSettings = function() cancel(); aquariumUI.close() end,
	settingsChanged = function(updated)
		preferences.reducedEffects = updated.reducedEffects == true
		preferences.soundEnabled = updated.soundEnabled ~= false
		preferencesTouched, preferencesDirty = true, true
		preferenceSendAt = now() + .4
		applyPreferences()
	end,
	castAgain = function()
		dismissResult()
		if not characterAlive or travelling() or aquariumUI.isOpen() or ui.isSettingsOpen() or pendingSince or packet.phase ~= "Idle" or now() < packet.nextStart then return end
		message = "Casting into the clouds..."
		request("Start")
	end,
	upgrade = function()
		if not packet.profile or pendingSince then return end
		request("Upgrade", packet.profile.level)
	end,
})
applyPreferences()
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(applyPreferences)
player.CharacterRemoving:Connect(function() stopWatchingCharacter(); cancel() end)
player.CharacterAdded:Connect(watchCharacter)
if player.Character then watchCharacter(player.Character) end
player:GetAttributeChangedSignal("IslandTravelMenuOpen"):Connect(function()
	if travelling() then cancel(); ui.closeJournal(); ui.closeSettings(); aquariumUI.close() end
end)
player:GetAttributeChangedSignal("IslandTravelBusy"):Connect(function()
	if travelling() then cancel(); ui.closeJournal(); ui.closeSettings(); aquariumUI.close() end
end)
task.spawn(TravelInterface.start)
local function release()
	if not heldInput then return end
	local stage, duration = heldStage, math.max(0, now() - heldAt)
	clearHeld()
	if stage == "Cast" then
		-- A quick tap chooses a no-bonus standard cast. It is a convenience
		-- mode, never a client claim about timing, strength or reward quality.
		local verb = if duration <= 0.12 then "QuickCast" else "Cast"
		if packet.phase == "ChargingCast" then request(verb)
		elseif packet.phase == "Idle" then queuedCastVerb = verb end
	elseif stage == "Reel" then
		audio.setReeling(false)
		if packet.phase == "Reeling" then request("Release") else releasedBeforeAck = true end
	end
end
local function capture(input: InputObject, stage: string)
	heldInput, heldStage, heldAt = input, stage, now()
	if not (preferences.reducedEffects or GuiService.ReducedMotionEnabled) then
		TweenService:Create(ui.buttonScale, TweenInfo.new(0.1), { Scale = 0.95 }):Play()
	end
	heldConnection = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.Cancel then cancel()
		elseif input.UserInputState == Enum.UserInputState.End then release() end
	end)
end
local function press(input: InputObject)
	if travelling() or not characterAlive then return end
	if ui.isJournalOpen() or ui.isSettingsOpen() or aquariumUI.isOpen() or cinematic.isPlaying() then return end
	if ui.isResultOpen() then ui.hideResult(); return end
	if heldInput or pendingSince then return end
	if packet.phase == "Idle" and now() >= packet.nextStart then
		ui.hideResult()
		queuedCastVerb, releasedBeforeAck = nil, false
		capture(input, "Cast")
		message = "Tap to cast, or release on gold for a precision cast."
		request("BeginCast")
	elseif packet.phase == "Waiting" and now() >= (packet.readyAt or math.huge) then
		releasedBeforeAck = false
		capture(input, "Reel")
		request("Hold")
	end
end
ui.button.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then press(input) end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and next(visiblePrompts)==nil and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonR2)
		and not UserInputService:GetFocusedTextBox() then press(input) end
end)
UserInputService.InputEnded:Connect(function(input)
	local held = heldInput
	if not held then return end
	if input == held
		or (held.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
		or (held.KeyCode == Enum.KeyCode.E and input.KeyCode == Enum.KeyCode.E)
		or (held.KeyCode == Enum.KeyCode.ButtonR2 and input.KeyCode == Enum.KeyCode.ButtonR2) then release() end
end)
UserInputService.WindowFocusReleased:Connect(cancel)
UserInputService.TextBoxFocused:Connect(cancel)
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Name == "RodWorkshopPrompt" or prompt.Name == "IslandTravelPrompt" or prompt.Name == "AquariumPrompt" then visiblePrompts[prompt]=true end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	visiblePrompts[prompt]=nil
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if prompt.Name == "RodWorkshopPrompt" and who == player and not travelling() then ui.openJournal("Workshop") end
	if prompt.Name == "AquariumPrompt" and who == player then openAquarium() end
end)
visual.OnClientEvent:Connect(presentation.apply)
state.OnClientEvent:Connect(function(incoming)
	if incoming.replyTo == "Preferences" then
		local currentWrite = incoming.preferenceRequestId ~= nil and incoming.preferenceRequestId == preferenceInFlightId
		if currentWrite then
			preferenceSentAt, preferenceInFlightId = nil, nil
			preferencesDirty = not (incoming.preferencesChanged == true and preferencesMatch(incoming.profile))
			preferenceSendAt = now() + (if incoming.preferencesChanged then .4 else 1)
		end
		if incoming.preferencesChanged then
			-- This is a private settings acknowledgement, not a cast transition.
			-- It must not clear an input pressed while that acknowledgement flew.
			receivePreferences(incoming.profile)
			packet.profile = incoming.profile
			ui.updateProfile(incoming.profile)
			aquariumUI.updateProfile(incoming.profile)
			return
		end
	end
	local previousId, previousCatches = packet.attemptId, packet.catches
	-- Location updates can cross an in-flight BeginCast. They are not its
	-- acknowledgement and must not discard a held press or an early release.
	local keepBegin = pendingVerb == "BeginCast" and incoming.phase == "Idle"
		and incoming.replyTo ~= "BeginCast" and incoming.replyTo ~= "Sync"
	local keepLaunch = (pendingVerb == "Cast" or pendingVerb == "QuickCast")
		and incoming.phase == "ChargingCast" and incoming.replyTo ~= pendingVerb
	local keepCancel = pendingVerb == "Cancel" and incoming.phase ~= "Idle"
		and incoming.replyTo ~= "Cancel" and incoming.replyTo ~= "Sync"
	packet = incoming
	if not keepBegin and not keepLaunch and not keepCancel then pendingSince, pendingVerb = nil, nil end
	receivePreferences(packet.profile)
	ui.updateProfile(packet.profile)
	aquariumUI.updateProfile(packet.profile)
	ui.updateLocation(packet.location, packet.profile)
	ui.setTimingWindow(Rules.centerAt(packet, now()), packet.timingWidth or 0.14)
	ui.setState(packet.phase)
	if packet.phase ~= "Idle" then dismissResult() end
	if packet.result and packet.catches > previousCatches then
		local result = packet.result
		message = (if result.variant and result.variant ~= "Normal" then result.variant .. " " else "")
			.. result.species .. " · " .. result.quality .. (if result.weightKg then string.format(" · %.2f kg", result.weightKg) else "")
		dismissResult()
		local generation, catches = revealGeneration, packet.catches
		local function completed()
			if generation == revealGeneration and packet.catches == catches and packet.phase == "Idle"
				and not travelling() and not aquariumUI.isOpen() and not ui.isJournalOpen() and not ui.isSettingsOpen() then
				ui.showResult(result, true, true)
			end
		end
		if not characterAlive or travelling() or aquariumUI.isOpen() or ui.isJournalOpen() or ui.isSettingsOpen() then
			-- The reward is already owned. A delayed server acknowledgement must
			-- not reopen presentation after death or over a chosen menu.
		elseif not cinematic.play(result, completed) then ui.showResult(result) end
		if (result.goalBonus or 0) > 0 then
			ui.notify("Adventure complete! +" .. result.goalBonus .. " bonus coins")
		elseif result.newDiscovery then ui.notify("New journal entry: " .. result.species) end
	elseif packet.message then message = packet.message end
	if packet.purchase then
		if packet.purchase.success then audio.upgrade(); ui.notify(packet.purchase.message)
		else audio.ui(false); ui.notify(packet.purchase.message) end
	end
	if packet.offline and packet.offline.coins > 0 then
		ui.notify("Welcome back! Your collection earned " .. packet.offline.coins .. " coins.")
		audio.coins()
	end
	if packet.phase == "Idle" and not keepBegin then
		clearHeld(); releasedBeforeAck, queuedCastVerb = false, nil
	elseif packet.phase == "Waiting" and (heldStage == "Cast" or packet.attemptId ~= previousId) then
		-- A timed-out charge launches automatically with the same attempt ID.
		-- Its old press cannot become an unintended reel input at the bite.
		clearHeld(); releasedBeforeAck, queuedCastVerb = false, nil
	elseif packet.phase == "Reeling" and packet.attemptId ~= previousId then
		clearHeld(); releasedBeforeAck, queuedCastVerb = false, nil
	end
	if packet.phase == "Waiting" and packet.attemptId ~= previousId then dismissResult() end
	audio.setReeling(packet.phase == "Reeling" and heldStage == "Reel" and not releasedBeforeAck and not keepCancel)
	if (not characterAlive or ui.isJournalOpen() or ui.isSettingsOpen() or aquariumUI.isOpen() or travelling())
		and (packet.phase == "Waiting" or packet.phase == "ChargingCast") then
		if not keepCancel then request("Cancel") end
		return
	end
	if packet.phase == "ChargingCast" then
		if queuedCastVerb then
			local verb = queuedCastVerb
			queuedCastVerb = nil
			request(verb)
		elseif heldStage ~= "Cast" and not keepLaunch and not keepCancel then request("Cancel") end
	end
	if packet.phase == "Reeling" then
		if keepCancel then return end
		if releasedBeforeAck then releasedBeforeAck = false; request("Release")
		elseif not heldInput then request("Cancel") end
	end
end)
RunService.RenderStepped:Connect(function(deltaTime)
	local time = now()
	if pendingSince and time - pendingSince > 3 then
		clearHeld(); releasedBeforeAck, queuedCastVerb = false, nil
		request("Sync")
	end
	if preferenceSentAt and time - preferenceSentAt > 3 then
		preferenceSentAt, preferenceInFlightId = nil, nil
		preferenceSendAt = time + 1
	end
	if preferencesDirty and profileReady and not preferenceSentAt and not pendingSince
		and packet.phase == "Idle" and time >= preferenceSendAt then
		preferenceSentAt = time
		preferenceWriteId = preferenceWriteId % 2147483647 + 1
		preferenceInFlightId = preferenceWriteId
		action:FireServer("Preferences", { soundEnabled = preferences.soundEnabled, reducedEffects = preferences.reducedEffects }, preferenceWriteId)
	end
	local camera = workspace.CurrentCamera
	if camera then
		ui.animate(time, camera.ViewportSize.X, camera.ViewportSize.Y)
		aquariumUI.animate(time, camera.ViewportSize.X, camera.ViewportSize.Y)
	end
	ui.button.BackgroundColor3 = Color3.fromRGB(37, 119, 109)
	ui.legend.Text = "NORMAL  ·  FINE  ·  BRILLIANT"
	if packet.phase == "ChargingCast" then
		local power = Rules.castProgressAt(packet, time)
		local grade = Rules.castGradeAt(power)
		ui.setCastProgress(power)
		ui.legend.Text = "CAST  " .. math.floor(power * 100 + 0.5) .. "%  ·  " .. string.upper(grade)
		ui.status.Text = if pendingSince then "Launching your line..." else "Release on gold for a precision cast. A quick tap works too."
		ui.button.Text = if pendingSince then "CASTING..." else "RELEASE TO CAST"
	elseif packet.phase == "Waiting" then
		local castFeedback = if packet.castGrade == "Perfect" then "Perfect cast!"
			elseif packet.castGrade == "Precise" then "Precise cast." else nil
		if time < (packet.castAt or 0) + (packet.castDuration or 0.65) then
			ui.status.Text = if castFeedback then castFeedback .. " Watch the float." else "Watch your bobber..."
			ui.button.Text = "CASTING..."
		elseif time < (packet.readyAt or math.huge) then
			ui.status.Text = if castFeedback then castFeedback .. " Wait for the bite." else "A shadow is circling. Watch for the bite!"
			ui.button.Text = "WATCH THE FLOAT"
		else
			ui.status.Text = "BITE! Hold, then release inside the zone."
			ui.button.Text = if pendingSince then "ONE MOMENT..." else "HOLD TO REEL" .. keyHint()
		end
	elseif packet.phase == "Reeling" then
		local progress = Rules.progressAt(packet, time)
		audio.updateReeling(progress, packet.difficulty, deltaTime)
		local center = Rules.centerAt(packet, time)
		ui.setTimingWindow(center, packet.timingWidth or 0.14)
		ui.marker.Position = UDim2.fromScale(progress, 0)
		local quality = Rules.qualityAt(progress, center, packet.timingWidth)
		ui.legend.Text = "NOW: " .. string.upper(quality or "OUTSIDE THE ZONE")
		ui.status.Text = if pendingSince then "Checking your catch..."
			elseif packet.timingMotion and packet.timingMotion.amplitude > 0 then "Follow its rhythm. Release on gold!"
			else "Release in the zone. Aim for gold!"
		ui.button.Text = if pendingSince then "ONE MOMENT..." else "RELEASE!"
		ui.button.BackgroundColor3 = Color3.fromRGB(151, 105, 31)
	elseif packet.phase == "Idle" then
		ui.status.Text = message
		ui.button.Text = if pendingSince then "ONE MOMENT..." elseif time < packet.nextStart then "GET READY..." else "CAST LINE" .. keyHint()
	else
		ui.status.Text = "Loading your collection safely..."
		ui.button.Text = "CONNECTING..."
	end
end)
request("Sync")
