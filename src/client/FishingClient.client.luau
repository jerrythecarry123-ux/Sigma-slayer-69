--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Rules = require(Shared:WaitForChild("FishingRules"))
local audio = require(script.Parent:WaitForChild("FishingAudio")).new()
local presentation = require(script.Parent:WaitForChild("FishingPresentation")).new(audio)
local Interface = require(script.Parent:WaitForChild("FishingInterface"))
local remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local action = remotes:WaitForChild("FishingAction") :: RemoteEvent
local state = remotes:WaitForChild("FishingState") :: RemoteEvent
local visual = remotes:WaitForChild("FishingVisual") :: RemoteEvent
local player = Players.LocalPlayer
local packet: any = { phase = "Connecting", catches = 0, nextStart = 0 }
local ui: any = nil
local pendingSince: number? = nil
local heldInput: InputObject? = nil
local heldConnection: RBXScriptConnection? = nil
local releasedBeforeAck = false
local workshopVisible = false
local message = "Find the lantern-lit dock and cast your first line."
local keyHint = if UserInputService.TouchEnabled then "" else "  [E]"
local function now(): number return workspace:GetServerTimeNow() end
local function clearHeld()
	heldInput = nil
	if heldConnection then heldConnection:Disconnect() end
	heldConnection = nil
	if ui then TweenService:Create(ui.buttonScale, TweenInfo.new(0.12), { Scale = 1 }):Play() end
end
local function request(verb: string, argument: any?)
	pendingSince = now()
	action:FireServer(verb, if verb == "Upgrade" then argument else packet.attemptId)
end
local function cancel()
	clearHeld()
	releasedBeforeAck = false
	if packet.attemptId then request("Cancel") end
end
ui = Interface.new(player:WaitForChild("PlayerGui"), audio, {
	openJournal = function() cancel(); ui.hideResult() end,
	upgrade = function()
		if not packet.profile or pendingSince then return end
		request("Upgrade", packet.profile.level)
	end,
})
local function release()
	if not heldInput then return end
	clearHeld()
	if packet.phase == "Reeling" then request("Release") else releasedBeforeAck = true end
end
local function press(input: InputObject)
	if ui.isJournalOpen() then return end
	if ui.isResultOpen() then ui.hideResult(); return end
	if heldInput or pendingSince then return end
	if packet.phase == "Idle" and now() >= packet.nextStart then
		ui.hideResult()
		message = "Casting into the clouds..."
		request("Start")
	elseif packet.phase == "Waiting" and now() >= (packet.readyAt or math.huge) then
		heldInput, releasedBeforeAck = input, false
		TweenService:Create(ui.buttonScale, TweenInfo.new(0.1), { Scale = 0.95 }):Play()
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
	if not processed and not workshopVisible and input.KeyCode == Enum.KeyCode.E and not UserInputService:GetFocusedTextBox() then press(input) end
end)
UserInputService.InputEnded:Connect(function(input)
	local held = heldInput
	if not held then return end
	if input == held
		or (held.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
		or (held.KeyCode == Enum.KeyCode.E and input.KeyCode == Enum.KeyCode.E) then release() end
end)
UserInputService.WindowFocusReleased:Connect(cancel)
UserInputService.TextBoxFocused:Connect(cancel)
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Name == "RodWorkshopPrompt" then workshopVisible = true end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt.Name == "RodWorkshopPrompt" then workshopVisible = false end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if prompt.Name == "RodWorkshopPrompt" and who == player then ui.openJournal("Workshop") end
end)
visual.OnClientEvent:Connect(presentation.apply)
state.OnClientEvent:Connect(function(incoming)
	local previousId, previousCatches = packet.attemptId, packet.catches
	packet, pendingSince = incoming, nil
	ui.updateProfile(packet.profile)
	ui.setState(packet.phase)
	if packet.result and packet.catches > previousCatches then
		local result = packet.result
		message = result.species .. " / " .. result.quality .. "! What will you discover next?"
		ui.showResult(result)
		if (result.goalBonus or 0) > 0 then
			ui.notify("Adventure complete! +" .. result.goalBonus .. " bonus coins")
			task.delay(0.45, audio.goal)
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
	if packet.phase == "Waiting" and packet.attemptId ~= previousId then ui.hideResult() end
	audio.setReeling(packet.phase == "Reeling")
	if ui.isJournalOpen() and packet.phase == "Waiting" then request("Cancel"); return end
	if packet.phase == "Reeling" then
		if releasedBeforeAck then releasedBeforeAck = false; request("Release")
		elseif not heldInput then request("Cancel") end
	end
end)
RunService.RenderStepped:Connect(function()
	local time = now()
	if pendingSince and time - pendingSince > 3 then clearHeld(); releasedBeforeAck = false; request("Sync") end
	local camera = workspace.CurrentCamera
	if camera then ui.animate(time, camera.ViewportSize.X, camera.ViewportSize.Y) end
	ui.button.BackgroundColor3 = Color3.fromRGB(37, 119, 109)
	ui.legend.Text = "NORMAL  ·  FINE  ·  BRILLIANT"
	if packet.phase == "Waiting" then
		if time < (packet.readyAt or math.huge) then
			ui.status.Text, ui.button.Text = "Watch your bobber...", "CASTING..."
		else
			ui.status.Text = "BITE! Hold, then release inside the zone."
			ui.button.Text = if pendingSince then "ONE MOMENT..." else "HOLD TO REEL" .. keyHint
		end
	elseif packet.phase == "Reeling" then
		local progress = math.clamp((time - (packet.chargeAt or time)) / (packet.duration or 1), 0, 1)
		ui.marker.Position = UDim2.fromScale(progress, 0)
		local quality = Rules.qualityAt(progress)
		ui.legend.Text = "NOW: " .. string.upper(quality or "OUTSIDE THE ZONE")
		ui.status.Text = if pendingSince then "Checking your catch..." else "Release in the zone. Aim for gold!"
		ui.button.Text = if pendingSince then "ONE MOMENT..." else "RELEASE!"
		ui.button.BackgroundColor3 = Color3.fromRGB(151, 105, 31)
	elseif packet.phase == "Idle" then
		ui.status.Text = message
		ui.button.Text = if pendingSince then "ONE MOMENT..." elseif time < packet.nextStart then "GET READY..." else "CAST LINE" .. keyHint
	else
		ui.status.Text = "Loading your collection safely..."
		ui.button.Text = "CONNECTING..."
	end
end)
request("Sync")
