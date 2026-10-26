# Development progress

## Stable starting point

v1.6, commit `7c39c2a`, is the last packaged checkpoint at the start of this work.
It includes fitted terrain/scenery, 15 distinct fish, procedural wildlife,
server-authoritative fishing, lease-protected saves, non-PvP collection progress,
five free portals, three-slot public aquariums and six shared material presets.

## Current milestone — v1.7, 26 October 2026

- Read the complete premium development directive supplied by the user.
- Inspected existing architecture and reused working save, travel and progression
  paths. Recorded the audit in `docs/project-audit.md`.
- Research recorded in `docs/competitor-research.md`. Competitor pages and APIs
  were blocked; official Roblox documentation was accessible. No competitor
  playthrough or current player-sentiment review has been claimed.
- Implemented private per-pond fish reservations, separate cast/bite clocks,
  species-based resistance and modest shared moving targets. The first three
  successful catches stay forgiving. No new reward authority lives on clients.
- Added all seven rarity definitions and two fully generated fish, Veilfin and
  Eclipse. All 17 species have explicit behavior, difficulty, animation and
  presentation data. The original 15 IDs and the ten old milestones remain;
  the 17-species milestone is appended. No save-store migration/reset is required.
- Added short local 3D catch sequences, distinct tier compositions, skip/repeat
  paths and reduced effects. A private viewport camera leaves world-camera and
  movement ownership intact. Death, replacement, travel, menus and stale callbacks
  have explicit cleanup paths.
- Added session sound/effects settings, Roblox Reduce Motion support, active-input
  hints, gamepad/keyboard modal handling and landscape catch-card layouts. Audio
  uses the existing six clips with bounded voices and cancellable tier phrases.
- Removed per-frame player discovery and idle rig allocation from fishing
  presentation. Cached rod sections, line sag, cranking and additive pose cleanup
  support the existing procedural animation path.
- Independent geometry review found and fixed detached Eclipse tail/marking
  pieces and incorrectly oriented Veilfin/Eclipse fin roots. Actual solid-contact
  guards and deliberate regression mutations now cover those flaws.

## Completed verification

- 122 core tests: 5 catalog, 30 engine, 12 locations, 36 progression/saving,
  6 layout, 15 travel rules, 14 world-layout and 4 Python export/material checks.
- All 36 production files and seven Luau suites compile (43 files).
- Actual production controller: 16 input/protocol/lifecycle scenarios. Actual
  audio: nine voice, cancellation, mixing-ownership and loop scenarios.
- Actual service and startup: server-selected reservations, shared timing,
  single rewards, late observers, travel/death/disconnection and custom maps.
- Rare reveals: 750 complete-sequence animated poses and 190,800 projected
  Part corners across five viewport sizes; resize, skip, reduced motion, focus,
  detached UI, replacement/death and world-camera isolation checks pass.
- Fish: 471 Parts total, at most 35 per species; 4,114 grouped motion samples,
  605 body joins, 4,598 real-solid contacts, 968 marking-footprint samples and
  two deliberate art-regression mutations. No added Parts for the final fit fixes.
- Aquariums: all 17 species at maximum weight across three slots and 3,111
  animated poses; 658 supported arrival/promenade samples and UI lifecycle checks.
- Preserved systems: 29 travel-adapter scenarios, portal UI ownership, 1,503
  resident animation steps, 47 sign boards / 94 faces, material/scenery lifecycle,
  178 world detail joins and full route/shoreline/waterfall checks pass.
- The initial world remains 10,806 Parts / 2,275 colliders and 6,203 material
  bindings. Lighting, audio asset library, travel layout and save namespace remain.

The downloadable checkpoint is `artifacts/Cloud-Anglers-v1.7.rbxlx`; the matching
ZIP includes source, checks, documentation and this continuity record. Packaging
verification compares the delivered scripts/files with the working sources.

## Validation boundary

The environment runs official standalone Luau and Python checks and can render
source geometry offline. It does not run Roblox Studio or the native Roblox
client. Engine rendering, real input/audio/networking, DataStore connectivity and
phone/iPad performance must be tested separately. Update this file at each stable
checkpoint with exact tests and remaining gaps.
