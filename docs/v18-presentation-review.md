# v1.8 presentation and ambient review

Reviewed the v1.7 client presentation code, then exercised the changed production
modules with deterministic geometry, scheduler, camera and event doubles. The
following are implemented fixes; none is a claim of a native Studio playtest.

## Casting and rod contact

The new server-approved `ChargingCast` state draws the rod back without creating
a bobber, line, splash or cast sound. Its progress uses the shared
`FishingRules.castProgressAt` function. Launch follows the server's `castAt`,
`castDuration`, `castPower` and final water target; it does not select rewards.
Release pitch follows the held strength and resolves into a short forward swing.

The flight now starts at the actual bent rod-tip endpoint, rather than an
unrelated point two studs above the hand. Five tested strengths retain that join
and land on their server-provided endpoints, with bounded arc heights.

The former reel crank spun around its own offset center. Its arm could therefore
look like a separate propeller. A fitted cylinder hub and small grip knob add two
Parts to an **active** rod; the arm and knob now rotate about the spool's axis.
430 actual cylinder/sphere contact poses cover more than a complete turn, the
static pose and five strength trajectories. All pieces remain cosmetic.
An offline four-pose review of the current production geometry is available in
the execution workspace at `/tmp/v18-reel-proof.png`; it does not emulate native
materials, lighting or avatar animation.

## Multiplayer effects and streamed characters

Before this pass, receiving a distant packet created rods, floats, catch fish,
water bursts and sounds before the next render frame culled some of them.
Allocation now checks character and camera distance first. Recovery displays an
ongoing cast without replaying old landing/bite cues. A streamed-out hand or
detached character clears its rig instead of leaving a frozen rod behind.

Water geometry shares a per-client ceiling of eight short effect groups, at most
96 Parts. Local feedback may replace an older remote group but cannot expand the
ceiling. Debris owns expiry; the small ownership list is pruned on allocation,
without a new per-frame effects scan. **This bound covers transient water accents
only**, not rods, flying fish, the world or aquarium displays. It is not an FPS
or memory measurement.

Two additional lifecycle regressions were fixed:

- A fresh observer catch can exist before its first rod allocation. Leaving view
  in that interval formerly skipped cleanup because it checked only `actor.rig`.
  Cleanup now also owns a pending caught fish/bobber.
- A successful result arriving while its hand is streamed out formerly fell
  through to the miss branch. It now omits the unavailable world flight without
  emitting a false failure. The authoritative reward and separate catch card are
  unaffected.

Portal-menu/busy state suppresses late fishing visuals. Actual shoulder base
poses and newer external animation ownership still survive cleanup.

The server now distinguishes `Missed`, `Cancelled`, `Interrupted` and `Caught`
outcomes. Only an actual `Missed` result plays the miss burst/sound; opening a
menu or deliberately cancelling no longer sounds like a failed release. Both
quiet outcomes still remove the bobber and allow the inactive rod pose to settle.

## Catch-stage lifecycle and work per frame

The rare stage rejects a missing/already-dead Humanoid. Changing to reduced effects
gets a short wall-time exit even while rendering is suspended; an old exit cannot
close a newer stage. Viewport layout writes now occur only when the canvas changes,
while camera/fish animation continues normally. Touch/gamepad focus, skip,
replacement, travel, resize and detached-UI ownership remain covered.

750 full-sequence poses and 190,800 projected Part corners across five viewport
sizes pass. The world camera's identity, CFrame, camera mode and FOV remain
unchanged. These projection checks do not reproduce Roblox font rendering or
native ViewportFrame appearance.

## Ambient streaming and readiness

Resident removal used to scan every actor's joint roots for each removed Part.
It now follows the removed object's own actor ancestry. Removing 500 unrelated
decorations performs **zero joint-root reads** in the production event check.
Whole-model-only removal disconnects nested readiness listeners; repeated child
notifications are harmless. Detached cached rods, eye parts, drops and joint roots
stop driving poses outside their actor.

Eye Parts can now receive `AmbientEyeSize` after they arrive and still activate
blinking. Readiness listeners are restricted to the small named eye set. Authored
moving scenery models also observe a property-only `PrimaryPart` change, so a
replacement root can resume without requiring another attribute/child event.
These connections disconnect on removal and world unbind.

## Checks executed

- Earned rod finishes use the existing eight-Part rig and server-approved level.
  Catalog-owned grip/shaft/reel/hardware roles distinguish Driftwood, Breeze,
  Nimbus and Aurora without extra geometry or per-frame color/material writes.
  Live finish changes preserve transforms, fitted joints and the tip attachment;
  malformed/missing levels fall back to Driftwood. See `v18-earned-rods.md` for
  the actual-source plate and material-rendering limits.
- The three shaft sections use native cylinders with their actual local-X axes
  mapped onto the existing logical animation frames. All original center/length
  positions and the grip-owned pivot remain; 1,630 actual cylinder-cap contact
  witnesses cover bent joints and the attached line end. Cast and Beam origins
  use the fitted Attachment's native WorldPosition.
- `check_fishing_presentation.py`: timing, windup, tip origins, five strengths,
  434 reel joins, physical/nonqueryable flags, line sag, authored shoulder poses,
  distant allocation, crowd cap, stream recovery, travel, effect expiry and all
  four finishes with zero repeated finish writes over 120 stable frames each.
- Seven deliberate mutations are rejected: distance allocation, effect ceiling,
  reel pivot, release origin, pre-rig catch cleanup, constant starter finish and
  an incorrect native-cylinder axis basis.
- `check_catch_cinematic.py`: full-sequence framing, cached layout, reduced-effect
  exits, living-character entry, skip/repeat, focus and stale lifecycle callbacks.
- `check_residents.py`: 1,505 finite animation steps, late eye metadata, detached
  props/roots, whole-model listener cleanup and the 500-decoration removal case.
- `check_scenery.py --capture /tmp/v17-final-world.json`: 6,203 captured surface
  bindings, four whole Atomic removals, readiness, ownership, motion-root changes,
  no retained ready-part listeners and no per-frame material assignment.
- The previous resident/scenery sources are rejected by the new late-eye and
  property-only root-readiness regressions respectively.
- All four changed production modules compile with the official Luau compiler.

Native avatar/Animator blending, actual Beam appearance, mobile graphics/audio,
streaming behavior and device profiling remain part of the private-client
acceptance checklist. The geometry and event checks do not replace those tests.
