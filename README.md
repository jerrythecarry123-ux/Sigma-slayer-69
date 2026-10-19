# Cloud Anglers — v0.5

[Open the Studio file on GitHub](https://github.com/jerrythecarry123-ux/Sigma-slayer-69/blob/main/artifacts/Cloud-Anglers-v0.5.rbxlx)

Choose **Download raw file**, open the downloaded `.rbxlx` in Roblox Studio and
press **Play**. The five-island map is generated when Play starts.

## Play

Follow the harbor trail to the lantern-lit main pier. **CAST LINE** with the button or E; at the
bite, hold and release in the colored zone. Gold gives Brilliant quality.
Catch six species, fill the field journal and earn coins for three rod upgrades.
Breeze Rod unlocks two rare fish; Nimbus Rod unlocks Aurorafin. Your best grade
per species adds to the collection leaderboard. Open **COLLECTION → Rod workshop** or visit the
workshop to upgrade.

## New in v0.5 — the world

An original sky archipelago roughly **800 × 550 studs**, with five connected,
walkable regions and five working fishing piers. Four wide bridges include level
coast landings and continuous, protected walking surfaces.

| Region | Places to explore |
| --- | --- |
| Sundrift Harbor | Enterable rod workshop/café/cottage, koi fountain, market stalls, flower planters and a climbable lighthouse |
| Petalwind Grove | Branching blossom trees, picnic clearings and an animated canvas windmill |
| Evergreen Reach | Layered pines, a timber cottage, rock formations and the rising summit bridge |
| Tideglass Cove | Curved palms, a shaded crystal grotto and a quiet lagoon |
| Starfall Lookout | Old stone observatory, telescope, ruins and a high fishing pier |

- Irregular coast polygons and layered cliffs replace the small platform.
- Native Roblox Terrain water provides waves/reflections in all five lagoons;
  waterfalls and a drifting airship add movement without more sound effects.
- Current **Realistic** lighting and quality-prioritized rendering are saved in
  the place. Lower ambient fill, afternoon sunlight and shadow-casting roofs,
  canopies and cliffs create shade. Small plants avoid unnecessary shadow work.
- Instance streaming loads neighborhoods as needed. Small trees/buildings/bridge
  sections are atomic; entire islands are not forced to load as one object.
- Server-owned fishing locks each attempt to its selected pier and correct water
  height. All existing collections, coins, rods, goals and offline income persist
  with the same v0.3 save namespace. The v0.4 UI and six-clip audio mix are retained.

The generator produces **9,655 anchored source parts**, including **941 colliders**
(invisible safety floors/rails included). Native water is separate terrain data.
These are measured source counts, not a mobile frame-rate guarantee.

All visual assets are original procedural geometry or Roblox built-in materials;
no imported models, custom audio IDs or external mesh uploads are needed.

## What was checked

64 automated tests pass: 19 fishing, 12 locations, 18 progression/saving, 4 UI layout,
8 world layout and 3 place export. All 23 production modules plus 5 Luau test suites
compile. Independent rays through the actual captured colliders check 3,639 route
samples for continuous support and six-stud headroom over a 2.6-stud corridor.

Offline Blender views were used to inspect geometry. They do not emulate Roblox
materials, native-water rendering, streaming, physics or device performance.
**Roblox Studio/client rendering and phone/iPad performance remain untested here.**
Use the [Studio checklist](docs/studio-testlista.md) before calling the map ready
for a public release.

## Saving and offline income

**Offline income requires a published Roblox experience.** In normal Roblox-client
play, saving is on by default. Each discovered species earns 0.25 coins/minute
while away, up to eight hours and 120 coins per return. The welcome summary shows
what was added. There is no separate claim button or client-calculated reward.

**Studio Play uses temporary profiles by default.** The UI clearly labels this.
For a real return test, publish a separate private test experience, join it through
the Roblox client, catch fish, leave for five minutes and rejoin.

Optional Studio persistence needs a published test place, Studio API access and
`SaveInStudio = true` in FishingConfig. It uses a separate test store.
No API keys are needed. Do not enable test writes against unrelated production data.

See [saving/return-play design and test steps](docs/discovery-and-return-play.md).
Actual DataStore integration, sound playback, visuals and mobile layout have not
been executed in the cloud runner; the [Studio checklist](docs/studio-testlista.md)
keeps those checks distinct from automated logic tests.

## Development

Source is embedded in the downloadable place. Studio changes do not sync back to
Git automatically. Edit source and rebuild; save custom world work separately.
Rojo is not configured. `CreatePrototypeWorld = false` supports a saved custom
`Workspace.World.FishingSpot`; its forward direction controls cast direction.

Python 3.10+, no packages:

```powershell
python tools/build_place.py
python tools/package_release.py
python -m unittest discover -s tests -p "test_*.py" -v
```

With the official Luau CLI:

```powershell
luau tests/fishing_engine.spec.luau
luau tests/fishing_progression.spec.luau
luau tests/interface_layout.spec.luau
luau tests/fishing_locations.spec.luau
luau tests/world_layout.spec.luau
```

Outputs: `artifacts/Cloud-Anglers-v0.5.rbxlx` and `artifacts/Cloud-Anglers-v0.5.zip`.

Shared modules contain tuning, quality rules, species data and fish geometry.
Server modules own attempts, economy/goals, atomic save rules, the DataStore adapter
and world construction. Client modules separate input, UI theme/interface, sounds
and 3D effects. All production modules are checked for inclusion in the place.

Optional geometry inspection (Luau and Blender required) is described in
`tools/preview_world.py`; `tools/check_world.py` checks actual generated colliders.
They capture production geometry for offline art review and route checks;
it does not emulate Roblox lighting, sound, physics, UI or runtime behavior.

The supplied YouTube video was blocked here. The return-income request was supplied
by the user; recommendation guidance was checked against [Roblox's official discovery
documentation](https://create.roblox.com/docs/discovery). No algorithm or retention
result is guaranteed or claimed.
