#!/usr/bin/env python3
"""Capture production map geometry for Blender inspection; never a Studio test.

Usage: python tools/preview_world.py --luau /path/to/luau --output /tmp/world.json
Then: blender -b -t 4 --python tools/render_world.py -- /tmp/world.json /tmp/world.png
The place builder does not depend on this optional developer tool.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXPORT = r'''
local world=modules.PrototypeWorld
local spot=world.create()
local parts={}
local collisions=0
local function vec(v) return {v.X,v.Y,v.Z} end
local function encode(v)
 if type(v)=="string" then return string.format("%q",v) end
 if type(v)=="number" or type(v)=="boolean" then return tostring(v) end
 local entries={}
 if #v>0 then
  for _,value in v do table.insert(entries,encode(value)) end
  return "["..table.concat(entries,",").."]"
 end
 for k,value in v do table.insert(entries,encode(k)..":"..encode(value)) end
 return "{"..table.concat(entries,",").."}"
end
for _,p in workspace:GetDescendants() do
 if p:IsA("BasePart") and p.Transparency<1 then
  if p.CanCollide then collisions+=1 end
  table.insert(parts,{name=p.Name,size=vec(p.Size),position=vec(p.CFrame.p),rotation=p.CFrame.r,
   color={p.Color.R,p.Color.G,p.Color.B},shape=p.Shape,material=p.Material,alpha=1-p.Transparency,
   collide=p.CanCollide})
 end
end
assert(spot.CFrame.p.Y>2 and spot.CFrame.p.Z==45,"fishing spot moved unexpectedly")
print(encode({parts=parts,collisions=collisions}))
'''


def capture(luau: str) -> dict:
    program = (ROOT / 'tools/preview_roblox.luau').read_text()
    for name, source in [('FishCatalog', 'src/shared/FishCatalog.luau'),
                         ('FishModel', 'src/shared/FishModel.luau'),
                         ('PrototypeWorld', 'src/server/PrototypeWorld.luau')]:
        program += '\nmodules.' + name + ' = (function()\n' + (ROOT / source).read_text() + '\nend)()\n'
        program += f'local token_{name}=Instance.new("ModuleScript"); token_{name}.Name="{name}"; token_{name}.Parent=shared\n'
    program += EXPORT
    with tempfile.TemporaryDirectory() as temp:
        script_path = Path(temp) / 'capture.luau'
        script_path.write_text(program)
        result = subprocess.run([luau, str(script_path)], check=True, text=True, capture_output=True)
    return json.loads(result.stdout)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    scene = capture(args.luau)
    args.output.write_text(json.dumps(scene))
    print(f"Captured {len(scene['parts'])} visible parts; {scene['collisions']} collidable. This is geometry inspection, not a Roblox runtime test.")
