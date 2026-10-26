# Fishing design research and evidence

Reviewed 2026-10-25. This is a source-backed design brief, not a claim that we
played, benchmarked or reviewed the current competitor builds.

## What could actually be researched

The requested comparison targets are [Fisch](https://www.roblox.com/games/16732694052/Fisch),
[Fish It](https://www.roblox.com/games/121864768012064/Fish-It) and
[Fishing Simulator](https://www.roblox.com/games/2866967438/Fishing-Simulator).
Their public Roblox pages and Roblox place-to-universe APIs returned network
proxy **403 Forbidden**. Fischipedia, the Fishing Simulator/Fish It Fandom pages,
PCGamesN/Pocket Tactics guide pages and a Bing query were also blocked. These
failures concern access from this environment; they do not mean the sites or
games are unavailable to players.

Consequently, current concurrent-player rankings, exact fishing controls,
current UI layouts, rare-catch sequences, live balance and player complaints
could **not** be verified. We do not infer those from the titles, stale memory
or promotional thumbnails. No competitor assets were downloaded or copied.
The three games remain references for a later hands-on comparison, rather
than evidence for claims about current trends or which game is best.

Roblox's official Creator Hub source files on `raw.githubusercontent.com` were
accessible. The findings below come from their text, not the embedded videos.
Links point to the published source and may change after this review.

## Verified standards and their application

| Source actually read | Supported finding | Decision for Cloud Anglers |
| --- | --- | --- |
| [Core loops](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/core-loops.md) | Distinguishes minute-to-minute interaction, repeated actions and the progression engine. | Judge the complete cast → bite → timing → catch → discover/display → next goal loop; extra scenery cannot compensate for an unsatisfying repeated action. |
| [Onboarding](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/onboarding.md) | Teach essentials, get to the fun quickly, expose future goals and create moments of joy; evaluate the onboarding funnel. | Preserve the short first walk and attainable starter catches. Show one next action and a meaningful discovery, rather than explaining seven rarities before the first cast. Measure completion rather than promising retention. |
| [Accessibility guidelines](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/accessibility.md) | Use readable contrast and text, avoid color-only or sound-only information, respect player preferences and offer volume controls. | Pair rarity color with its name and a distinct symbol; pair bites with a clear visual cue. A quiet/reduced-effects mode must retain all timing information. |
| [Mobile input](https://github.com/Roblox/creator-docs/blob/main/content/en-us/input/mobile.md) | Respond to `PreferredInput`, including a gamepad attached to a touch device; mobile orientation and controls need deliberate treatment. | Keep one clearly labeled fishing action across touch, keyboard and gamepad. Do not decide current input solely from `TouchEnabled`. Check phone landscape and iPad, including changes during play. |
| [Position and size](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/position-and-size.md) and [size modifiers](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/size-modifiers.md) | Layouts, anchors, constraints and automatic sizing control responsive UI; constraints can override layout sizing. | Give catch text and buttons explicit bounds on a safe canvas. Verify long names, very small screens and increased text size; scaling an entire desktop panel alone is insufficient evidence. |
| [Camera API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Camera.yaml) | Each client has its own camera. `Scriptable` stops default camera updates; custom scripts must maintain `Focus`. | Any optional cinematic is local to its catcher. Keep camera ownership and restoration explicit, with exit paths for skip, respawn, travel, replacement camera and interruption. A viewport reveal is the safer default when world-camera ownership is unnecessary. |
| [GuiService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml) | `ReducedMotionEnabled` is a readable player preference tied to Roblox's Reduce Motion setting. | Combine the engine preference with an in-game reduced-effects option. Use a still reveal or a brief fade, preserving rarity and rewards. Do not rely on a setting whose toggle is never consulted by the animation. |
| [ParticleEmitter API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ParticleEmitter.yaml) | Effects can emit automatically through `Rate` or as bounded bursts through `Emit()`. | Prefer brief, bounded catch accents to persistent high-rate effects. Remove transient instances and cancel stale callbacks. Part-based effects also need a bound; avoiding an emitter does not make an effect free. |
| [Design for performance](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/design.md) | Pick a real baseline device, measure frame rate/memory throughout development; the Studio device emulator does not reproduce device memory behavior. | Native phone/iPad profiling remains a release gate. Offline Part counts and scripted checks identify regressions but do not prove mobile FPS or memory safety. |
| [Improve performance](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/improve.md) | Dense objects, layered transparency, particles, shadow casting and redundant high-frequency work can be costly. | Keep shared material maps and streamed worlds. Avoid piling global bloom, transparent overlays, lights or permanent frame loops onto every rarity. Animate only visible/active subjects where practical. |
| [Securing the client-server boundary](https://github.com/Roblox/creator-docs/blob/main/content/en-us/scripting/security/client-server-boundary.md) | Validate context, types, structure and values; reject nonfinite numbers and rate-limit server actions. | The server chooses eligible species, time windows and rewards. Clients request actions and render outcomes; skip/settings cannot award, reroll or duplicate a catch. |

These are published engineering/design recommendations, not evidence that a
specific competitor uses them or that they guarantee popularity or revenue.

## Priorities inferred from our existing game

The v1.6 baseline already has five distinct islands, fifteen species with
different silhouettes, four rods, a discovery journal, earned aquarium themes,
public player tanks, a timing grade, a bounded skill chain and server-calculated
offline income. It also has procedural casting/fish animation and restrained
world lighting. Reuse these systems and retain their save IDs.

The strongest feasible improvement is the **existing fishing loop**, followed by
a shared rarity language and a better reveal. Broadly adding weather, islands,
currencies or purchases before that loop is validated would create more content
without answering the central quality problem.

Design hypotheses to validate, rather than claims about competitors:

1. A smooth line/rod arc and an unmistakable bite should make an individual cast
   easier to understand than a timer alone. The meter must agree with the
   server's actual scoring window.
2. Higher rarity should change recognizable behavior and silhouette, alongside
   text and restrained visual accents. A recolor by itself does not communicate
   a different animal.
3. An exceptional first discovery deserves a brief, skippable reveal. A common
   repeat should return control quickly. Cancelling presentation must leave
   the already-awarded result intact.
4. The game's identity is a bright but comfortable sky-waterfront, distinct
   pond populations and a collection friends can physically visit. Preserve
   that identity and the subdued exposure while improving game feel.
5. Collections, skill records and personally chosen tank displays provide
   reasons to return without a punishment for missing a day. Keep offline
   income bounded and explain it honestly; do not promise earnings or demand
   a purchase to claim it.

## Hands-on competitor review still required

When a Roblox client and normal web access are available, record the build/date
and platform for each of the three references. Use the same checklist so the
comparison is useful rather than subjective praise:

- Time spawn → first valid cast → first catch → first meaningful choice.
- Inputs per cast, readable response to pressing/releasing, and what happens
  with lag, a missed bite or an early release.
- Ordinary repeat-reveal duration versus first exceptional-reveal duration;
  skip availability and whether other players lose camera/control.
- Fish silhouette, motion, rarity words/icons and effects without color/sound.
- Journal navigation, next-goal clarity and thumb reach on a real phone.
- Rod/equipment decisions, habitat differences and nonpaying-player progress.
- Readable distance landmarks, route downtime and how the fishing area frames
  the catch rather than hiding it with decoration.
- Frame rate/memory on the chosen baseline phone at low and medium graphics.

For criticism/request analysis, gather actual dated, attributable review or
feedback samples with links and sample size. Separate repeated observations
from isolated opinions, and do not treat a few loud comments as representative
of all children or the whole player population. Current player sentiment is an
explicit research gap in this environment.

## Validation standard

Automated tests can check scoring, eligibility, rewards, cancellation, timeouts,
finite animation poses and UI bounds. They cannot establish that an animation
feels satisfying, a sound is pleasant, a reveal looks cinematic, or a child
wants to return. Review the actual Studio/client build, then observe a small
consented playtest: first-cast success, first discovery, next-goal comprehension,
voluntary second cast, skip behavior and accessibility choices. Use observations
to choose the next iteration. No superiority, retention or spending result is
guaranteed by these changes.
