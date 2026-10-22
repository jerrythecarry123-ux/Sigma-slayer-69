--!strict
local Layout = require("../src/client/InterfaceLayout")
local passed = 0
local function check(name: string, run: () -> ())
	run()
	passed += 1
	print("PASS " .. name)
end
check("portrait, landscape, tablet and desktop fit the inset-safe canvas", function()
	for _, viewport in { {320, 530}, {375, 625}, {390, 764}, {568, 280}, {667, 335}, {844, 335}, {768, 964}, {1024, 728}, {1920, 1040} } do
		local w, h = viewport[1], viewport[2]
		local l = Layout.measure(w, h)
		assert(l.bookWidth <= w - 24 and l.bookHeight <= h - 24, "modal clipped")
		assert(l.panelWidth <= w - 32, "casting controls clipped")
		assert(h - l.panelBottom - 180 >= 60, "active fishing obscures the top HUD")
		assert(l.revealWidth * l.revealScale <= w - 24 and l.revealHeight * l.revealScale <= h - 32, "catch reveal clipped")
		assert(l.cardHeight >= 124 and (l.bookWidth - 36) / l.columns - 7 >= 100, "fish cards too small")
	end
end)
check("aquarium and journal navigation retain separate touch targets", function()
	for _, viewport in { {320,530}, {375,625}, {568,280}, {844,335}, {1920,1040} } do
		local w,h=viewport[1],viewport[2]
		local l=Layout.measure(w,h)
		assert(l.navWidth >= 100 and l.navWidth <= 156)
		assert(l.aquariumX+l.navWidth <= w-16 and l.soundX+44 <= w-16)
		if l.compact then
			assert(l.aquariumX > (w+l.panelWidth)/2, "aquarium covers fishing controls")
			assert(16+l.navWidth < (w-l.panelWidth)/2, "journal covers fishing controls")
			assert(l.aquariumY+48 <= 114, "navigation intrudes into lower thumb controls")
		else
			assert(l.aquariumX >= 16+l.navWidth+8 and l.soundX >= l.aquariumX+l.navWidth+8)
		end
	end
end)
check("portrait fishing stays above the thumb controls", function()
	for _, w in {320, 375, 390, 430} do
		local l = Layout.measure(w, 640)
		assert(l.panelBottom >= 150)
		assert(l.columns == 2 and l.workshopVertical)
	end
end)
check("landscape fishing fits between the thumb controls", function()
	for _, w in {568, 667, 740, 844} do
		local l = Layout.measure(w, 320)
		assert((w - l.panelWidth) / 2 >= 150)
		assert(l.compact and l.goalHeight == 0 and l.panelBottom == 20)
		assert(not l.workshopVertical)
	end
end)
check("desktop uses the larger collection gallery without stretching cards", function()
	local l = Layout.measure(1920, 1040)
	assert(l.bookWidth == 900 and l.bookHeight == 590 and l.columns == 3)
	assert(l.panelWidth == 360 and l.revealScale == 1)
end)
print(passed .. " interface layout checks passed")
