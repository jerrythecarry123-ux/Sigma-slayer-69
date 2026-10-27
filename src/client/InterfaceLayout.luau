--!strict
-- Pure layout arithmetic: measured in the ScreenGui's inset-safe canvas.
local Layout = {}
function Layout.measure(width: number, height: number)
	local w, h = math.max(280, width), math.max(240, height)
	local compact = h < 480
	local tightCanvas = compact and w < 480
	local narrow = w < 660
	local portrait = narrow and not compact
	local panelWidth = if compact then math.min(340, math.max(220, w - 320)) else math.min(360, w - 32)
	local navWidth = if compact then 128 else math.min(156, (w - 112) / 2)
	local revealWidth = if tightCanvas then 296 elseif compact then 560 else 360
	local revealHeight = if tightCanvas then 212 elseif compact then 240 else 420
	return {
		width = w, height = h, narrow = narrow, compact = compact,
		tightCanvas = tightCanvas,
		panelWidth = panelWidth, panelBottom = if portrait then 152 else 20,
		panelIdleHeight = if tightCanvas then 96 else 122,
		panelActiveHeight = if tightCanvas then 140 else 180,
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
		columns = if compact then (if w < 480 then 1 elseif w < 800 then 2 else 3) elseif narrow then 2 else 3,
		cardHeight = if compact then 80 elseif narrow then 150 else 174,
		journalFooter = if compact then (if h < 300 then 0 else 48) elseif narrow then 76 else 60,
		workshopVertical = narrow and not compact,
		revealWidth = revealWidth, revealHeight = revealHeight,
		revealScale = math.min(1, (w - 24) / revealWidth, (h - (if tightCanvas then 24 else 32)) / revealHeight),
	}
end
return Layout
