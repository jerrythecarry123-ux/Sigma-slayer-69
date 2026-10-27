#!/usr/bin/env python3
"""Exercise production fish geometry and animation with spatial doubles.

Checks bounded, distinct geometry, cosmetic physics flags, variant contrast and
repeatable appearance/animation away from the origin. Rendering needs Studio.
Run: python tools/check_fish_models.py --luau /path/to/luau
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CHECK = r'''

local count,totalParts,maxParts=0,0,0
local silhouettes={}
local function near(a,b) return (a-b).Magnitude<.00001 end
local function sameFrame(a,b) return near(a.Position,b.Position) and near(a.RightVector,b.RightVector) and near(a.UpVector,b.UpVector) end
local function sameColor(a,b) return math.abs(a.R-b.R)<.00001 and math.abs(a.G-b.G)<.00001 and math.abs(a.B-b.B)<.00001 end
local function luminance(color) return color.R*.2126+color.G*.7152+color.B*.0722 end
local motionSignatures={}
local jointSamples,bodyJoins,exceptionalContacts,veinFootprints=0,0,0,0
local hingeSamples,connectedDetails,faceContacts=0,0,0
local function insideEllipsoid(part,point)
 local localPoint=part.CFrame:PointToObjectSpace(point)
 local p=Vector3.new(localPoint.X*2/part.Size.X,localPoint.Y*2/part.Size.Y,localPoint.Z*2/part.Size.Z)
 return p:Dot(p)<.999
end
local function insideShape(part,point)
 if not part:IsA('WedgePart') then return insideEllipsoid(part,point) end
 local localPoint=part.CFrame:PointToObjectSpace(point)
 local p=Vector3.new(localPoint.X/part.Size.X,localPoint.Y/part.Size.Y,localPoint.Z/part.Size.Z)
 -- Native wedges have their full-height end at local +Z and a sloping Y=Z face.
 return math.abs(p.X)<.499 and p.Y>-.499 and p.Z<.499 and p.Z>-.499 and p.Y<p.Z-.001
end
local function joined(a,b)
 for sample=0,300 do
  local point=a.Position:Lerp(b.Position,sample/300)
  if insideShape(a,point) and insideShape(b,point) then return true end
 end
 -- An oblique, slender ellipsoid can meet the skin near its end even when
 -- the line between the two part centres misses that small intersection.
 for _,candidate in {a,b} do
  if candidate:IsA('WedgePart') then continue end
  for _,axis in {Vector3.xAxis,Vector3.yAxis,Vector3.zAxis} do
   for sample=-49,49 do
    local point=candidate.CFrame*(candidate.Size*axis*(sample/100))
    if insideShape(a,point) and insideShape(b,point) then return true end
   end
  end
  for _,axes in {{Vector3.xAxis,Vector3.yAxis},{Vector3.xAxis,Vector3.zAxis},{Vector3.yAxis,Vector3.zAxis}} do
   for first=-6,6 do for second=-6,6 do
    local u,v=first*.15,second*.15
    if u*u+v*v>=.96 then continue end
    local point=candidate.CFrame*(candidate.Size*(axes[1]*u+axes[2]*v)*.5)
    if insideShape(a,point) and insideShape(b,point) then return true end
   end end
  end
 end
 -- A wedge's box centre is on its diagonal face, so a centre-to-centre ray
 -- alone can miss a genuine root contact. Search its real triangular volume.
 for _,candidate in {a,b} do
  if not candidate:IsA('WedgePart') then continue end
  for zStep=0,24 do
   local z=-.48+zStep*.96/24
   for yStep=0,24 do
    local y=-.48+(z+.478)*yStep/24
    local point=candidate.CFrame*(Vector3.new(0,y,z)*candidate.Size)
    if insideShape(a,point) and insideShape(b,point) then return true end
   end
  end
 end
 return false
end
local function bounds(part)
 local h=part.Size*.5
 local a,b,c=part.CFrame.RightVector,part.CFrame.UpVector,part.CFrame.LookVector
 local extent=Vector3.new(math.abs(a.X)*h.X+math.abs(b.X)*h.Y+math.abs(c.X)*h.Z,
  math.abs(a.Y)*h.X+math.abs(b.Y)*h.Y+math.abs(c.Y)*h.Z,
  math.abs(a.Z)*h.X+math.abs(b.Z)*h.Y+math.abs(c.Z)*h.Z)
 return {lo=part.Position-extent,hi=part.Position+extent}
end
local function overlap(first,second)
 return first.lo.X<second.hi.X and second.lo.X<first.hi.X
  and first.lo.Y<second.hi.Y and second.lo.Y<first.hi.Y
  and first.lo.Z<second.hi.Z and second.lo.Z<first.hi.Z
end
local function assertConnected(fish,species)
 local parts=fish:GetChildren()
 local boxes,attached={}, {[fish.PrimaryPart]=true}
 for _,part in parts do boxes[part]=bounds(part) end
 local remaining=#parts-1
 for _=1,#parts do
  local progressed=false
  for _,part in parts do
   if attached[part] then continue end
   local candidates={}
   for support in attached do
    if overlap(boxes[part],boxes[support]) then table.insert(candidates,support) end
   end
   table.sort(candidates,function(a,b)return (a.Position-part.Position).Magnitude<(b.Position-part.Position).Magnitude end)
   for _,support in candidates do
    if joined(part,support) then
     attached[part]=true;remaining-=1;connectedDetails+=1;progressed=true;break
    end
   end
  end
  if remaining==0 then return end
  if not progressed then break end
 end
 local detached={}
 for _,part in parts do if not attached[part] then table.insert(detached,part.Name) end end
 assert(false,species.Id..' has detached actual geometry: '..table.concat(detached,', '))
end
for _,species in modules.FishCatalog.Species do
 local fish=modules.FishModel.create(workspace,nil,species.Id)
 local faceColors={}
 local signature={}
 for _,p in fish:GetChildren() do
  if p.Name=="EyeWhite" or p.Name=="Pupil" or p.Name=="EyeGlint" or p.Name=="Mouth" then faceColors[p]=p.Color end
  table.insert(signature,string.format("%.3f,%.3f,%.3f/%.3f,%.3f,%.3f",p.Size.X,p.Size.Y,p.Size.Z,p.Position.X,p.Position.Y,p.Position.Z))
 end
 table.sort(signature)
 silhouettes[species.Id]=table.concat(signature,";")
 fish:PivotTo(CFrame.new(217,41,-81)*CFrame.Angles(.1,.3,-.05))
 local pivot=fish:GetPivot()
 modules.FishModel.applyAppearance(fish,"Golden",species.WeightMax)
 local snapshot={}
 for _,p in fish:GetChildren() do
  assert(p.Anchored and not p.CanTouch and not p.CanQuery and not p.CanCollide,"fish added physics")
  assert(p.Material~="Neon","fish added eye-straining emission")
  if p:IsA("Part") then
   local mesh=p:FindFirstChild("EllipsoidMesh")
   assert(mesh and mesh:IsA("SpecialMesh") and mesh.MeshType==Enum.MeshType.Sphere,
    "fish depends on a native Ball being freely stretched")
   assert(near(mesh.Scale,Vector3.one),"fish mesh scale no longer follows parent rest dimensions")
  end
  snapshot[p]={size=p.Size,frame=p.CFrame,color=p.Color}
 end
 modules.FishModel.animate(fish,1.28)
 modules.FishModel.applyAppearance(fish,"Normal",species.WeightMin)
 modules.FishModel.applyAppearance(fish,"Golden",species.WeightMax)
 for p,a in snapshot do
  assert(near(p.Size,a.size) and sameFrame(p.CFrame,a.frame),"appearance geometry accumulated after animation")
  assert(sameColor(p.Color,a.color),"appearance tint accumulated")
 end
 for _,variant in {"Normal","Golden","Prismatic"} do
  modules.FishModel.applyAppearance(fish,variant,species.WeightMax)
  for p,a in snapshot do assert(near(p.Size,a.size) and sameFrame(p.CFrame,a.frame),"variant changed a species silhouette") end
  for p,color in faceColors do assert(sameColor(p.Color,color),variant.." changed face readability") end
  if variant~="Normal" then
   local skin=luminance(fish.PrimaryPart.Color)
   for _,p in fish:GetChildren() do
    if p:GetAttribute("FishColorRole")=="Pattern" then
     assert(math.abs(luminance(p.Color)-skin)>.035,variant.." erased a fitted marking")
    end
   end
  end
 end
 local whites,pupils,glints={},{},{}
 for _,part in fish:GetChildren() do
  if part.Name=='EyeWhite' then table.insert(whites,part)
  elseif part.Name=='Pupil' then table.insert(pupils,part)
  elseif part.Name=='EyeGlint' then table.insert(glints,part) end
 end
 assert(#whites==2 and #pupils==2 and #glints==2,species.Id..' lost a complete readable pair of eyes')
 for index=1,2 do
  local head=fish:FindFirstChild('TurtleHead') or fish.PrimaryPart
  assert(joined(head,whites[index]),species.Id..' eye white floats outside its actual head')
  assert(joined(whites[index],pupils[index]),species.Id..' pupil floats outside its eye white')
  assert(joined(pupils[index],glints[index]),species.Id..' glint floats outside its pupil')
  faceContacts+=3
 end
 assert(joined(fish:FindFirstChild('TurtleHead') or fish:FindFirstChild('PikeSnout') or fish.PrimaryPart,fish:FindFirstChild('Mouth')),
  species.Id..' mouth floats outside its actual face')
 faceContacts+=1
 if species.Id=='cloudmoth' then
  local wings,spots,pearls={},{},{}
  for _,part in fish:GetChildren() do
   if part.Name=='WingTip' then table.insert(wings,part)
   elseif part.Name=='MothWingSpot' then table.insert(spots,part)
   elseif part.Name=='MothWingPearl' then table.insert(pearls,part) end
  end
  for index=1,2 do
   assert(joined(wings[index],spots[index]),'Cloudmoth eyespot lost its fixed hind-wing support')
   assert(joined(spots[index],pearls[index]),'Cloudmoth pearl floats above its eyespot')
  end
 end
 local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 local groups,relative={},{}
 for _,p in fish:GetChildren() do
  local group=p:GetAttribute('FishMotionGroup')
  if group~=nil then
   groups[group]=groups[group] or {};table.insert(groups[group],p)
  end
 end
 for group,parts in groups do
  relative[group]={}
  for _,p in parts do relative[group][p]=parts[1].CFrame:Inverse()*p.CFrame end
 end
 local firstMotion,changed=false,false
 for frame=0,120 do
  modules.FishModel.animate(fish,frame*.05)
  for _,part in fish:GetChildren() do
   local kind=part:GetAttribute('FishMotionKind')
   if part.Name=='Fin' or part.Name=='Tail' or part.Name=='Tentacle' or part.Name=='TentacleTip' then
    assert(kind~=nil,species.Id..' legacy '..part.Name..' must have an authored skin hinge')
   end
   if not kind or part.Name=='TentacleTip' then continue end
   local support=if kind=='Tail' then fish:FindFirstChild('TailStock') or fish.PrimaryPart
    elseif kind=='Tentacle' then fish:FindFirstChild('MantleRim') else fish.PrimaryPart
   local root=pivot*part:GetAttribute('FishMotionCenter')
   assert(insideShape(support,root) and insideShape(part,root),species.Id..' moving '..part.Name..' lost its embedded skin hinge')
   hingeSamples+=1
  end
  for group,parts in groups do
   for _,p in parts do
    assert(sameFrame(parts[1].CFrame:Inverse()*p.CFrame,relative[group][p]),'a fitted membrane left its animated segment')
    jointSamples+=1
   end
  end
  if species.Id=='veilfin' then
   local previous=fish.PrimaryPart
   local segments={}
   for _,p in fish:GetChildren() do
    if p.Name=='VeilSegment' then
     local shared=false
     for sample=0,100 do
      local point=previous.Position:Lerp(p.Position,sample/100)
      if insideEllipsoid(previous,point) and insideEllipsoid(p,point) then shared=true;break end
     end
     assert(shared,'Veilfin has an open body joint during its wave')
     bodyJoins+=1;previous=p;segments[p:GetAttribute('FishMotionGroup')]=p
    end
   end
   for _,p in fish:GetChildren() do
    local support=nil
    if p.Name=='VeilMembrane' or p.Name=='VeilSpine' then support=segments[p:GetAttribute('FishMotionGroup')]
    elseif p.Name=='VeilStreamer' then support=previous
    elseif p.Name=='VeilHeadFin' or p.Name=='VeilCrest' then support=fish.PrimaryPart end
    if support then
     assert(joined(support,p),'Veilfin detail is detached from its actual support skin: '..p.Name)
     exceptionalContacts+=1
    end
   end
  elseif species.Id=='eclipse' then
   local previous=fish.PrimaryPart
   local wings={}
   for _,p in fish:GetChildren() do
    if p.Name=='EclipseWing' then wings[p:GetAttribute('FishMotionGroup')]=p end
    if p.Name=='CometTail' then
     assert(joined(previous,p),'Eclipse has an open ellipsoid tail joint')
     exceptionalContacts+=1;previous=p
    end
   end
   for _,p in fish:GetChildren() do
    if p.Name=='CometStreamer' or p.Name=='CometPearl' then
     assert(joined(previous,p),'Eclipse terminal detail is detached from the actual tail skin: '..p.Name)
     exceptionalContacts+=1
    elseif p.Name=='CrescentRim' or p.Name=='EclipseWing' then
     assert(joined(fish.PrimaryPart,p),'Eclipse fitted detail is detached from actual body skin: '..p.Name)
     exceptionalContacts+=1
    elseif p.Name=='EclipseWingVein' then
     local wing=wings[p:GetAttribute('FishMotionGroup')]
     assert(joined(wing,p),'Eclipse vein is detached from its actual wing skin')
     for _,y in {-1,1} do for _,z in {-1,1} do
      local q=wing.CFrame:PointToObjectSpace(p.CFrame*Vector3.new(0,y*p.Size.Y*.5,z*p.Size.Z*.5))
      assert(q.Y>-.5*wing.Size.Y and q.Z>-.5*wing.Size.Z and q.Z<.5*wing.Size.Z
       and q.Y/wing.Size.Y<q.Z/wing.Size.Z,'Eclipse vein footprint overhangs the actual triangular wing')
      veinFootprints+=1
     end end
     exceptionalContacts+=1
    end
   end
  end
  if frame==0 then assertConnected(fish,species) end
  local motion={}
  for _,p in fish:GetChildren() do
   assert((p.Position-pivot.Position).Magnitude<7,"fish joint escaped at distant pivot")
   assert(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,"fish size invalid")
   local a,b,c=p.CFrame.RightVector,p.CFrame.UpVector,p.CFrame.LookVector
   assert(math.abs(a.Magnitude-1)<.00001 and math.abs(b.Magnitude-1)<.00001 and math.abs(c.Magnitude-1)<.00001
    and math.abs(a:Dot(b))<.00001 and math.abs(a:Dot(c))<.00001 and math.abs(b:Dot(c))<.00001
    and a:Cross(b):Dot(-c)>.99999,'fish animation produced a skewed or mirrored frame')
   if p:GetAttribute('FinRest') then
    local f=pivot:Inverse()*p.CFrame
    table.insert(motion,string.format('%.4f/%.4f/%.4f/%.4f/%.4f',f.Position.X,f.Position.Y,f.Position.Z,f.UpVector.X,f.LookVector.X))
   end
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    local v=pivot:PointToObjectSpace(p.CFrame*(p.Size*Vector3.new(x,y,z)*.5))
    lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
    hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
   end end end
  end
  local signature=table.concat(motion,';')
  if frame==0 then firstMotion=signature else changed=changed or signature~=firstMotion end
  if frame==39 then motionSignatures[species.Id]=signature end
 end
 assert(changed,'a production species has no animated parts')
 local pupil=fish:FindFirstChild("Pupil")
 assert(pupil.Color.R<.2 and pupil.Color.G<.3,"variant made eyes unreadable")
 local parts=#fish:GetChildren()
 assert(parts<=50,"fish exceeds cosmetic part budget")
 local extents=hi-lo
 print(string.format("%-13s %2d parts; maximum-weight animated box %.2f x %.2f x %.2f",species.Id,parts,extents.X,extents.Y,extents.Z))
 count+=1;totalParts+=parts;maxParts=math.max(maxParts,parts)
end
for _,pair in {{"pufflet","petalperch"},{"mintfin","pinepike"},{"sunskipper","cloudmoth"},{"coralcrown","crownwhale"},{"veilfin","ribbonkoi"},{"eclipse","moonray"}} do
 assert(silhouettes[pair[1]]~=silhouettes[pair[2]],"related species only differ by color")
end
assert(motionSignatures.veilfin~=motionSignatures.eclipse,'exceptional fish share an animation')
print("PASS",count,"production species:",totalParts,"parts total,",maxParts,"maximum; distinct geometry, stable appearance/animation, readable variant faces and markings, no physics/Neon")
print('PASS',jointSamples,'grouped membrane/wing/tail samples and',bodyJoins,'continuous Veilfin body joins; all species actually animate')
print('PASS',exceptionalContacts,'exceptional-fish actual ellipsoid/wedge contacts: fins, membranes, crests, tail, fork roots and crescent')
print('PASS',veinFootprints,'complete vein-footprint corners contained inside the actual triangular wings')
print('PASS',connectedDetails,'actual attached details across the complete catalog;',faceContacts,'fitted face contacts;',hingeSamples,'embedded animated fin/tail/arm roots')
'''


def check(luau: str) -> None:
    program = (ROOT / "tools/preview_roblox.luau").read_text()
    program += "\nlocal nativeTypeof=typeof\nlocal typeof=function(v) return if getmetatable(v)==CF then \"CFrame\" elseif getmetatable(v)==V then \"Vector3\" else nativeTypeof(v) end\n"
    for name, source in (("FishCatalog", "src/shared/FishCatalog.luau"),
                         ("FishModel", "src/shared/FishModel.luau")):
        program += f"\nmodules.{name}=(function()\n" + (ROOT / source).read_text() + "\nend)()\n"
        program += f'local token=Instance.new("ModuleScript");token.Name="{name}";token.Parent=shared\n'
    program += CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_fish_models.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)
        # Prove that the checks reject the two defects found in the art review,
        # instead of merely checking relative transforms or intersecting boxes.
        mutations = (
            ("opposite comet-tail yaw", "tail.CFrame *= CFrame.Angles(0, .16 + index * .16, 0)",
             "tail.CFrame *= CFrame.Angles(0, -.16 - index * .09, 0)",
             "Eclipse has an open ellipsoid tail joint"),
            ("mirrored veil root", "membrane.CFrame *= CFrame.Angles(0, side * -.25, -side * math.pi / 2)",
             "membrane.CFrame *= CFrame.Angles(0, side * -.25, side * math.pi / 2)",
             "Veilfin detail is detached from its actual support skin: VeilMembrane"),
            ("unhinged legacy fin", 'hinged(fin, 100 + side, (fin.CFrame * CFrame.new(0,-span*.34,0)).Position, "Fin", side)',
             'fin:SetAttribute("Side",side)', "legacy Fin must have an authored skin hinge"),
            ("floating royal fork", 'tail.CFrame = CFrame.fromMatrix(root + outward*.17 + Vector3.zAxis*(if petal then .29 else tailSize.Z*.5-.04), up:Cross(back),up,back)',
             'if kind == "Whale" then tail.CFrame = CFrame.new(side*.36,-.05,size.Z*.56+.3)*CFrame.Angles(0,side*-.15,side*math.pi/2) else tail.CFrame = CFrame.fromMatrix(root + outward*.17 + Vector3.zAxis*(if petal then .29 else tailSize.Z*.5-.04), up:Cross(back),up,back) end',
             "crownwhale moving Tail lost its embedded skin hinge"),
            ("detached whiskers", 'whisker.CFrame=CFrame.fromMatrix(root+direction*.32,direction,up,direction:Cross(up))',
             'whisker.CFrame=CFrame.new(side*.85,-.12-branch*.17,-size.Z*.40)*CFrame.Angles(0,side*-.3,side*(.1+branch*.2))',
             "starwhisker has detached actual geometry"),
            ("outward squid roots", 'tentacle.CFrame*=CFrame.Angles(-.13*math.sin(angle),0,.23*math.cos(angle))',
             'tentacle.CFrame*=CFrame.Angles(.13*math.sin(angle),0,-.23*math.cos(angle))',
             "bubblesquid moving Tentacle lost its embedded skin hinge"),
        )
        for name, current, broken, expected in mutations:
            assert program.count(current) == 1, f"Mutation target changed: {name}"
            path.write_text(program.replace(current, broken))
            result = subprocess.run([luau, str(path)], text=True, capture_output=True)
            assert result.returncode and expected in result.stderr, f"Contact regression missed {name}"
        print("PASS six art-review mutations: comet/veil roots, legacy fin hinges, royal fork, whiskers and squid roots are rejected")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
