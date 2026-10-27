# v1.8 progression and returning-player review

This review follows the production catalog, progression, fishing engine, save
rules, service and English interface. It uses the actual Luau modules with
deterministic inputs. It does not measure human enjoyment, session length,
retention, spending or native Roblox execution.

## Corrected next-step guidance

The old guidance checked a Fine/Brilliant chain before an affordable rod. A
player who kept catching well could therefore see `KEEP THE RHYTHM` indefinitely
while an earned equipment upgrade was ready. The interface now prioritizes the
ready rod after the first-fish aquarium introduction. Chain feedback remains
when another rod is not affordable. Fishing rewards, costs and streak rules are
unchanged.

The terminal state also needed a distinct instruction. With all 17 species
discovered and the final rod equipped, the old local-pond completion message
still asked the player to try another portal. The current message is
`JOURNAL COMPLETE · SHOW YOUR FINEST FISH`. Weight records, catch grades,
variants and aquarium presentation remain available after journal completion.

A completed local pond now also takes priority over chain encouragement. A
three-Fine-catch harbor profile receives the portal instruction instead of being
encouraged to stay indefinitely in the completed starter pond. Chains still
appear in an incomplete pond. This follows the routing sensitivity identified
by the pacing study, without changing rewards, odds or adding automated travel.

`tools/check_fishing_interface.py` follows two actual Fine harbor catches through
production progression into the first affordable rod, then makes that purchase
and verifies that chain feedback returns. It also checks available upgrades at
the wallet cap and the completed 17-species state. Restoring the old chain-first
ordering in the generated check program fails the earned-upgrade assertion.
That deliberate regression never changes the production source file.

## Existing progression contracts retained

- All five islands are free to visit, with at least one starter-rod species in
  each pond. The server-selected pond and saved rod level restrict eligibility.
- The first three successful catches teach eligible unseen protected species.
  Original species retain bounded per-pond duplicate protection. Mythical and
  Secret fish use eligible relative spawn weights and are not forced by that
  protection. Abandoning a cast does not earn a discovery.
- Earned rods retain costs of 32, 90 and 160 coins, their existing 15%, 30% and
  45% fish-value bonuses and their original unlocks. The v1.8 timing widths are
  derived from the existing saved level; they need no new saved equipment field.
- Fish, chain, cast and milestone payments report actual paid whole coins at the
  one-billion coin ceiling. Cast accuracy does not multiply chain or goal income.
- Better grades replace a species' collection score rather than accumulating
  unlimited leaderboard points. Weight records only improve. The three aquarium
  slots require discovered fish; cosmetic styles charge once and add no fishing
  power.
- The original ten goal positions, targets and rewards remain stable. The final
  17-species goal is appended, so a completed older journal does not repay old
  milestones. Milestones already achieved before they become the visible goal
  are resolved in order.

## Offline income and honest presentation

Published play calculates income on the server when acquiring the saved profile:

`min(120, remaining wallet capacity, floor(awayMinutes × discoveredSpecies × 0.25))`

The elapsed period is capped at eight hours. A clean departure uses its final
saved activity time. Recovery after an expired lease starts after that lease's
expiry, avoiding income for time that could still belong to another active
server. The same acquisition identity retains the committed award when a lost
response is retried; it does not pay a second time.

The workshop shows the server-provided rate and cap. The welcome summary reports
the actual award, not projected earnings. A fresh profile and a profile with no
discoveries earn no fictional gift. Studio's default temporary profiles explicitly
say offline earnings require the published game. This is a modest return gift;
there is no missed-day penalty, paid boost, compulsory return schedule or claim
of proven retention improvement.

## Verification and remaining native checks

An additional [pacing study](v18-pacing-study.md) exercises 2,000 fresh simulated
profiles through the actual progression module. Under its explicit hypothetical
grade/purchase policies, rod medians are 3/6/13 successful catches, while the
final journal depends strongly on visiting the correct remaining habitats.
Targeted and rotating policies have full-journal medians of 101 and 330
successful catches respectively. These are neither human playtime nor observed
retention. No weights, prices or protection rules changed in response to the
study; native next-goal/habitat comprehension is the next observation priority.

The independent review ran all 40 progression/save tests, 10 preference migration
and state tests, and nine final-save transition tests. The production interface
check passed its progression guidance assertions together with 4,998 existing
journal/catch portrait poses and 1,107,792 projected corners. The changed interface
compiles with the official Luau compiler, and `git diff --check` is clean.

These checks establish logic, compatibility and generated geometry. They do not
establish real Roblox DataStore availability, native text wrapping, the feel of
the upgrade pace, mobile input comfort, or player interest. Those still need a
private published-client playtest and observation of actual players. No real
money purchase flow is implemented or inferred by this review.
