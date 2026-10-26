# Known issues and validation limits

## Must be checked before public release

- No Roblox Studio/native client is available in this environment. Offline
  geometry previews and event doubles do not reproduce native graphics,
  animations, input, audio, physics, streaming or frame rate.
- Real phone/iPad performance is unmeasured. The v1.6 world has 10,806 initial
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

## Scope and research limits

- Competitor pages/APIs and secondary reviews were proxy-blocked during this
  session. No current rankings, hands-on findings or player complaint trends
  were verified. See `docs/competitor-research.md`.
- No custom animation/sound asset uploads, native weather or environmental spawn
  conditions are implemented as part of this milestone. Later roadmap items must
  not be described as shipped features.
- Session sound/effects settings are local to the current session, not saved
  profile fields. Rejoining returns local preferences to their defaults while
  still respecting Roblox Reduce Motion.
