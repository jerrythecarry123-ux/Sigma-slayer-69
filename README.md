# Cloud Anglers — v1.8

[Download the Roblox Studio place](https://github.com/jerrythecarry123-ux/Sigma-slayer-69/blob/main/artifacts/Cloud-Anglers-v1.8.rbxlx)

Choose **Download raw file**, save the `.rbxlx`, open it in Roblox Studio and
press **Play**. The world is generated at Play, so an empty Edit viewport is
expected. No plugin, model import, API key or animation upload is needed.

The [source ZIP](https://github.com/jerrythecarry123-ux/Sigma-slayer-69/blob/main/artifacts/Cloud-Anglers-v1.8.zip)
contains the same place, Luau source, checks and development notes. GitHub hosts
the files; Roblox Studio opens the downloaded place. There is no GitHub import
plugin required by this project.

## Fishing and collection

Explore five sky-waterfront islands, use free portals between ponds and discover
17 fish across **Common, Uncommon, Rare, Epic, Legendary, Mythical and Secret**.
Species have distinct silhouettes, habitats, movement and catch resistance.
Golden and Prismatic appearances retain readable faces and markings. Best
grades, size records, discoveries and three favorite aquarium displays provide
non-PvP progress friends can see.

At a fishing marker:

1. Tap the main button for a normal cast. You can also use **E** or gamepad **RT**.
2. For a precision cast, hold and release on the separate gold cast band.
3. Watch the float and bite cue, then press and hold to reel.
4. Release inside the reeling zone; aim for gold. Catch grade and cast accuracy
   are separate, and a normal tap can still catch every eligible species.

The first three successful catches use a forgiving static reeling target.
Earned rods keep their existing prices/unlocks and now widen the gold reeling
window. An affordable rod takes priority in the next-step guidance. The journal
shows discoveries, habitats and records; the workshop explains the next rod.

Epic and higher fish have short, skippable local 3D reveals. Repeats are quicker;
reduced effects use a brief still presentation. The reveal has its own viewport
camera, leaving the player's world camera and movement ownership intact.

## New in this quality pass

- **More deliberate casts:** a separate charging meter, a server-timed accuracy
  bonus and bounded landing depth inside the existing water lanes. Quick taps
  remain a safe convenience choice, including with delayed acknowledgements.
  Precision grades receive clear feedback even when a coin bonus rounds to zero.
- **Fitted fish details:** embedded fin/tail hinges, joined forks, seated whiskers
  and lure roots, connected squid arms and clearer moth-wing markings. All 17
  models still total 471 Parts, at most 35 per species. The
  [catalog geometry comparison](docs/images/fish-catalog-v18.png) shows the actual
  models with normalized display sizes; it is an offline review, not a Roblox screenshot.
- **More reliable presentation:** fitted rod-tip launch and reel crank, quiet
  interruption cleanup, no replayed distant bite/splash cues, bounded water
  accents and cleanup when characters or scenery stream out. The four earned
  rods have distinct fitted finishes on the same eight-Part rig; see the
  [actual-source finish comparison](docs/images/rod-finishes-v18.png).
- **Clearer small-screen UI:** complete compact journal rows, larger aquarium
  actions, dedicated short-screen catch cards, padded animated fish framing,
  outlined timing needles and owned keyboard/gamepad focus, including the portal
  destination dialog. Closed/compact-hidden aquarium portraits skip animation.
- **Saved preferences:** sound and reduced-effects choices save with published
  profiles. Choices apply locally immediately; independent write acknowledgements
  protect rapid toggles without blocking fishing. Roblox Reduce Motion also applies.
- **Existing-world refinements:** pointed thin fern leaves, seated shelf pottery
  and visible trunks that replace redundant hidden cores. Initial geometry is
  10,759 Parts, 47 fewer than v1.7, with 2,275 colliders. Lighting retains the calm,
  shaded direction and the six shared material presets/18 map references.
- **Save recovery:** a departing player's newest snapshot waits for an older
  autosave to finish. Idempotent final-write receipts handle committed writes
  whose responses were lost. Existing profiles and store names remain compatible.

The same six shipped sound clips are used. Audio starts quietly before readiness
waits so saved mute is respected during loading. Reel pitch follows resistance
and progress within a restrained range; muting, cancellation and loop ownership
remain bounded. Native sound quality has to be judged in Roblox.

## Returning players and saving

Each discovered species earns **0.25 coins/minute** while away, up to eight hours
and **120 coins per return**. The server awards the actual amount on profile
acquisition and shows a welcome summary. There is no daily-loss penalty or paid
claim. Rods, variants, records, displays, themes and preferences use the existing
lease-protected profile.

**Studio Play uses temporary profiles by default.** Its settings footer explains
that choices apply to the Studio visit. For real persistence, publish a separate
private test experience and join through the Roblox client. Optional Studio
saving uses a separate test store. Production remains `CloudAnglers_Player_v03`;
Studio testing remains `CloudAnglers_Test_v03`. No save reset is required.

See the [server/save review](docs/v18-server-review.md) and
[progression/return review](docs/v18-progression-review.md) for exact rules and limits.

## Verification and native acceptance

The consolidated cloud run passed **32 check stages**, including **167 core
tests** and compilation of **36 production files plus nine Luau suites**.
Separate checks execute the actual controller, server/store adapters, full
fishing stack, audio, UI, fish, aquariums, residents, scenery, signs and travel
with deterministic services/geometry/event doubles. Fourteen complete fishing
scenarios exercise queued transport, including delayed preference replies.

The checks establish code behavior and analytic geometry. They do **not** run
Roblox Studio or native rendering, input, audio, physics, real DataStore requests
or phone/iPad frame rates. Offline Blender images show source geometry/colors,
not Roblox screenshots. Native acceptance remains open in the
[Studio checklist](docs/studio-testlista.md) and [known issues](KNOWN_ISSUES.md).

Competitor pages and the supplied YouTube video were network-blocked. Accessible
official Roblox guidance and the user's supplied return-income idea informed the
work; no current competitor playthrough or measured retention/revenue is claimed.
See [research notes](docs/competitor-research.md).

## Build and check the source

The place and source ZIP use Python's standard library:

```powershell
python tools/build_place.py
python tools/package_release.py
```

Outputs are `artifacts/Cloud-Anglers-v1.8.rbxlx` and
`artifacts/Cloud-Anglers-v1.8.zip`. To run all available automated checks, install
the official standalone [Luau CLI](https://github.com/luau-lang/luau) and run:

```powershell
python tools/check_project.py --luau C:/tools/luau.exe --compiler C:/tools/luau-compile.exe --report verification.json
```

Use executable paths for your machine. On Linux, the executable names have no
`.exe`. `--quick` limits the run to compilation, pure rules, place export and
protocol/save checks; it omits the full art, UI, audio and world checks. The full
run captures the production world once, shares it between geometry/material
checks and records complete outputs. Before/after source fingerprints must match
for the run to pass.
Report files must be JSON outside the checked source folders and active ledger.
The runner enables UTF-8 for child tools on Windows. Native Windows process-tree
timeout handling remains untested; a successful cloud check is not a Windows test.

Development continuity: [plan](DEVELOPMENT_PLAN.md), [progress](PROGRESS.md),
[next steps](NEXT_STEPS.md), [active work ledger](WORK_LOG.md).
Detailed v1.8 reviews cover [casting](docs/v18-casting-protocol.md),
[rods](docs/v18-earned-rods.md), [fish](docs/v18-fish-review.md),
[interface](docs/v18-interface-review.md), [presentation](docs/v18-presentation-review.md),
[world](docs/v18-world-review.md) and [native API access](docs/v18-native-api-review.md).
[Earlier release notes](docs/release-history-through-v17.md) preserve the history.
