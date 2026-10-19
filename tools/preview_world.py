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
modules.IslandTravel.create(workspace:FindFirstChild("MolnfiskarnaPrototype"))
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
 if p:IsA("BasePart") then
  if p.CanCollide then collisions+=1 end
  local parentNames={}; local cursor=p; while cursor and cursor~=workspace do table.insert(parentNames,1,cursor.Name); cursor=cursor.Parent end
  table.insert(parts,{name=p.Name,size=vec(p.Size),position=vec(p.CFrame.p),rotation=p.CFrame.r,
   color={p.Color.R,p.Color.G,p.Color.B},shape=if p:IsA("WedgePart") then "Wedge" else p.Shape,material=p.Material,alpha=1-p.Transparency,
   collide=p.CanCollide,query=p.CanQuery,shadow=p.CastShadow,anchored=p.Anchored,path=table.concat(parentNames,"/")})
 end
end
assert(spot:IsA("BasePart") and spot.Anchored,"missing primary fishing spot")
local ambient={}
for _,node in workspace:GetDescendants() do
 if node:IsA("Model") and node:GetAttribute("AmbientKind") then
  table.insert(ambient,{kind=node:GetAttribute("AmbientKind"),name=node.Name,origin=vec(node:GetPivot().p)})
 end
end
local layout=modules.WorldLayout
for _,bridge in layout.Bridges do bridge.Points=layout.bridgePoints(bridge) end
local travel={}
for _,dock in layout.Docks do
 local frame=CFrame.new(table.unpack(dock.Spot))*CFrame.Angles(0,dock.Yaw,0)
 local source=workspace:FindFirstChild("MolnfiskarnaPrototype"):FindFirstChild("IslandTravelStations"):FindFirstChild(dock.Id)
 table.insert(travel,{id=dock.Id,arrival=vec((frame*CFrame.new(0,3.3,5.4)).Position),kiosk=vec(source.PrimaryPart.Position)})
end
local support=workspace:FindFirstChild("MolnfiskarnaPrototype"):FindFirstChild("TravelArrivalSupports")
print(encode({parts=parts,collisions=collisions,terrainWrites=#waterWrites,ambient=ambient,waterColor={workspace.Terrain.WaterColor.R,workspace.Terrain.WaterColor.G,workspace.Terrain.WaterColor.B},lighting={brightness=Lighting.Brightness,clockTime=Lighting.ClockTime,ambient={Lighting.Ambient.R,Lighting.Ambient.G,Lighting.Ambient.B}},
 travel=travel,persistentTravelSupport=support.ModelStreamingMode==Enum.ModelStreamingMode.Persistent,
 layout={Islands=layout.Islands,Bridges=layout.Bridges,Paths=layout.Paths,Waters=layout.Waters,Docks=layout.Docks,Spawn=layout.Spawn,RodStand=layout.RodStand,WalkSpeed=layout.WalkSpeed}}))
'''


def capture(luau: str) -> dict:
    program = (ROOT / 'tools/preview_roblox.luau').read_text()
    for name, source in [('FishCatalog', 'src/shared/FishCatalog.luau'),
                         ('FishModel', 'src/shared/FishModel.luau'),
                         ('WorldPrimitives', 'src/server/WorldPrimitives.luau'),
                         ('WorldNature', 'src/server/WorldNature.luau'),
                         ('WorldArchitecture', 'src/server/WorldArchitecture.luau'),
                         ('WorldLayout', 'src/server/WorldLayout.luau'),
                         ('IslandTravelRules', 'src/shared/IslandTravelRules.luau'),
                         ('IslandTravel', 'src/server/IslandTravel.luau'),
                         ('WorldLandscaping', 'src/server/WorldLandscaping.luau'),
                         ('WorldResidents', 'src/server/WorldResidents.luau'),
                         ('PrototypeWorld', 'src/server/PrototypeWorld.luau')]:
        program += '\nmodules.' + name + ' = (function()\n' + (ROOT / source).read_text() + '\nend)()\n'
        program += f'local token_{name}=Instance.new("ModuleScript"); token_{name}.Name="{name}"; token_{name}.Parent=shared\n'
    program += EXPORT
    with tempfile.TemporaryDirectory() as temp:
        script_path = Path(temp) / 'capture.luau'
        script_path.write_text(program)
        result = subprocess.run([luau, str(script_path)], check=False, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    scene = capture(args.luau)
    args.output.write_text(json.dumps(scene))
    print(f"Captured {len(scene['parts'])} source parts including invisible colliders; {scene['collisions']} collidable. This is geometry inspection, not a Roblox runtime test.")
