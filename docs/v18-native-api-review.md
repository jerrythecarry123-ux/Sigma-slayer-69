# v1.8 native API review

Reviewed the 36 production Luau sources in the working tree on 2026-10-26. This review found no confirmed missing native member, prohibited runtime setter or non-creatable class in the inspected paths. It found one authored audio value outside the documented range: `CompressorSoundEffect.Attack = 0.02`. That value is now `0.1`, matching the documented minimum and the value the native engine would clamp to. This is an authoring correction, not evidence of an audible improvement.

## Evidence and provenance

The supplied `/tmp/cloud-anglers-current-api.json` contains 938 classes and 651 enums. Its SHA-256 is `0c956ff6959637dd0b89002aa44aa1f1fb94de1f518c9dc8f5c29076492aec61`. The origin and engine build of that existing snapshot were not preserved. Its top-level `Version = 1` describes the dump schema; it does not identify a Roblox release.

Fresh requests to both official version endpoints failed with `Tunnel connection failed: 403 Forbidden`:

- `https://setup.rbxcdn.com/versionQTStudio`
- `https://clientsettingscdn.roblox.com/v2/client-version/WindowsStudio64/channel/LIVE`

Consequently, this review cannot certify that the reflection snapshot exactly matches today's installed Roblox engine. It also independently fetched 36 files from the official [Roblox creator-docs repository](https://github.com/Roblox/creator-docs/tree/main/content/en-us/reference/engine), using the raw `main/content/en-us/reference/engine/classes/{Class}.yaml` and `datatypes/{Datatype}.yaml` metadata. These provide independent documentation for the specific high-risk APIs below. Retrieved document hashes and the reflected-member inventory are saved in the temporary evidence files listed below.

## Checks performed

| Check | Result and scope |
| --- | --- |
| Runtime property writes | Instrumented the existing Instance doubles while running unchanged production sources. Recorded 1,369 distinct source-line/class/property writes, representing 309 actual class/property pairs across all 23 modules that wrote Instance properties in these runs. Every recorded setter exists on the class or its ancestors, is a Property, has public write security, lacks `ReadOnly`/`NotScriptable`, and requires no `PluginOrOpenCloud` write capability. |
| Runtime construction | Recorded 119 production construction sites, covering all 39 literal Instance classes used by the source. Each reflected class is creatable. Fixture-created services and fake test fields were excluded by the immediate caller's production-source line. |
| Reads, methods and events | Reviewed 132 explicit native class/member pairs across 31 classes, resolving inherited members. No protected read/call or missing member was found in that inventory. Native arguments and every possible dynamic receiver were not exhaustively proven. |
| Datatypes and enum names | Checked 31 used datatype constructor/method names against official documentation and all 63 distinct literal Enum constants across all 36 source files against the reflection snapshot. No missing names were found. |
| Place serialization | Built a temporary place with the actual builder. All 51 serialized Instances and their property fields resolve to loadable reflected properties. All 16 serialized enum tokens resolve to the intended enum items. Privileged serialized fields were checked separately from ordinary runtime writers. |
| Native terrain preconditions | Inspected the production `WriteVoxels` arrays and freshly captured layout. All five regions use resolution 4, grid-aligned bounds, matching positive integer dimensions, Water/Air materials and 1/0 occupancies. Their sizes are 1,116 / 702 / 702 / 675 / 676 voxels, below the documented 4,194,304-voxel limit. |

The write traces came from production world generation with three preview gallery occupants, generated/custom-map server startup, the complete fishing service/controller/UI/audio/presentation/cinematic flow, fishing UI, catch cinematic, fishing presentation, residents, scenery with 6,203 captured material surfaces, aquarium and portal-interface checks. The instrumented production checks passed. Intentional regression mutations still failed as expected. Logging was added only to temporary harnesses; no fake-only properties such as `AbsoluteSize` assignments or fixture event objects were treated as production setters. One temporary logging approach exhausted the combined harness's local registers; scoping the instrumentation fixed that harness issue before its final passing run.

## Specific native risks reviewed

