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
local audio = require(script.Parent:WaitForChild("FishingAudio")).new()
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
local revealGeneration = 0
local characterAlive = false
local deathConnection: RBXScriptConnection? = nil
local humanoidConnection: RBXScriptConnection? = nil
local pendingSince: number? = nil
local heldInput: InputObject? = nil
local heldConnection: RBXScriptConnection? = nil
local releasedBeforeAck = false
local visiblePrompts: {[ProximityPrompt]: boolean} = {}
local message = "The pond is right ahead. Cast your first line!"
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
	audio.setEnabled(preferences.soundEnabled)
	presentation.setReducedEffects(reduced)
	cinematic.setReducedEffects(reduced)
	if ui then ui.setPreferences({
		reducedEffects = preferences.reducedEffects, soundEnabled = preferences.soundEnabled,
		systemReducedMotion = systemReducedMotion,
	}) end
end
local function dismissResult()
	revealGeneration += 1
	cinematic.stop("dismissed")
	if ui then ui.hideResult() end
end
local function clearHeld()
	heldInput = nil
	if heldConnection then heldConnection:Disconnect() end
	heldConnection = nil
	if ui then
		if preferences.reducedEffects or GuiService.ReducedMotionEnabled then ui.buttonScale.Scale = 1
		else TweenService:Create(ui.buttonScale, TweenInfo.new(0.12), { Scale = 1 }):Play() end
	end
end
local function request(verb: string, argument: any?)
	pendingSince = now()
	action:FireServer(verb, if verb == "Upgrade" or verb == "Display" or verb == "Style" then argument else packet.attemptId)
end
local function cancel()
	dismissResult()
	clearHeld()
	releasedBeforeAck = false
	if packet.attemptId then request("Cancel") end
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
	clearHeld()
	if packet.phase == "Reeling" then request("Release") else releasedBeforeAck = true end
end
local function press(input: InputObject)
	if travelling() or not characterAlive then return end
	if ui.isJournalOpen() or ui.isSettingsOpen() or aquariumUI.isOpen() or cinematic.isPlaying() then return end
	if ui.isResultOpen() then ui.hideResult(); return end
	if heldInput or pendingSince then return end
	if packet.phase == "Idle" and now() >= packet.nextStart then
		ui.hideResult()
		message = "Casting into the clouds..."
		request("Start")
	elseif packet.phase == "Waiting" and now() >= (packet.readyAt or math.huge) then
		heldInput, releasedBeforeAck = input, false
		if not (preferences.reducedEffects or GuiService.ReducedMotionEnabled) then
			TweenService:Create(ui.buttonScale, TweenInfo.new(0.1), { Scale = 0.95 }):Play()
		end
		heldConnection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.Cancel then cancel()
			elseif input.UserInputState == Enum.UserInputState.End then release() end
		end)
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
	local previousId, previousCatches = packet.attemptId, packet.catches
	packet, pendingSince = incoming, nil
	ui.updateProfile(packet.profile)
	aquariumUI.updateProfile(packet.profile)
	ui.updateLocation(packet.location, packet.profile)
	ui.setTimingWindow(Rules.centerAt(packet, now()), 0.14)
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
	if packet.phase == "Idle" or packet.attemptId ~= previousId then clearHeld(); releasedBeforeAck = false end
	if packet.phase == "Waiting" and packet.attemptId ~= previousId then dismissResult() end
	audio.setReeling(packet.phase == "Reeling")
	if (ui.isJournalOpen() or ui.isSettingsOpen() or aquariumUI.isOpen() or travelling()) and packet.phase == "Waiting" then request("Cancel"); return end
	if packet.phase == "Reeling" then
		if releasedBeforeAck then releasedBeforeAck = false; request("Release")
		elseif not heldInput then request("Cancel") end
	end
end)
RunService.RenderStepped:Connect(function()
	local time = now()
	if pendingSince and time - pendingSince > 3 then clearHeld(); releasedBeforeAck = false; request("Sync") end
	local camera = workspace.CurrentCamera
	if camera then
		ui.animate(time, camera.ViewportSize.X, camera.ViewportSize.Y)
		aquariumUI.animate(time, camera.ViewportSize.X, camera.ViewportSize.Y)
	end
	ui.button.BackgroundColor3 = Color3.fromRGB(37, 119, 109)
	ui.legend.Text = "NORMAL  ·  FINE  ·  BRILLIANT"
	if packet.phase == "Waiting" then
		if time < (packet.castAt or 0) + (packet.castDuration or 0.65) then
			ui.status.Text, ui.button.Text = "Watch your bobber...", "CASTING..."
		elseif time < (packet.readyAt or math.huge) then
			ui.status.Text, ui.button.Text = "A shadow is circling. Watch for the bite!", "WATCH THE FLOAT"
		else
			ui.status.Text = "BITE! Hold, then release inside the zone."
			ui.button.Text = if pendingSince then "ONE MOMENT..." else "HOLD TO REEL" .. keyHint()
		end
	elseif packet.phase == "Reeling" then
		local progress = Rules.progressAt(packet, time)
		local center = Rules.centerAt(packet, time)
		ui.setTimingWindow(center, 0.14)
		ui.marker.Position = UDim2.fromScale(progress, 0)
		local quality = Rules.qualityAt(progress, center)
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
