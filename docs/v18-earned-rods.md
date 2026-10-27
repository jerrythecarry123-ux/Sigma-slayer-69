# Earned rod control — v1.8

Rod upgrades now improve a physical part of the existing reeling interaction:
the gold Brilliant timing window becomes wider. This complements their existing
species unlocks and earned-coin bonuses. Names, level indices, costs, coin
multipliers and unlock requirements remain compatible with old saves.

| Earned rod | Cost | Existing coin bonus | Gold width on the timing track | Wider than Driftwood |
| --- | --- | --- | --- | --- |
| Driftwood | Free | 0% | 0.140 | — |
| Breeze | 32 coins | 15% | 0.156 | About 11% |
| Nimbus | 90 coins | 30% | 0.172 | About 23% |
| Aurora | 160 coins | 45% | 0.188 | About 34% |

Only earned coins purchase these upgrades. There is no paid boost, new currency,
paid random reward, extra purchase step or guaranteed catch.

## Existing rod finishes

The four earned rods now use distinct finishes on the same fitted eight-Part
rig. `Catalog.Rods[].Finish` supplies four material/color roles, separate from
costs, unlocks, bonuses and timing widths:

| Rod | Grip and shaft | Reel and hardware |
| --- | --- | --- |
| Driftwood | Dark timber grip and warm natural wood shaft | Muted bronze spool and aged metal fittings |
| Breeze | Light wood grip and teal shaft | Pale metal spool and deep teal fittings |
| Nimbus | Slate fabric grip and blue shaft | Pale metal spool and warm brass fittings |
| Aurora | Dark violet fabric grip and violet shaft | Gold spool and pale aqua fittings |

The existing public server `rodLevel` chooses the finish. A missing, nonnumeric,
fractional, nonfinite or out-of-range level falls back to Driftwood. The client
does not choose equipment or receive any reward authority. A changed level
updates colors/materials once, retaining the live rig, its tip attachment,
geometry and animation. Stable render frames no longer rewrite shaft colors.
There are no extra Parts, assets, lights or effects.

The three visible shaft sections also have round native-cylinder cross-sections.
Their native local-X axis is composed with the existing Y-up animation frame,
retaining the authored lengths, centers, bend joints and grip-owned model pivot.
The line attachment sits at the actual final cylinder cap. Launch and Beam
origins read its native `WorldPosition`; a shared pose helper keeps the physical
sections and that endpoint together during wind-up, release and reeling.

[Four finishes from actual production geometry](images/rod-finishes-v18.png)
shows the authored colors and fitted reel parts. This Blender plate is a source
geometry comparison, not a Roblox screenshot; native Wood/Fabric/Metal shaders,
lighting and normal play-distance readability still need client inspection.

## Bound grading and display

`Catalog.Rods[].TimingWidth` is the definition. `FishingProgression.timingWidth`
derives the equipped value from the saved level, and snapshots expose the current
and next rod's widths for the workshop. Width is not a new saved profile field.

The engine binds the width when a cast actually launches. The first three
successful catches retain the original 0.14 introductory width; later attempts
use the equipped rod. Buying/changing rods is rejected during a wind-up, Waiting
or Reeling, so the current attempt cannot be altered midway. A successful earned
upgrade affects the next cast.

`packet.timingWidth` travels with private state and public fishing presentation.
The server grades `FishingRules.qualityAt(progress, center, timingWidth)`. The
client draws that same centered span and uses the same rules for feedback.
Brilliant remains centered on the fish's moving target; the Fine and overall
catchable bands are unchanged. A wider gold band still requires a valid release
inside the server's fishing attempt and never awards a fish on its own.

The rule's third argument is optional. Existing two-argument callers retain the
0.14 span. Invalid/nonfinite width falls back to 0.14; finite tuning is clamped
to 0.08–0.22. Production catalog widths are 0.14–0.188. Clients never submit the
authoritative width; altering a local packet or adding release arguments cannot
widen the server's grade.

## Verification and native limits

Production-code checks cover every rod level, inclusive gold edges, unchanged
Fine grading, first-three-catch behavior, active-attempt upgrade rejection,
next-cast upgrade application, edited snapshots and forged/extra width payloads.
The real service adapter also proves that a release just outside Driftwood gold
becomes Brilliant with the earned Breeze rod, with matching public metadata.

The actual presentation checker also verifies all four finishes, their eight
existing Parts and unchanged transforms/tip attachment through a live finish
update. Twelve malformed/missing-level cases use the starter finish. A 120-frame
probe per level performs zero repeated color/material writes. Existing cast,
line, shoulder, distance, interruption and geometry checks still pass, with 434
reel-contact samples, 1,630 actual cylinder-cap contact witnesses and seven
rejected deliberate regression mutations. The native-section checks inspect
local-X endpoints, circular radial dimensions, a root inside the grip, two
shared bend contacts and the actual line attachment, including all five sampled
cast strengths. A wrong cylinder basis fails the centerline assertion. Restoring
a constant starter finish fails the earned-equipment assertion. The complete
14-scenario production fishing flow and five catalog cases also pass.

The shared spatial inspection shim now models Attachment local Position/CFrame
synchronization and derives WorldCFrame/WorldPosition from rotated BasePart or
nested Attachment parents. Focused tests check offset, orientation and nested
composition. This improves the analytic geometry evidence; it does not reproduce
native replication, Beam rendering or Roblox floating-point behavior.

These are rule/state/transport-double checks. They do not establish native font
rendering, touch feel or network fairness. Actual input latency still affects
receipt-time scoring and needs the private-client device acceptance matrix.
