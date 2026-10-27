#!/usr/bin/env python3
"""Exercise the production fishing interface with UI, tween and geometry doubles.

Uses actual catalog, progression, theme and fish modules. This verifies callbacks,
layout arithmetic and delayed reveals, not Roblox rendering or native input.
Run: python tools/check_fishing_interface.py --luau /path/to/luau
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PREPARE = r'''

local nativeTypeof=typeof
local typeof=function(value)
 return if getmetatable(value)==CF then "CFrame" elseif getmetatable(value)==V then "Vector3" else nativeTypeof(value)
end
local originalIndex, originalNewIndex = mt.__index, mt.__newindex
local signals={Changed=true,MouseEnter=true,MouseLeave=true,Activated=true}
mt.__index=function(self,key)
 if signals[key] then self.props[key]=self.props[key] or signal(); return self.props[key] end
 return originalIndex(self,key)
end
mt.__newindex=function(self,key,value)
 originalNewIndex(self,key,value)
 if key=='Value' and self.props.Changed then self.props.Changed:Fire(value) end
end
local originalNew=Instance.new
Instance.new=function(class)
 local object=originalNew(class)
 object.AbsoluteSize=Vector2.new(1280,720);object.Visible=true
 return object
end
function methods:Destroy()
 self.Parent=nil
 for _,child in table.clone(self.children) do child:Destroy() end
end
function methods:IsDescendantOf(parent)
 local current=self.Parent
 while current do if current==parent then return true end;current=current.Parent end
 return false
end
function methods:GetBoundingBox()
 local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,p in self:GetDescendants() do if p:IsA('BasePart') then
  for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
   local v=p.CFrame*(p.Size*Vector3.new(x,y,z)*.5)
   lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
   hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
  end end end
 end end
 return CFrame.new((hi+lo)/2),hi-lo
end
-- A requested native model pivot is exact. Repeated matrix inverses in this
-- lightweight double otherwise amplify rounding rather than emulate CFrames.
local originalPivot=methods.PivotTo
function methods:PivotTo(frame)
 originalPivot(self,frame)
 if self.PrimaryPart then self.PrimaryPart.CFrame=frame end
end
local UDim={new=function(scale,offset)return {Scale=scale,Offset=offset}end}
UDim2.new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
local TweenInfo={new=function(duration)return {duration}end}
local TweenService={Create=function(_,object,info,values)
 local tween={cancelled=false}
 function tween:Play() task.delay(info[1],function()if self.cancelled then return end;for key,value in values do object[key]=value end end)end
 function tween:Cancel()self.cancelled=true end
 return tween
end}
local GuiService={SelectedObject=nil}
local UserInputService={InputBegan=signal()}
game.GetService=function(_,name)
 if name=='TweenService' then return TweenService end
 if name=='GuiService' then return GuiService end
 if name=='UserInputService' then return UserInputService end
 return ReplicatedStorage
end
'''
CHECK = r'''

local audioCalls={catch=0,ui=0}
local audio=setmetatable({}, {__index=function(_,key)return function()if audioCalls[key]~=nil then audioCalls[key]+=1 end end end})
local pgui=Instance.new('PlayerGui')
local callbacks={aquarium=0,cast=0,settings=0,preferences=nil}
local ui
ui=modules.FishingInterface.new(pgui,audio,{openJournal=function()ui.hideResult()end,upgrade=function()end,openAquarium=function()callbacks.aquarium+=1;ui.closeJournal();ui.hideResult()end,castAgain=function()callbacks.cast+=1 end,
 openSettings=function()callbacks.settings+=1 end,settingsChanged=function(value)callbacks.preferences=value end})
local progression=modules.FishingProgression.new(modules.FishCatalog,function()return .5 end)
local profile=progression.create()
local function snapshot()local data=progression.snapshot(profile);data.persistent=false;data.offlineRate=0;return data end
local gui=pgui:FindFirstChild('MolnfiskarnaFishing')
local function find(node,name)
 if node.Name==name then return node end
 for _,child in node.children do local found=find(child,name);if found then return found end end
end
local function text(node,value)
 if node.Text==value then return node end
 for _,child in node.children do local found=text(child,value);if found then return found end end
end
-- Resolve the authored UDim/UIScale/grid sizes needed for camera projection.
-- This deliberately does not emulate text metrics or Roblox's layout engine.
local function resolvedSize(node)
 if node==gui then return gui.AbsoluteSize end
 local parent=resolvedSize(node.Parent)
 local authored=node.Size
 for _,child in node.Parent.children do
  if child.ClassName=='UIGridLayout' then authored=child.CellSize;break end
 end
 local factor=1
 for _,child in node.children do if child.ClassName=='UIScale' then factor*=child.Scale or 1 end end
 return Vector2.new((parent.X*authored.X.Scale+authored.X.Offset)*factor,(parent.Y*authored.Y.Scale+authored.Y.Offset)*factor)
end
local function resolvePortraits()
 for _,node in gui:GetDescendants() do if node.ClassName=='ViewportFrame' then node.AbsoluteSize=resolvedSize(node) end end
end
local projectedCorners,portraitPoses=0,0
local function insidePortrait(view,fish,label)
 local camera=view.CurrentCamera
 local tangent=math.tan(math.rad(camera.FieldOfView*.5))
 local aspect=view.AbsoluteSize.X/view.AbsoluteSize.Y
 assert(aspect>0 and camera.CFrame.Position.Magnitude<100,'portrait camera not finite/bounded: '..label..' '..view.AbsoluteSize.X..'x'..view.AbsoluteSize.Y..' camera '..camera.CFrame.Position.X..','..camera.CFrame.Position.Y..','..camera.CFrame.Position.Z)
 for _,part in fish:GetDescendants() do if part:IsA('BasePart') then
  for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
   local point=camera.CFrame:PointToObjectSpace(part.CFrame*(part.Size*Vector3.new(x,y,z)*.5))
   assert(point.Z<0 and math.abs(point.Y)<-point.Z*tangent*.99 and math.abs(point.X)<-point.Z*tangent*aspect*.99,
    label..' clips '..part.Name..' at '..point.X..','..point.Y..','..point.Z)
   projectedCorners+=1
  end end end
 end end
 portraitPoses+=1
end
assert(find(gui,'PreferencesStatus').Text=='Your collection is getting ready.','settings claimed a save before the collection loaded')
ui.updateProfile(snapshot())
ui.updateLocation({zoneId='forest',zoneName='Evergreen Reach'})
local function luminance(color)
 local function linear(channel)return if channel<=.04045 then channel/12.92 else ((channel+.055)/1.055)^2.4 end
 return linear(color.R)*.2126+linear(color.G)*.7152+linear(color.B)*.0722
end
local function contrast(foreground,background)
 local a,b=luminance(foreground),luminance(background)
 return (math.max(a,b)+.05)/(math.min(a,b)+.05)
end
for _,pair in {{modules.UITheme.Muted,modules.UITheme.Panel},{modules.UITheme.Muted,modules.UITheme.Soft},{modules.UITheme.Teal,modules.UITheme.Soft},{modules.UITheme.Panel,modules.UITheme.Teal}} do
 assert(contrast(pair[1],pair[2])>=4.5,'small interface text lost normal-text contrast')
end
assert(find(gui,'Location').BackgroundTransparency==0,'location contrast depends on the world behind it')
assert(#modules.FishCatalog.Species==17,'catalog expansion missing')
assert(text(gui,'EVERGREEN REACH') and text(gui,'0/4 LOCAL SPECIES FOUND'),'location stays stale after travel')
assert(text(gui,'JOURNAL  0/'..#modules.FishCatalog.Species),'journal total was not catalog driven')
text(gui,'MY AQUARIUM').Activated:Fire();assert(callbacks.aquarium==1)
for _,view in {{320,240},{320,530},{375,625},{568,280},{844,335},{768,964},{1920,1040}} do
 gui.AbsoluteSize=Vector2.new(view[1],view[2]);ui.animate(now,view[1],view[2])
 local loc=find(gui,'Location');local wallet=find(gui,'Wallet')
 assert(loc.Position.X.Offset+loc.Size.X.Offset<=view[1]-138-8,'location overlaps wallet')
 local settings=find(gui,'SettingsButton')
 assert(settings.Size.X.Offset>=44 and settings.Size.Y.Offset>=44,'settings touch target too small')
 assert(settings.Position.X.Offset+settings.Size.X.Offset<=view[1]-16,'settings clips screen')
 if view[2]<480 then
  assert(loc.Position.X.Offset+loc.Size.X.Offset<=settings.Position.X.Offset-8,'settings overlaps location')
  assert(settings.Position.X.Offset+settings.Size.X.Offset<=view[1]-138-8,'settings overlaps wallet')
 end
 local card=find(gui,'DiscoveryCard');local scale=find(card,'UIScale').Scale
 for _,label in {'MY AQUARIUM','CAST AGAIN'} do
  local action=text(card,label)
  assert(action.Size.Y.Offset*scale>=44-1e-6,'catch action shrinks below touch size')
  assert(action.Position.Y.Offset+action.Size.Y.Offset<=card.Size.Y.Offset,'catch action leaves card')
  assert(action.TextSize*scale>=12-1e-6,'catch action text too small')
 end
 assert(find(gui,'PreferencesCard').Size.X.Offset<=view[1]-24 and find(gui,'PreferencesCard').Size.Y.Offset<=view[2]-24,'settings modal clips canvas')
 if view[1]<480 and view[2]<480 then
  GuiService.SelectedObject=text(gui,'JOURNAL  0/17')
  ui.setState('ChargingCast');step(.2)
  local panel=find(gui,'CastCard');local panelTop=view[2]+panel.Position.Y.Offset-panel.Size.Y.Offset
  assert(not text(gui,'MY AQUARIUM').Visible and not text(gui,'JOURNAL  0/17').Visible,'tiny active card still overlaps visible navigation')
  assert(GuiService.SelectedObject==settings,'tiny active card left focus on hidden navigation')
  assert(panelTop>=settings.Position.Y.Offset+settings.Size.Y.Offset+8,'tiny active card covers its interruption path')
  assert(ui.button.Size.Y.Offset>=44 and ui.button.Position.Y.Offset+ui.button.Size.Y.Offset<=panel.Size.Y.Offset,'tiny fishing action clipped')
  ui.setState('Idle');step(.2)
  panelTop=view[2]+panel.Position.Y.Offset-panel.Size.Y.Offset
  local journal=text(gui,'JOURNAL  0/17')
  assert(journal.Visible and text(gui,'MY AQUARIUM').Visible and panelTop>=journal.Position.Y.Offset+journal.Size.Y.Offset+8,'tiny idle card covers navigation')
 end
 local book=find(gui,'CollectionBook');local gallery=find(gui,'FishGallery');local grid=find(gallery,'UIGridLayout')
 if view[2]<480 then
  local galleryHeight=book.Size.Y.Offset*gallery.Size.Y.Scale+gallery.Size.Y.Offset
  assert(galleryHeight>=grid.CellSize.Y.Offset,'short landscape cannot show a complete fish card')
  assert(grid.CellSize.Y.Offset==80,'short landscape still shrinks a tall portrait card')
  local firstCard=find(gallery,'pufflet');local portrait=find(firstCard,'Portrait')
  assert(portrait.Size.X.Offset==84 and portrait.Size.Y.Offset==-8 and not find(firstCard,'RarityDot').Visible,'compact journal did not switch to horizontal cards')
 end
end
for _,rarity in modules.FishRarity.Order do
 local expected=tostring(modules.FishRarity.get(rarity).Rank)..' / '..string.upper(rarity)
 assert(text(find(gui,'FishGallery'),expected),'journal rarity has only color or missing tier: '..rarity)
end
local castTrack=find(gui,'CastTrack')
local castPrecise=find(castTrack,'CastPrecise');local castPerfect=find(castTrack,'CastPerfect')
assert(castPrecise.Position.X.Scale==modules.FishingRules.CastPreciseMin and castPrecise.Size.X.Scale==modules.FishingRules.CastPreciseMax-modules.FishingRules.CastPreciseMin)
assert(castPerfect.Position.X.Scale==modules.FishingRules.CastPerfectMin and castPerfect.Size.X.Scale==modules.FishingRules.CastPerfectMax-modules.FishingRules.CastPerfectMin)
for _,needle in {find(castTrack,'CastPowerNeedle'),find(gui,'Needle')} do
 local outline=find(needle,'UIStroke')
 assert(outline and outline.Color==modules.UITheme.Ink and outline.Thickness>=1,'skill needle disappears over the gold target')
end
ui.setState('ChargingCast');step(.2)
assert(castTrack.Visible and not find(gui,'TimingTrack').Visible and find(gui,'CastCard').Size.Y.Offset==180,'casting reused the reeling target or clipped its power track')
for _,power in {-1,0,.52,.72,.8,.88,.95,1,2} do
 ui.setCastProgress(power)
 local needle=find(castTrack,'CastPowerNeedle').Position.X.Scale
 assert(needle==math.clamp(power,0,1),'cast needle disagrees with server power')
end
ui.setState('Reeling');step(.2)
assert(not castTrack.Visible and find(gui,'TimingTrack').Visible,'cast and reel tracks compete')
ui.setState('Idle');step(.2)
assert(not castTrack.Visible and not find(gui,'TimingTrack').Visible,'idle leaves an active skill meter')
local fine=find(find(gui,'TimingTrack'),'Fine');local gold=find(find(gui,'TimingTrack'),'Brilliant')
for attempt=1,5 do
 local center=modules.FishingRules.centerFor(attempt)
 ui.setTimingWindow(center,.14)
 local displayedCenter=gold.Position.X.Scale+gold.Size.X.Scale/2
 assert(modules.FishingRules.qualityAt(displayedCenter,center)=='Brilliant','displayed gold target does not award Brilliant')
 assert(math.abs(fine.Position.X.Scale-(center-.2))<1e-8 and math.abs(fine.Size.X.Scale-.36)<1e-8,'fine region disagrees with server')
 assert(math.abs(gold.Position.X.Scale-(center-.07))<1e-8 and math.abs(gold.Size.X.Scale-.14)<1e-8,'gold region disagrees with server')
end
for level,rod in modules.FishCatalog.Rods do
 local width=rod.TimingWidth or .14
 ui.setTimingWindow(.68,width)
 assert(math.abs(gold.Size.X.Scale-width)<1e-8,'earned rod window was clipped or ignored by the UI')
 assert(modules.FishingRules.qualityAt(.68+width/2,.68,width)=='Brilliant','shown rod gold edge disagrees with server')
 local workshopProfile=snapshot();workshopProfile.level=level-1;workshopProfile.rod=rod.Name;workshopProfile.timingWidth=width
 local nextRod=modules.FishCatalog.Rods[level+1]
 workshopProfile.nextUpgrade=if nextRod then {name=nextRod.Name,cost=nextRod.Cost,description=nextRod.Description,timingWidth=nextRod.TimingWidth} else nil
 ui.updateProfile(workshopProfile)
 local displayed=if nextRod then nextRod.TimingWidth else width
 local expected=math.floor((displayed/.14-1)*100+.5)
 assert(string.find(find(gui,'RodTimingBenefit').Text,tostring(expected)..'%',1,true),'workshop hides the actual earned rod timing benefit')
end
-- Follow actual earned progression into a first upgrade. Good catches must not
-- indefinitely hide that next step behind the chain celebration.
local journey=progression.create()
progression.catch(journey,'Fine','harbor')
ui.updateProfile(progression.snapshot(journey))
assert(text(find(gui,'CastCard'),'YOUR FIRST FISH IS HOME  ·  OPEN MY AQUARIUM'),'first discovery no longer introduces the aquarium')
progression.catch(journey,'Fine','harbor')
assert(journey.combo==2 and journey.coins>=modules.FishCatalog.Rods[2].Cost,'earned two-catch example no longer reaches the first rod')
ui.updateProfile(progression.snapshot(journey))
assert(text(find(gui,'CastCard'),'YOUR NEXT ROD IS READY  ·  VISIT THE WORKSHOP'),'a good catch chain hides an earned rod upgrade')
assert(progression.upgrade(journey).success)
ui.updateProfile(progression.snapshot(journey))
assert(text(find(gui,'CastCard'),'FINE+ CHAIN  x2  ·  KEEP THE RHYTHM'),'chain feedback disappeared when no upgrade is affordable')
journey.coins=1000000000
ui.updateProfile(progression.snapshot(journey))
assert(text(find(gui,'CastCard'),'YOUR NEXT ROD IS READY  ·  VISIT THE WORKSHOP'),'wallet cap hides an available rod')
while progression.snapshot(journey).nextUpgrade do assert(progression.upgrade(journey).success) end
for _,species in modules.FishCatalog.Species do progression.catch(journey,'Fine',species.Zone,species.Id) end
local complete=progression.snapshot(journey)
assert(complete.species==#modules.FishCatalog.Species and not complete.nextUpgrade)
ui.updateProfile(complete)
assert(text(find(gui,'CastCard'),'JOURNAL COMPLETE  ·  SHOW YOUR FINEST FISH'),'completed journal still asks the player to search another pond')
ui.updateProfile(snapshot())
local result=progression.catch(profile,'Fine','harbor');result.variant='Golden';result.coins=18;result.comboBonus=3;result.goalBonus=10
ui.updateProfile(snapshot());ui.showResult(result);step(.651)
assert(ui.isResultOpen() and text(gui,'GOLDEN CATCH'),'special catch reveal missing')
assert(text(gui,string.format('%.2f kg  ·  NEW RECORD',result.weightKg)),'size record missing from catch reveal')
assert(text(gui,'+18 coins  +10 bonus'),'chain bonus was displayed twice')
assert(text(gui,'JOURNAL  1/'..#modules.FishCatalog.Species),'discovery count stale')
local cast=text(find(gui,'DiscoveryCard'),'CAST AGAIN');cast.Activated:Fire();assert(callbacks.cast==1 and not ui.isResultOpen())
ui.showResult(result);ui.hideResult();step(.7);assert(not ui.isResultOpen(),'cancelled reveal reopened')
ui.showResult(result);step(.651);ui.openJournal('Collection');step(3);assert(ui.isJournalOpen() and not ui.isResultOpen(),'collection competes with delayed reveal')
ui.closeJournal();ui.showResult({species='Pufflet',speciesId='pufflet',rarity='Common',quality='Fine',variant='Normal',weightKg=1.25,coins=8,combo=2})
step(.651);assert(ui.isResultOpen());step(1.401);assert(not ui.isResultOpen(),'ordinary repeat catch blocks next cast too long')

local journal=text(gui,'JOURNAL  1/'..#modules.FishCatalog.Species)
GuiService.SelectedObject=journal
ui.openJournal('Workshop')
assert(ui.isJournalOpen() and GuiService.SelectedObject.Text=='Rod workshop','journal gamepad focus missing')
UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.ButtonB},false)
assert(not ui.isJournalOpen() and GuiService.SelectedObject==journal,'journal cancel/focus restoration failed')
ui.showResult(result)
ui.openSettings();step(.7)
assert(ui.isSettingsOpen() and not ui.isResultOpen() and not ui.isJournalOpen(),'settings competes with delayed result')
assert(not find(gui,'CastCard').Visible and GuiService.SelectedObject.Name=='SoundToggle','settings lacks modal focus')
ui.setPreferences({reducedEffects=false,soundEnabled=true,persistent=false,savePending=false})
assert(find(gui,'PreferencesStatus').Text=='Applies to this Studio visit.','Studio preferences imply published persistence')
ui.setPreferences({reducedEffects=false,soundEnabled=true,persistent=true,savePending=true})
assert(find(gui,'PreferencesStatus').Text=='Updating your preferences...','pending preferences hide their status')
ui.setPreferences({reducedEffects=false,soundEnabled=true,persistent=true,savePending=false})
assert(find(gui,'PreferencesStatus').Text=='Preferences save with your collection.','accepted preferences still claim session-only behavior')
ui.setPreferences({reducedEffects=false,soundEnabled=true,systemReducedMotion=true,persistent=true,savePending=false})
assert(find(gui,'ReducedEffectsToggle').Text=='OFF' and find(gui,'PreferencesStatus').Text=='Roblox Reduce Motion is on.\nPreferences save with your collection.','system motion preference confused with local preference')
find(gui,'ReducedEffectsToggle').Activated:Fire()
assert(callbacks.preferences.reducedEffects==true and callbacks.preferences.soundEnabled==true,'motion preference callback wrong')
assert(find(gui,'PreferencesStatus').Text=='Roblox Reduce Motion is on.\nUpdating your preferences...','local change lost published metadata or OS explanation')
local preferenceFields=0;for _ in callbacks.preferences do preferenceFields+=1 end
assert(preferenceFields==2,'preference callback leaked UI status metadata into the server request')
local priorSounds=audioCalls.ui
find(gui,'SoundToggle').Activated:Fire()
assert(callbacks.preferences.soundEnabled==false and find(gui,'SoundToggle').Text=='OFF','sound preference callback wrong')
assert(audioCalls.ui==priorSounds,'muting played a confirmation sound')
UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.Escape},false)
assert(not ui.isSettingsOpen() and GuiService.SelectedObject==journal,'settings cancel/focus restoration failed')
ui.openSettings();ui.openJournal('Collection')
assert(ui.isJournalOpen() and not ui.isSettingsOpen(),'journal does not replace settings')
ui.closeJournal();ui.openSettings()
local external=Instance.new('TextButton');external.Parent=pgui
GuiService.SelectedObject=external
ui.closeSettings()
assert(GuiService.SelectedObject==external,'closing settings stole focus from another interface')

ui.setPreferences({reducedEffects=true,soundEnabled=true})
local priorCatches=audioCalls.catch
UserInputService.PreferredInput=Enum.PreferredInput.Gamepad
GuiService.SelectedObject=journal
ui.showResult(result,true,true);step(.001)
assert(ui.isResultOpen() and audioCalls.catch==priorCatches,'post-cinematic card delayed or duplicated sound')
assert(GuiService.SelectedObject.Text=='CAST AGAIN','result does not focus gamepad continuation')
UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.ButtonB},false)
assert(not ui.isResultOpen() and GuiService.SelectedObject==journal,'result cannot dismiss with gamepad or restore focus')
for _,rarity in {'Epic','Legendary','Mythical','Secret'} do
 ui.showResult({species='Test',speciesId='pufflet',rarity=rarity,quality='Fine',weightKg=1,coins=8},true,true);step(.001)
 assert(text(find(gui,'DiscoveryCard'),modules.UITheme.rarityLabel(rarity)..' · Fine'),'catch rarity missing word/rank')
end
ui.hideResult()
-- Inspect the actual UI models, animation, appearance scale and portrait camera
-- rather than a separately reconstructed fish or a finite-camera-only check.
local function portraitLayout(size)
 gui.AbsoluteSize=Vector2.new(size[1],size[2]);ui.animate(now,size[1],size[2]);resolvePortraits();ui.animate(now,size[1],size[2])
end
ui.setPreferences({reducedEffects=false,soundEnabled=true})
for _,size in {{320,240},{320,530},{375,625},{568,280},{844,335},{768,964},{1920,1040}} do
 portraitLayout(size)
 ui.openJournal('Collection')
 for _,species in modules.FishCatalog.Species do
  local card=find(find(gui,'FishGallery'),species.Id)
  card.Activated:Fire()
  local portrait=find(card,'Portrait')
  local model=portrait:FindFirstChild('WorldModel'):GetChildren()[1]
  for pose=0,20 do
   ui.animate(pose*.237,size[1],size[2])
   insidePortrait(portrait,model,'journal '..species.Id..' '..size[1]..'x'..size[2])
  end
 end
 ui.closeJournal()
 for _,species in modules.FishCatalog.Species do
  ui.showResult({species=species.Name,speciesId=species.Id,rarity=species.Rarity,quality='Brilliant',variant='Prismatic',weightKg=species.WeightMax,coins=18,goalBonus=10,castBonus=2,castGrade='Perfect'},true,true)
  step(.001);portraitLayout(size)
  local portrait=find(gui,'CatchPortrait');local model=portrait:FindFirstChild('WorldModel'):GetChildren()[1]
  for pose=0,20 do
   ui.animate(pose*.237,size[1],size[2])
   insidePortrait(portrait,model,'catch '..species.Id..' '..size[1]..'x'..size[2])
  end
  assert(text(find(gui,'Earnings'),'+18 coins  +10 bonus\nIncludes +2 cast bonus'),'cast bonus was omitted or counted a second time')
  ui.hideResult()
 end
end
print('PASS actual fishing UI: catalog totals, region update, aquarium action and responsive layout')
print('PASS earned rod guidance outranks chains, wallet-cap upgrades and completed-journal next step')
print('PASS server-aligned timing zones, variant/weight reveal, accurate coin totals and cast-again action')
print('PASS cancelled/stale reveal, journal overlay and short repeat-catch dismissal')
print('PASS seven-tier labels, published/Studio preference status, system reduced motion and silent immediate result')
print('PASS journal/settings modal exclusion, gamepad focus, Escape/ButtonB and external focus ownership')
print('PASS independent cast-power meter/bands, included cast bonus and',portraitPoses,'actual journal/catch portrait poses /',projectedCorners,'projected corners')
'''


def check(luau: str) -> None:
    spec = importlib.util.spec_from_file_location("portal_check", ROOT / "tools/check_portal_interface.py")
    portal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portal)
    # Reuse only the portal check's scheduler and signals; geometry/UI objects
    # below are the shared preview doubles, not a replacement implementation.
    scheduler = portal.PREPARE.split("local methods={}")[0]
    program = (ROOT / "tools/preview_roblox.luau").read_text() + scheduler + PREPARE
    sources = (("FishRarity", "src/shared/FishRarity.luau"),
               ("FishCatalog", "src/shared/FishCatalog.luau"),
               ("FishingRules", "src/shared/FishingRules.luau"),
               ("FishModel", "src/shared/FishModel.luau"),
               ("UITheme", "src/client/UITheme.luau"),
               ("InterfaceLayout", "src/client/InterfaceLayout.luau"),
               ("FishingProgression", "src/server/FishingProgression.luau"),
               ("FishingInterface", "src/client/FishingInterface.luau"))
    for name, source in sources:
        program += f"\nmodules.{name}=(function()\n" + (ROOT / source).read_text() + "\nend)()\n"
        program += f'local token=Instance.new("ModuleScript");token.Name="{name}";token.Parent=shared\n'
    program += CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_fishing_interface.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
