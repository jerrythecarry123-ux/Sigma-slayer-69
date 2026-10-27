# Fish craft and animation review — v1.8

Reviewed 26 October 2026 against the seventeen species shipped in v1.7
(`65d426d`). This is a correction pass on existing models, not additional fish
content. Species IDs, rarity, colors, weights, rewards and saved collection
records are unchanged. All fish remain cosmetic and noncolliding.

## Problems found and corrected

| Area | Starting problem | Final behavior |
| --- | --- | --- |
| Legacy side fins | Wedge inner edges faced away from the body, while motion rotated around each blade's center. Thin connections could separate during flapping. | The straight inner edge faces the skin. Each blade rotates around a common point inside both its real shape and the body. |
| Tail forks | Crownwhale and Sunskipper's horizontal fork roots sat beyond the tail stock. Other forks could open during a beat. | The broad roots seat through the stock, both halves share its embedded hinge, and the stock remains connected to the body. Rounded petal tails keep a deeper seat. |
| Starwhisker | Four narrow whiskers floated outside the actual curved head surface. | Whiskers start within the head and extend outward along fitted local frames. |
| Aurorafin | The lowest lure segment ended above the real body skin, leaving its entire lure unsupported. | The existing lowest segment extends into the skin; the other segments and pearl retain their silhouette and joins. |
| Mossback | Outer flippers sat too low and far from the rounded body, with motion that could open the remaining connections. | All four flippers sit closer to the body and rotate around embedded roots. |
| Bubble Squid | Some arm roots leaned away from the mantle rim, and tips animated independently around their centers. | Arm roots lean into the real rim. Each tip shares its arm's rooted transform, so the authored curve remains joined while the six arms move with different phases. |
| Sunskipper | Underside keels could remain separated from the body. | Their existing upper edges intersect the underside; the intended keel outline is retained. |
| Cloudmoth | Hind-wing support depended too much on the moving forewing; moving the hind wing forward hid its eyespots. | Hind wings sit inward while retaining their rear silhouette. The fixed eyespots and pearls fit their real wing and sit farther aft, where they remain recognizable around the moving forewings. |

Veilfin and Eclipse retain the v1.7 fitted body, membrane, crescent and comet-tail
work. Their contact checks remain active. No Parts were added: the complete
catalog is still **471 Parts**, with **35** the largest species. Veilfin uses 34
and Eclipse 27. Some existing envelopes become smaller: Crownwhale's measured
animated depth changes from approximately 4.66 to 4.42 studs at maximum weight.
This is a source geometry measurement, not a rendering performance result.

## Inspection and evidence

The review used actual production `FishModel` output. Normal, Golden and
Prismatic appearances were inspected from top, side and three-quarter views.
Additional pose plates show measured low/high front-fin positions and a middle
pose, selected from the actual animation rather than a separate illustrated rig.
Colors and species silhouettes remain distinct without relying on emission.

The offline plates are local review evidence, not Roblox screenshots. Examples:

- `/tmp/v18-fish-before-0-quarter.png` and
  `/tmp/v18-fish-before-1-quarter.png`: starting models and variants.
- `/tmp/v18-fish-sealed-0-quarter.png`,
  `/tmp/v18-fish-sealed-1-quarter.png` and
  `/tmp/v18-fish-sealed-2-quarter.png`: final catalog/variant comparisons.
- `/tmp/v18-fish-sealedmotion-0-quarter.png` through
  `/tmp/v18-fish-sealedmotion-2-quarter.png`: measured motion pose plates.

Temporary review files are not dependencies of the downloadable game or source
checks. They may not survive replacement of the cloud workspace.

## Automated checks

`tools/check_fish_models.py` executes the production module with spatial doubles.
It samples actual ellipsoid and native wedge volumes. A contact requires a point
strictly inside both shapes; overlapping bounding boxes alone cannot pass.
Bounding boxes only prune unnecessary candidate comparisons. The complete
catalog must form a connected component from each fish's body.

Animated hinges use a shared model-space point inside the moving shape and its
support. Rotation about that point preserves the contact. The checker evaluates
the actual implementation through 121 poses per species, including scaled models
at a distant, rotated pivot, rather than assuming the declared root is used.
Grouped pieces retain their measured relative transforms. Every sampled frame
must stay finite, orthonormal and right-handed.

Final fish results:

- 17 distinct species, 471 Parts total, maximum 35 Parts per species.
- 454 attached details across the complete catalog.
- 119 fitted head/eye/pupil/glint/mouth contacts; both complete eyes must remain
  readable across variants. Cloudmoth also has explicit hind-wing/spot/pearl checks.
- 7,623 embedded animated fin, tail and arm-root samples.
- 12,463 grouped membrane, wing, tail and arm samples.
- 605 continuous Veilfin body joins and 4,598 exceptional-fish solid contacts.
- 968 contained Eclipse wing-marking footprint corners.
- Six deliberate regressions rejected: opposite comet-tail yaw, mirrored veil
  roots, missing legacy fin hinges, floating royal fork, detached whiskers and
  outward squid roots.

Final integration checks against these same models pass:

- Public aquariums: 3,111 maximum-weight poses across all seventeen species and
  all three slots, plus 658 supported arrival/promenade samples.
- Aquarium menu: 2,448 poses and 542,592 projected corners.
- Journal/catch portraits: 4,998 poses and 1,107,792 projected corners.
- Exceptional-catch stages: 750 full-sequence poses and 190,800 projected corners
  across five viewport sizes; the world camera remains untouched.
- Source compilation and diff whitespace validation.

Re-run with the official standalone Luau executable:

```text
python tools/check_fish_models.py --luau /path/to/luau
python tools/check_aquarium.py --luau /path/to/luau
python tools/check_fishing_interface.py --luau /path/to/luau
python tools/check_catch_cinematic.py --luau /path/to/luau
```

## Native acceptance remains open

These are source geometry, projection and event-double checks. They do not run
Roblox Studio, its native shaders, native font metrics, replication or device
rendering. Before public release, inspect every species in a real catch, journal,
public aquarium and applicable rare reveal on Windows, phone and iPad. Check the
full animation from multiple viewpoints at low and high graphics, particularly
thin fins, face contrast, Cloudmoth's hind-wing spots, the squid's six arms and
fork roots. Confirm that the fish remain recognizable at normal play distance
and that the geometry budget performs acceptably on the selected baseline phone.
