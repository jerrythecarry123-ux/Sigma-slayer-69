#!/usr/bin/env python3
"""Run production rare-catch stages with scheduler, camera, UI and geometry doubles.

Verifies ownership and callbacks, not native Roblox rendering or device input.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PREPARE = r'''
local nativeTypeof=typeof
local typeof=function(v)
 return if getmetatable(v)==CF then "CFrame" elseif getmetatable(v)==V then "Vector3" else nativeTypeof(v)
end
local originalIndex,originalNewIndex=mt.__index,mt.__newindex
mt.__index=function(self,key)
 if key=='Activated' or key=='MouseEnter' or key=='MouseLeave' or key=='AncestryChanged' or key=='CharacterRemoving' or key=='CharacterAdded' or key=='Died' or key=='InputBegan' or key=='ChildAdded' then
  self.props[key]=self.props[key] or signal();return self.props[key]
 end
 return originalIndex(self,key)
end
mt.__newindex=function(self,key,value)
 originalNewIndex(self,key,value)
 if key=='Parent' and self.props.AncestryChanged then self.props.AncestryChanged:Fire(self,value) end
end
local instanceNew=Instance.new
Instance.new=function(class)
 local o=instanceNew(class);o.AbsoluteSize=Vector2.new(1280,720);o.Visible=true;return o
end
function methods:Destroy()
 self.Parent=nil
 for _,c in table.clone(self.children) do c:Destroy() end
 self.destroyed=true
end
function methods:FindFirstChildOfClass(class)
 for _,child in self.children do if child:IsA(class) then return child end end
 return nil
end
function methods:IsDescendantOf(parent)
 local n=self.Parent
 while n do if n==parent then return true end;n=n.Parent end
 return false
end
function methods:GetAttributeChangedSignal(key)
 self.props['Attr'..key]=self.props['Attr'..key] or signal();return self.props['Attr'..key]
end
local originalSetAttribute=methods.SetAttribute
function methods:SetAttribute(key,value)
 originalSetAttribute(self,key,value)
 if self.props['Attr'..key] then self.props['Attr'..key]:Fire() end
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
UDim2.new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
local TweenInfo={new=function(duration)return {duration}end}
local TweenService={Create=function(_,object,info,values)
 local tween={cancelled=false}
 function tween:Play()task.delay(info[1],function()if not self.cancelled and not object.destroyed then for k,v in values do object[k]=v end end end)end
 function tween:Cancel()self.cancelled=true end
 return tween
end}
local player=Instance.new('Player');player.UserId=101
local pgui=Instance.new('PlayerGui');pgui.Parent=player
local character=Instance.new('Model');player.Character=character
local humanoid=Instance.new('Humanoid');humanoid.Parent=character
local input=Instance.new('UserInputService');input.GamepadEnabled=false;input.PreferredInput=Enum.PreferredInput.KeyboardAndMouse
local GuiService={SelectedObject=nil,ReducedMotionEnabled=false}
local RunService={RenderStepped=signal(),PreSimulation=signal()}
local worldCamera=Instance.new('Camera');worldCamera.Name='UntouchedWorldCamera';worldCamera.CFrame=CFrame.new(13,21,-6);worldCamera.CameraType='Custom';worldCamera.FieldOfView=70
workspace.CurrentCamera=worldCamera
local services={Players={LocalPlayer=player},ReplicatedStorage=ReplicatedStorage,UserInputService=input,GuiService=GuiService,RunService=RunService,TweenService=TweenService}
game.GetService=function(_,name)return services[name] end
local function find(node,name)
 if node.Name==name then return node end
 for _,child in node.children do local found=find(child,name);if found then return found end end
end
local calls={}
local audio={catch=function(...)table.insert(calls,{...})end}
local function frame(delta)
 step(delta);RunService.PreSimulation:Fire(delta);RunService.RenderStepped:Fire(delta)
end
'''
CHECK = r'''
local complete=0
local stage=modules.CatchCinematic.new(pgui,audio)
local gui=find(pgui,'CatchCinematic');local skip=find(gui,'SkipCatch');local view=find(gui,'FishStage');local privateCamera=view.CurrentCamera
local savedWorldFrame=worldCamera.CFrame
local function result(species)
 return {species=species.Name,speciesId=species.Id,rarity=species.Rarity,quality='Brilliant',variant='Normal',weightKg=species.WeightMax,newDiscovery=true,newRecord=true}
end
local function done()complete+=1 end
local projectedCorners,animatedPoses=0,0
local compositions={}
for _,species in modules.FishCatalog.Species do
 if modules.FishRarity.get(species.Rarity).Rank<4 then
  assert(not stage.play(result(species),done) and not stage.isPlaying(),'ordinary catch blocked in a cinematic')
 else
  for _,size in {{320,530},{568,280},{375,625},{768,964},{1920,1040}} do
   gui.AbsoluteSize=Vector2.new(size[1],size[2])
   local count=#calls
   assert(stage.play(result(species),done) and stage.isPlaying() and gui.Enabled,'exceptional catch did not open')
   assert(#calls==count+1,'stage did not own exactly one catch phrase')
   local panel=find(gui,'PortraitStage')
   assert(panel.Size.X.Offset<=size[1]-24 and panel.Size.Y.Offset<=size[2]-20,'stage exceeds safe viewport')
   view.AbsoluteSize=Vector2.new(panel.Size.X.Offset*view.Size.X.Scale+view.Size.X.Offset,panel.Size.Y.Offset*view.Size.Y.Scale+view.Size.Y.Offset)
   if size[2]<430 then
    assert(view.AbsoluteSize.Y>=size[2]-52 and view.AbsoluteSize.X>=220,'landscape portrait was reduced to a thin strip')
    assert(skip.Size.Y.Offset>=44,'landscape skip is too small for touch')
   end
   for pose=1,30 do
    frame(modules.FishRarity.get(species.Rarity).RevealDuration*.90/30)
    assert(stage.isPlaying(),'first reveal ended before framing samples completed')
    animatedPoses+=1
    local v=privateCamera.CFrame.Position
    assert(v.X==v.X and v.Y==v.Y and v.Z==v.Z and v.Magnitude<100,'private camera framing is not finite/bounded')
    local aspect=view.AbsoluteSize.X/view.AbsoluteSize.Y
    local tangent=math.tan(math.rad(privateCamera.FieldOfView*.5))
    for _,p in find(view,'PortraitWorld'):GetDescendants() do if p:IsA('BasePart') then
     for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
      local point=privateCamera.CFrame:PointToObjectSpace(p.CFrame*(p.Size*Vector3.new(x,y,z)*.5))
      assert(point.Z<0 and math.abs(point.Y)<-point.Z*tangent*.99 and math.abs(point.X)<-point.Z*tangent*aspect*.99,'animated fish clipped portrait on '..size[1]..'x'..size[2]..': '..species.Id..'/'..p.Name)
      projectedCorners+=1
     end end end
    end end
    if pose==15 then
     local signature={}
     for index=1,8 do
      local mote=find(view,'Accent'..index)
      assert(mote and mote.Visible and mote.Parent==view,'tier accents escaped the portrait or were missing')
      local x,y=mote.Position.X.Scale,mote.Position.Y.Scale
      assert(x>=.10 and x<=.90 and y>=.22 and y<=.76,'tier accent intrudes into copy or leaves portrait')
      table.insert(signature,string.format('%.3f/%.3f/%d/%d',x,y,mote.Size.X.Offset,mote.Size.Y.Offset))
     end
     local effect=modules.FishRarity.get(species.Rarity).Effect
     compositions[effect]=table.concat(signature,';')
     if effect=='Crown' then
      for index=1,8 do assert(find(view,'Accent'..index).Position.Y.Scale<=.401,'crown accents no longer form an upper arc')end
     elseif effect=='Aurora' then
      for index=1,8 do local x=find(view,'Accent'..index).Position.X.Scale;assert(x<.25 or x>.75,'aurora ribbons obscured the fish center')end
     elseif effect=='Eclipse' then
      assert(find(view,'Accent8').Size.Y.Offset==3 and find(view,'Accent1').Size.Y.Offset>3,'eclipse lost its distinct comet point')
     end
    end
    assert(workspace.CurrentCamera==worldCamera and worldCamera.CFrame==savedWorldFrame and worldCamera.CameraType=='Custom' and worldCamera.FieldOfView==70,'stage stole world camera')
   end
   local before=complete
   skip.Activated:Fire();assert(complete==before+1 and not stage.isPlaying() and not gui.Enabled,'skip did not complete exactly once')
   frame(5);assert(complete==before+1,'old watchdog completed twice')
  end
 end
end
for _,first in {'Petals','Crown','Aurora','Eclipse'} do
 assert(compositions[first],'exceptional tier has no tested composition')
 for _,second in {'Petals','Crown','Aurora','Eclipse'} do if first~=second then assert(compositions[first]~=compositions[second],'exceptional tiers differ only by color/duration')end end
end
local legendary=result(modules.FishCatalog.get('crownwhale'));legendary.newDiscovery=false
input.GamepadEnabled=true;input.PreferredInput=Enum.PreferredInput.Gamepad
local prior=Instance.new('TextButton');prior.Parent=pgui;GuiService.SelectedObject=prior
assert(stage.play(legendary,done) and GuiService.SelectedObject==skip)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.ButtonB},true)
assert(not stage.isPlaying() and GuiService.SelectedObject==prior,'gamepad skip failed to restore owned focus')
stage.play(legendary,done);local external=Instance.new('TextButton');external.Parent=pgui;GuiService.SelectedObject=external
skip.Activated:Fire();assert(GuiService.SelectedObject==external,'stage overwrote newer modal focus')
input.PreferredInput=Enum.PreferredInput.Touch
GuiService.SelectedObject=prior;stage.play(legendary,done)
assert(GuiService.SelectedObject==prior,'connected gamepad stole active touch focus')
local portraitModel=find(view,'CinematicFish')
for _,size in {{568,280},{320,530},{768,964},{1920,1040}} do
 gui.AbsoluteSize=Vector2.new(size[1],size[2]);frame(.01)
 local panel=find(gui,'PortraitStage')
 view.AbsoluteSize=Vector2.new(panel.Size.X.Offset*view.Size.X.Scale+view.Size.X.Offset,panel.Size.Y.Offset*view.Size.Y.Scale+view.Size.Y.Offset)
 frame(.01)
 assert(stage.isPlaying() and find(view,'CinematicFish')==portraitModel,'resize restarted or lost an active catch')
 assert(skip.Size.Y.Offset>=44,'resize shrank the skip touch target')
end
stage.stop();input.PreferredInput=Enum.PreferredInput.Gamepad
stage.play(legendary,done);local detachedAt=complete;gui.Parent=nil;frame(5)
assert(not stage.isPlaying() and complete==detachedAt and not stage.play(legendary,done),'detached overlay kept an invisible stage alive')
gui.Parent=pgui
stage.play(legendary,done);local before=complete;step(1.86)
assert(not stage.isPlaying() and complete==before+1,'repeat presentation exceeds bounded watchdog duration')
stage.play(legendary,done);before=complete;stage.stop('new cast');frame(5)
assert(not stage.isPlaying() and complete==before,'cancel reopened/completed a stale result')
stage.play(legendary,done);humanoid.Died:Fire();frame(5)
assert(not stage.isPlaying() and complete==before,'death left a catch overlay')
stage.play(legendary,done);player.CharacterRemoving:Fire(Instance.new('Model'));frame(5)
assert(not stage.isPlaying() and complete==before,'character removal left a catch overlay')
for _,key in {'IslandTravelMenuOpen','IslandTravelBusy'} do
 stage.play(legendary,done);player:SetAttribute(key,true);frame(5)
 assert(not stage.isPlaying() and complete==before,'travel left stale catch stage')
 player:SetAttribute(key,false)
end
stage.play(legendary,done)
local newCharacter=Instance.new('Model');player.Character=newCharacter;player.CharacterAdded:Fire(newCharacter)
assert(not stage.isPlaying() and complete==before,'character replacement without removal retained an old reveal')
local lateHumanoid=Instance.new('Humanoid');lateHumanoid.Parent=newCharacter;newCharacter.ChildAdded:Fire(lateHumanoid)
stage.play(legendary,done);lateHumanoid.Died:Fire();frame(5)
assert(not stage.isPlaying() and complete==before,'late humanoid death binding was missed')
stage.setReducedEffects(true);stage.play(legendary,done);frame(.1)
local pose=privateCamera.CFrame
for _,child in view.children do if string.sub(child.Name,1,6)=='Accent' then assert(not child.Visible,'reduced effects retained moving accents') end end
frame(.1);assert((privateCamera.CFrame.Position-pose.Position).Magnitude<.000001,'reduced stage still moves camera')
frame(.7);assert(not stage.isPlaying() and complete==before+1,'reduced stage did not finish briefly')
stage.setReducedEffects(false);GuiService.ReducedMotionEnabled=true;stage.play(legendary,done);frame(.1)
for _,child in view.children do if string.sub(child.Name,1,6)=='Accent' then assert(not child.Visible,'ignored Roblox Reduce Motion preference') end end
stage.stop();GuiService.ReducedMotionEnabled=false
stage.play(legendary,done);before=complete;stage.destroy();frame(5)
assert(not stage.isPlaying() and complete==before and not stage.play(legendary,done),'destroy left callbacks or reopened the stage')
assert(workspace.CurrentCamera==worldCamera and worldCamera.CFrame==savedWorldFrame,'cleanup touched world camera')
print('PASS rare-catch stages:',animatedPoses,'animated full-sequence poses /',projectedCorners,'projected corners on five viewport sizes, bounded distinct tier compositions and exactly-once skip')
print('PASS common catches bypass; repeat/quiet durations; reduced motion; owned gamepad focus; travel/character/cancel/destroy stale callbacks')
print('PASS private camera only: world camera identity, CFrame, camera mode and FOV unchanged throughout')
'''


def program() -> str:
    spec = importlib.util.spec_from_file_location("portal_check", ROOT / "tools/check_portal_interface.py")
    portal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portal)
    scheduler = portal.PREPARE.split("local methods={}")[0]
    code = (ROOT / "tools/preview_roblox.luau").read_text() + scheduler + PREPARE
    for name, path in (("FishCatalog", "src/shared/FishCatalog.luau"),
                       ("FishRarity", "src/shared/FishRarity.luau"),
                       ("FishModel", "src/shared/FishModel.luau"),
                       ("UITheme", "src/client/UITheme.luau"),
                       ("CatchCinematic", "src/client/CatchCinematic.luau")):
        module = InstanceHeader(name)
        code += module + (ROOT / path).read_text() + "\nend)()\n"
    return code


def InstanceHeader(name: str) -> str:
    return f'\nlocal token=Instance.new("ModuleScript");token.Name="{name}";token.Parent=shared\nmodules.{name}=(function()\n'


def check(luau: str) -> None:
    with tempfile.TemporaryDirectory(prefix="cloud-anglers-cinematic-") as temp:
        script = Path(temp) / "check.luau"
        script.write_text(program() + CHECK)
        subprocess.run([luau, str(script)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
