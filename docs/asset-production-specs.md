# Optional authored asset upgrades

The v1.7 build is playable without uploads: fish/rods/catch animation are
procedural, catch cameras are private ViewportFrame cameras, and the six audio
clips ship with Roblox. There are no placeholder asset IDs to configure. The
following specifications describe future quality work, not assets already made
or a dependency hidden from the player.

## Bespoke sound set

Keep the existing `FishingAudio` interface and replace the `clips` mapping only
after uploaded assets load in the published test experience. Preserve bounded
voices, group-level mute, phrase cancellation, ambient ducking and the peak mix.
Do not stack a new full melody on the existing tier phrases.

| Entry | Art brief | Practical source specification |
| --- | --- | --- |
| Cast | Short soft rod swish, cloth/line movement; no sharp click | 0.20–0.45s, mono, no clipped transients |
| Splash | Small bobber surface impact, close droplets; not a cannon splash | 0.25–0.70s, mono, quick decay |
| Chime | Warm rounded note that remains pleasant when pitch-shifted | 0.25–0.50s, mono; test 0.7–1.45 playback speeds |
| Reel | Low mechanical spindle/line texture with no rhythmic bump | 0.6–1.2s seamless mono loop |
| Miss | Gentle falling/water motion; never a punitive alarm | 0.20–0.45s, mono, quiet tail |
| Wind | Soft waterfront air without hiss or dramatic gusts | 6–12s seamless stereo source, low mix |

Author lossless 48 kHz sources with headroom, clean starts/ends and no DC offset.
Keep masters and licensing/creator records. Obtain upload/use permissions for the
actual experience owner. Verify asset moderation, delivery, loop seams, mobile
speaker clarity and mute/unmute in a native client. A source file or plausible
numeric ID is not proof of a usable Roblox asset.

## Rod and avatar animation

`FishingPresentation` currently provides a procedural cast, flexible rod sections,
line sag, reel crank and additive R6/R15 shoulder poses. Any authored replacement
must preserve the server's `castAt`, `castDuration`, `readyAt`, `chargeAt` and
`duration` timeline rather than deciding when a reward happens.

- Cast: readable anticipation followed by forward release and settle. The bobber
  lands at `castAt + castDuration`; anticipation of a bite continues separately.
- Reeling: short seamless motion with low/high resistance blending, no abrupt
  arm snapping. The rod and line remain continuous at every sampled frame.
- Catch: small reactions for ordinary fish; heavier resolve for Crownwhale and
  broad disk fish. Movement still permits interruption and normal locomotion.
- Export and validate R6/R15 ownership/priority separately. A single uploaded
  animation should not be assumed to work on both rigs.

An AnimationTrack integration must stop/fade only tracks it owns, restore
external animation state, and disconnect on death, character replacement and
distance culling. Continue to support the procedural path when an asset fails.

## Fish meshes and materials

Preserve all 17 catalog IDs, `Shape`/model reference, color roles, weight scaling
and animation identity if native meshes replace the current fitted primitives.
Do not change save keys because an artist changes a model filename.

- Keep clean silhouettes at journal-card size and against pond water. Veilfin's
  continuous ribbon body and Eclipse's fitted crescent/asymmetric comet tail
  must remain recognizable without effects or rarity color.
- Prefer one body material and a restrained fin/accent material; do not add
  persistent dynamic lights or many transparent layers to each fish.
- Author fin/tail pivots and test them at all extremes, variants, weight scales
  and distant world coordinates. Fit the complete motion inside the existing
  aquarium glass and responsive portrait camera.
- Set a measured per-model triangle/texture budget using the chosen real baseline
  phone. Current Part limits are an automatic regression guard, not a GPU budget.

Create and license original work. Do not extract competitor meshes, textures or
audio. Native asset appearance, import scale, permissions and performance require
actual Studio/client acceptance before switching the production references.
