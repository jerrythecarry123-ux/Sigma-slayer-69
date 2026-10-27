# Cast strength and accuracy — v1.8 implementation

The cast adds an optional skill beat to the existing one-button fishing loop.
A normal quick tap remains valid. Holding and releasing near the marked target
can improve cast accuracy; no cast grade changes fish odds, eligible species,
discovery protection, variant odds or reeling grade.

## State and authority

| State/action | Server behavior |
| --- | --- |
| Idle + `BeginCast` | Validate the same living-character/proximity/travel context as fishing, allocate one attempt ID, bind that pond, enter `ChargingCast`. No species is selected and no reward is granted. |
| ChargingCast + numeric-ID `Cast` | Compute power from server receipt time and launch the cast with that attempt ID. Only now reserve a fish using the existing per-pond cache. |
| ChargingCast + numeric-ID `QuickCast` | Launch power 0.65, Clean grade and zero accuracy bonus. This is a convenience choice, not a client-supplied power or grade. |
| ChargingCast timeout | At 2.2 seconds, launch the same plain 0.65 cast; a held or lost release cannot leave the player stuck. |
| ChargingCast + numeric-ID `Cancel` | Cancel without rolling a fish, including when the explicit cancellation arrives just after the automatic-launch deadline. |
| Waiting/Reeling | Existing bite, Hold, receipt-time Release, movement/death checks, cooldown and single reward rules continue. |

Legacy `Start` remains an immediate plain cast for existing tools/adapter callers.
The updated client uses `BeginCast` followed by `Cast` or `QuickCast`. Extra
client timestamps, power, grade or reward fields are not accepted: the release
argument is the server-approved numeric attempt ID.

One rejected/replayed release cannot replace an active cast, alter its power or
change its target. The normal all-request token bucket also covers these actions.
The current server snapshot exposes only generic timing/behavior; the reserved
species ID is still private until a successful catch.

## Shared timing and grades

Packets contain `castChargeAt` and `castChargeDuration` (1.0 second). The client
draws `FishingRules.castProgressAt(packet, serverTime)`. On an actual `Cast`, the
server evaluates the same linear receipt-time expression, clamped to 0–1:

```text
power = clamp((receiptTime − castChargeAt) / castChargeDuration, 0, 1)
```

| Power | Cast grade | Earned-fish coin bonus |
| --- | --- | --- |
| 0.72–0.88 inclusive | Perfect | 10% |
| 0.52–0.95 inclusive, outside Perfect | Precise | 5% |
| Other power | Clean | 0% |

`QuickCast`, automatic timeout and legacy `Start` deliberately remain Clean even
though their convenient standard power is 0.65. Choosing the convenience mode
therefore never obtains an accuracy bonus. A client can safely request it after
a short local tap and a delayed BeginCast acknowledgement: network round-trip
time does not turn that convenience request into an accidental high-grade cast.

After launch, `castAt` is the launch receipt time, `castDuration` remains 0.65
seconds and `readyAt` is the separate bite time. The existing random anticipation
is shortened by 0.05/0.10 seconds for Precise/Perfect respectively. The first
three successful catches still retain the existing static, forgiving reeling
target; an accuracy miss never makes a fish impossible to catch.

Real release transit still affects receipt-time power and reel scoring. Pure
rules and transport doubles cannot establish input fairness at real ping. The
native device/latency acceptance matrix remains mandatory; there is no trusted
client timestamp or unverified lag compensation.

## Bounded water destination

The adapter captures the accepted fishing spot's horizontal forward direction
when binding the location. Power offsets the existing lane's depth through
`FishingRules.castDepthFor(power)`:

```text
depth = clamp(14 + (power − 0.65) × 4, 12, 15.4)
target = authored14StudTarget + capturedHorizontalForward × (depth − 14)
```

The lane side coordinate and water height remain authored. Standard power 0.65
retains the exact old 14-stud target. The client never submits a destination or
pond ID. Finished results and Idle Sync retain the actual launched depth instead
of snapping back to the default target. Expanded world checks must establish
water support and clearance for every allowed target, not merely the old center.

## Payout and persistence

Only a successful server-authorized catch can receive the accuracy bonus:

```text
fishCoins = floor(baseValue × rodMultiplier × reelGrade × variant × sizeFactor)
castBonus = floor(fishCoins × accuracyPercent / 100)
coins = fishCoins + chainBonus + castBonus
```

It does not multiply chains or milestone rewards. Whole-coin rounding may make
a small bonus zero on a low-value fish. `result.castBonus` is already included
in `result.coins`; an interface must not add it a second time. The result also
includes `castGrade`, `castPower` and `castBonusPercent` for explanation.

The wallet remains capped at one billion. Catch, goal, chain and cast summaries
now report the amounts actually credited at that cap, avoiding a prior mismatch
between the visible reward and wallet delta. The collection/record can still
improve when no additional currency fits.

Cast metadata is transient attempt state. No new save fields, save namespace,
currencies, unlock requirements or reordered milestones are introduced.

## Response routing and verification

Command responses include `replyTo` for the requesting client, allowing the input
controller to distinguish a BeginCast response from an unrelated passive Idle
location update. Public fishing visual packets omit this hint along with private
profile and wallet fields. This is response routing, never reward authority.

### Independent settings writes

The sound and reduced-effects toggles take effect locally and save through a
separate debounced `Preferences` request. That request carries exactly the two
boolean preferences and a third, positive integer write ID. The server echoes
the ID as private `preferenceRequestId`; public fishing visuals never receive
settings or this correlation ID. Legacy two-argument callers remain valid.

Settings never occupy the controller's gameplay request latch. An accepted
settings acknowledgement updates the private profile and returns before cast
input or presentation transitions run. Only the acknowledgement for the current
write may release its timer, and it settles the choice only when the accepted
values still match the latest local choice. An ordinary profile with matching
values or a timed-out older write cannot complete a newer opposite write. A
three-second timeout permits a later retry without blocking fishing. The engine
accepts writes while Idle; its defensive active-cast rejection does not tick,
launch, reroll or reward that cast.

`tools/check_fishing_flow.py` executes the production server, rules, controller,
interfaces, audio, fish/rod presentation and cinematic code through queued remote
transport. Its 14 scenarios use 58 actual RPC requests and 62 delivered private
states. They include settings replies crossing an early cast release, a real
passive location snapshot crossing an opposite settings write, and an older
five-second acknowledgement crossing a newer opposite write. The delayed-reply
cases preserve server response order. A deliberate mutation that treats any
settings reply as the current write fails the integrated regression scenario.
Only native services/Instances/transport, world scenery and island travel are
doubled or excluded here; their separate checks do not replace native playtests.

Production-code checks cover charging acceptance, convenience taps with delayed
acknowledgement, numeric-ID validation, forged metadata, duplicate/stale casts,
timeout/movement/death/cancellation, location binding, actual target depth,
private/public metadata, bounded rewards, accurate cap summaries and 6,000 mixed
three-player actions. Tests use pure rules and event/geometry doubles. Native
Roblox input, transport, audio, water rendering and device performance remain
outside those checks.
