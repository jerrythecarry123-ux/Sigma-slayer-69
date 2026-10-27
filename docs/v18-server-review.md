# v1.8 server and persistence review

Reviewed 26 October 2026 against the v1.7 starting point (`65d426d`) and the
integrated v1.8 casting work. This is a source/behavior review with standalone
Luau and deterministic event/DataStore doubles. No native Roblox DataStore,
transport, shutdown or request-budget acceptance is claimed.

## Confirmed defects fixed

### Departure snapshot could be discarded after a slow autosave

The former `FishingService.release` waited at most 20 seconds for `session.busy`,
then attempted one final save. When the in-flight autosave remained busy, that
save correctly returned `busy`; the service nevertheless abandoned its newer
departure snapshot. The older autosave could finish afterward with no owner left
to save the player's latest actions.

The release worker now retains that snapshot until the existing save finishes,
retries a transient `busy` response and checks whether another owned release
already closed the session. An adapter exception also clears the service's
pending-release count through a protected call. The existing, independent
25-second `BindToClose` budget remains: the worker no longer imposes a separate
20-second deadline on ordinary departures.

The regression executes the actual service, engine, progression and profile
store. A 30-second yielding autosave holds an older one-catch snapshot while the
player earns a second catch and leaves. More than 21 seconds after departure,
the final worker still owns the latest snapshot; when the autosave returns, the
record contains both catches, the correct balance and a released lease. Restoring
the former 20-second helper deliberately fails this regression.

### Committed final saves could be reported as a lost lease after response loss

`UpdateAsync` can commit a final save that clears its lease and then fail to
deliver the response. Previously, the retry saw an unlocked record, returned
`lost_lease` and could not acknowledge its own completed write.

Each final `FishingProfileStore.save` call now allocates one GUID before its
retry loop. The released version-1 record may contain:

```text
releaseReceipt = { leaseId = the existing session GUID,
                   operationId = this final-save operation GUID }
```

Only an unlocked record with both matching identities acknowledges that same
operation. The acknowledgement copies the already committed profile and original
commit timestamp; it never rewrites them from a stale caller snapshot. A new
acquisition clears the receipt. A different operation, former owner or currently
active replacement lease cannot use it to overwrite progress.

This is optional metadata on the existing version-1 record. Production remains
`CloudAnglers_Player_v03`, Studio remains `CloudAnglers_Test_v03`, and player keys,
existing profile fields, IDs, balances, milestones and save version remain
compatible. Optional preference fields are described below. Legacy
records with no receipt remain valid. Malformed receipts, non-GUID operations or
receipts attached to active leases are rejected rather than replaced by defaults.

### Preparation exceptions could permanently retain save ownership

The store set `session.busy = true` before copying a snapshot and allocating a
release identity. An exception in either preparation step could leave the session
busy even though no request reached the backend. Snapshot-copy failures now return
`invalid_data`; identity-allocation failures return `unavailable`. Both clear busy
ownership. Load identity failures also return normally so the service can clear
its loading state and follow its existing safe rejection path.

## Player preferences use the existing save path

Profiles may now contain `preferences = { soundEnabled: boolean,
reducedEffects: boolean }`. New players and legacy records default to sound on
and normal effects. Copies, snapshots and migrated profiles receive independent
tables; changing a client-facing snapshot cannot change the server profile.

The `Preferences` action accepts exactly those two raw boolean keys while Idle.
It uses the existing rate limit and inspects at most three table keys, including
when the caller supplies thousands of unknown fields. Active charging, waiting
and reeling attempts reject the action before calling the timing state machine;
settings cannot accidentally launch, cancel, reroll or reward a cast. The
acceptance packet contains `preferencesChanged = true`, not a purchase/reward,
and public fishing visuals contain no preferences or private profile.

A client may also send a separate numeric `preferenceRequestId` argument for
private response correlation. The service echoes it only on `Preferences`
responses when it is an integer in 1–2,147,483,647. It has no effect on validation,
rewards, rate limits or saving. Missing/invalid correlation values keep legacy
preference requests compatible without echoing unvalidated data. Other commands
and public visuals never carry it. This lets the client distinguish current
acceptances from old replies while preserving newer local choices.

