# Cloud Anglers — development roadmap

Current code checkpoint: v1.7, fishing identity and catch presentation, built on
v1.6 (`7c39c2a`). The six priorities below are implemented and checked in the
available environment; native acceptance remains open. This is a continuing
project, not a claim of finished commercial quality. Preserve the five islands, existing collection IDs, earned
progress, portal travel, public aquariums and the calm, shaded art direction.

## Priorities and acceptance gates

| Priority | Work | Acceptance |
| --- | --- | --- |
| 1 | Audit and research | Inspect existing code, record sourced design guidance and access limits; keep native/client gaps explicit. |
| 2 | Fishing feel | Server-bound fish, varied readable anticipation, species resistance, forgiving first catches; cancel/retry never grants rewards or rerolls rare fish. |
| 3 | Fish identity | Seven data-driven rarity tiers, two finished species for the missing tiers, distinct silhouettes and motion; no save reset or paid lottery. |
| 4 | Rare-catch presentation | Short local reveals, immediate skip, reduced effects, reliable cancellation and no takeover of another player's view or the world camera. |
| 5 | Interface | Readable moving timing zones, rarity words plus rank, working desktop/touch/gamepad navigation and session audio/effects settings. |
| 6 | Integration and release | Production code checks, exact source/place packaging, continuity docs, downloadable GitHub Studio file. Native acceptance remains mandatory before public launch. |

## Later milestones

1. Run the documented Studio/client acceptance matrix on Windows, a real phone
   and iPad. Tune real input latency, camera composition, fish framing, material
   delivery and sound balance from observed behavior.
2. Profile the existing world on those devices before adding more scenery.
   Measure memory, draw calls, frame time, streaming and allocation hotspots.
   Revisit the 768-stud target radius using measurements, rather than guessing.
3. Improve rod control with an experimentally validated cast-accuracy mechanic
   and richer resistance input if it improves the current accessible timing game.
4. Commission or author licensed custom animation/audio/mesh assets where the
   procedural approach cannot meet the visual standard. Validate permissions and
   loading before enabling assets; do not leave fake IDs in the shipped place.
5. Add environmental fishing conditions, optional weather, achievements and
   additional earned cosmetics only after the core loop and mobile budget pass.
6. Conduct actual hands-on competitor sessions and voluntary player playtests.
   Evaluate onboarding comprehension, catch pacing, repeat-reveal fatigue and
   progression clarity. No retention, discovery ranking or revenue is guaranteed.

See [research](docs/competitor-research.md), [baseline audit](docs/project-audit.md),
[authored asset specifications](docs/asset-production-specs.md), the
[original directive](docs/premium-development-directive.md) and
[next tasks](NEXT_STEPS.md). Later ideas are planned work, not shipped features.
