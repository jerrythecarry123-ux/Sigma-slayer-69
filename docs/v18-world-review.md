# v1.8 world craft and geometry review

Reviewed the v1.7 world at ground height using the actual production geometry,
then refined existing forms. The five islands, walking/travel coordinates, water
footprint, lighting and palette are retained. This review does not claim native
Roblox rendering, physics, sound or mobile frame-rate results.

## Findings and changes

| Evidence in the existing world | Change | Verification |
| --- | --- | --- |
| Each tree trunk section had a hidden native-cylinder core and a slightly wider visible cylinder. Both occupied essentially the same location. | Removed 79 redundant hidden cylinders. Visible timber owns the former exact physical footprint; 67 sections remain physical and 12 young-tree sections retain their decorative/nonquerying role. | Compared all 79 old core sizes, complete transforms, native shapes, anchoring, collision and query properties against their visible replacements. All match exactly. |
| The 32 existing fern fronds used shallow ramps with rectangular planforms. The walking-height close view made them read as thick planks. Their roots were already seated, so they did not need relocating. | Each existing leaf now uses two thin native triangular halves with a broad grounded root and a shared pointed tip. No plants were added. | 32 paired leaves share their complete root-to-tip edge; 128 root-end samples cross visible terrain. The smallest measured root embed is about 0.0241 stud. |
| All 12 interior storage pots had a 0.015-stud gap above their display shelves. | Lowered the existing pots by 0.02 stud, seating each base 0.005 stud into its shelf. | 96 native circular-foot samples are inside the actual shelf blocks. |

The net result is **10,759 initial Parts**, 47 fewer than v1.7's 10,806. The fern
shape pass adds 32 thin triangle halves while trunk consolidation removes 79
duplicates. The world still has **2,275 colliders** and **6,203 surface bindings**.
These are source counts and exact geometry comparisons, not measured device
performance. The existing 10,825-Part bound is retained.

## Actual-source visual evidence

Seven ground-height views covered the harbor town, trail rest, pier, café
resident, grove, cove and summit. Closer fern views isolated the existing
production foliage and mushrooms against a ground-height preview plane so their
silhouette and thickness could be judged clearly. The close views below show
the captured source geometry and colors. Blender does not reproduce Roblox
material maps, terrain-water shaders, SurfaceGui text or native lighting.

[Before: rectangular fern ramps](images/world-ferns-v18-before.png)

[After: thin, pointed native leaf halves](images/world-ferns-v18-after.png)

The review found no reason to add more buildings, islands, plants, lights or
decorative prompts. Existing buildings, planters, porch supports, pier props,
shore boundaries, gull wings and the fitted lighthouse dome retain their
previous structural checks. The underlying source remains the evidence for
those checks; a distant preview is not proof that every detail is perfect.

## Checks run

The new `tools/check_world_craft.py` executes against a production capture and
checks visible trunk roles, paired native fern geometry and seated pottery. Four
deliberate regressions are rejected: disabled trunk collision, a complete leaf
pair floating above the meadow, a mirrored leaf root and the former shelf-pot
gap. An optional v1.7 capture checks the exact old/new trunk footprint comparison.

```text
python tools/preview_world.py --luau /path/to/luau --output /tmp/world.json
python tools/check_world_craft.py /tmp/world.json --mutations
python tools/check_world.py /tmp/world.json
python tools/check_details.py /tmp/world.json
python tools/check_residents.py --luau /path/to/luau
python tools/check_scenery.py --luau /path/to/luau
```

The complete walking/shoreline/waterfall geometry check and the existing 178
detail joins pass with this source geometry. The changed nature, architecture
and landscaping modules compile. Actual Studio/client review remains necessary
for native materials, physical contact, streaming and phone/iPad performance.
