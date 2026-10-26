# Project audit — premium development baseline

Reviewed 25 October 2026 against `7c39c2a` (v1.6). This describes the starting
point for the premium gameplay work, not a review of a later native playtest.
The source, pure Luau suites and event/UI doubles were available; Roblox Studio,
native client input, asset rendering and device profiling were unavailable.

## Preserve these working systems

- `FishingEngine` is an explicit server state machine. Attempt IDs, phase checks,
  proximity/death checks, timeouts and an all-request token bucket prevent ordinary
  replay, cross-player completion and reward parameter forgery.
- `FishingProgression` owns selection, rewards, purchases, grade improvements,
  records and display ownership. Client requests contain actions and IDs, not
  authoritative currency, fish or quality.
- `FishingSaveRules` uses atomic lease ownership and rejects corrupt/newer records.
  Copies and snapshots detach nested mutable data. Version-1 migration retains
  existing earned progress. Separate Studio test stores avoid touching live saves.
- Locations are bound to an accepted cast, rather than following a client-supplied
  water position. Travel validates destinations, source proximity, living character,
  streaming completion and the same character before moving anyone.
- Catch reveal generation tokens already cancel delayed reopen after dismissal,
  another cast or opening the journal. The client also retains the important
  release-before-Hold-acknowledgement path and timeout resynchronization.
- World detail and material presentation already use streamed-model recovery and
  bounded animation distances. The existing map should be retained while the core
  loop improves.

## Priority findings

| Priority | Starting behavior and evidence | Practical improvement | Acceptance evidence |
| --- | --- | --- | --- |
| P0 | Fish selection occurs only inside successful `FishingProgression.catch`, after the timing release. All attempts use one duration and a five-center timing pattern. | Reserve a server-owned candidate before reeling, award only on a valid completion, and drive resistance from a public behavior profile. Preserve the approachable one-button interaction on touch. | Candidate survives Sync; cancellation/death/disconnect award nothing; one completion awards once; each difficulty profile agrees between displayed and scored progress. |
| P0 | `FishingClient` displays synchronized server-time progress, while `FishingEngine` scores packet receipt time. Release transit therefore shifts the actual judged position later than the visible one. | Keep timing forgiving and check network fairness explicitly. Any compensation must be bounded and server-derived; never accept an unvalidated client quality or timestamp. | Private-client tests at several simulated latency levels, plus deterministic rule/engine tests. CLI doubles alone cannot establish network fairness. |
| P0 | `FishingPresentation` has no focused behavior/lifecycle test runner. Existing checks exercise the UI, models, scenery and residents separately. | Add a production presentation checker for casting, bite, catch, cancellation, late packets, character replacement and cleanup. Cover camera ownership if cinematics are introduced. | No lingering bobber/fish or stale callbacks after interruption; no camera/control property owned after exit; normal gameplay immediately resumes. |
| P1 | The catalog contains Common through Legendary, but no Mythical/Secret. Spawn weights, rod levels and habitats exist; struggle, reveal and environment data do not. | Add shared tier/behavior definitions with validated species references. Add distinctive high-tier content as a complete vertical slice, preserving existing IDs and migration. State conditional selection odds accurately. | Every species builds and animates in catch/journal/tank; invalid definitions fail validation; high-tier fish are legitimately obtainable; existing profiles remain valid. |
| P1 | All successful catches follow the same 1.3-second world arc and delayed card. Rarity mainly affects text/color and the existing audio phrase. | Give exceptional fish short, distinct reveals, with skip and reduced-effects paths. Ordinary repeats should remain fast. Keep effects local and budgeted. | Skip, repeated catches, travel, death, resize and camera replacement all clean up reliably; other players retain their camera and controls. |
| P1 | The journal/workshop lacks Escape/ButtonB handling and explicit gamepad focus ownership. Aquarium/travel menus already handle these. | Bring journal/settings/reveal interaction up to the existing travel standard; retain separated touch targets and inset-safe layout. | Keyboard/gamepad close, focus restoration, mobile portrait/landscape and modal mutual exclusion tests. Native font/input checks still required. |
| P1 | `FishingPresentation` calls `GetPlayers` every rendered frame and builds idle rods for nearby players. It also repeatedly looks up the same rod parts. | Track players through lifecycle events, cache rig pieces and allocate transient fishing objects only when needed. | Joining/leaving/streaming recovery tests plus instance/connection counts. Profile actual CPU/GPU cost in the client. |
| P2 | The collection stores best grades, records and variants, rather than an inventory of individually owned catches. | Keep this clear in the interface. If individual fish selling/trading is added later, design explicit item ownership and migration first. | Documentation and UI describe collection records accurately; any future inventory has transaction/duplication tests. |

## Risks that require native measurements

- v1.6 starts with 10,806 Parts and 2,275 colliders. The exported target streaming
  radius is 768 studs. Those counts and settings are source measurements, not a
  mobile performance result. Measure initial load, crowded harbor/tank views,
  portals, memory, frame time and low graphics on a real phone and iPad before
  choosing a smaller radius or altering mesh/detail density.
- The cloud environment cannot judge native material/PBR appearance, audio quality,
  animation interaction with Roblox's Animator, terrain water, native UI font
  metrics, touch ergonomics or real network streaming from offline renders.
- DataStore transitions are tested as pure operations. A private published
  experience still needs rapid rejoin, concurrent-session exclusion, outage,
  shutdown and lease-recovery checks with actual DataStoreService.
- Cinematics should not change global Lighting or slow the server simulation.
  A ViewportFrame presentation can provide a controlled stage while preserving
  the player's world camera. If a world camera is used, it needs explicit ownership,
  timeouts, skip, reduced effects and interruption restoration.

## Baseline checks executed during this audit

- `luau tests/fishing_engine.spec.luau tests/fishing_progression.spec.luau tests/fishing_locations.spec.luau`:
  24 engine, 31 progression/save and 12 location cases passed.
- `python tools/check_fishing_interface.py --luau /tmp/molnfiskarna-luau/luau`:
  actual production UI catalog/layout/timing/reward/delayed-reveal cases passed.

These results establish the v1.6 regression baseline. New premium features need
their own integration checks and an updated native Studio checklist.
