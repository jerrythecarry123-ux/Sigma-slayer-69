--!strict
-- Pure layout arithmetic: measured in the ScreenGui's inset-safe canvas.
local Layout = {}
function Layout.measure(width: number, height: number)
	local w, h = math.max(280, width), math.max(240, height)
	local compact = h < 480
	local narrow = w < 660
	local portrait = narrow and not compact
	local panelWidth = if compact then math.min(340, math.max(220, w - 320)) else math.min(360, w - 32)
	local navWidth = if compact then 128 else math.min(156, (w - 112) / 2)
	local revealWidth, revealHeight = if compact then 560 else 360, if compact then 240 else 420
	return {
		width = w, height = h, narrow = narrow, compact = compact,
		panelWidth = panelWidth, panelBottom = if portrait then 152 else 20,
		goalWidth = if narrow then w - 32 else 264,
		goalHeight = if compact then 0 else 64,
		journalY = if compact then 66 elseif narrow then 140 else 150,
		navWidth = navWidth,
		aquariumX = if compact then w - 144 else 24 + navWidth,
		aquariumY = if compact then 66 elseif narrow then 140 else 150,
		soundX = if compact then w - 210 else 32 + navWidth * 2,
		soundY = if compact then 12 elseif narrow then 140 else 150,
		settingsWidth = 64,
		settingsDialogWidth = math.min(400, w - 24), settingsDialogHeight = math.min(380, h - 24),
		bookWidth = math.min(900, w - 24), bookHeight = math.min(590, h - 24),
		columns = if narrow then 2 else 3,
		cardHeight = if compact then 124 elseif narrow then 150 else 174,
		workshopVertical = narrow and not compact,
		revealWidth = revealWidth, revealHeight = revealHeight,
		revealScale = math.min(1, (w - 24) / revealWidth, (h - 32) / revealHeight),
	}
end
return Layout
