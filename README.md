# Cloud Anglers — v0.2

An English-language Roblox fishing playtest with a floating island, Sundrift Pond
and a catchable Pufflet. This is the presentation update to the first prototype.

[Download the Studio place](https://github.com/jerrythecarry123-ux/Sigma-slayer-69/raw/refs/heads/main/artifacts/Cloud-Anglers-v0.2.rbxlx)

## Open and play

1. Download `Cloud-Anglers-v0.2.rbxlx` and open it in Roblox Studio.
2. Start **Play**, not just Run: the interface needs a player.
3. Follow the path to the glowing spot at the end of the dock.
4. Click/tap **CAST LINE**, or tap E and release it.
5. Watch the rod cast and the bobber land. When the bite cue appears, hold the
   button or E. Release while the marker is in the colored zone.
6. Normal, Fine and Brilliant are the three catch qualities. Gold is best.
7. The fish jumps from the pond and appears in an animated 3D catch card.
   Close the card with its x button or E, or wait for it to close automatically.

The world is generated when Play starts, so the editor initially looks empty.
Save as a separate private test place to play with your collaborator.

## What changed in v0.2

- All in-game text is English, including results and server feedback.
- A wooden dock, cloud pond, trees, lanterns, clearer signs and warmer lighting.
- A visible fishing rod, animated arm pose, arcing cast, line and bobber.
- Floating/bobbing motion, bite indicator, expanding ripples and catch sparks.
- A fish with a face, fins and tail, a catch flight and animated 3D result card.
- Cast, splash, bite, reeling, success and miss sounds; **SFX ON/OFF** control.
- Server-approved visual events let players see one another's fishing.
- Button press feedback, pulsing bite highlight and animated result presentation.

Animations use procedural CFrame/Motor6D motion and tweens. Sound effects use
Roblox client content (`rbxasset://sounds/...`), so no custom animation or audio
uploads are required. These are starter effects, not a custom soundtrack.

Catches are session-only. Saving, currency, upgrades and aquarium progression
are still outside this version.

## Source layout

| File | Responsibility |
| --- | --- |
| `src/shared/FishingConfig.luau` | Timing, distance and prototype mode |
| `src/shared/FishingRules.luau` | Catch quality windows |
| `src/shared/FishModel.luau` | Original fish geometry shared by the world and UI |
| `src/server/FishingEngine.luau` | Testable authoritative attempt and catch rules |
| `src/server/FishingService.luau` | Player lifecycle, validity checks, private state and visual broadcasts |
| `src/server/PrototypeWorld.luau` | Island, pond, dock and spawn |
| `src/server/FishingServer.server.luau` | Server entry point |
| `src/client/FishingClient.client.luau` | English UI, controls and catch card |
| `src/client/FishingPresentation.luau` | Rod, arms, bobber, line and world effects |
| `src/client/FishingAudio.luau` | Sound preload, mix, effects and mute control |

The source files are embedded by the place builder. Edits made in Studio are not
synced back to Git automatically. Edit source and rebuild for lasting code changes;
keep a separate saved copy of any world you edit in Studio. Rojo is not configured.

To use your own world later, set `CreatePrototypeWorld = false` and create an
anchored `Workspace.World.FishingSpot`. Its forward direction determines where
casts land. Save your world in Studio: the builder does not import custom maps.

## Build and checks

Python 3.10+ is sufficient to build; no extra Python packages are needed.
The prebuilt place does not require Python.

```powershell
python tools/build_place.py
python tools/package_release.py
python -m unittest discover -s tests -p "test_*.py" -v
```

With the official Luau CLI installed:

```powershell
luau tests/fishing_engine.spec.luau
```

Build outputs are `artifacts/Cloud-Anglers-v0.2.rbxlx` and
`artifacts/Cloud-Anglers-v0.2.zip`.

The rule tests exercise actual production logic. Packaging tests verify every
production module is present, has the right source/class and builds repeatably.
Studio and real devices are still required to verify the actual animations,
audio playback, layout and multiplayer visuals. See the
[Studio test checklist](docs/studio-testlista.md) for the unrun checks.

Server receipt time determines catch quality. Network delay can shift the apparent
meter result, so test latency before competitive or persistent rewards are added.
Visuals are cosmetic; clients cannot award fish by triggering their own effects.

Design and the initial learning plan remain available in Swedish:
[Game design](docs/molnfiskarna-gdd.md), [First week](docs/forsta-veckan.md).
