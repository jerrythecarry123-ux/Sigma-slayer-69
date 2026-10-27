# v1.8 interface review and validation

Reviewed against the v1.7 checkpoint and the current v1.8 working sources on
26 October 2026. This review covers the actual fishing/journal/workshop and
aquarium interfaces. Roblox Studio and the native client are unavailable here;
no native rendering, font, touch or device-performance result is claimed.

## Confirmed problems corrected

| Starting behavior | Implemented correction |
| --- | --- |
| Journal, catch and aquarium portraits use fixed cameras even for long or asymmetric fish. | Capture the generated model's padded bounds after its appearance is applied, then fit its actual pivot and viewport aspect. The camera updates only when pivot or viewport size changes. Catch portraits now receive the real caught weight. |
| Compact aquarium slots, tabs and visit controls are only 34/32/36 pixels high. | All remain at least 44 pixels high. The 320×240 layout also retains one complete list row, rather than making a large button mostly invisible. |
| Compact journal cards are taller than the visible gallery. | Short screens use complete 80-pixel horizontal cards. A separate details footer is hidden only on very short canvases; name, rarity and record/rod information remain in each row. |
| The 320×240 main card overlaps both navigation buttons and the upper HUD. | A 96-pixel idle card and 140-pixel active card fit separately. Secondary navigation hides during the brief active phase, while Settings remains a visible interruption path. Hidden navigation cannot retain gamepad focus. |
| Narrow result cards scale a large desktop layout into tiny controls. | The exceptionally short/narrow canvas uses its own 296×212 card with 44-pixel actions, an 88-pixel portrait and real text. Existing portrait and wider-landscape compositions remain separate. |
| White skill needles disappear against the gold and green timing bands. | Both cast and reel needles have an Ink outline, retaining a bright core against the dark track and a dark edge against light targets. |
| Long locked aquarium hints wrap into clipped second lines. | Single-line hints explicitly truncate; full habitat/equipment information remains available in the journal. Selected journal details no longer repeat a long habitat/flavor string inside a two-line box. |
| Aquarium motion ignores the reduced-effects preference. | Menu portraits and nearby world-tank decorative motion stop at a stable pose. Normal motion resumes after the preference is disabled. |
| Aquarium focus depends on any connected gamepad, including a touch device currently using touch. | Initial gamepad focus follows `PreferredInput`; closing restores a previous selection only while the aquarium owns focus. |
| A changed profile can leave slot 3 selected when only slot 2 is available. | Selection clamps to the available slots. Loading slots and gallery visits are disabled and focus returns to a visible control. |
| Portrait caching ignores a change in ownership while ID/weight/appearance stay the same. | The cache signature includes ownership validity. A newly invalid portrait is removed, and a newly valid one is rebuilt. Invalid IDs do not display a fallback fish name. |
| The aquarium rewrites its static layout every render frame, including while closed, and animates portraits hidden by the compact layout. | Static layout follows effective canvas changes and opening. Closed menus skip layout and portrait work; compact hidden portraits skip model animation. Visit/loading text still follows profile changes without resizing. |

## Casting and equipment integration

`setState("ChargingCast")` presents a separate **CastTrack**, rather than reusing
the reeling grades. `ui.setCastProgress(power)` clamps the shown needle to the
server's 0–1 power range. Precise and Perfect bands use the shared rule constants.
Reeling retains `setTimingWindow(center, width)` and its independent timing track.

The catch receipt labels a positive cast bonus as **included** in the shown coins;
it never adds that amount to the total again. The workshop explains the actual
earned rod benefit: a gold window approximately 11%, 23% or 34% wider than the
starter window. The displayed percentage derives from the snapshot's timing
width and remains separate from coin bonuses and rod unlock descriptions.

The modal books, settings, receipts and aquarium use native selection groups with
Stop behavior, so directional selection does not escape into the world HUD.
The existing Escape/ButtonB dismissal and owned-focus restoration remain.

## Aquarium work while hidden or unchanged

The aquarium's layout and portrait animation now have separate responsibilities.
The layout uses the ScreenGui's actual canvas, with the controller's most recent
inset-safe dimensions as a fallback while native dimensions are zero. Opening
applies the current canvas immediately, including a rotation while the menu was
closed. Static sizes, positions, visibility and label formatting are only written
when the effective canvas changes. A separate Visit-text helper handles profile
arrival/loss, so caching does not leave a loading message or the wrong compact
label after a profile update at unchanged dimensions.

