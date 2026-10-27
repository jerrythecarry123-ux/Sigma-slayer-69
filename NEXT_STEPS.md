# Resume instructions

Current branch: `work`; repository: `/workspace/Sigma-slayer-69`.

**Active v1.8 request:** first read the active section of `PROGRESS.md` and
`WORK_LOG.md`. Run `python tools/work_session.py resume` on a continuation;
do not count the usage pause or reset sealed time. The two-hour target is a
minimum before completion, not a reason to stop with broken integration.
Finish current cast/controller/UI/save/model work, run the relevant checks, then
continue the next useful directive priority while active time remains. Preserve
work and checkpoint frequently if another usage interruption occurs.

Immediate integration details: `Rules.castProgressAt`, `castGradeAt`,
`castDepthFor`; phases ChargingCast/Waiting/Reeling; commands BeginCast,
Cast/QuickCast (numeric accepted ID). QuickCast is a no-bonus convenience mode,
not trusted client timing. `replyTo` is a response-only command acknowledgement.
Earned rods now bind a `timingWidth`; pass it to UI and actual grading. The
world capture exports 101 actual cast depths; 10,100 footprint checks passed
against native-water cells. Fish/portrait framing checks passed after the final
fish source changes; do not repeat unchanged checks without a reason.

Current integration queue:

- Finish supported native-cylinder rod sections without changing their logical
  centers/endpoints, eight-Part count, rod-tip launch or fitted reel contacts.
  The earlier four catalog finishes are complete. Keep no per-frame finish writes.
- The constructor audio gap is fixed: `Audio.new(true)` starts muted before any
  RemoteEvent/PlayerGui waits. Twelve actual audio cases and the controller/full
  flow checks pass. Retain the default enabled `Audio.new()` for legacy callers.
- Aquarium static layout now caches effective canvas changes; closed/compact
  hidden portraits skip work. Existing full pose/lifecycle checks plus measured
  120-call probes and three rejected mutations passed.
- Update release/continuity records, verify source/place/ZIP agreement and publish
  the named v1.8 files only after the active-time target and remaining checks.

1. Read `PROGRESS.md`, `KNOWN_ISSUES.md` and `DEVELOPMENT_PLAN.md` first.
2. Inspect `git status --short` and the current diff. Do not discard working
   changes or restart the world. The v1.7 checkpoint builds on v1.6.
3. v1.7 integrates the fish/rarity, server timing, settings and private-camera
   reveal modules. Do not repeat that work. Its checks and packaging commands
   are listed in README; `PROGRESS.md` records the completed validation.
4. Next release gate: run the v1.8 section in `docs/studio-testlista.md` in a
   private native Roblox experience. Prioritize input/grade agreement at 50,
   100 and 200 ms latency, full fish framing, sound balance and phone/iPad load.
   Record actual device/settings and Output errors. Never mark unrun boxes passed.
5. Fix observed native regressions first. If a native client remains unavailable,
   use the roadmap to choose a feasible code/art improvement and explicitly retain
   these validation gaps. Optional cast accuracy is now implemented and needs
   native/player validation; environmental conditions/weather and bespoke assets
   remain later work.
6. For source changes, run the relevant checks, update all four continuity files,
   rebuild a new named place/ZIP and verify exact embedded sources. Existing
   authorization covers publishing completed repository work to GitHub main.
   Provide a normal GitHub `.rbxlx` download, not compressed PowerShell transport.

No background auto-resume or scheduling mechanism is configured. Work resumes
when Codex is invoked again.
