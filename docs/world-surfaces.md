# World surface finish — v1.6

The Studio file includes six MaterialVariants under MaterialService. They reuse
the complete Color, Normal and Roughness sets from Roblox's documented **Current
Base** materials. The [manifest](../tools/world_materials.json) records all 18 IDs,
the source URL and its content hash. There are no uploaded custom textures, image
overlays, global material overrides, emission maps or custom physical properties.
Base material physics are inherited.

| Preset | Base material | Studs per tile | Pattern |
| --- | --- | ---: | --- |
| AnglersWeatheredWood | Wood | 4 | Regular |
| AnglersCanvas | Fabric | 2 | Regular |
| AnglersRoofSlate | Slate | 6 | Organic |
| AnglersPlaster | Plaster | 6 | Organic |
| AnglersCutStone | Limestone | 6 | Organic |
| AnglersFineSand | Sand | 8 | Organic |

These scales are authored appearance choices, not measured Roblox defaults.
Regular patterns suit ordered wood and woven cloth; Organic patterns reduce
obvious repetition on stone and sand. WoodPlanks floors keep their existing native
plank textures. Fish and leaves keep their quieter surfaces. Built-in Sphere
SpecialMeshes do not receive native Part material maps, so they explicitly retain
no surface preset. Four picnic cushions use native cloth faces instead.

Part.Color values and lighting settings are retained. The official same-base
ColorMaps supply grain and speckling that a blank albedo map would remove. This
does not prove identical rendered colors: Roblox documents that MaterialVariant
and native base materials use different shaders.

The builder serializes the map bindings and BaseMaterial because their setters
require Studio/plugin permissions. Runtime code selects only supported material
names and replicated style tags. The client applies these through world/collection
events, with temporary readiness listeners for incomplete arrivals. Finished
surfaces have no per-part readiness listeners or per-frame material writes.
Streaming cleanup uses direct surface lookups and the removed part's ancestors,
rather than scanning all moving scenery for each plank or stone.

The six presets share 18 texture references. This is not a memory/FPS measurement.
Their IDs and API serialization were checked against Roblox's documentation and
API dump; direct asset delivery was blocked by the environment's network proxy.
Offline Blender previews do not load these maps or reproduce the Roblox shader.
Inspect native texture visibility, brightness, tiling seams and phone/iPad graphics
levels in Studio/client play before public release.

References:

- [Roblox materials and published map IDs](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/materials.md#base-materials)
- [MaterialVariant](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/MaterialVariant.yaml)
- [MaterialPattern](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/MaterialPattern.yaml)

Build and behavior checks:

```sh
python -m unittest discover -s tests -p 'test_*.py' -v
python tools/preview_world.py --luau /path/to/luau --output /tmp/world.json
python tools/check_world.py /tmp/world.json
python tools/check_scenery.py --luau /path/to/luau --capture /tmp/world.json
```
