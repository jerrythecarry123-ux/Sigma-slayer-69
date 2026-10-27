# Known issues and validation limits

v1.8 is the current cloud-verified source/artifact checkpoint. The complete
available check suite and final targeted follow-ups passed. No further confirmed
source regression remained in the reviewed paths; the native gaps below remain
open. Do not present the offline images, event doubles or pacing study as native
playtests or evidence of commercial readiness.

## Must be checked before public release

- No Roblox Studio/native client is available in this environment. Offline
  geometry previews and event doubles do not reproduce native graphics,
  animations, input, audio, physics, streaming or frame rate.
- Real phone/iPad performance is unmeasured. The v1.8 world has 10,759 initial
  Parts; public tanks add more. The 768-stud streaming target radius may keep
  several islands resident. Profile before expanding the map.
- Material asset delivery is blocked by the network proxy here. The six presets
  reference official published Roblox maps, but actual delivery and shader
  appearance need Studio verification.
- Catch scoring uses server receipt time, not a trusted client clock. Real
  latency can shift release grading; test low and high ping with touch and
  gamepad and tune from measurements. No unverified latency compensation claim.
- Pending fish reservations survive interrupted casts within the current server
  session, but reset on rejoin. They are not persisted in saved profiles. This
  prevents simple cancel-rerolling, not every possible inference or rejoin strategy.
- Published-client DataStore persistence, session contention and disconnect
  recovery need a separate private test experience. Studio defaults to temporary
  profiles and must never be mistaken for production persistence.
- An accepted preference update changes the server profile before the ordinary
  autosave/final save. It is not a separate durable-write receipt. Leaving before
  the local debounce/request arrives or during a backend outage can lose that
  newest unsaved choice. The interface keeps pending acceptance distinct from
  the statement that preferences save with the collection.
- The consolidated checker enables UTF-8 for child tools and bounds owned
  processes. Its Windows process-tree termination is best effort and has not
  been run on native Windows. This does not affect the downloaded game's runtime.

## Scope and research limits

- Competitor pages/APIs and secondary reviews were proxy-blocked during this
  session. No current rankings, hands-on findings or player complaint trends
  were verified. See `docs/competitor-research.md`.
- No custom animation/sound asset uploads, native weather or environmental spawn
  conditions are implemented as part of this milestone. Later roadmap items must
  not be described as shipped features.
- Sound/effects settings now use optional backwards-compatible saved fields.
  Published-client rejoin and startup-silence acceptance remain unrun. Ordinary
  Studio profiles remain temporary; Roblox Reduce Motion is always independent.