The checker counts attempted assignments, including equal-value writes, rather
than treating native property-change notifications as a work counter. Over each
120-call probe at stable dimensions, the current code performs **zero repeated
static layout writes**. The previous layout issued 31 such assignments per call,
or 3,720 over an equivalent probe. A full open menu retains its **360 fish
animation calls** across the three visible portraits. Compact hidden portraits
and closed menus perform **zero**. After a reduced-effects pose is established,
another 120 calls make no fish-animation calls; normal motion resumes when that
preference is disabled. The existing 20 Hz nearby world-tank loop is unchanged.

These are production-code operation counts using geometry/event doubles, not a
claim about measured Roblox frame rate, rendering cost or device battery life.

## Preference status integration

The existing `settingsChanged` callback still returns exactly the two local
booleans, `soundEnabled` and `reducedEffects`. It does not send presentation status
or Roblox's system preference back as profile data. The controller can pass
`persistent` and `savePending` into `ui.setPreferences` alongside those values.

The footer distinguishes a loading collection, temporary Studio choices, a pending
server update and preferences that save with the published collection. Roblox
Reduce Motion remains an independent explanation above that status. Local toggles
preserve the persistence metadata while the debounced request is outstanding.

The server acknowledgement confirms authoritative profile acceptance; it is not
an immediate durable-write receipt. Consequently the interface says **Preferences
save with your collection**, rather than prematurely claiming that a save has
already completed. The ordinary autosave/final-save pipeline handles persistence.
These loading/Studio/pending/accepted/OS-combination states and the two-field
callback contract are exercised by the production fishing-interface checker.

## Readability and geometry evidence

The palette is retained. Calculated standard sRGB contrast ratios are:

- Muted text on Panel: **5.14:1**; Muted on Soft: **4.68:1**.
- Teal on Panel: **5.12:1**; Teal on Soft: **4.65:1**.
- The old white needle against Gold: **1.69:1**. Its new dark edge against Gold:
  approximately **6.71:1**.

The location card is opaque so its small text does not depend on the world behind
it. Rarity names and ranks remain readable words, not color-only information.
These calculations do not reproduce Roblox font rasterization or text preferences.

Production checks exercise seven fishing-interface canvases: 320×240, 320×530,
375×625, 568×280, 844×335, 768×964 and 1920×1040. The aquarium additionally retains
its six-canvas matrix, including 320×240. Actual generated model Part corners
are projected through their actual UI cameras after animation, rather than merely
checking that camera values are finite.

## Commands and results

```text
python tools/check_fishing_interface.py --luau /path/to/luau
luau tests/interface_layout.spec.luau
python tools/check_aquarium.py --luau /path/to/luau
```

Verified on the current fish source after the final hinge/detail work:

- **4,998 journal/catch portrait poses**, **1,107,792 projected Part corners**;
  all 17 species, caught weight/appearance, seven canvases and complete animation
  samples. Cast/reel band separation, earned rod widths, included cast bonuses,
  contrast, modal exclusion, settings and owned focus checks also pass.
- **8 layout cases** pass, including complete compact journal rows and the
  exceptionally short/narrow active/idle/result compositions.
- **2,448 aquarium-menu poses**, **542,592 projected Part corners**;
  maximum weights, all 17 species and all three slots. Physical touch targets,
  profile/ownership cache changes, loading, active-input focus and reduced menu/
  world motion checks pass.
- Existing aquarium guards still pass: **3,111 full tank poses** and **658 actual
  arrival/promenade collider samples**, independent ownership, themes, streaming
  recovery and departure cleanup.
- All four changed production UI modules compile; whitespace checks pass.

The geometry doubles pin requested model pivots exactly. Without this correction,
repeated raw matrix inverses in the inspection shim amplify floating-point error;
that is a limitation of the double rather than evidence of a native Roblox defect.
Native APIs for model bounds, viewport cameras and selection groups were checked
against the current public API metadata and have ordinary script access.

## Native acceptance still required

Run the interface in Studio and a published private client on Windows, a phone
and iPad. Check actual Gotham text metrics, larger Roblox text preferences,
safe-area/inset behavior, device rotation, scroll selection, thumb reach, input
switching, real asset rendering and frame time. Inspect the abbreviated labels
on 320×240 separately; the automatic checks establish bounds and state ownership,
not that a child finds the interface comfortable or beautiful.
