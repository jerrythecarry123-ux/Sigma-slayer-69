# Historical release notes through v1.7

This is the README preserved from the v1.7 release. Counts, download names and
session-only settings below describe that historical build. Current instructions
and validation are in the root README and v1.8 review documents.

# Cloud Anglers — v1.7

[Download the Roblox Studio file on GitHub](https://github.com/jerrythecarry123-ux/Sigma-slayer-69/blob/main/artifacts/Cloud-Anglers-v1.7.rbxlx)

Choose **Download raw file**, open the `.rbxlx` in Roblox Studio and press **Play**.
The world is generated at Play; an empty Edit viewport before Play is expected.
No plugins, model imports, API keys or animation uploads are needed.

## New in v1.7 — fish behavior and exceptional catches

The existing world now supports a more deliberate fishing loop. A server-owned
fish is bound before the bite. Its behavior changes anticipation, rod response,
reeling duration and a modestly drifting gold target. The first three successful
catches retain static, forgiving timing. Misses and cancelled casts keep the same
private fish choice in that pond until a successful catch; no reward is granted
before a valid release. Reservations last for the server session, not across
rejoins. See [the fishing protocol](fishing-loop.md) for the actual formulas
and latency limits.

All seven rarity tiers have shared presentation data: **Common, Uncommon, Rare,
Epic, Legendary, Mythical and Secret**. The original fifteen fish keep their IDs,
rarities and values. **Veilfin** adds a flowing segmented eel with paired veil fins
to Evergreen Reach; **Eclipse** adds a crescent-backed disk with an asymmetric
comet tail to Starfall Lookout. Both need the Aurora Rod. They use weighted
selection and do not receive the original collection's duplicate protection.
[Offline geometry review of the exceptional fish](images/fish-silhouettes-v1.7.png)
shows the actual production shapes and colors; it does not reproduce Roblox
shaders or the in-game interface.

Species now have explicit behavior, difficulty, procedural model/animation and
presentation references. These are real generated models, not unconfigured asset
IDs. Every species remains within the 50-Part cap.

Epic and higher catches receive short, skippable 3D portrait sequences, with
species movement and restrained rarity accents. Their camera belongs exclusively
to a ViewportFrame; your world camera and movement remain yours. First reveals
last 1.9–3.5 seconds, repeats at most 1.5 seconds, and reduced effects use a still
0.85-second presentation. Skip, death, travel, menus and replacement characters
cancel or complete without duplicating rewards or reopening stale cards.

**SETTINGS** provides session sound and reduced-effects controls. Roblox Reduce
Motion is also respected. Journal, settings and catch cards gain keyboard/gamepad
close and focus handling; short landscape screens use a horizontal catch card
with physical touch targets of at least 44 pixels at the checked sizes. The same
six shipped sounds receive quieter, distinct tier phrases, bounded voices and
mute cancellation. No audio uploads or additional clip library is required.

The server save namespace, old milestones, coins, rods, displays, lighting and
five-island layout remain compatible. A final 17-species goal is appended after
the ten original milestones. Native rendering, animation feel, audio and real
phone/iPad performance still require the Studio/client checklist.

The long-term roadmap and honest research/validation gaps are saved in
[DEVELOPMENT_PLAN.md](../DEVELOPMENT_PLAN.md), [PROGRESS.md](../PROGRESS.md),
[NEXT_STEPS.md](../NEXT_STEPS.md) and [KNOWN_ISSUES.md](../KNOWN_ISSUES.md).

## New in v1.6 — surface textures and fitted world details

Six shared material presets use Roblox's published color, normal and roughness
maps for timber, woven fabric, slate, plaster, limestone and sand. Their tile
scales suit the existing buildings and props. Painted color inputs and lighting
settings are retained; smooth fish, leaves and cosmetic Sphere meshes are kept
separate. Native cloth faces replace four untexturable cushion meshes. Material
selection follows streamed parts without a per-frame surface scan or permanent
readiness listeners on finished surfaces. See [surface notes](world-surfaces.md)
for the exact maps, scales and rendering limits.

Existing details receive another contact and shape pass: seated roof courses and
crate stacks, fitted barrel hoops, contained planter soil, attached flowers and
leaves, supported cleats, coaxial fishing floats, anchored pennants, curved shell
ribs and inlaid mushroom spots. Picnic cups, plates, fruit and cloth sit on their
supports, with small tea surfaces inside the visible white cup borders. Seven
existing rock groups become closed, beveled hulls with moss fitted to their faces;
coconuts follow the actual leaning palm trunks through the canopy sway.
The lighthouse's existing metal ribs now follow the dome instead of disappearing
inside it. Initial source geometry is **10,806 Parts**, within a **10,825-Part**
budget; the added geometry refines existing rocks, cushions, cups and dome ribs.

These are refinements to the same world and props. The fish collection, progression,
travel coordinates, sound mix and saved records retain their existing settings.
Native textures and device performance must still be inspected in Roblox Studio;
offline previews show geometry and color, not the Roblox material shader.

## New in v1.5 — solid wings and accurate pond edges

All six gulls have solid, swept wing prisms, gray coverts and joined dark flight
feathers. The broad wing surface is visible from above and below and follows the
existing shoulder animation through flaps and glides. Delayed wing joints and
streamed-out birds recover without stopping the opposite wing.

All five lagoons now generate their water, basin foundation and stone bank from
one shared four-stud Terrain-cell footprint. Mitered coping covers the stepped
water edge, with sloping outside faces, an inner retaining wall and fitted returns
at the spillways. Rope posts sit on this stone instead of hovering at an idealized
ellipse. Coping continues beneath the raised piers; rails leave their approaches
open. The nine cliff cascades land within the exposed water, clear of the coping.
The native water volume stays above the basin floor instead of extending through
its tapered underside.
Existing long outlets have real low openings through the rocks and matching
cuts through the basin floors and undersides, so stone no longer crosses the fall.

Existing signs gain a small fish mark, restrained inset border, correctly
proportioned canvases, clearer title/caption spacing and readable reverse faces.
Floating dock lamps, canopy brackets, cottage lantern stems, the observatory
plaque, flower leaves, hedge rosettes, pennants and the grotto plaque are fitted to
their actual supports. The airship bands follow its narrower end sections.

Cosmetic ellipsoids now use an explicit built-in Sphere SpecialMesh with
independent dimensions, including the fish models. No mesh upload is required.
The old offline preview had treated native Ball parts as stretched ellipsoids;
it was insufficient evidence of their appearance in Roblox. The preview now
distinguishes the actual mesh from the native primitive and exports occupied
water cells. See [geometry notes](native-geometry.md) for the limits.

Initial source geometry is **10,643 Parts**, within a **10,650-Part** budget.
The fitted bank and real cuts through existing waterfall cliffs/basins account
for the increase from v1.4. This is a bounded detail budget,
not a phone/iPad performance measurement. Lighting, sound, fish collection,
progression, travel coordinates and save records retain their existing settings.

## New in v1.4 — fish identity, gulls and a fitted lagoon fence

This pass focuses on the existing fish, birds and waterfront details. All fifteen
species keep their IDs, habitats, rewards and saved records. Their models now have
more distinct proportions, fin outlines and fitted markings: a freckled Pufflet,
striped Mintfin, flame-finned Emberfin, petal-shaped perch, marked long-snouted pike,
rounded moth wings, swept flying-fish fins, koi patches, shell scutes, mantle spots,
whiskers, coral branches and Crownwhale's compact tiara. Dark patterns and pale
accents retain their contrast in Golden and Prismatic appearances. The same models
appear in catches, journal portraits and player aquariums; each uses at most 35
Parts, within the existing 50-Part species limit.

The same six seagulls gain fitted eyes and tapered beaks, gray wing coverts,
dark primaries, paired tail feathers and tucked feet. Wing details belong to their
existing animated joints, so they flap together. No birds or animation loops are
added.

Low timber posts and sagging rope follow the exposed edges of all five lagoons.
A stone retaining rim reaches down to the existing basin floor, and those basin
foundations now have an even outline beneath it. Docks, portal approaches, boat
access and existing waterfall outlets remain open. There are no hidden fence
panels. The gallery entry also removes overlapping deck surfaces and lifts its
top slightly above the meadow to prevent flicker.

Initial source geometry is **10,254 Parts**, 307 more than v1.3 (about 3.1%). The
bounded detail budget is now 10,350; extra parts belong to the requested waterfront
and bird details. This is not a device-performance result. Lighting, audio,
progression, travel coordinates and saving are retained.

## New in v1.3 — visible surfaces and matching collision

This is a correction pass on the existing map. In v1.2, hidden persistent floors
could outlive the visible portal/gallery decks when decoration streamed out.
The actual visible plank decks now supply persistent landing and walking support;
the duplicate hidden underplates are removed. Pier/bridge subdecks are visible
wood beneath their individual boards, with the same physical footprint.

The temporary raised spawn pad loses collision after the finished world is
parented, so it cannot make avatars hover above the pier. Large rocks use their
visible facets for collision; the old hidden boxes protruded beyond the slopes.
The existing skiff sits in the water throughout its gentle bob, and its bow floor
is a fitted horizontal triangle rather than a ramp protruding through the hull.

The initial map is **9,947 parts**. Walking routes, fishing, travel coordinates,
lighting, audio and saving remain. New checks reject invisible walking planes,
raised spawn collision and hidden rock boxes, and sample 100 positions above the
server's bobber lanes. Portal/gallery tests also detach decoration and check the
remaining visible support. This is an analytic/event-double check, not a claim
that real Roblox streaming or physics has been tested here.

## New in v1.2 — refine the existing terrain and models

The same five islands, paths, residents, buildings and fishing content remain.
The focus is shape, proportion and how existing surfaces meet:

- Sand paths have filleted corners, subtle width variation and a warmer worn
  surface. Their destinations and the level walking floor are unchanged.
- Existing grassy knolls have rounded shoulders, while island undersides have
  less uniform strata and a restrained exposed-earth collar.
- Tree crowns are closed foliage volumes, with softer silhouettes instead of
  open star-shaped wedge fans. Existing moss follows the actual stone slope.
- Pond cliffs have supported, narrower upper masses and sloped water-facing
  shoulders. Dangling cap wedges are removed; the same nine waterfalls remain.
- Cottage roofs have a stronger pitch, broader aligned slate courses and less
  busy gables. Deep teal and muted coral accents sit against warm plaster.
- Existing barrels have bowed staves and fitted hoops rather than straight
  cylinders with floating seam rods.

Art direction takes cues from readable low-poly forms and a clear fishing
waterfront in [Fisch](https://www.roblox.com/games/16732694052/Fisch) and
[Fish It](https://www.roblox.com/games/121864768012064/Fish-It), alongside the
user-provided Duck Pond image. Their public pages were blocked in this environment;
this is a style reference, not a review of their current releases or rankings.
No models or textures were copied from those games.

The lighting, audio, progression, travel coordinates and save format are retained.
Extra geometry is confined to shaping existing terrain/models, not scattering
more scenery. Initial source geometry is 9,960 parts, within the existing 10,000-part
budget. Native materials and actual device performance still need Studio.

## New in v1.1 — materials and a more inhabited world

The existing five islands and seven residents are refined. There are no new zones,
paid systems or sounds. Initial scenery falls from 9,584 to **9,332 parts**.

| Surface | Native Roblox material |
| --- | --- |
| Pier boards, timber, trunks, crates and painted woodwork | Wood; WoodPlanks on broad floors |
| House and lighthouse walls | Plaster |
| Roofs, cliffs and faceted rocks | Slate; Limestone on dressed stone |
| Grass, sandy coast and paths, pot soil | Grass, Sand and Ground |
| Awnings, flags, cushions, rope and resident clothing | Fabric |
| Small fittings and aquarium frames | Metal; transparent Glass stays separate |

Most legacy studs are removed where they masked wood or stone textures. Painted
ceramics, leaves and fish intentionally keep quieter smooth surfaces. Existing
subtle plank/roof/rock color variation remains. Exposure, low reflections and
shadow settings stay subdued. These are Roblox's built-in materials; no external
texture uploads, asset IDs or extra texture-overlay Parts are required.

Residents glance at nearby characters and offer brief greetings before returning
to work. Their existing jobs now use a real repair bench, a planted watering patch,
a level serving tray and a fishing line with a fixed water endpoint. Walking leg
cadence follows travel speed; blinks and wildlife banking add restrained motion.
The café server is moved out of the wall and onto the porch.

The same ponds have lower, distinct shorelines and fewer rock masses, replacing
repeated high walls. Visible rock now owns collision, without taller invisible
copies. Waterfalls have connected source channels, clear drops and edges inside
native water. Wrapped streaks fade instead of visibly jumping.

The boat's dock anchor stays fixed while its bow moves; its native Beam rope sags
between the ends. Parasol canvas and pennants sway gently. Nearby planting is
recomposed around working/seating scenes; trail pots, book, shells, bench supports
and the lifebuoy attachment are corrected. The aquarium promenade gains timber
support and framing. The old floating prototype fish is removed, and an existing
tree moves clear of the first gallery's viewing corridor.

Native materials must be judged in Roblox Studio. Offline previews show geometry
and color only; they do not emulate Roblox material texture maps or normal maps.

## Your first session

1. Start beside the water. Tap **CAST LINE**, or press E / gamepad RT.
2. When the bobber bites, hold the button, then release inside the colored zone.
   Gold earns Brilliant quality. The target changes between casts and may drift with fish resistance: watch the meter.
3. Your first three species automatically fill your personal aquarium. Open
   **MY AQUARIUM** to pick three favorites, then **VISIT MY TANK** to see them.
4. After three different fish, buy the Breeze Rod through **JOURNAL → Rod workshop**
   or the dockside upgrade stand. The next goal always appears in the HUD.
5. Step into a **POND PORTAL** and choose another island. Each pond has its own
   population, with starter fish available on every island. Islands are free.

Fine and Brilliant catches build a skill chain with a bounded coin bonus. Failed
or cancelled attempts clear that chain. Species have different weight ranges;
beat your personal size records and find Golden or Prismatic appearances. The
first three catches have normal appearances so the introduction teaches real
progress. Afterward, Golden is 2.5% and Prismatic is 0.5%, from gameplay only.
A missed fish never removes money or collected fish.

## Seventeen fish, five habitats

| Island | Its collection |
| --- | --- |
| Sundrift Harbor | Pufflet, Mintfin, Emberfin |
| Petalwind Grove | Petalperch, Ribbon Koi, Starwhisker (Breeze Rod) |
| Evergreen Reach | Mossback, Pinepike, Moonray (Breeze Rod), Veilfin (Aurora Rod) |
| Tideglass Cove | Bubble Squid, Sunskipper, Coralcrown (Nimbus Rod) |
| Starfall Lookout | Cloudmoth, Aurorafin (Nimbus Rod), Crownwhale and Eclipse (Aurora Rod) |

The journal shows habitats, rod requirements, best grades and weight records.
Discovery protection guarantees an unseen eligible original species after at most
two consecutive duplicates while protected undiscovered fish remain in that pond.
Veilfin and Eclipse are weighted-only discoveries; the journal does not promise
them within three catches.
Collection points reward better grades rather than duplicate grinding. Other
players' collections appear on the leaderboard; there is no PvP.

## A collection you can show

Each player gets a public tank along the harbor's Aquarium Walk. Three selected
fish swim locally, with their collected appearances, species names and best
weight labels. Friends can walk through the gallery and see real player displays.
Vacated plots can be reused; more rows are built as players join.

Four aquarium themes use earned coins: **Lagoon** is free, **Blossom Garden**
costs 65, **Coral Reef** 110 and **Star Observatory** 140. They change colors and
physical decorations: a sunken arch, bonsai garden, coral branches or observatory
stones. Owned themes can be re-equipped without another charge.
The three-slot editor rejects unowned species, duplicate placements and invalid
slots. Size records and collected variants are independent achievements; a tank's
**BEST** weight label does not claim that its displayed variant set that record.

There are no Robux checkout buttons or paid random rewards in this build. Cosmetic
progress is playable now; no unconfigured purchases are shown to children.

## More shaped scenery

- Fish have tapered fins, forked tails, inset faces, gills and species-specific
  silhouettes: rays, a turtle-like Mossback, squid, winged fish and Crownwhale.
- Trees use branching trunks, pointed crowns, layered pine skirts and curved
  palms. Rocks have chipped facets; plants have pointed leaves and shaped petals.
- Floating islands taper underneath. Pond walls gain sloping rock faces, cracks,
  moss ledges, trailing vines and softened waterfalls, replacing flat block fronts.
- Houses have fitted gables, shaped window crowns, planter rims, roof caps and
  folded canvas hems. Smooth broad surfaces replace most exposed toy-brick studs.
- Aquariums gain beveled pedestals, open frame rails, arched crowns, glass mullions
  and small themed scenes. Close details remain clear of the fish swim volumes.
- Animated residents, gulls, butterflies, fish schools, drifting boats and swaying
  foliage remain. The existing audio mix is retained; no new sounds are added.

Afternoon Realistic lighting retains exposure −0.2, low ambient fill and stronger
shade. Bloom, sun rays and water reflectance are off. Portal/gallery travel uses
a short dark transition, with no white flash, camera shake or paid unlock.

## Saving and return play

Published Roblox-client play saves automatically. The existing v0.3 save namespace
and version-1 records remain: old coins, rods, catch grades and milestones migrate
without resetting progress. New records, variants, aquarium slots and themes save
with the same lease-protected profile.

Each discovered species earns 0.25 coins/min while away, up to eight hours and
120 coins per return. The welcome summary reports the server-calculated gift.
Studio Play uses temporary profiles by default and labels them clearly.
For persistence testing, publish a separate private test experience and join it
through the Roblox client. Optional Studio saving uses a separate test store;
see [return-play design](discovery-and-return-play.md).

## Validation and limits

122 automated tests cover catalog data, fishing, locations, progression/saving,
responsive layout, travel authorization and place export. All 36 production
modules/scripts and seven Luau suites compile. Separate checks execute unchanged production code for:

- 29 portal/gallery server scenarios: authorization, streaming failure, concurrent
  requests, character replacement, departure and movement during loading.
- Dark transitions, control restoration, stale callbacks, gamepad focus and
  timeouts with UI/event/tween doubles.
- All 17 fish: distinct geometry, at most 35 Parts each, readable variant patterns,
  repeatable appearances and animation at distant pivots.
- Actual fishing service: private fish reservations, public timing metadata,
  single authoritative rewards, late observers and movement/death/travel guards.
- Actual fishing controller: 16 input/protocol scenarios including release before
  Hold acknowledgement, lost responses, system/local preferences, active-device
  hints and stale rewards after interruption.
- Actual audio: nine event cases covering voice caps, loop ownership, mute/unmute,
  cancelled notes and bounded tier phrases. These do not judge native sound quality.
- Actual catch/presentation modules: private-camera framing, skip/repeat/reduced
  paths, death/travel/resize cleanup, rod/line motion and transient ownership.
- Actual fishing UI: catalog totals, every timing target, region changes, accurate
  rewards, cancelled reveals, settings, gamepad focus and touch-target arithmetic.
- Player aquariums: independent owners, profile caching, theme changes, plot reuse,
  dynamic rows, supported arrivals, swim bounds, local animation and streaming rebind.
- Existing residents: 1,503 finite animation steps, nearby-character reactions,
  greeting cooldown, stable jobs, fixed water endpoints, blinks and streamed recovery;
  gull feather offsets remain fixed through both measured flap extremes.
- Scenery: fixed mooring anchors, sagging Beam control points, authored pivots,
  bounded rotations, quiet flow wraps, distance limits and opacity ownership;
  27 extreme boat poses keep hull/water contact and the interior dry.
- Material export checks verify the six presets and 18 shared map references.
  Production event checks cover late tags, attributes and materials, independent
  owners, delayed meshes, full streamed-model removal and world rebind. An optional
  captured-world stress pass exercises more than 6,000 actual surface bindings.
- 178 actual scenery joins: supported lamps, canopy posts and hems, brackets,
  plaque stands, contained planters and attached flower/leaf parts.
  Sign checks cover 47 boards / 94 faces with three preview owners,
  including long owner names; actual Roblox font rendering remains untested.
- Normal generated-Folder startup, custom-map startup, and a regression mutation
  that restores the former broken Model-only travel guard.

Analytic rays through captured colliders check 3,681 walking-route points, 225 spawn
points, 125 portal-arrival points and 429 portal approaches. Another 2,373 samples
check that the visible trails still cover the walking corridors. Pond checks use
the actual occupied water cells and constructed coping/retaining wedges to inspect
water containment, supported posts, cascade landings and unobstructed spillways.
Representative captured material roles are checked for
old Studs overrides. Another 100 bobber-lane samples check for obstructions,
and thin physical walking surfaces must be visible. Initial scenery stays
below the 10,825-Part detail budget; player tanks add streamed Atomic displays. Only thin
visible portal decks and gallery walking surfaces are persistent. Walking speed is
22 studs/second; the first casting marker is about one second from spawn.

Offline Blender previews inspect source geometry and placement. They do not
reproduce Roblox rendering, physics, native input, streaming, sound or device FPS.
**Actual Roblox Studio/client visuals and phone/iPad performance remain untested
here.** Complete the [Studio checklist](studio-testlista.md) before public release.

## Build and check

Python standard library builds the place and source ZIP:

```powershell
python tools/build_place.py
python tools/package_release.py
python -m unittest discover -s tests -p "test_*.py" -v
```

Outputs: `artifacts/Cloud-Anglers-v1.7.rbxlx` and `artifacts/Cloud-Anglers-v1.7.zip`.
With the official Luau CLI, run every `tests/*.luau` suite, then:

```powershell
python tools/check_startup.py --luau /path/to/luau
python tools/check_travel.py --luau /path/to/luau
python tools/check_portal_interface.py --luau /path/to/luau
python tools/check_fishing_interface.py --luau /path/to/luau
python tools/check_fishing_service.py --luau /path/to/luau
python tools/check_fishing_client.py --luau /path/to/luau
python tools/check_fishing_audio.py --luau /path/to/luau
python tools/check_catch_cinematic.py --luau /path/to/luau
python tools/check_fishing_presentation.py --luau /path/to/luau
python tools/check_fish_models.py --luau /path/to/luau
python tools/check_aquarium.py --luau /path/to/luau
python tools/check_residents.py --luau /path/to/luau
python tools/check_scenery.py --luau /path/to/luau
python tools/preview_world.py --luau /path/to/luau --output /tmp/world.json
python tools/check_world.py /tmp/world.json
python tools/check_details.py /tmp/world.json
python tools/check_signs.py --luau /path/to/luau
```

`preview_world.py --gallery-players 3` adds clearly named **offline preview** owners
for art inspection. They never appear in the downloadable game.

The supplied YouTube video was unavailable in this environment. Offline income
came from the user's explicit request. No discovery ranking, retention or revenue
result is guaranteed or claimed.
