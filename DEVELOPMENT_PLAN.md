# Cloud Anglers — development roadmap

The v1.8 cloud quality checkpoint completes the original cumulative two-hour
request. It adds optional cast accuracy, earned rod control/finishes, saved
preferences and refinements across models, UI, presentation and save recovery.
Read `WORK_LOG.md` for verified active intervals and `PROGRESS.md` for evidence.

This continues the v1.7/v1.6 project. The six priorities below are implemented
and checked within the available cloud environment; native Roblox acceptance
remains open. Preserve the five islands, existing IDs, earned progress, portal
travel, public aquariums and calm shaded direction. Source checks are not a claim
of finished commercial quality or measured player enjoyment.

## Priorities and acceptance gates

| Priority | Work | Acceptance |
| --- | --- | --- |
| 1 | Audit and research | Inspect existing code, record sourced design guidance and access limits; keep native/client gaps explicit. |
| 2 | Fishing feel | Server-bound fish, varied readable anticipation, species resistance, forgiving first catches; cancel/retry never grants rewards or rerolls rare fish. |
| 3 | Fish identity | Seven data-driven rarity tiers, two finished species for the missing tiers, distinct silhouettes and motion; no save reset or paid lottery. |
| 4 | Rare-catch presentation | Short local reveals, immediate skip, reduced effects, reliable cancellation and no takeover of another player's view or the world camera. |
| 5 | Interface | Readable separate cast/reel zones, rarity words plus rank, desktop/touch/gamepad modal ownership, compact cards and saved audio/effects choices with honest pending status. |
| 6 | Integration and release | Production code checks, exact source/place packaging, continuity docs, downloadable GitHub Studio file. Native acceptance remains mandatory before public launch. |

## Later milestones

1. Run the documented Studio/client acceptance matrix on Windows, a real phone
   and iPad. Tune real input latency, camera composition, fish framing, material
   delivery and sound balance from observed behavior.
2. Profile the existing world on those devices before adding more scenery.
   Measure memory, draw calls, frame time, streaming and allocation hotspots.
   Revisit the 768-stud target radius using measurements, rather than guessing.
3. Validate the v1.8 cast-accuracy and wider earned-rod windows with actual
   players and measured latency. Tune from observations before introducing
   richer resistance input or another minigame layer.
4. Commission or author licensed custom animation/audio/mesh assets where the
   procedural approach cannot meet the visual standard. Validate permissions and
   loading before enabling assets; do not leave fake IDs in the shipped place.
5. Add environmental fishing conditions, optional weather, achievements and
   additional earned cosmetics only after the core loop and mobile budget pass.
6. Conduct actual hands-on competitor sessions and voluntary player playtests.
   Evaluate onboarding comprehension, catch pacing, repeat-reveal fatigue and
   progression clarity. The [hypothetical pacing study](docs/v18-pacing-study.md)
   identifies pond-choice sensitivity; observe whether beginners can locate a
   desired remaining species before changing odds. No retention, discovery
   ranking or revenue is guaranteed.

See [research](docs/competitor-research.md), [baseline audit](docs/project-audit.md),
[authored asset specifications](docs/asset-production-specs.md), the
[original directive](docs/premium-development-directive.md) and
[next tasks](NEXT_STEPS.md). Later ideas are planned work, not shipped features.
