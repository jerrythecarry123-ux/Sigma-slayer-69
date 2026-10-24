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
 local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 for frame=0,120 do
  modules.FishModel.animate(fish,frame*.05)
  for _,p in fish:GetChildren() do
   assert((p.Position-pivot.Position).Magnitude<7,"fish joint escaped at distant pivot")
   assert(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,"fish size invalid")
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    local v=pivot:PointToObjectSpace(p.CFrame*(p.Size*Vector3.new(x,y,z)*.5))
    lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
    hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
   end end end
  end
 end
 local pupil=fish:FindFirstChild("Pupil")
 assert(pupil.Color.R<.2 and pupil.Color.G<.3,"variant made eyes unreadable")
 local parts=#fish:GetChildren()
 assert(parts<=50,"fish exceeds cosmetic part budget")
 local extents=hi-lo
 print(string.format("%-13s %2d parts; maximum-weight animated box %.2f x %.2f x %.2f",species.Id,parts,extents.X,extents.Y,extents.Z))
 count+=1;totalParts+=parts;maxParts=math.max(maxParts,parts)
end
for _,pair in {{"pufflet","petalperch"},{"mintfin","pinepike"},{"sunskipper","cloudmoth"},{"coralcrown","crownwhale"}} do
 assert(silhouettes[pair[1]]~=silhouettes[pair[2]],"related species only differ by color")
end
print("PASS",count,"production species:",totalParts,"parts total,",maxParts,"maximum; distinct geometry, stable appearance/animation, readable variant faces and markings, no physics/Neon")
'''


def check(luau: str) -> None:
    program = (ROOT / "tools/preview_roblox.luau").read_text()
    program += "\nlocal nativeTypeof=typeof\nlocal typeof=function(v) return if getmetatable(v)==CF then \"CFrame\" else nativeTypeof(v) end\n"
    for name, source in (("FishCatalog", "src/shared/FishCatalog.luau"),
                         ("FishModel", "src/shared/FishModel.luau")):
        program += f"\nmodules.{name}=(function()\n" + (ROOT / source).read_text() + "\nend)()\n"
        program += f'local token=Instance.new("ModuleScript");token.Name="{name}";token.Parent=shared\n'
    program += CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_fish_models.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
