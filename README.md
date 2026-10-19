# Cloud Anglers — v0.3

[Open the Studio file on GitHub](https://github.com/jerrythecarry123-ux/Sigma-slayer-69/blob/main/artifacts/Cloud-Anglers-v0.3.rbxlx)

Choose **Download raw file**, open the downloaded `.rbxlx` in Roblox Studio and
press **Play**. The island is generated when Play starts.

## Play

Follow the glowing path to the dock. **CAST LINE** with the button or E; at the
bite, hold and release in the colored zone. Gold gives Brilliant quality.
Catch six species, fill the field journal and earn coins for three rod upgrades.
Breeze Rod unlocks two rare fish; Nimbus Rod unlocks Aurorafin. Your best grade
per species adds to the collection leaderboard. Open **JOURNAL** or visit the
workshop to upgrade.

## New in v0.3

- A redesigned responsive HUD, animated coin counter, goal bar and field journal.
- Six fish with distinct colors and silhouettes, moving fins and discovery reveals.
- Five goals, coin rewards, three rod upgrades and visible collection scores.
- Lighting/atmosphere pass, rim rocks, flowers, crystals and a rod workshop.
- UI, coin, goal, upgrade, quality-meter and discovery audio plus quiet wind ambience.
- Saved collections, coins, goals and rods, with server-owned offline income.

All in-game text remains English. Sounds use Roblox client content and visuals
are procedural, so custom audio/animation/mesh uploads are not needed.

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
```

Outputs: `artifacts/Cloud-Anglers-v0.3.rbxlx` and `artifacts/Cloud-Anglers-v0.3.zip`.

Shared modules contain tuning, quality rules, species data and fish geometry.
Server modules own attempts, economy/goals, atomic save rules, the DataStore adapter
and world construction. Client modules separate input, UI theme/interface, sounds
and 3D effects. All production modules are checked for inclusion in the place.

The supplied YouTube video was blocked here. The return-income request was supplied
by the user; recommendation guidance was checked against [Roblox's official discovery
documentation](https://create.roblox.com/docs/discovery). No algorithm or retention
result is guaranteed or claimed.
