# Cloud Anglers — v1.5

[Download the Roblox Studio file on GitHub](https://github.com/jerrythecarry123-ux/Sigma-slayer-69/blob/main/artifacts/Cloud-Anglers-v1.5.rbxlx)

Choose **Download raw file**, open the `.rbxlx` in Roblox Studio and press **Play**.
The world is generated at Play; an empty Edit viewport before Play is expected.
No plugins, model imports, API keys or animation uploads are needed.

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
water cells. See [geometry notes](docs/native-geometry.md) for the limits.

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
   Gold earns Brilliant quality. The target changes between casts: watch the meter.
3. Your first three species automatically fill your personal aquarium. Open
   **MY AQUARIUM** to pick three favorites, then **VISIT MY TANK** to see them.
4. After three different fish, buy the Breeze Rod through **JOURNAL → Rod workshop**
   or the dockside upgrade stand. The next goal always appears in the HUD.
5. Step into a **POND PORTAL** and choose another island. Each pond has its own
   three species, with starter fish available on every island. Islands are free.

Fine and Brilliant catches build a skill chain with a bounded coin bonus. Failed
or cancelled attempts clear that chain. Species have different weight ranges;
beat your personal size records and find Golden or Prismatic appearances. The
first three catches have normal appearances so the introduction teaches real
progress. Afterward, Golden is 2.5% and Prismatic is 0.5%, from gameplay only.
A missed fish never removes money or collected fish.

## Fifteen fish, five habitats

| Island | Its collection |
| --- | --- |
| Sundrift Harbor | Pufflet, Mintfin, Emberfin |
| Petalwind Grove | Petalperch, Ribbon Koi, Starwhisker (Breeze Rod) |
| Evergreen Reach | Mossback, Pinepike, Moonray (Breeze Rod) |
| Tideglass Cove | Bubble Squid, Sunskipper, Coralcrown (Nimbus Rod) |
| Starfall Lookout | Cloudmoth, Aurorafin (Nimbus Rod), Crownwhale (Aurora Rod) |

The journal shows habitats, rod requirements, best grades and weight records.
Discovery protection guarantees an unseen eligible fish after at most two
consecutive duplicates while eligible undiscovered fish remain in that pond.
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
see [return-play design](docs/discovery-and-return-play.md).

## Validation and limits

104 automated tests cover fishing, locations, progression/saving, responsive layout,
travel authorization and place export. All 34 production modules/scripts and six
Luau suites compile. Separate checks execute unchanged production code for:

- 29 portal/gallery server scenarios: authorization, streaming failure, concurrent
  requests, character replacement, departure and movement during loading.
- Dark transitions, control restoration, stale callbacks, gamepad focus and
  timeouts with UI/event/tween doubles.
- All 15 fish: distinct geometry, at most 35 Parts each, readable variant patterns,
  repeatable appearances and animation at distant pivots.
- Actual fishing UI: catalog totals, every timing target, region changes, accurate
  rewards, cancelled reveals and repeat-catch dismissal.
- Player aquariums: independent owners, profile caching, theme changes, plot reuse,
  dynamic rows, supported arrivals, swim bounds, local animation and streaming rebind.
- Existing residents: 1,503 finite animation steps, nearby-character reactions,
  greeting cooldown, stable jobs, fixed water endpoints, blinks and streamed recovery;
  gull feather offsets remain fixed through both measured flap extremes.
- Scenery: fixed mooring anchors, sagging Beam control points, authored pivots,
  bounded rotations, quiet flow wraps, distance limits and opacity ownership;
  27 extreme boat poses keep hull/water contact and the interior dry.
- 96 actual scenery joins: supported lamps, canopy posts and hems, brackets and
  plaque stands. Sign checks cover 47 boards / 94 faces with three preview owners,
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
below the 10,650-Part detail budget; player tanks add streamed Atomic displays. Only thin
visible portal decks and gallery walking surfaces are persistent. Walking speed is
22 studs/second; the first casting marker is about one second from spawn.

Offline Blender previews inspect source geometry and placement. They do not
reproduce Roblox rendering, physics, native input, streaming, sound or device FPS.
**Actual Roblox Studio/client visuals and phone/iPad performance remain untested
here.** Complete the [Studio checklist](docs/studio-testlista.md) before public release.

## Build and check

Python standard library builds the place and source ZIP:

```powershell
python tools/build_place.py
python tools/package_release.py
python -m unittest discover -s tests -p "test_*.py" -v
```

Outputs: `artifacts/Cloud-Anglers-v1.5.rbxlx` and `artifacts/Cloud-Anglers-v1.5.zip`.
With the official Luau CLI, run every `tests/*.luau` suite, then:

```powershell
python tools/check_startup.py --luau /path/to/luau
python tools/check_travel.py --luau /path/to/luau
python tools/check_portal_interface.py --luau /path/to/luau
python tools/check_fishing_interface.py --luau /path/to/luau
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