Acceptance changes the authoritative in-memory profile. It does **not** certify
that DataStoreService has durably saved the change at that instant. The existing
autosave and final-save pipeline persists it; temporary Studio profiles remain
temporary. Native Roblox persistence still needs published-client verification.

Save validation accepts legacy absence but rejects partial, extra or wrongly
typed preference fields. The store validates the incoming profile before its
whitelist copy, so malformed optional fields cannot disappear into valid defaults
and accidentally pass a subsequent save. Release-response retries retain the
committed preference table instead of replaying stale caller defaults.

## Casting integration

`FishingLocations.acceptStart` now accepts an approved new `ChargingCast` attempt
as well as legacy `Waiting`. It requires a positive integer attempt ID and retains
the existing non-rebinding guard. Launching a charged cast, retrying BeginCast or
moving toward another spot cannot replace the server-selected location while
the same attempt is active. This extends the adapter contract without trusting a
client-selected pond or water position.

## Verification actually executed

- `tests/fishing_saves.spec.luau`: **9** release-transition cases, including lost
  responses, stale snapshots, unrelated operation IDs, replacement ownership,
  offline-award timing/idempotence, corrupt metadata and legacy records.
- `tools/check_profile_store.py`: **20** cases running the actual store module
  with actual progression/save rules. Covers production/Studio isolation,
  transport and callback retries, expiring/live leases, one detached snapshot,
  loss of ownership, release receipts, exhausted responses, preparation faults,
  persisted preferences and bounded request validation.
- `tools/check_save_lifecycle.py`: **10** cases running the actual service/store
  together. Covers clean/double departures, slow autosaves, transient busy,
  unavailable backend, adapter exceptions, shutdown deadline, loading/departure
  and loading/shutdown races, preference departure/rejoin and a new owner during
  a stalled old save. Includes
  the deliberate old-helper mutation described above.
- `tests/fishing_locations.spec.luau`: **14** cases, including the two new
  charging/malformed-binding cases.
- `tests/fishing_preferences.spec.luau`: **10** state/migration cases covering
  defaults, legacy records, detached copies, malformed requests/records,
  player isolation, phase rejection, rate limits and release-retry preferences.
- `tools/check_fishing_service.py` additionally covers private preference
  acknowledgement, active-cast rejection, independent joining-player defaults,
  correlation-ID boundaries, malformed/legacy nonces and public privacy.
- Changed pure save/location modules pass standalone Luau analysis. The changed
  production service/store modules compile; standalone compilation does not prove
  native API execution or runtime behavior.

The additional adapter checks are separate from the existing core progression
tests. Their numbered counts do not turn source samples into native playtests.

## Preserved safeguards and remaining limits

The audit found no additional confirmed duplication or client-reward exploit in
the reviewed save/location/travel paths. Attempt IDs, leases, server-chosen travel
targets, living-character/source checks and late streaming identity checks remain.
The slow-save replacement-owner case proves that an old autosave and its eventual
release cannot overwrite a newer owner through the atomic transition rules.

An outage that loses every response remains ambiguous to the old server: the
store reports `unavailable`, even if the backend committed. The receipt leaves a
valid unlocked record that a later server can acquire without paying or applying
the final profile twice. The code does not invent a successful acknowledgement.

If every response to an initial acquisition is lost, an owned 120-second lease
can remain even though the joining server could not finish loading. Another
server deliberately cannot steal that live lease; it can recover after expiry.
The actual adapter test covers this temporary rejoin restriction and proves the
new session keeps the stored profile rather than replacing it with defaults.

No implementation can guarantee the newest unsaved actions survive an unavailable
backend or native process termination before its close deadline. Final-save
`lastSeen` is a server commit timestamp, not a client-supplied activity timestamp.
Validate rapid rejoin, live concurrent servers, platform retries/budgets, backend
outages and shutdown termination in a separate private published experience.
Native testing remains required before public release.
