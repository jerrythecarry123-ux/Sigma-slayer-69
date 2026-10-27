# v1.8 progression pacing study

Reviewed 27 October 2026 using the **actual `FishCatalog` and
`FishingProgression` modules** in standalone Luau. This is a deterministic design
study of successful fish draws. It is not another unit-test count, a Roblox
playtest, or a forecast of human session duration, enjoyment or retention.
No production weights, prices, goals or rewards were changed.

## Assumptions and method

Each policy runs 1,000 fresh profiles with seeds 1–1,000 and stops at all 17
species or 2,500 successful catches. Every simulated catch calls production
`progression.catch`; real eligible selection, duplicate protection, weight,
variant, chain, wallet and sequential goal payments execute. After each catch,
the policy buys every currently affordable next rod using `progression.upgrade`.

- Grades are an explicit hypothetical mix: 80% Normal, 17% Fine, 3% Brilliant.
  They do not improve with the rod or represent observed children.
- Cast bonus is zero, representing ordinary convenience casts. There is no
  offline income, style purchase, paid boost or manually granted balance.
- Misses, cancellations, travel time, menus and reveal time are omitted.
  Failed attempts do not earn fish or reroll the existing reservation. Omitting
  their possible chain resets makes this an optimistic economic simplification.
- Two independent deterministic random streams use Park–Miller multiplier
  48,271 modulo 2,147,483,647, with 16 warm-up steps. Grade seed is
  `seed * 21 + 17`; progression seed is `seed * 7919 + 104729`.
- **Targeted collector:** stay in the current pond while it has eligible unseen
  original species. Otherwise choose the pond with most such entries, breaking
  ties in catalog order. After those are complete, target a missing eligible
  Mythical/Secret in its own pond. If nothing new is eligible, continue fishing
  until an earned upgrade opens more. This assumes the player understands the
  journal's habitat/equipment information.
- **Rotating ponds:** fish three successful catches in each pond, cycling through
  the five catalog locations regardless of which fish remain undiscovered.

“Original 15” means every one of the original fifteen species IDs, not merely
15 distinct entries including a newer fish. The production 15-species milestone
still uses its actual distinct-entry rule and pays through the real module.

## Observed successful-catch counts

Each cell is **median / 95th percentile** across the complete 1,000-profile
cohort. Percentile ranks use `ceil(cohort size × percentile)`; a censored rank
would be reported as unknown rather than silently removed.

| Earned outcome | Targeted collector | Rotating ponds |
| --- | ---: | ---: |
| Breeze Rod | 3 / 3 | 3 / 3 |
| Nimbus Rod | 6 / 7 | 6 / 7 |
| Aurora Rod | 13 / 14 | 13 / 15 |
| All original 15 species | 24 / 28 | 43 / 43 |
| Complete 17-species journal | 101 / 245 | 330 / 973 |

No run was censored at the 2,500-success cap in this sample. The largest observed
full-journal count was 459 for targeted collection and 2,368 for rotation.
Those are observed sample maxima, **not** discovery guarantees. The study ran
116,372 successful catches for targeted profiles and 405,045 for rotating ones.

The rod milestones are early under both assumptions. The main difference is
the optional final collection tail and whether catches occur in a pond that can
contain a missing fish. These figures must not be converted into player minutes
without real input success, travel and presentation measurements.

## Why the final two have a long tail

At the final rod level, after protected original species in the relevant pond
are already discovered:

| Fish | Eligible relative weight | Raw probability per fresh draw in that pond | Ideal geometric median / 95th percentile |
| --- | --- | ---: | ---: |
| Veilfin, Evergreen Reach | 2 of 84 | 2.381% | 29 / 125 |
| Eclipse, Starfall Lookout | 1 of 58 | 1.724% | 40 / 173 |

The analytic percentile is `ceil(log(1 − percentile) / log(1 − probability))`.
These probabilities apply to the weighted branch in the correct pond. Duplicate
protection bypasses that branch to force an eligible unseen original species;
it does not remove discovered fish from the weighted pool and never forces
Mythical/Secret. Protected draws therefore cannot be treated as ordinary rare
rolls. Neither final fish has a finite guaranteed discovery count.

## Design implications and next native observation

The study found no progression-code defect or hidden mandatory waiting timer.
It does identify a substantial routing and rarity-tail sensitivity. Preserve the
ready-upgrade guidance and readable habitat/rod hints. During a beginner playtest,
observe whether a player can identify the pond containing their next desired
fish without coaching; cycling randomly should not be the only understood plan.

Keep ordinary discoveries, earned equipment, size/grade records and aquarium
choices useful before the full journal. The final two already do not gate free
island travel or further rod upgrades. Do not present the 17-entry endpoint as
a short guaranteed task or use this study to justify paid rolls or return pressure.

Record actual first-cast success, next-goal comprehension, voluntary continuation,
miss rate and pond choices in the private Windows/phone/iPad playtest. Tune
guidance or rarity pacing only from that evidence; these hypothetical policies
cannot determine what a child finds enjoyable or frustrating.

Temporary reproduction files are `/tmp/v18_pacing_study.py`,
`/tmp/v18-pacing-study.luau` and `/tmp/v18-pacing-study.json`. They are not game
dependencies and may disappear when the cloud workspace is replaced. Reviewed
source SHA-256 values:

```text
FishCatalog:        80367c39a6ab9fc47517bc59f7b1fc3bf3f9b19da5eca68d4c6e89d9010dc17d
FishingProgression: ee95c4f8fefe324a370cf68e7337990bb61527b096d8f185be6413ab42069696
```
