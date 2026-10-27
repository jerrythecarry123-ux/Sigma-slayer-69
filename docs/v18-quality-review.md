# v1.8 directive and quality review

This pass builds on v1.7 (`65d426d`) rather than replacing its world or saved
progress. The user's minimum active-work request is tracked in `WORK_LOG.json`;
usage pauses and parallel-agent hours are not counted as additional work.
The ledger is the time record, not this document's creation timestamp.

## What changed and what is still open

| Directive area | Working implementation and evidence | Remaining boundary |
| --- | --- | --- |
| Research | Existing-project audit, accessible official Roblox design/API guidance, explicit competitor access log. See `competitor-research.md` and `v18-native-api-review.md`. | Fisch/Fish It/Fishing Simulator hands-on sessions, current reviews and the supplied video were inaccessible. No invented competitor findings. |
| Visual identity and world | Existing shaded sky-waterfront palette retained. Pointed fern silhouettes, seated pots and consolidated visible tree trunks refine the same map. Six shared material presets remain. See `v18-world-review.md`. | Native material delivery, water shader, lighting and real viewing distances need Roblox inspection. No new weather/day-night system is presented as implemented. |
| Seven rarities | All seven definitions and 17 species are implemented. Existing silhouettes, fitted markings, behavior and tier presentation use shared data. See `v18-fish-review.md`. | Native visibility at low graphics and child/player recognition need playtests. Rarity is not differentiated by color alone. |
| Fishing | Separate optional cast charging, safe quick tap, shared server-receipt timing, bounded cast rewards/landing depth, species resistance and earned rod gold widths. See `v18-casting-protocol.md` and `v18-earned-rods.md`. | Actual input latency/fairness and fishing feel need measured Windows/touch/gamepad sessions. No trusted client timestamps or claimed lag compensation. |
| Exceptional catches | Private-camera viewport reveals, short/repeat/reduced paths, skip, interruption and reward isolation. Cinematic geometry/lifecycle checks run actual source. | Native sound/visual timing, font metrics and reveal fatigue need observation. |
| Animation | Embedded fish hinges, connected arms/forks/whiskers, rod-tip cast origin, fitted reel crank and bounded quiet LOD recovery. See fish and presentation reviews. | Procedural animation remains; no custom uploaded avatar animation is claimed. Native R6/R15 blending still needs checking. |
| Interface | Compact rows/cards, minimum tested touch targets, complete animated portraits, readable timing needles, progression guidance and owned modal focus. See `v18-interface-review.md`. | Real text metrics, larger Roblox text, safe areas, rotation and thumb comfort remain native acceptance items. |
| Progression and return play | Existing rods/17-species journal/records/variants/public aquariums preserved. Ready upgrades take priority; completed journals get useful guidance. Server-calculated bounded offline income remains. A 2,000-profile hypothetical pacing study highlights habitat/rareness sensitivity. See `v18-progression-review.md` and `v18-pacing-study.md`. | No measured human playtime, retention, spending or recommendation result. Weather/events and further earned cosmetics remain roadmap items. |
| Audio | Same six clips, bounded voices and cancellable phrases, quiet intentional cancellation and progress/resistance-driven reel pitch. | No new clip library or uploaded sound is claimed. Actual quality, loop seam and balance need listening in Roblox. |
| Architecture/security | Authoritative species, attempts, location, rewards, profile validation, leases and rate limits retained. Preference writes have independent private correlation. | Event/service doubles do not reproduce native transport, service budgets or outages. |
| Saving | Slow-autosave departure race fixed. Final operation receipts acknowledge response loss without stale replay. Legacy profiles and optional preference migration use the same version/store. See `v18-server-review.md`. | Real published-client persistence, contention, request budgets and shutdown remain open. Outages cannot be guaranteed to preserve every newest action. |
| Resource work | Removed 79 redundant trunk cores; bounded transient accents; no distant/idle rig allocation; streaming cleanup and stable reduced motion. | Counts and eliminated work are not FPS/memory benchmarks. The existing streaming target requires real baseline-phone profiling. |
| Quality control | Compilation, pure suites, actual-module adapter/lifecycle checks, full fishing scenarios, analytic world/model/UI checks and deliberate regression mutations. | The coverage is broad but does not prove perfection or exhaustive native behavior. |
| Continuity and delivery | Four project records, an active work ledger, reproducible named place/ZIP and one full verification command. | A usage interruption requires a new invocation; no automatic background resume is configured. |
| Final ambition | Concrete improvements to existing game feel, visual details, clarity and reliability. | Commercial quality, superiority, player enjoyment and revenue require evidence from real clients and players. |