- **Streaming modes:** [Model.ModelStreamingMode](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Model.yaml) is publicly writable. The documentation permits Scripts and warns against changing it from LocalScripts. Current mode assignments are server-side. Atomic scenery and persistent arrival/gallery supports use valid enum items.
- **Streaming and lighting configuration:** `Workspace` streaming radius/behavior properties are `NotScriptable`; `StreamingEnabled`, `LightingStyle` and `PrioritizeLightingQuality` also carry a `PluginOrOpenCloud` write capability in the supplied dump. They are serialized by the builder and are not set by runtime production Luau. The legacy restricted `Lighting.Technology` setter is absent. Runtime clock, shadows, exposure, ambient, atmosphere, sky/cloud and post-effect setters inspected here are public. Both Bloom and SunRays intensity remain zero.
- **Material variants:** [BasePart.MaterialVariant](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/BasePart.yaml) is publicly writable and `NotReplicated`. The client scenery binding therefore matters; setting a server-side string alone does not establish client appearance. Runtime code writes that selection string, while the builder serializes [MaterialVariant](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/MaterialVariant.yaml) base material and texture-map fields whose setters require plugin security. No runtime production reader/writer accesses those protected map fields.
- **Input and motion preferences:** `GuiService.ReducedMotionEnabled` is Hidden, ReadOnly and publicly readable. Reading it and subscribing to its property signal is allowed; production does not assign it. `UserInputService.PreferredInput` and the Touch/Gamepad/KeyboardAndMouse enum items exist and are public to read. Hidden metadata was not mistaken for restricted read security.
- **Portrait cameras:** `UITheme.fitPortrait` uses public `ViewportFrame.AbsoluteSize`, `Camera.FieldOfView/CFrame`, `Model:GetBoundingBox`, `Model/PVInstance:GetPivot` and documented CFrame operations. The helper adds no invented native method. It owns each viewport's private camera; projection tests establish arithmetic bounds, not a native render result.
- **Sound and scheduling:** `Sound`, `SoundGroup`, Equalizer/Compressor effects, `PreloadAsync`, Debris, Tween methods and `RBXScriptSignal:Once/Wait/Connect` exist. The compressor's attack correction above is the only confirmed native value-range discrepancy found. `RunService.Heartbeat`, `PreSimulation`, `RenderStepped` and the used input/prompt events are public APIs.

## Remaining limits

Follow-up on 27 October: the existing three shaft Parts now use native
`Part.Shape = Cylinder`, whose length is its local X axis. Their size/frame
conversion preserves the logical rod centers, lengths and cap contacts; no new
native class or uploaded mesh is involved. Rod-tip/line origins read the actual
`Attachment.WorldPosition`. The reflected metadata and the official
[Attachment documentation](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Attachment.yaml)
confirm public local Position/CFrame and derived WorldPosition/WorldCFrame access,
local offset synchronization and parent-frame composition. These follow-up reads
are additional to the earlier captured read totals. The inspection double now
models that production-used transform subset explicitly, including rotated and
nested parents; it is still not a general native engine implementation.

This is a reflected-API/documentation audit supported by production-source execution with doubles. Roblox Studio and a native Roblox client were not run. A legal member can still receive an invalid value in an unexercised branch, be written at an unsuitable lifecycle moment, or behave differently under native replication, Animator scheduling, streaming, physics and UI layout.

Roblox's Lua `PlayerModule:GetControls()/Disable()/Enable()` contract is outside the reflected class dump and remains a client integration check. Native asset permission/loading, six built-in sound paths, actual effect mixing, shader/material appearance, shadows, mobile/iPad input, render timing, device memory/FPS and live streaming still require playtesting. The review does not establish them.

Temporary evidence retained in this workspace:

- `/tmp/v18-native-api-combined.json`: merged production construction/write source records and harness results.
- `/tmp/v18-native-read-audit.json`: 132 reflected read/method/event pairs, datatype names, enums, document hashes and bounded findings.
- `/tmp/v18-native-world-docs.json`: additional official world/render/material documentation URLs and hashes.
- `/tmp/v18-native-builder-audit.json` and `/tmp/v18-native-water-constraints.json`: serialization tokens and current terrain dimensions.
- `/tmp/v18-native-api-provenance.json`: exact official version-request failures.
- `/tmp/v18-native-audit.py`: the temporary instrumentation runner; not a Roblox runtime emulator or a shipped game dependency.
