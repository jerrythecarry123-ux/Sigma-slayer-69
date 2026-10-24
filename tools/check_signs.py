#!/usr/bin/env python3
"""Check production world sign layout with spatial/UI doubles, not Studio fonts.

Builds the actual map, portals and three occupied aquarium displays, including
maximum-length wide owner names. Checks both faces, physical canvas proportions,
contained artwork, separated text rows and bounded text scaling. Native text
rasterization, lighting and device readability still require Roblox Studio.
"""
import argparse
import json

import preview_world


CHECK = r'''
local count,faces=0,0
local boards={}
local function rectangle(item)
 return {item.Position[1],item.Position[2],item.Size[1],item.Size[2]}
end
local function same(a,b)
 for index=1,#a do if math.abs(a[index]-b[index])>.00001 then return false end end
 return true
end
for _,front in workspace:GetDescendants() do
 if not front:IsA("SurfaceGui") or front.Name~="PaintedSign" then continue end
 local board=front.Parent
 local back=board:FindFirstChild("PaintedSignBack")
 assert(back and back:IsA("SurfaceGui"),board.Name.." lost its reverse face")
 assert(front.Face==Enum.NormalId.Front and back.Face==Enum.NormalId.Back,board.Name.." has duplicated face orientation")
 local width,height=front.CanvasSize.X,front.CanvasSize.Y
 local actual=board.Size.Y/board.Size.X
 assert(math.abs(height/width-actual)/actual<.008,board.Name.." stretches its painted artwork")
 local record={board=board.Name,width=width,height=height,size={board.Size.X,board.Size.Y},
  color={board.Color.R,board.Color.G,board.Color.B},elements={}}
 for _,gui in {front,back} do
  assert(gui.CanvasSize.X==width and gui.CanvasSize.Y==height,board.Name.." reverse canvas differs")
  assert(gui.SizingMode==Enum.SurfaceGuiSizingMode.FixedSize and not gui.AlwaysOnTop,board.Name.." ignores its physical surface")
  local title,caption=gui:FindFirstChild("Title"),gui:FindFirstChild("Caption")
  assert(title and caption and #title.Text>0 and #caption.Text>0,board.Name.." lost sign copy")
  assert(title.Text==front:FindFirstChild("Title").Text and caption.Text==front:FindFirstChild("Caption").Text,board.Name.." reverse copy differs")
  local tr,cr=rectangle(title),rectangle(caption)
  assert(tr[2]+tr[4]<cr[2] and cr[2]+cr[4]<height,board.Name.." text rows overlap")
  local rule=gui:FindFirstChild("QuietHeaderRule")
  assert(rule and rule.Position[2]+rule.Size[2]<tr[2],board.Name.." header rule intersects title")
  local fishTail=gui:FindFirstChild("HarborFishTail")
  assert(fishTail and fishTail.Position[1]+fishTail.Size[1]*1.5<tr[1],board.Name.." fish mark overlaps copy")
  for _,item in gui:GetChildren() do
   if item:IsA("Frame") or item:IsA("TextLabel") then
    local r=rectangle(item)
    assert(r[1]>=0 and r[2]>=0 and r[3]>0 and r[4]>0 and r[1]+r[3]<=width and r[2]+r[4]<=height,board.Name.." artwork escapes its board")
    local other=front:FindFirstChild(item.Name)
    assert(other and same(r,rectangle(other)),board.Name.." reverse artwork moved")
    if item:IsA("TextLabel") then
     local sizing=nil
     for _,child in item:GetChildren() do if child:IsA("UITextSizeConstraint") then sizing=child end end
     assert(sizing and sizing.MinTextSize>=10 and sizing.MaxTextSize>=sizing.MinTextSize,board.Name.." has unbounded text")
     assert(item.TextScaled and not item.TextWrapped and not item.AutoLocalize,board.Name.." lost single-row scaled text")
     assert(r[4]>=sizing.MinTextSize,board.Name.." text box is shorter than its minimum font")
    end
    if gui==front then
     table.insert(record.elements,{name=item.Name,class=item.ClassName,rect=r,
      text=item:IsA("TextLabel") and item.Text or "",rotation=item.Rotation or 0,
      color=if item:IsA("TextLabel") then {item.TextColor3.R,item.TextColor3.G,item.TextColor3.B} else {item.BackgroundColor3.R,item.BackgroundColor3.G,item.BackgroundColor3.B},
      alpha=1-(item:IsA("TextLabel") and item.BackgroundTransparency or item.BackgroundTransparency or 0)})
    end
   end
  end
  faces+=1
 end
 table.insert(boards,record)
 count+=1
end
assert(count>=47,"production sign coverage unexpectedly fell")
local function encode(value)
 if type(value)=="string" then return string.format("%q",value) end
 if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
 local entries={}
 if #value>0 then
  for _,entry in value do table.insert(entries,encode(entry)) end
  return "["..table.concat(entries,",").."]"
 end
 for key,entry in value do table.insert(entries,encode(key)..":"..encode(entry)) end
 return "{"..table.concat(entries,",").."}"
end
print(encode({boards=boards,count=count,faces=faces}))
'''


def check(luau: str) -> dict:
    original = preview_world.EXPORT
    # Reuse the normal production-map capture setup without exporting geometry.
    initialization = original.split("local parts={}", 1)[0]
    initialization = initialization.replace('"Preview Angler "..index', 'string.rep("W",20)')
    preview_world.EXPORT = initialization + CHECK
    try:
        result = preview_world.capture(luau, gallery_players=3)
    finally:
        preview_world.EXPORT = original
    print(f"PASS {result['count']} production sign boards / {result['faces']} faces: physical aspect, contained artwork, separated copy and bounded text; includes 20-character wide owner names")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    parser.add_argument("--output", help="Optional layout JSON for offline typography inspection")
    args = parser.parse_args()
    result = check(args.luau)
    if args.output:
        from pathlib import Path
        Path(args.output).write_text(json.dumps(result))