## Checks and how to interpret them

The full cloud run passed **32 check stages** with unchanged sources during that
run. It includes **167 core tests**: 5 catalog, 48 engine, 14 location, 10
preference, 40 progression/save, 9 final-save transition, 8 interface layout,
15 travel, 14 world-layout and four Python place/material export checks.
All **36 production files and nine Luau suites** compile.

Separate checks run real modules, with native services/Instances replaced by
documented doubles:

- Controller: 25 input/protocol/lifecycle scenarios plus seven preference cases.
- Full fishing stack: 14 scenarios, 58 queued RPCs and 62 delivered private
  states, including response-order-respecting preference races. The production
  UI, audio, models and presentation execute; world scenery/travel have dedicated
  checks. These numbers describe that specific deterministic run.
- Profile store: 20 cases. Service/store lifecycle: 10 cases, including a
  30-second yielding autosave with a newer departure snapshot. The old helper
  fails the regression when deliberately restored in a temporary program.
- Audio: 12 cases. The optional initially-muted constructor keeps startup quiet
  through delayed profile/remote readiness; explicit enabling restores ambience
  without replaying old notes. The client requests this quiet construction before
  any readiness waits. The prior constructor fails the new delayed-load case.
- Fish: all 17 species/variants, 454 attached details, 7,623 rooted animation
  samples and six rejected deliberate art regressions; 471 Parts total/max35.
- Portraits: 4,998 journal/catch poses, 2,448 aquarium-menu poses and 750 cinematic
  poses. Full public tanks additionally cover 3,111 poses and 658 route samples.
- World: 3,681 route, 2,373 trail, 225 spawn, 125 portal-arrival and 429 approach
  samples; native-water containment, coping/rail/outlet support, 178 detail joins
  and 10,100 power-dependent landing footprints. Existing resident/scenery/sign
  and portal ownership/lifecycle checks also pass.

Changes made after the consolidated run must receive their relevant checks;
do not reuse an earlier result as evidence for changed code. The final progress
record states those follow-up results. Samples are not added together and called
native playtests, and multiple agents do not multiply the work time.

Follow-up work also eliminates aquarium layout and animation work at stable
dimensions: zero repeated layout writes over 120 calls instead of 3,720; 360
visible portrait animation calls remain, while compact-hidden and closed menus
make none. These are measured source operations, not a native frame-rate result.

The consolidated suite was rerun after the round rod/Attachment and quiet audio
bootstrap changes; all 32 stages passed with matching source fingerprints. The
later portal dialog focus-boundary fix passed its targeted actual-module check
and compilation. A separate independent production diff review reported no
further confirmed regression in the reviewed cross-module paths.

The final player-feedback pass preserves a server-confirmed Perfect/Precise cast
acknowledgement during flight/anticipation, without obscuring the bite. A receipt
also acknowledges a precision grade when a low-value bonus rounds to zero;
positive bonuses remain explicitly included in the unchanged total. The actual
controller, interface and complete fishing flow passed after this change. The
interface additionally checks 28 zero-bonus grade states across seven canvases.
Completed-pond navigation now takes priority over chain encouragement, while
chains remain visible in incomplete ponds.

```text
python tools/check_project.py --luau /path/to/luau --compiler /path/to/luau-compile --report /tmp/cloud-anglers-check.json
```

The runner captures one world, gates dependent checks on successful capture,
records complete outputs/exit codes, and fails if checked sources change during
its run. UTF-8 child configuration preserves the game's English typography on
Windows. Its process management was checked on Linux; Windows tree termination
remains an explicit platform gap. Optional baseline trunk comparisons remain
available separately through `check_world_craft.py --baseline`.

## Native release gate

Use `studio-testlista.md` in a private test experience on Windows, a real phone
and iPad. Prioritize one full first-session loop, every input/grade combination
at measured latency, each fish at maximum weight in every display, rejoin/save
contention, material/audio delivery and crowded-pond frame time. Record actual
device, graphics settings, build and Output errors. Fix observed failures before
public launch. No unrun native box is marked passed by this review.
