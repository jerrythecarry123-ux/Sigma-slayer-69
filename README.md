# Cloud Anglers — v0.4

[Open the Studio file on GitHub](https://github.com/jerrythecarry123-ux/Sigma-slayer-69/blob/main/artifacts/Cloud-Anglers-v0.4.rbxlx)

Choose **Download raw file**, open the downloaded `.rbxlx` in Roblox Studio and
press **Play**. The island is generated when Play starts.

## Play

Follow the stepping stones to the lantern-lit dock. **CAST LINE** with the button or E; at the
bite, hold and release in the colored zone. Gold gives Brilliant quality.
Catch six species, fill the field journal and earn coins for three rod upgrades.
Breeze Rod unlocks two rare fish; Nimbus Rod unlocks Aurorafin. Your best grade
per species adds to the collection leaderboard. Open **COLLECTION → Rod workshop** or visit the
workshop to upgrade.

## New in v0.4

- A cream-and-jade interface: smaller fishing controls, a single wallet, clear
  adventure progress and larger, separated collection/workshop pages.
- Actual 3D fish portraits in the collection, selectable entries, rarity details
  and a larger animated discovery card. All game text is English.
- A rebuilt harbor: curved floating cliffs, a suspended lagoon, flowing waterfall,
  rope boardwalk, framed lanterns, striped workshop, branching trees, flowers,
  distant islands and a gently drifting airship.
- **No additional sound clips or event types.** The same six built-in clips have
  softer pitches, equalization, peak control, quieter ambience and reel fades.
  Reward phrases are shorter, goals avoid stacking on catches, meter pings are
  removed, and nearby multiplayer effects have a voice limit and shorter range.
- Layout arithmetic covers phone portrait/landscape, tablet and desktop. Portrait
  fishing controls sit above the thumb controls; short landscape pages scroll.

Collections, coins, rod upgrades, goals and offline income carry forward from
v0.3 with the same save namespace and rules. The map uses 707 visible primitive
parts, of which 56 are collidable. These counts are measured by the geometry
capture tool; frame rate must still be measured on an actual phone/iPad.

All art is procedural and all six sound clips are Roblox client content. No
custom mesh, animation or audio uploads are needed. These are improvements to the
existing built-in sounds; they are not newly recorded audio assets.

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
```

Outputs: `artifacts/Cloud-Anglers-v0.4.rbxlx` and `artifacts/Cloud-Anglers-v0.4.zip`.

Shared modules contain tuning, quality rules, species data and fish geometry.
Server modules own attempts, economy/goals, atomic save rules, the DataStore adapter
and world construction. Client modules separate input, UI theme/interface, sounds
and 3D effects. All production modules are checked for inclusion in the place.

Optional geometry inspection (Luau and Blender required) is described in
`tools/preview_world.py`. It captures production geometry for offline art review;
it does not emulate Roblox lighting, sound, physics, UI or runtime behavior.

The supplied YouTube video was blocked here. The return-income request was supplied
by the user; recommendation guidance was checked against [Roblox's official discovery
documentation](https://create.roblox.com/docs/discovery). No algorithm or retention
result is guaranteed or claimed.
