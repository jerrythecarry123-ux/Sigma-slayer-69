# Fishing loop and authority — v1.7

The fishing loop builds on the existing hold-and-release timing game. It adds a
separate cast flight, a short variable anticipation period, and modest resistance
that follows the fish selected by the server. It is not a simulated line-tension
or directional steering system. Desktop, touch and controller share the same
server rules.

## State and request protocol

`FishingService` measures the living character's distance from a valid anchored
fishing spot. The client cannot name a fishing zone or supply a target position.
The accepted spot and its water target remain bound to that attempt; moving to a
different pond cannot retarget it.

| State | Accepted action | Result |
| --- | --- | --- |
| Idle | `Start` after cooldown, within 16 studs | Reserve a server-selected fish; begin Waiting |
| Waiting | `Hold` at or after `readyAt` | Begin Reeling with a 0.3-second charge lead |
| Reeling | `Release` with the current attempt ID | Grade at server receipt time; reward once or fail |
| Waiting or Reeling | `Cancel` with the current attempt ID | Return Idle; no reward; clear skill chain |
| Any connected session | `Sync` | Return an authoritative snapshot; no reward |

Every request consumes the existing token bucket: capacity 12, refill 5/second.
Malformed and unknown actions consume it too. Attempt IDs are server-generated.
Stale IDs, another player's ID, Release without Hold and replayed Release cannot
complete a catch. A duplicate Start cannot replace an active attempt.

The server checks distance, living character and travel-busy state again on
requests and at most every 0.1 seconds through Heartbeat. Leaving, dying,
character removal, portal travel and attempt timeout abort fishing. A missed or
cancelled attempt grants no fish, coins, records, variant, goal reward or catch
count, and removes no previously collected fish or coins.

## Cast and bite timings

The server packet describes presentation without exposing the reserved fish's
name, species ID or rarity before the catch:

| Field | Meaning |
| --- | --- |
| `castAt` | Server time of the accepted Start |
| `castDuration` | 0.65 seconds of procedural cast flight |
| `readyAt` | Earliest accepted Hold and the visible bite time |
| `expiresAt` | Server timeout for the current state |
| `chargeAt` | Server-approved start of the reeling meter, after its lead time |
| `duration` | Authoritative duration for this fish's meter |
| `timingCenter` | Base target center for this attempt |
| `timingMotion` | Optional bounded target amplitude, speed and phase |
| `behavior`, `difficulty` | Generic movement tuning, not a species identity |

With current tuning, `readyAt` is:

```text
castAt + 0.8 + random(0.35, 1.05) + difficulty × 0.18
```

The resulting wait is 1.15–1.958 seconds from Start across current difficulty
bounds. The cast lands before that bite. The client first says CASTING, then
WATCH THE FLOAT, then HOLD TO REEL. Nibbles and the float's motion support that
short anticipation period. Waiting expires 12 seconds after `readyAt` if the
player does not begin reeling.

The adapter supplies the bite roll from server `Random`; tests inject bounded
rolls. Random bite pacing does not change the reserved fish or award anything.

## Resistance and grading

The first three successful catches keep difficulty zero, no moving target and
the original 2.8-second meter. Failed attempts do not consume that introduction.
Later casts use the reserved species' catalog difficulty, clamped to 0–0.6:

```text
duration = 2.8 − difficulty × 0.6
```

Current durations therefore remain between 2.44 and 2.8 seconds. After Hold,
the meter begins at `chargeAt = receiptTime + 0.3`. Reeling expires at
`chargeAt + duration`.

The base target cycles through 0.68, 0.52, 0.75, 0.60 and 0.70. Difficulty above
0.15 adds small sinusoidal motion. Its amplitude is `difficulty × 0.07`, at most
0.042 of the full track. Speed depends on behavior: Drift 2, Dart 3.1, Glide 1.6
and Surge 2.5 radians/second. The phase is `(attemptId % 7) × 0.53`.

`FishingRules.centerAt(packet, serverTime)` evaluates this expression for both
the server grade and client rendering:

```text
center = clamp(base + sin(max(0, time − chargeAt) × speed + phase) × amplitude,
               0.45, 0.79)
```

Without motion it returns the clamped base. This clamp keeps the complete Fine
region inside the catchable track. The marker moves linearly over the duration:

```text
progress = (time − chargeAt) / duration
```

The client clamps the rendered marker to 0–1. The server grades its unclamped
progress, so an early or late Release cannot become successful through visual
clamping. Normal is possible from 0.22 through 0.95. Fine spans center −0.20 to
center +0.16. Brilliant spans center ±0.07. Gold takes precedence over Fine.
All bounds are inclusive. NaN, infinite and outside-track progress fail.

