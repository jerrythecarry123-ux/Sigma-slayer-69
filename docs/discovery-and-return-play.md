# v0.3 — discovery, first-session goals and return play

## Sources and limits

The supplied video is https://www.youtube.com/watch?v=e4o-ECkzDoI.
YouTube and its oEmbed endpoint returned a network-policy 403 in this environment.
The video was not watched or transcribed. The user supplied its relevant takeaway:
add a reason to return, for example earning money offline.

Roblox's official discovery documentation was read from its creator-docs source:
https://create.roblox.com/docs/discovery
https://github.com/Roblox/creator-docs/blob/main/content/en-us/discovery.md

It describes play-through rate, first-play bounce, play days, playtime and
intentional co-play among recommendation signals. Signals change, relate to
acquisition cohorts and do not provide a guaranteed formula for distribution.
No live analytics for Cloud Anglers were accessed, and no retention improvement
has been measured yet.

## Changes to test

- Early clarity: visible path to the dock, one cast action, first-catch goal.
- Variety: the first three successful catches introduce three different species.
- A next action: a field journal, five goals, visible prices and three rod upgrades.
- Personal mastery: best quality per species; collection points cap at 18.
- Unlocks: Breeze Rod adds two rare species; Nimbus Rod adds one epic species.
- Bounded discovery: at most two duplicates while unlocked undiscovered species remain.
- Return play: discovered species generate server-calculated offline coins.
- Social visibility: public catches and the collection leaderboard; balances stay private.
- Feedback: distinct interface, meter, discovery, upgrade, goal and return sounds.

There are no paid random rewards or loss of a daily streak. Content is still
small; finishing six species is a natural endpoint rather than endless content.

## Offline income and saving

Each discovered species earns 0.25 coins/minute while the player is away.
Elapsed time caps at eight hours and the award caps at 120 coins per return.
No discovered species means no offline income. Earnings are credited atomically
on load and displayed as a welcome-back summary, without a second claim action.

Saved fields: coins, rod level, catch count, Brilliant catch count, goal position,
best quality per species and duplicate-discovery counter. Active casts are not saved.

The production store is `CloudAnglers_Player_v03`; opt-in Studio saves use
`CloudAnglers_Test_v03`. Keep this namespace/schema compatible in future updates
or implement an explicit migration; do not simply change it for each release.

UpdateAsync owns a 120-second lease. Autosaves run every 30 seconds, with bounded
request retries, disconnect saves and a shutdown deadline. A different active
lease blocks loading. Invalid/newer records block play rather than being replaced
by a fresh profile. An expired/lost session stops accepting actions. After a crash,
offline credit begins after the stale lease expires to avoid overlapping sessions.

Pure transition tests cover retries, duplicate credit, ownership, corruption and
caps. Actual Roblox DataStore behavior and network failures still need private
published-experience tests; the cloud runner cannot execute Roblox services.

## Private Roblox test for return income

1. Open the v0.3 place and publish it as a separate private test experience.
2. Keep `EnableSaving = true`. Join through the Roblox client, not Studio Play.
3. Catch at least one fish, note coins and collection, then leave normally.
4. Wait five minutes and rejoin. One species should earn one coin in that interval;
   more species earn proportionally more. Verify existing upgrades/grades remain.
5. Rejoin immediately again: do not receive the same offline reward twice.
6. Test data failures and simultaneous sessions with appropriate Studio/server tools
   before public release. Do not deliberately corrupt live player data.

Studio Play defaults to temporary profiles (`SaveInStudio = false`), so the file
opens without publishing or enabling APIs. To test Studio saving, first publish a
private test place, enable Studio API access for that test experience and opt into
`SaveInStudio = true`. Its test store is separate from the Roblox-client store.

## First playtest measurements

Observe new testers without instructions: time to first cast/catch, early exits,
understanding of the next goal, time to first upgrade and whether a player wants
another trip. Also test touch readability and whether effects obscure the meter.
Then inspect real Creator Analytics for return behavior after private/public
playtests; do not infer retention from a longer tutorial or more reward popups.
