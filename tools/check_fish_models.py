#!/usr/bin/env python3
"""Exercise unchanged production fish geometry and animation with spatial doubles.

Checks bounded geometry, cosmetic physics flags, repeatable variant application,
and stable animation away from the origin. Roblox rendering still needs Studio.
Run: python tools/check_fish_models.py --luau /path/to/luau
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CHECK = r'''

local count=0
for _,species in modules.FishCatalog.Species do
 local fish=modules.FishModel.create(workspace,nil,species.Id)
 fish:PivotTo(CFrame.new(217,41,-81)*CFrame.Angles(.1,.3,-.05))
 local pivot=fish:GetPivot()
 local function near(a,b) return (a-b).Magnitude<.00001 end
 modules.FishModel.applyAppearance(fish,"Golden",species.WeightMax)
 local snapshot={}
 for _,p in fish:GetChildren() do
  assert(p.Anchored and not p.CanTouch and not p.CanQuery and not p.CanCollide,"fish added physics")
  assert(p.Material~="Neon","fish added eye-straining emission")
  snapshot[p]={size=p.Size,position=p.Position,color=p.Color}
 end
 modules.FishModel.applyAppearance(fish,"Normal",species.WeightMin)
 modules.FishModel.applyAppearance(fish,"Golden",species.WeightMax)
 for p,a in snapshot do
  assert(near(p.Size,a.size) and near(p.Position,a.position),"appearance geometry accumulated")
  assert(math.abs(p.Color.R-a.color.R)<.00001 and math.abs(p.Color.G-a.color.G)<.00001 and math.abs(p.Color.B-a.color.B)<.00001,"appearance tint accumulated")
 end
 for frame=0,120 do
  modules.FishModel.animate(fish,frame*.05)
  for _,p in fish:GetChildren() do
   assert((p.Position-pivot.Position).Magnitude<7,"fish joint escaped at distant pivot")
   assert(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,"fish size invalid")
  end
 end
 modules.FishModel.applyAppearance(fish,"Prismatic",species.WeightMax)
 local pupil=fish:FindFirstChild("Pupil")
 assert(pupil.Color.R<.2 and pupil.Color.G<.3,"variant made eyes unreadable")
 assert(#fish:GetChildren()<=50,"fish exceeds cosmetic part budget")
 count+=1
end
print("PASS",count,"production species: bounded silhouettes, no physics/Neon, repeatable appearance, stable animation at distant pivots")
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