The client updates the shown bands every rendered frame using the same pure
function; it never submits a grade, elapsed time, reward or selected fish. Generic
resistance tuning can make fish feel different; it is not a promise that an
untrusted client cannot infer something about the fish from those timings.

## Private candidate reservations

`FishingProgression.prepare(profile, zoneId)` selects an eligible species without
changing collection, wallet, goals, records, variant ownership or pity counters.
`FishingEngine` holds that candidate privately, keyed by pond, for this session.
The returned state and public visual packets do not contain its ID. Public
visuals also omit the private profile and wallet.

A reservation survives Cancel, a miss, timeout, moving away, fishing in another
pond, character replacement and rod upgrades. These events cannot repeatedly
reroll the pending fish. Upgrading keeps the already eligible candidate; the new
rod's expanded population becomes available for a later selection. Successfully
landing the reserved fish clears that pond's reservation.

Reservations are intentionally transient. Player removal clears them and they
are not written into the version-1 save record. A rejoin therefore selects again;
this build does not claim rejoin-proof reservation persistence. Collected fish,
coins, records, variants, display choices and goals retain their existing
lease-protected saving. No new save namespace or destructive migration is used.

On successful Release, progression validates that the internally reserved ID is
still eligible for its bound pond and rod level, then computes the existing
quality, weight, variant, rod, chain and milestone rewards. No successful reward
is selected by the client. The attempt ends immediately, and replay cannot pay
again. Direct pure progression calls used by tools/tests can omit the reserved ID
and select normally; the production engine always supplies its private choice.

## Populations and discovery protection

Catalog `Weight` is a relative selection weight, not an unconditional percentage.
Eligible species are those in the accepted pond with `Level <= profile.level`.
On an ordinary weighted selection, a species' probability is its weight divided
by the sum of eligible weights. Rod level, current pond and discovery protection
therefore change the actual probability.

The original fifteen species retain their discovery protection: while eligible
protected discoveries remain, the first three successful catches teach unseen
species, and two consecutive duplicates in that pond make the next selection an
eligible protected discovery. Pond counters survive fishing elsewhere. Preparing
or failing to land a fish does not advance the counter. Existing beginner
collection and milestone rewards remain intact.

The new Mythical Veilfin and Secret Eclipse have `DiscoveryProtection = false`.
They can be selected by their real relative weights after the Aurora Rod is
unlocked, and are never forced by the original three-catch protection. This keeps
exceptional discoveries distinct without weakening the established introduction.
They require earned gameplay progress, not a paid random roll.

For a fully upgraded rod after the protected population has been discovered:

| Pond | Exceptional species | Relative weight / pool | Weighted probability |
| --- | --- | --- | --- |
| Evergreen Reach | Veilfin, Mythical | 2 / (43 + 28 + 11 + 2) | About 2.38% |
| Starfall Lookout | Eclipse, Secret | 1 / (47 + 7 + 3 + 1) | About 1.72% |

These are selection probabilities, not claims about catch success, session length
or guaranteed waiting time. The existing Golden and Prismatic appearances remain
separate rolls after a successful catch; no rarity grants a guaranteed variant.

## Verification and native acceptance risks

The standalone tests execute the real engine, rules, progression and save
transitions. They cover beginner protection, moving-band agreement, safe target
bounds, seeded bite bounds, single rewards, invalid reservations, top-tier pity
exclusion and migration of an already completed old journal. The actual-service
event-double check also verifies the network packet projection, late-client cast
sync, shared resistance fields and aborts for movement, travel, character removal,
death and departure.

```text
/path/to/luau tests/fishing_engine.spec.luau
/path/to/luau tests/fishing_locations.spec.luau
/path/to/luau tests/fishing_progression.spec.luau
python tools/check_fishing_service.py --luau /path/to/luau
```

These checks do not simulate Roblox transport latency. Release is graded at
server receipt time; a high-ping player can see the marker closer to gold than the
server grade. No client timestamp is trusted and no untested lag-compensation
claim is made. Before a public release, test the real client on desktop, phone and
iPad with low and high ping, including touch release outside the button, a release
before Hold acknowledgement, focus loss, respawn, portal travel and a timeout.
Verify visible bands match the received grade and adjust only through a bounded,
tested latency policy if that evidence requires it.

Native sound timing, real controller focus, Roblox camera behavior, animations,
replication and phone frame rate still need Studio/client testing. Passing pure
math and event doubles is not a native playtest or a retention result.
