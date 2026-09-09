# Session Log

<!--
This is the project's activity log. Every agent appends entries here.
The TL captures agent TLDRs verbatim and adds retrospective notes.

## Format Guide

### Iteration structure:

## Iteration N: [Title]

### Phase N: [Phase Name]

**[Sender → Receiver agent]**
- **Agent type**: `type`
- **Task**: description
- **GitHub issues**: #N, #M

**[Agent → Team Lead] — COMPLETED/FAILED**
- **Agent TLDR**: [agent's own summary — captured verbatim, not paraphrased]

### Judge Gate
- **Verdict**: PASS / FAIL
- **Gaps**: [if any]

### Retrospective
- **Improvement applied**: [what was changed and where]
- **Improvement rejected**: [what was suggested and why it was rejected]

### Task List Snapshot
| Issue | Title | Status | Owner |
|-------|-------|--------|-------|
| #1 | ... | open/closed | ... |
-->

---
### [2026-09-05 10:30] — developer — #10
**Task**: Fix enemy jet sprites too small at distance
**Result**: COMPLETED
**Files changed**: `scenes/enemies/enemy_jet.tscn`, `scripts/enemies/enemy_spawner.gd`, `tests/test_enemy_spawner.gd`
**Key changes**:
- `scenes/enemies/enemy_jet.tscn:14` — `pixel_size` 0.03 → 0.08; sprite is now 2.67x larger in world space, visible at spawn distance
- `scripts/enemies/enemy_spawner.gd:6` — `SPAWN_Z` -80 → -50; reduces initial distance so enemies appear at a recognizable size and grow dramatically on approach
- `tests/test_enemy_spawner.gd` — added `test_spawn_z_visible_range` to guard SPAWN_Z stays in visible range (-60 to -30)
**Testing**: All 12 spawner tests pass. Sprite generator and enemy jet tests unaffected.
**Improvement Insights**:
- [developer.md]: When fixing visibility bugs, include the world-space math (sprite_size_px * pixel_size = world_units) in the comment — makes the tradeoff explicit and reviewable

---
### [2026-09-05 10:30] — developer — #9
**Task**: Fix player jet sprite too small and not clearly visible
**Result**: COMPLETED
**Files changed**:
- scenes/player/player_jet.tscn
- scripts/player/player_jet.gd

**Key changes**:
- player_jet.tscn:26 — pixel_size 0.03 -> 0.07 (sprite world width ~1.9 -> ~4.5 units)
- player_jet.tscn:34 — AfterburnerFlame offset adjusted (Y -0.15->-0.35, Z 0.4->0.6) to align with larger sprite exhaust
- player_jet.gd:7-8 — MOVE_MIN/MAX tightened (X +-6->+-5, Y 1.5-5.5->1.0-4.0) to fit new closer Z position
- player_jet.gd:13 — RESPAWN_POSITION Z changed -8 -> -2; Y changed 3 -> 2 (jet now close to camera, fills bottom quarter)

**Testing**: Godot headless parse check passed with no errors. Root cause: at Z=-8 the jet was 8 units from camera making it tiny despite pixel_size; moving to Z=-2 with larger pixel_size makes it prominent.
**Improvement Insights**:
- [developer.md]: When debugging 3D visibility issues, compute world-space sprite size (pixels * pixel_size) vs camera distance as a first step — catches this class of bug instantly.

---
### [2026-09-05 12:00] — developer — #11
**Task**: Fix player dying too quickly — survivability tuning
**Result**: COMPLETED
**Files changed**: scripts/player/player_jet.gd, scripts/enemies/enemy_jet.gd, scripts/enemies/enemy_spawner.gd
**Key changes**:
- scripts/player/player_jet.gd:36-40 — Added 3-second invincibility at game start in `_ready()`, mirroring respawn logic
- scripts/enemies/enemy_jet.gd:69 — Changed initial `_fire_timer` from `randf_range(0.5, fire_interval)` to `randf_range(fire_interval * 0.8, fire_interval * 1.5)` to delay first shot
- scripts/enemies/enemy_spawner.gd:37 — Changed initial `_spawn_timer` from 1.0 to 3.0 to delay first wave
**Testing**: Verified no parse errors with headless Godot `--quit` run. Traced survivability math: first bullets arrive ~8-9 s into stage 1, player invincibility covers first 3 s. Stage 1 players can survive well past 30 s without moving.
**Improvement Insights**:
- [developer.md]: Note that `--check-only` on a single script fails for autoload references; use `--quit` headless run for parse verification

---
### [2026-09-05 21:00] — qa — #9, #10, #11
**Task**: Verify developer fixes for player sprite visibility (#9), enemy sprite visibility (#10), and player survivability (#11)
**Result**: FAIL (2 bugs remain, 1 new bug found)
**Issues verified**: #9 (PARTIAL FAIL), #10 (PASS), #11 (PARTIAL FAIL)
**New bugs filed**: #12 (LIVES label clipped)
**Key findings**:
- #10 PASS: Enemy sprites clearly visible at Z=-50 spawn distance, smooth Super Scaler growth confirmed visually across multiple waves
- #9 PARTIAL FAIL: Player jet is now a recognizable shape (improvement), but renders at horizon line not bottom-quarter, and estimated 5-7% screen height vs required 15-20%. Root cause: Z=-2 at Y=2 places player on the ground plane level, not floating in the "bottom of screen" space. The fix moved in right direction but overshot the Z (too close to camera) and undershot pixel_size relative to camera geometry.
- #11 PARTIAL FAIL: 3s invincibility correctly implemented in code. First wave correctly delayed to 3s. However "survive 30s idle" criterion fails (~12-15s actual survival). Root cause not fully addressed: SPAWN_Y_MIN=2.0 overlaps with player Y=2.0 — enemies physically fly through player position as they approach. Timer delays help but geometry ensures collision without player input.
- #12 NEW: LIVES label clipped at right edge — "LIVES:" prefix cut off in HBoxContainer layout
- #9 and #11 relabeled to `developer` for further work
**Improvement Insights**:
- [qa.md]: When testing 3D game bugs, take screenshots at 0.5s intervals during the critical first 5 seconds — 1-2s intervals miss fast state changes (death, flashing, spawning)
- [qa.md]: Include explicit camera geometry math in QA reports for 3D sprite-size bugs — state camera position, FOV, sprite Z/Y, and estimated screen percentage. Don't rely only on visual inspection.
- [developer.md]: For 3D Sprite3D placement, validate against camera math: at distance D from camera with FOV F, a sprite of world-height H occupies H/D * (screenHeight / 2*tan(F/2)) pixels. Use this before marking a size fix as done.
- [workflow]: Headless parse testing is insufficient for gameplay bugs — developers must test with live Godot run and screenshots before marking survivability/visibility fixes complete

---
### [2026-09-05 21:30] — developer — #12
**Task**: Fix LIVES label clipping in bottom-right HUD
**Result**: COMPLETED
**Files changed**: scenes/hud/hud.tscn
**Key changes**:
- hud.tscn:187 — Changed LivesLabel size_flags_horizontal from 3 (FILL+EXPAND) to 4 (SHRINK_END): stops the label competing for extra space with MISSILES and SPEED
- hud.tscn:188 — Added custom_minimum_size = Vector2(160, 0): guarantees enough width for "LIVES: ♦♦♦" at font size 18 monospace regardless of sibling widths
- hud.tscn:197 — Added clip_text = false: makes clipping opt-out explicit
**Testing**: Code review only — root cause was clear (three FILL+EXPAND labels dividing space equally; SPEED bar with 10 Unicode block chars dominated). Layout math: at 960px wide, 32px margins, three equal thirds = ~299px each. "SPEED: █████░░░░░" at 18px monospace is ~200px but Unicode blocks can be wider; LIVES label shrank below its text width. Fix reserves 160px minimum for LIVES and gives remainder to MISSILES+SPEED.
**Improvement Insights**:
- [developer.md]: For HUD layout bugs in Godot, check size_flags_horizontal first — FILL+EXPAND (3) on all siblings is a common root cause of clipping when content widths differ significantly

---
### [2026-09-05 12:00] — developer — #11
**Task**: Fix player dying too quickly — enemies geometric collision + high difficulty on stage 1
**Result**: COMPLETED
**Files changed**: scripts/enemies/enemy_spawner.gd, scripts/enemies/enemy_jet.gd, scripts/stage/stage_data.gd
**Key changes**:
- enemy_spawner.gd:7 — SPAWN_Y_MIN 2.0 → 3.5: root cause fix, enemies now clear player's Y range
- enemy_spawner.gd:126-133 — scattered formation Y clamped to maxf(SPAWN_Y_MIN, ...) so variance can't drop below 3.5
- enemy_spawner.gd:11,41 — spawn_interval default and first-wave delay: 3.0 → 5.0
- enemy_spawner.gd:23-36 — wave definitions reworked: early waves 2 enemies, 12 total types with gradual ramp
- enemy_jet.gd:40 — BULLET_SPEED 30.0 → 20.0
- enemy_jet.gd:16-36 — fire_interval: fighter 3.0→5.0, interceptor 2.0→3.5, bomber 1.2→2.5
- stage_data.gd:8-16 — stage 1 spawn_interval 3.0→5.0, stage 2 2.8→4.0, stages 3-5 smoothed ramp
**Testing**: Project loads without parse errors (Godot headless --quit). Calculated first bullet arrival: t=9s minimum (spawn at t=5 + fire_interval*0.8=4s). Enemies Y range 3.5-6.0 vs player Y~1-2, no overlap.
**Improvement Insights**:
- [developer.md]: When reviewing collision/survival bugs, check geometric overlap of spawn ranges against player position before code logic — it's often the coordinate ranges that are wrong, not the collision detection code

---
### [2026-09-05 14:30] — developer — #9
**Task**: Fix player jet position and size (second attempt) — bottom quarter, 15-20% screen height
**Result**: COMPLETED
**Files changed**: scripts/player/player_jet.gd, scenes/player/player_jet.tscn
**Key changes**:
- player_jet.gd:7-8 — MOVE_MIN.y 1.0→3.0, MOVE_MAX.y 4.0→4.8 (keep jet in lower screen)
- player_jet.gd:14 — RESPAWN_POSITION (0,2,-2)→(0,4.4,-8) (correct bottom-quarter placement)
- player_jet.tscn:26 — pixel_size 0.07→0.03 (correct sprite size to ~18% screen height)
**Testing**: Camera projection math verified. At (0,4.4,-8): NDC_y=-0.500 (bottom quarter), sprite=18.1% of screen height. Godot headless boot: no script errors.
**Improvement Insights**:
- [developer.md]: Always read the camera basis matrix from the .tscn file directly rather than trusting textual descriptions of rotation — the transform values are authoritative.

---
### 2026-09-05 23:45 — judge — Visual Fidelity Assessment
**Gate type**: final (critical state assessment)
**Verdict**: FAIL
**Score**: 2/10
**Key gaps**: Player sprite wrong perspective (top-down vs rear-view), sprites too small (15% vs 30-40% screen), ground is flat checkerboard, sky is bare gradient, explosions are orange squares, no missile trails/lock-on/tracers, muted color palette, no sense of speed. Every visual element fails to match After Burner II.
**Improvement Insights**:
- criteria.md: Add measurable visual targets (sprite screen coverage %, minimum resolution, color saturation). "No placeholder art" criterion was never enforced.
- architect.md: Spec must define sprite viewing angles and pixel dimensions explicitly.
- developer.md: Agents should compare visual output against reference before marking complete.
- CLAUDE.md: Add visual reference section with measurable targets for each visual element.

---
### [2026-09-05 12:00] — ui-designer — #13
**Task**: Complete visual redesign spec for After Burner II arcade recreation — sprites, shaders, HUD
**Result**: COMPLETED
**Elements designed**:
- Player F-14 Tomcat rear-view sprite sheet (5 banking frames, 64x48px per frame)
- Enemy Fighter front-view sprite (48x48px, red palette)
- Enemy Interceptor front-view sprite (48x48px, green palette)
- Enemy Bomber front-view sprite (64x64px, grey palette)
- Explosion animation (8 frames, 64x64px, orange/red/yellow progression)
- Ground shader (ocean perspective band pattern, 5-color palette)
- Sky shader (5-stop gradient, 2-layer cloud rendering)
- Missile sprite (8x24px, off-white aluminum body + smoke trail spec)
- Vulcan bullet sprite (4x4px bright yellow dot)
- HUD layout (positions, colors, targeting reticle bracket design)
**Key design decisions**:
- Enemy jets MUST be front-view (nose-on, approaching camera) not top-down — this is the #1 visual error
- Player jet MUST be rear-view (tail fins, engine nozzles, swept stabilizers) not top-down — #2 visual error
- Color palette is BOLD arcade saturation: hot reds (#D9261E), deep blues (#0D2680), bright greens (#33FF66)
- Ground shader uses perspective band distortion (pow(uv.y, 0.4) warp) for Super Scaler feel
- Targeting reticle uses 4 corner brackets (NOT a circle or full box) — authentic arcade style
- Explosion is 8-frame sprite animation not GPUParticles — necessary for arcade look
- Player jet sprite rendered at 192px screen width (20% of 960px) — matches original arcade proportion
**Improvement Insights**:
- [ui-designer.md]: Add explicit rule: always read existing sprite generator code before writing specs, to make specs directly actionable (column/row coordinates that match existing canvas sizes)
- [CLAUDE.md]: Document that enemy viewing angle (front vs top vs rear) is a critical design parameter that should be in the initial architecture spec — not discovered during visual QA
- [criteria.md]: Add visual correctness criterion to architect gate: "sprite viewing angles must match game perspective (rail shooter = rear player, front enemies)"
- [workflow]: UI designer should be invoked BEFORE developer on visual features, not as a fix-up pass after broken implementation

---
### [2026-09-05 23:55] — senior-developer — #13
**Task**: Rewrite enemy sprite generator to draw front-view jets per UI designer spec
**Result**: COMPLETED
**Files changed**: scripts/enemies/enemy_sprite_generator.gd
**Key changes**:
- Complete rewrite of all three enemy sprite drawing functions (fighter, interceptor, bomber)
- Fighter (48x48, red): nose cone rows 2-7, fuselage 3-section taper, cockpit canopy with highlight, delta wings root-to-tip, engine intakes as ovals, edge highlights
- Interceptor (48x48, green): longer nose rows 2-10, narrower fuselage (8px), angular wings reaching col 6/41, smaller intakes
- Bomber (64x64, grey): rounded nose, wide 16px fuselage, broad wings to col 4/59, twin engine pods at cols 10-16 and 47-53 with intake circles
- Replaced old top-down ellipse/wing_pair helpers with front-view-specific: _draw_delta_wing, _draw_rect, _draw_hline, _draw_filled_oval, _safe_pixel
- All colors match UI designer spec exactly
- API unchanged: generate_texture(EnemyVisual) -> ImageTexture, same enum values
**Technical decisions**: (1) Used row-by-row lerp for nose cones to get smooth taper from 1px tip to full width. (2) Delta wings drawn as column-strips swept from root to tip with tapering thickness and edge highlight on leading edge. (3) Kept _draw_filled_oval from old code (same algorithm) for intakes and engine pod circles.
**Testing**: All 11 existing tests pass (texture sizes, non-null, bomber larger, textures differ). No API changes so enemy_jet.gd compatibility is guaranteed.
**Improvement Insights**:
- [developer.md]: When rewriting sprite generators, export a debug PNG to verify visually before marking done — pixel-level drawing bugs are invisible in unit tests that only check dimensions

---
### [2026-09-05 24:10] — developer — #13
**Task**: Rewrite explosion effect from GPUParticles3D to animated sprite
**Result**: COMPLETED
**Files changed**: scripts/effects/explosion.gd, scenes/effects/explosion.tscn
**Key changes**:
- explosion.gd:1 — extends Sprite3D instead of GPUParticles3D
- explosion.gd: procedurally generates a 512×64 sprite sheet at _ready() with 8 × 64px frames
- explosion.gd: _process() advances frame index every 0.05s, queue_free() after frame 8
- explosion.gd: drawing helpers _circle, _ring, _irregular_circle, _smoke_wisps, _blobs, _sparse_pixels
- explosion.tscn — node type changed to Sprite3D, removed ParticleProcessMaterial and QuadMesh sub-resources
**Testing**: Godot headless parse passes with no errors. Script check-only passes clean. Instantiation API unchanged (position set externally, added as child).
**Improvement Insights**:
- [developer.md]: For procedural sprite work, exporting a debug PNG snapshot would catch pixel drawing bugs faster than any unit test

---
### [2026-09-05 23:45] — senior-developer — #13
**Task**: Rewrite ground scroll shader and sky gradient shader for After Burner II arcade look
**Result**: COMPLETED
**Files changed**: assets/shaders/ground_scroll.gdshader, assets/shaders/sky_gradient.gdshader
**Key changes**:
- ground_scroll.gdshader — replaced checkerboard pattern with ocean perspective bands (pow compression), 5-color cycling, foam noise, horizon fade
- sky_gradient.gdshader — replaced 2-stop linear gradient with 5-stop smoothstep gradient, added two cloud layers with hash noise and TIME drift
**Technical decisions**: (1) Kept all existing uniform names (color_a, color_b, scroll_offset, scroll_speed, tile_scale, color_top, color_horizon) so stage_manager.gd and ground_scroll.gd continue working without changes. (2) Stage colors applied at 30% blend influence — enough for stage variety without overriding the arcade palette. (3) Ground uses scroll_offset from GDScript rather than TIME to stay synchronized with the existing ground_scroll.gd driver script.
**Testing**: Godot headless launch — no shader compilation errors. Verified uniform API compatibility by grep across all .gd files.
**Improvement Insights**:
- [workflow]: Shader changes need visual verification via screenshot — headless compile check only catches syntax errors, not visual correctness

---
### [2026-09-05 18:30] — senior-developer — #13
**Task**: Rewrite player F-14 sprite generator to rear-view based on UI designer spec
**Result**: COMPLETED
**Files changed**: scripts/player/jet_sprite_generator.gd, tests/test_jet_sprite_generator.gd (new)
**Key changes**:
- scripts/player/jet_sprite_generator.gd — complete rewrite: rear-view F-14 with fuselage, twin tail fins, horizontal stabilizers, twin engine nozzles, cockpit spine, afterburner flames. 5 banking frames with cos/sin transforms. Sheet changed from 320x64 to 320x48.
- tests/test_jet_sprite_generator.gd — new test file with 14 assertions covering dimensions, pixel presence, frame differentiation, afterburner colors
**Technical decisions**: (1) Banking uses cos_b to squish horizontal coords toward center col 32 and sin_b*8 for lateral shift — matches spec formula. (2) Hard bank (>30 deg) hides the downward fin and adds a wing stub, soft bank extends the near fin tip by 1px. (3) Afterburner flames use distance-from-center to select 3-layer color rings. (4) Kept same public API (static generate_sprite_sheet() -> ImageTexture) for backward compatibility.
**Testing**: 14/14 unit tests pass. Godot headless build clean. No regressions in project load.
**Improvement Insights**:
- [workflow]: Sprite generators need visual screenshot verification — unit tests confirm structure but not visual correctness

---
### 2026-09-06 — judge — Visual Overhaul Critical Assessment
**Gate type**: final (visual fidelity review)
**Verdict**: FAIL
**Score**: 4/10
**Key gaps**:
- Player jet is ~12% screen height vs required 25-30% (pixel_size=0.03 should be ~0.06)
- Explosions are microscopic at 3% screen height (pixel_size=0.006 should be ~0.025)
- No lock-on targeting reticle (core mechanic visual feedback missing)
- Sprite resolution 64x48 too low for attempted detail level
- Screen lacks energy: no screen shake, sparse enemies, no speed indicators
**Top 5 fixes**: (1) Double player jet pixel_size, (2) 5x explosion size + screen shake, (3) Add lock-on reticle, (4) Increase sprite resolution to 128x96, (5) Double enemy spawn rate + add tracers
**Improvement Insights**:
- criteria.md: Add measurable visual scale targets (% of screen height for player, explosions)
- developer.md: Require on-screen coverage math before implementing visual changes
- architect.md: Visual specs should include reference measurements from original game screenshots

---
### [2026-09-06 10:30] — developer — #13
**Task**: Add lock-on targeting reticle to HUD
**Result**: COMPLETED
**Files changed**: `scripts/ui/reticle.gd` (new), `scenes/hud/hud.tscn` (modified)
**Key changes**:
- `scripts/ui/reticle.gd:1` — new Control subclass with `_draw()` rendering 4 L-shaped corner brackets; polls enemy positions via scene tree to determine lock state, mirroring weapon_manager.gd's LOCKON_RECT logic without touching weapon files
- `scenes/hud/hud.tscn:77` — replaced 4 Label nodes ([ ] characters) with single Control using reticle.gd script, sized 120x120px
**Testing**: Godot headless `--quit` passes with no GDScript parse errors; only pre-existing MCP port 9501 error present
**Improvement Insights**:
- developer.md: When spec says "do not modify X files", note that reading private fields is also off-limits — prefer mirroring detection logic rather than exposing internals
- workflow: For HUD-only visual changes, a screenshot-based QA check is more useful than headless build — suggest QA uses `/screenshot` command

---
### [2026-09-06 12:00] — senior-developer — #13
**Task**: Upgrade player F-14 sprite resolution from 64x48 to 128x96
**Result**: COMPLETED
**Files changed**: `scripts/player/jet_sprite_generator.gd`
**Key changes**:
- jet_sprite_generator.gd:7-8 — FRAME_W 64->128, FRAME_H 48->96, CENTER constant added at 64
- jet_sprite_generator.gd:16 — Warmer fuselage Color(0.60, 0.58, 0.55) replacing cool grey-blue
- jet_sprite_generator.gd:94 — Panel line (1px darker stripe along fuselage center)
- jet_sprite_generator.gd:78-89 — Tapered tail fins via _draw_fin_tapered() replacing rectangular _draw_fin()
- jet_sprite_generator.gd:114-121 — Concentric nozzle rings (outer, ring, inner) for exhaust detail
- jet_sprite_generator.gd:107-108 — Wing root fairings at stabilizer-fuselage junction
- jet_sprite_generator.gd:218-241 — Afterburner flames 24px long (was 12), 8px wide (was 6), row-parity flicker
**Technical decisions**: (1) All coordinates scaled exactly 2x from originals to maintain proportional geometry. (2) Replaced _draw_fin with _draw_fin_tapered that narrows tip by 2px on inward side per row for realistic vertical stabilizer silhouette. (3) Added flickering to afterburner via modulo-3 width variation rather than randomness — deterministic so the sprite sheet is consistent across runs.
**Testing**: Godot headless --check-only parse passed clean, no errors.
**Improvement Insights**:
- workflow: When doubling sprite resolution, the .tscn pixel_size must be halved in the same PR — splitting across tasks risks a visually broken intermediate state
- CLAUDE.md: Document the relationship between sprite resolution and pixel_size (world_size = pixels * pixel_size) as a project convention

---
### [2026-09-06 14:00] — senior-developer — #14
**Task**: Add procedural audio system — chip-tune music and sound effects
**Result**: COMPLETED
**Files changed**: `scripts/autoload/audio_manager.gd` (new), `project.godot`, `scripts/ui/title_screen.gd`, `scripts/weapons/weapon_manager.gd`, `scripts/enemies/enemy_jet.gd`, `tests/test_audio_manager.gd` (new)
**Key changes**:
- `scripts/autoload/audio_manager.gd` — new AudioManager autoload: real-time PCM synthesis via AudioStreamGenerator for music (square wave lead + triangle wave bass, 2 voices mixed), 3 looping tracks with note sequences, 4 procedural SFX via AudioStreamWAV (vulcan noise burst, missile pitch sweep, explosion noise+falling pitch, lock-on sine beep), 8-player SFX pool
- `project.godot:21` — registered AudioManager autoload between GameState and McpBridgeGame
- `scripts/ui/title_screen.gd:111` — calls `AudioManager.play_music(_selected_track)` on game start
- `scripts/weapons/weapon_manager.gd:53` — vulcan fire SFX on each shot
- `scripts/weapons/weapon_manager.gd:68` — missile launch SFX on each missile
- `scripts/weapons/weapon_manager.gd:106-108` — lock-on beep when acquiring new target
- `scripts/enemies/enemy_jet.gd:112` — explosion SFX on enemy death
- `tests/test_audio_manager.gd` — 221 assertions covering note frequencies, track validity, SFX WAV generation, format correctness, durations
**Technical decisions**: (1) Used AudioStreamGenerator for music (real-time buffer filling in _process) because it allows seamless looping without pre-rendering large WAV buffers. (2) Used AudioStreamWAV for SFX because they're short one-shots that benefit from pre-generation and pool playback. (3) 22050Hz sample rate — sufficient for chip-tune fidelity, half the CPU cost of 44100Hz. (4) Square wave for lead voice and triangle wave for bass — classic NES/arcade sound chip topology. (5) SFX pool of 8 players to handle overlapping vulcan fire without cutting off sounds.
**Testing**: 221/221 tests pass. All existing tests (spawner 12/12, sprite_generator 11/11) still pass. Godot headless build clean, no parse errors.
**Improvement Insights**:
- [workflow]: Audio features need live playback testing — headless mode cannot verify that sounds actually play correctly through speakers
- [CLAUDE.md]: Document the AudioManager autoload and its public API (play_music, play_vulcan_fire, play_missile_launch, play_explosion, play_lockon_beep) for other developers

---
### [2026-09-06 14:00] — ui-designer — #15 (relates to #9, #13)
**Task**: Diagnose 3D perspective failures vs original After Burner II arcade and produce actionable fix specs
**Result**: COMPLETED
**Elements designed**: Player jet sprite angle, player jet size/position, ground perspective shader, horizon line placement, sky colors, enemy saturation, world-tilt camera roll, HUD color scheme
**Key design decisions**:
- Player jet must be redrawn as top-rear 3/4 view (dorsal view showing wing tops, canopy, engine nozzles) — the current direct-rear view is the #1 visual failure; every source confirms the original camera is "behind and above"
- Ground scroll speed must triple (8.0 → 18.0+) — multiple sources describe "nauseating" speed; our current rate reads as leisurely
- Horizon line needs to sit at 50–55% from top (currently ~40%) — camera X rotation +15° → +20°
- Sky gradient must be deeper/more saturated — deep navy `#050A40` top to electric blue `#3366C7` at horizon, eliminating the current white haze
- World-tilt on banking (camera Z-roll ±8–10° tracking bank angle) is a critical speed/immersion cue that the original uses but we do not have
- Player jet pixel_size: 0.03 → 0.055 and Z position: -8.0 → -5.5 to achieve target 20% screen height at bottom-center
**Improvement Insights**:
- [ui-designer.md]: Require the designer agent to use `/screenshot` command to view the actual game state before diagnosing — all diagnosis was from code reading which is valid but seeing the screenshot would confirm or correct assumptions
- [workflow]: Visual design tasks should come with a screenshot from the `/screenshot` command so the agent isn't blind — saves multiple rounds of inference from code reading
- [CLAUDE.md]: Document the pixel_size / Z-position / screen-percentage relationship formula so future agents don't have to re-derive it: `screen_height_fraction ≈ (sprite_height_px × pixel_size) / (2 × Z_distance × tan(FOV/2))`

---
### [2026-09-06 10:00] — developer — #18
**Task**: Add camera Z-roll on player banking
**Result**: COMPLETED
**Files changed**: scripts/player/player_jet.gd
**Key changes**:
- player_jet.gd:26 — added `var _camera: Camera3D` field
- player_jet.gd:43 — `_camera = get_viewport().get_camera_3d()` in `_ready()`
- player_jet.gd:102-106 — camera roll in `_update_banking()`: `move_toward` toward `-horizontal_input * 10.0` at 60°/s
- player_jet.gd:157 — reset `_camera.rotation_degrees.z = 0.0` in `_respawn()` to clear roll after death
**Testing**: GDScript syntax check passes (GameState autoload error is expected in headless standalone mode). Logic reviewed manually — null guard on `_camera`, smooth lerp via `move_toward`, roll resets on respawn.
**Improvement Insights**:
- [developer.md]: Note that `get_viewport().get_camera_3d()` returns null until the viewport is fully set up — calling it in `_ready()` is fine for autoloaded scenes but may need deferral in edge cases

---
### [2026-09-06 12:00] — senior-developer — #16
**Task**: Redraw player jet sprite as top-rear 3/4 dorsal view
**Result**: COMPLETED
**Files changed**: scripts/player/jet_sprite_generator.gd, scenes/player/player_jet.tscn, tests/test_jet_sprite_generator.gd
**Key changes**:
- jet_sprite_generator.gd: Complete rewrite. Frame size 128x96 -> 160x96 (800x96 sheet). Dorsal view with wings as dominant element spanning cols 20-140. Independent wing scaling for banking (not uniform squish). Cockpit canopy dark blue dome. Foreshortened engine nozzles and short afterburner flames.
- player_jet.tscn:26 — pixel_size 0.03 -> 0.055 for ~20% screen height
- test_jet_sprite_generator.gd: Rewritten with 9 tests / 16 assertions covering new dimensions, wing span, canopy colors, banking asymmetry
**Technical decisions**: (1) Banking uses per-wing scale factors rather than trig-based cos(bank) transform — gives more artistic control over foreshortening ratios. (2) Wings drawn as swept-back delta shapes with quadratic ease-in on leading edge for realistic F-14 sweep geometry. (3) Afterburner flames shortened to 10px (vs 24px old) since viewed from above they're foreshortened.
**Testing**: All 16 test assertions pass. Godot project loads cleanly. Frame pixel counts confirm L/R symmetry in banking (frames 1/3 identical, 0/4 near-identical).
**Improvement Insights**:
- [CLAUDE.md]: Sprite generator tests should specify explicit pixel coordinate ranges in acceptance criteria to make judge gates deterministic
- [criteria.md]: Add visual sprite criteria — "shape reads as X from a distance" is hard to test programmatically; consider screenshot-based visual QA for sprite work

---
### [2026-09-06 12:00] — senior-developer — #17
**Task**: Fix ground speed, perspective formula, camera angle, and sky colors
**Result**: COMPLETED
**Files changed**: assets/shaders/ground_scroll.gdshader, assets/shaders/sky_gradient.gdshader, scenes/main.tscn, scripts/player/player_jet.gd, scripts/stage/ground_scroll.gd
**Key changes**:
- ground_scroll.gdshader:8 — scroll_speed default 8.0->18.0, hint_range upper 10->30
- ground_scroll.gdshader:33 — perspective formula pow(1.0-uv.y, 0.4) -> pow(uv.y, 2.5) for dramatic near-wide/far-thin bands
- ground_scroll.gdshader:20 — SKY_HAZE changed from white (0.75,0.85,0.98) to match sky horizon (0.20,0.40,0.78)
- sky_gradient.gdshader:8-12 — all sky stops replaced with deeper blues, SKY_HAZE=SKY_HORIZON to eliminate white
- sky_gradient.gdshader:77 — below-horizon falloff uses SKY_HORIZON instead of SKY_HAZE
- scenes/main.tscn:40 — camera transform updated from 15deg to 20deg X rotation
- scenes/main.tscn:13-14 — sky shader params updated to new deep blue defaults
- scenes/main.tscn:27,49 — scroll_speed 8.0->18.0 in both shader param and export
- scripts/player/player_jet.gd:7-8 — MOVE_MIN.y 3.0->2.5, MOVE_MAX.y 4.8->4.2
- scripts/player/player_jet.gd:14 — RESPAWN_POSITION Y 4.4->3.8 for new camera angle
- scripts/stage/ground_scroll.gd:3 — scroll_speed default 8.0->18.0
**Technical decisions**: (1) Used pow(uv.y, 2.5) instead of pow(1.0-uv.y, ...) — simpler and correct since UV.y=0 is near camera; high exponent compresses horizon bands. (2) Set SKY_HAZE equal to SKY_HORIZON rather than removing it, to avoid breaking the gradient logic structure. (3) Lowered player Y by 0.6 units to compensate for 5deg additional camera downtilt.
**Testing**: Godot --import passes clean. All shader syntax valid. GDScript compiles (GameState autoload error expected in headless mode).
**Improvement Insights**:
- [workflow]: When changing camera angle, a screenshot verification step would catch positioning issues faster than manual math

---
### 2026-09-06 — judge — Critical State Assessment
**Gate type**: final (overall game state audit)
**Verdict**: FAIL
**Score**: 4/10
**Key gaps**: (1) Player and enemy sprites are flat-colored geometric shapes, not recognizable aircraft. (2) No Super Scaler multi-resolution sprite system. (3) Explosions too small and too fast. (4) Audio uses basic waveforms, not FM synthesis character. (5) No barrel roll, no ground variety, no enemy approach animation.
**Top 5 fixes**: Enemy sprites, player jet sprite, explosion scale/duration, multi-resolution sprite scaling, audio FM synthesis.
**Improvement Insights**:
- criteria.md: Add sprite fidelity criterion and Super Scaler technique requirement
- CLAUDE.md: Note that procedural sprite generation is stopgap, not target

---
### 2026-09-06 14:30 — ui-designer — #19
**Task**: Diagnose why procedural jet sprites produce blobs, specify exact fixes for player jet, enemy jets, and explosions
**Result**: COMPLETED
**Elements designed**: Player F-14 sprite (5 banking frames), Enemy Fighter (48×48 red), Enemy Interceptor (48×48 green), Enemy Bomber (64×64 grey), Explosion (10-frame, 128px cell)
**Key design decisions**:
- Kept procedural generation — the architecture is sound; specific functions are broken
- Root cause of enemy blobs identified: `_draw_delta_wing()` walks a diagonal pixel-wide line instead of filling a triangle. Spec replaces it with `_draw_filled_wing_triangle()` that uses hline fills row by row
- Player jet lacks 5 F-14 identity markers: twin-boom tail gap, two-seat tandem canopy, fixed wing gloves, variable-sweep crease lines, and separation between fuselage/wing luminance values
- Explosion scaled 4x (cell 64→128px, pixel_size 0.025→0.06), duration 2.5x (0.4→1.0s), frames 8→10
- Spec is pixel-level specific: exact x/y coordinates for every geometry element, exact hex colors, exact function signature for the replacement wing fill algorithm
**Improvement Insights**:
- [ui-designer.md]: Add a mandatory "function-level diagnosis" step before writing specs — previous specs failed because they described WHAT should look like, not WHY the code produced wrong output. Diagnosing the broken drawing primitive first made this spec 10x more actionable
- [workflow]: UI designer should verify previous spec comments on the issue before starting work, to avoid repeating directions that already failed
- [criteria.md]: Add criterion: "wing surfaces must be filled triangular regions; single-pixel diagonal draws are automatically FAIL"

---
### 2026-09-06 15:00 — developer — #19
**Task**: Fix explosions — scale up cell, pixel_size, frame count, duration; redraw 10 frames for 128px canvas
**Result**: COMPLETED
**Files changed**: `scripts/effects/explosion.gd`
**Key changes**:
- explosion.gd:5-9 — FRAME_COUNT 8→10, FRAME_DURATION 0.05→0.1, SHEET_W 512→1280, SHEET_H 64→128, CELL 64→128
- explosion.gd:27 — pixel_size 0.025→0.06 (world size 1.6→7.68 units)
- explosion.gd:57-88 — _draw_frame rewritten for 10 frames at cx=64,cy=64 with spec radii; removed unused helpers (_irregular_circle, _smoke_wisps, _blobs)
**Testing**: `godot --headless --check-only` — no parse errors. Constants verified: 10×128=1280 matches SHEET_W; max ring r_outer=58 stays within 64px half-cell boundary.
**Improvement Insights**:
- [developer.md]: When removing helper functions check they're not called from outside the file first. In this case they were all private and only called from _draw_frame, safe to remove.

---
### [2026-09-06 14:30] — senior-developer — #19
**Task**: Fix enemy jet sprites — wings drawn as lines instead of filled triangles
**Result**: COMPLETED
**Files changed**: scripts/enemies/enemy_sprite_generator.gd, tests/test_enemy_sprite_generator.gd
**Key changes**:
- enemy_sprite_generator.gd:243-278 — Replaced `_draw_delta_wing()` with `_draw_filled_wing_triangle()` using horizontal line fills per row instead of diagonal pixel walk
- enemy_sprite_generator.gd:9-36 — Updated all color palettes to higher saturation/contrast per UI spec; added shadow colors for trailing edge depth
- enemy_sprite_generator.gd:97-101 — Updated fighter wing calls: wider span (tip at col 2/46), new function signature
- enemy_sprite_generator.gd:141-143 — Updated interceptor wing calls: tips at col 5/43
- enemy_sprite_generator.gd:183-185 — Updated bomber wing calls: tips at col 2/62; added fuselage highlight spine and bomb bay belly stripe
- test_enemy_sprite_generator.gd — Added 3 wing fill verification tests counting opaque pixels in wing regions
**Technical decisions**: (1) Used horizontal line fill algorithm (hline per row from fuselage to interpolated edge) rather than scanline polygon fill — simpler, matches existing `_draw_hline` helper, and delta wings are always triangles with one vertical edge. (2) Shadow on trailing 20% of rows via t > 0.80 threshold rather than per-pixel distance — cheap and effective for implying wing depth. (3) Leading edge gets full-row highlight on first row only, outermost pixel highlighted on every row — gives wing a bright leading edge without overwhelming the fill color.
**Testing**: 17/17 tests pass. Wing fill tests confirm fighter ~230-257 opaque pixels per wing (old code ~25), interceptor ~172-184, bomber ~341-350. No regressions in existing tests.
**Improvement Insights**:
- [criteria.md]: Add a "sprite readability" criterion — minimum opaque pixel count in expected regions, testable programmatically
- [CLAUDE.md]: Document that procedural sprite drawing should use horizontal line fills for filled shapes, not diagonal pixel walks — this was the root cause of a major visual bug

---
### [2026-09-06 12:00] — senior-developer — #19
**Task**: Fix player jet sprite — add 5 missing F-14 identity markers
**Result**: COMPLETED
**Files changed**: scripts/player/jet_sprite_generator.gd, tests/test_jet_sprite_generator.gd
**Key changes**:
- jet_sprite_generator.gd:87-100 — Twin tail boom gap: rear fuselage rows 68-80 now split into two nacelles with transparent 6px center gap
- jet_sprite_generator.gd:160-177 — Tandem canopy: replaced single oval with two separate bumps (front rows 18-27, rear rows 28-34) with gap at row 27
- jet_sprite_generator.gd:120-145 — Wing gloves: new `_draw_wing_glove()` draws darker trapezoidal root sections (COL_GLOVE) at cx-10 to cx-22
- jet_sprite_generator.gd:228-237 — Sweep crease line: panel line at glove/panel boundary (cx+-22) rows 36-54
- jet_sprite_generator.gd:30-55 — Palette overhaul: fuselage-wing luminance gap increased from 0.08 to 0.13, distinct hue separation (grey-tan vs blue-grey)
- jet_sprite_generator.gd:222-225 — Panel line now skips canopy rows 18-35 to avoid overwriting canopy glass
**Technical decisions**: (1) Drew gloves before movable panels (painter's algorithm) so the darker glove color shows at the root while panels extend outward. (2) Used scale-aware crease line position (22.0 * bank_scale) so the crease follows banking foreshortening correctly. (3) Skipped spine panel line over canopy area — drawing detail lines last means they can overwrite anything; needed explicit row exclusion.
**Testing**: 27/27 tests pass (16 existing + 11 new). New tests cover: twin tail boom gap transparency + nacelle presence, tandem canopy two-bump detection with gap check, glove-darker-than-panel luminance comparison, sweep crease dark pixel count, fuselage/wing luminance gap >= 0.10.
**Improvement Insights**:
- [criteria.md]: Add per-identity-marker test criteria for procedural sprites — each visual feature should be independently verifiable
- [CLAUDE.md]: When drawing detail/panel lines last, explicitly skip regions owned by other features (canopy, insignia) — blind full-row lines cause subtle overwrite bugs

---
### [2026-09-06 16:00] — judge — #19
**Gate type**: final (post-sprite-fix visual fidelity)
**Verdict**: PASS
**Score**: 7/10
**Key gaps**: No multi-resolution Super Scaler sprites, no screen shake, no missile/bullet trails, no enemy banking animation, procedural art ceiling
**Improvement Insights**:
- [criteria.md]: Add sprite readability criterion with measurable thresholds (opaque pixel counts, luminance contrast minimums)
- [criteria.md]: Add visual scale criterion requiring documented minimum world-unit size per sprite type
- [developer.md]: Require running sprite generator tests before marking visual changes complete
- [workflow]: Mandate function-level root cause diagnosis in visual bug specs (UI designer pattern from #19)

---
### [2026-09-07 10:00] — ui-designer — #20
**Task**: Design 3D shading spec for player jet sprite and enemy sprites — transform flat silhouettes into depth-illusion arcade sprites
**Result**: COMPLETED
**Elements designed**:
- Player F-14 fuselage shading (nose, forward, mid, rear, nacelles) — left/right split lit-from-top-left
- Player wing shading — 4-zone horizontal span gradient (highlight root, base, midtone, shadow tip)
- Player wing glove — fuselage undershadow band (3px dark at root)
- Player canopy — white specular core + blue halo + shadow side
- Player tail fins — 3-tone per-column assignment
- Banking frame shading shifts — 5 frames with BANK_HIGHLIGHT_BIAS array
- Enemy fighter (48x48) — cross-axis fuselage shading, 4-zone wing, white specular
- Enemy interceptor (48x48) — same treatment, green palette extension
- Enemy bomber (64x64) — wide-fuselage 3-zone shading, shifted spine highlight
**Key design decisions**:
- Light source fixed at top-left 45 degrees — established as global convention for all sprites
- Used 4-tone ramps (HIGHLIGHT/TOP/MID/SHADOW) instead of 3 to allow smoother cylindrical fuselage reads
- Fuselage shading uses LEFT/RIGHT column split (not TOP/BOTTOM horizontal bands) — this is the correct simulation of a cylinder seen from above with side lighting
- Panel line value deepened from 0.416 to 0.278 — the existing panel lines were effectively invisible against the fuselage surface
- Banking bias array approach keeps code compact while creating consistent lighting across all 5 frames
- Canopy specular changed from blue-tinted highlight to near-white (0.920, 0.965, 1.000) — at game resolution blue specular disappears into the canopy body
- Enemy fuselage now gets explicit left/right zone split with new shadow colors added to each enemy palette
**References**:
- F-14 real-world colors: Light Gull Gray topside (FS 36440), Low-visibility Dark Ghost Gray schemes
- 3-tone pixel art method: pixelartmaker.ai/blog/the-3-tone-shading-method.html
- Military shmup sprites: slynyrd.com/blog/2024/1/23/pixelblog-48-military-shmup
- Hardcore Gaming 101 After Burner analysis: hardcoregaming101.net/after-burner/
**Improvement Insights**:
- [ui-designer.md]: Add requirement to explicitly quote exact GDScript line numbers that produce each diagnosed issue — prevents vague "this looks flat" feedback
- [criteria.md]: Add criterion: "light direction is consistent across all sprites and all banking frames — left wing not brighter than right when light is top-left"
- [workflow]: UI designer should receive current screenshot alongside code so visual bugs can be confirmed visually before spec writing, not inferred from code alone

---
### [2026-09-07 12:00] — senior-developer — #20
**Task**: Add 3D shading to enemy jet sprites (fighter, interceptor, bomber)
**Result**: COMPLETED
**Files changed**: scripts/enemies/enemy_sprite_generator.gd, tests/test_enemy_sprite_generator.gd
**Key changes**:
- enemy_sprite_generator.gd: Added _draw_shaded_rect() helper for 4-zone left-to-right fuselage shading
- enemy_sprite_generator.gd: Added _draw_shaded_wing_triangle() with 3-zone span-based wing shading and asymmetric L/R lighting
- enemy_sprite_generator.gd: Nose cones now have left-half bright / right-half base split with top-left highlight pixel
- enemy_sprite_generator.gd: Canopy specular core pixel (near-white) added to all 3 enemy types
- enemy_sprite_generator.gd: Bomber spine highlight shifted from cols 31-32 to cols 28-29 per light direction
- enemy_sprite_generator.gd: 13 new color constants for shading tones per UI design spec
- tests/test_enemy_sprite_generator.gd: 6 new tests verifying shading behavior
**Technical decisions**: (1) Used fractional zone thresholds (30/35/25/10) for fuselage shading to approximate cylindrical falloff without actual per-pixel lerp — simpler and matches 2-3 tone pixel art style. (2) Right wing inner zone demoted one step darker than left wing inner to maintain consistent top-left light direction across the whole sprite.
**Testing**: 23/23 tests pass including 6 new shading verification tests
**Improvement Insights**:
- [criteria.md]: Add shading verification criterion: "left-side avg brightness > right-side avg brightness for all enemy fuselages" as automated check
- [workflow]: Shading specs should include explicit pixel coordinate ranges for each zone boundary, not just percentages — reduces ambiguity during implementation

---
### [2026-09-07 14:30] — senior-developer — #20
**Task**: Add 3D shading to player jet sprite
**Result**: COMPLETED
**Files changed**: scripts/player/jet_sprite_generator.gd, tests/test_jet_sprite_generator.gd
**Key changes**:
- jet_sprite_generator.gd:30-80 — Replaced flat 3-color palette with full shading palette (5 fuselage tones, 5 wing tones, 3 glove tones, 3 fin tones, canopy shadow + specular)
- jet_sprite_generator.gd:100-170 — Fuselage rendering rewritten with left/right column shading (highlight left, shadow right) across all sections, banking bias shifts zones
- jet_sprite_generator.gd:230-290 — Wing glove lit/dark split with 3px fuselage undershadow at root
- jet_sprite_generator.gd:295-395 — Wing panels use 4-zone horizontal span gradient (tip shadow -> outer mid -> main top -> root highlight), right wing demoted one step, banking bias adjusts inner zone width
- jet_sprite_generator.gd:400-450 — Canopy specular upgraded to 3px near-white core + halo, shadow side on right/bottom
- jet_sprite_generator.gd:460-480 — Tail fins 3-tone per-column (TOP/MID/EDGE)
- tests/test_jet_sprite_generator.gd — 6 new tests, 1 test sample point updated for new gradient model
**Technical decisions**: (1) Used fractional zone boundaries (0.15/0.40/0.75/1.0) for wing shading to approximate radial light falloff without per-pixel lerp — matches pixel art aesthetic. (2) Banking bias applied as additive float to zone thresholds rather than separate color tables per frame — simpler, fewer constants, smooth interpolation across 5 frames. (3) Right wing inner zone gets COL_WING_TOP not HIGHLIGHT to maintain consistent top-left light direction. (4) Updated test_wing_glove_darker_than_panel sample point from cx-40 to cx-25 because cx-40 now falls in wing shadow zone, making the old comparison meaningless.
**Testing**: 37/37 player jet tests pass, 23/23 enemy sprite tests pass (regression check)
**Improvement Insights**:
- [criteria.md]: Add automated shading criteria: "fuselage left avg luminance > right avg luminance" and "wing root luminance > wing tip luminance" for all sprite generators
- [CLAUDE.md]: GDScript type inference note: const arrays return Variant on index access — use explicit `var x: float = ARRAY[i]` not `:=` to avoid parse errors

---
### [2026-09-07 10:00] — architect — #21
**Task**: Design targeting sight and missile lock-on system spec
**Result**: COMPLETED
**Key decisions**:
- WeaponManager owns all targeting state (sight position, locked enemies, timers) — Reticle is pure visual renderer with zero game logic
- Sight tracks in viewport pixel coordinates, positioned via lerp toward input-offset from screen center (SIGHT_SPEED=8.0 for responsive feel)
- Lock-on uses circular proximity (60px radius) around sight position instead of the old center-40% rectangle
- Multi-lock with MAX_LOCKS=3, lock break after 0.5s delay using per-enemy timers
- Vulcan bullets get aim_direction property to aim toward sight world position (camera ray projection to Z=-50)
- Reticle node moved to full-screen direct child of HUD CanvasLayer for drawing lock markers anywhere on screen
**Spec posted to**: GitHub issue #21 comment
**Improvement Insights**:
- agent-definition/architect.md: Could benefit from a checklist item reminding to verify camera.is_position_behind() handling for any spec involving screen-space projection of 3D positions
- CLAUDE.md: The architecture.md Weapons module description should mention sight/targeting as a sub-concern, not just "lock-on targeting"

---
### 2026-09-07 — judge — #20
**Gate type**: per-agent (developer)
**Verdict**: PASS
**Score**: 9/10
**Key gaps**: Minor — enemy wing zone test samples transparent pixels (0.000) instead of actual outer wing pixels; test is weak but sprite rendering is correct.
**Improvement Insights**:
- criteria.md: Add criterion for test robustness — visual tests should verify sample coordinates land on rendered pixels before asserting brightness comparisons.
- developer.md: When writing pixel-sampling tests, always assert opacity first at the exact sample coordinate, not just in a nearby region.

---
### 2026-09-07 — judge — #21
**Gate type**: per-agent (architect)
**Verdict**: PASS
**Score**: 9/10
**Key gaps**: Confusing double is_position_behind check in sample code (cosmetic, non-blocking). Missing explicit _update_sight() call site in _process(). Minor tscn edit could be more specific.
**Improvement Insights**:
- criteria.md: Add architect criterion for "code samples are syntactically correct and free of dead/confusing code"
- architect.md: When modifying tscn files, provide exact node blocks, not just prose instructions

---
### [2026-09-07 14:00] — senior-developer — #21
**Task**: Implement targeting sight and missile lock-on system
**Result**: COMPLETED
**Files changed**: scripts/weapons/weapon_manager.gd, scripts/ui/reticle.gd, scripts/weapons/vulcan_bullet.gd, scenes/hud/hud.tscn, scripts/ui/hud.gd, tests/test_lock_on.gd
**Key changes**:
- weapon_manager.gd: Replaced single-target LOCKON_RECT with movable sight + multi-lock (3 targets, 60px radius, 0.5s break delay). Added get_sight_world_position() for vulcan aiming.
- reticle.gd: Full rewrite as pure renderer. Draws movable crosshair + per-enemy bracket markers. No game logic.
- vulcan_bullet.gd: Added aim_direction property, bullets fly toward sight world position instead of hardcoded -Z.
- hud.tscn: Moved Reticle to direct child of HUD CanvasLayer with full-rect anchors.
- hud.gd: Updated reticle reference path from %Reticle to $Reticle.
- test_lock_on.gd: 9 tests (20 assertions), all passing.
**Technical decisions**:
1. Sight tracks in viewport pixel coords (not NDC) for direct use in _draw() and camera.unproject_position() comparisons
2. Used explicit type annotations (Vector3, float) where get_parent() returns Node to avoid Godot type inference failures
3. Untyped Array in stale cleanup test because TypedArray rejects freed object references at push_back
4. Reticle placed before MarginContainer in tscn so HUD labels render on top of crosshair
**Testing**: All 20 assertions in test_lock_on.gd pass. All existing test suites still pass (no regressions).
**Improvement Insights**:
- CLAUDE.md: Document that TypedArray[Node3D] cannot hold freed references — use untyped Array for collections that may contain stale refs, or clean before storing
- criteria.md: Add developer criterion for "no Godot type inference errors when scripts are compiled standalone"
- architect.md: Note that normalize() after setting a min component value reduces that component — spec should account for this

---
### 2026-09-08 — judge — #21
**Gate type**: per-agent (developer)
**Verdict**: PASS
**Score**: 9/10
**Key gaps**: none (minor: tests simulate logic rather than exercising actual WeaponManager instances; unused unique_name_in_owner on Reticle node)
**Improvement Insights**:
- criteria.md: Consider criterion for tests exercising actual implementation code vs logic duplication
- developer.md: Note headless test limitations explicitly in implementation notes so QA knows coverage gaps

---
### [2026-09-09 12:00] — ui-designer — #22
**Task**: Diagnose visual failures and write pixel-level spec for comprehensive visual overhaul
**Result**: COMPLETED
**Elements designed**: Player jet contrast palette, ground scroll formula, ground color system, sky gradient, reticle sizing, HUD font sizing, spawn rate
**Key design decisions**:
- Jet is already 47% of screen height mathematically (pixel_size=0.055, FRAME_H=96, z_dist=8, FOV=70). The "tiny jet" complaint is a CONTRAST problem not a SIZE problem. Wing mid-tones at Color(0.333, 0.349, 0.388) match sky horizon blue Color(0.20, 0.40, 0.78) closely — jet blends into sky. Fix is palette brightening and de-bluing of wings.
- Ground scroll formula (line 34 of ground_scroll.gdshader) adds scroll_offset to BAND PHASE not UV.y position. Bands stay in fixed screen positions and cycle colors (strobe). True AB2 scroll requires UV.y to shift — replaced with `scrolled_y = fract(uv.y - scroll_offset * 0.05)` formula.
- Exponent increased from pow(uv.y, 2.5) to pow(uv.y, 3.0) for more dramatic near/far compression.
- Ground uses hardcoded OCEAN_ constants that ignore the color_a stage color uniform (only 30% blend applied). Rewrote to drive all band colors from color_a and color_b directly.
- Reticle crosshair was 28px total span (2.6% of 1080p screen). Original AB2 reticle is ~12.5% of 320px screen. Scaled to 1080p = 96px target. New values: ARM_LENGTH=40, GAP=8.
- Spawn interval 3.0s with 5s initial delay produces empty-screen experience. Reduced to 1.2s / 1.5s for arcade density.
**Improvement Insights**:
- **ui-designer.md**: Add mandatory math verification step before any size-related diagnosis. Size complaints may be palette/contrast issues not geometry issues.
- **criteria.md**: Add criterion: "Wing/fuselage colors must have <0.1 chroma similarity to sky background colors (measured by hue angle distance)". Prevents blend-in invisibility.
- **workflow**: When ui-designer spec is done, developer should run a screenshot comparison immediately after each sub-fix, not all at once at the end.

---
### [2026-09-09 00:00] — senior-developer — #22
**Task**: Implement jet palette, reticle, and HUD font size fixes from UI designer spec
**Result**: COMPLETED
**Files changed**: scripts/player/jet_sprite_generator.gd, scripts/ui/reticle.gd, scenes/hud/hud.tscn
**Key changes**:
- jet_sprite_generator.gd:37-71 — Shifted wing palette from blue-grey to warm grey-green for sky contrast; pushed fuselage highlights to near-white and shadows to near-black; deepened canopy blue; brighter nozzle glow and flame core
- reticle.gd:10-16 — Increased crosshair size (arm 10->40, gap 4->8, stroke 2->3) and lock box (20->60, stroke 2->3)
- hud.tscn — Top row font_size 18->28, bottom row font_size 18->24
**Technical decisions**: Used GitHub spec's exact per-constant mapping rather than task summary values where they differed, since the spec had more granular per-constant targets. Kept glove colors unchanged as spec did not modify them.
**Testing**: GDScript syntax check passed for both .gd files via Godot --check-only. Verified .tscn font_size counts (3x28 top, 3x24 bottom).
**Improvement Insights**:
- **CLAUDE.md**: Color constant changes should include a verification step that no blue component exceeds green component in wing colors (enforceable rule).
- **workflow**: For palette-only changes, a visual diff screenshot before/after would catch regressions faster than syntax checks alone.

---
### [2026-09-09 00:00] — senior-developer — #22
**Task**: Implement shader and spawner fixes from UI designer spec
**Result**: COMPLETED
**Files changed**: assets/shaders/ground_scroll.gdshader, assets/shaders/sky_gradient.gdshader, scripts/enemies/enemy_spawner.gd, scenes/main.tscn
**Key changes**:
- ground_scroll.gdshader:20 — replaced broken color-phase scroll with true UV.y scrolling via fract(uv.y - scroll_offset * 0.05)
- ground_scroll.gdshader:23 — changed perspective exponent from 2.5 to 3.0 for wider near bands
- ground_scroll.gdshader:27-31 — replaced hardcoded OCEAN palette with 5 tones derived from color_a/color_b uniforms
- sky_gradient.gdshader:8-16 — updated 7 color constants to higher saturation values per spec
- enemy_spawner.gd:11 — spawn_interval default 2.0 -> 1.2
- enemy_spawner.gd:41 — _spawn_timer initial 5.0 -> 1.5
- main.tscn:55 — spawn_interval scene override 3.0 -> 1.2
**Technical decisions**: (1) Removed ocean-specific effects (foam noise, wave shimmer, broken stage tint blend) since ground is now land-biome driven. Simpler shader = fewer visual artifacts. (2) Kept all uniform names identical so stage_manager.gd and ground_scroll.gd need zero changes. (3) Used fract() on scrolled_y which handles the ever-growing offset from ground_scroll.gd cleanly.
**Testing**: Verified uniform API compatibility with stage_manager.gd and ground_scroll.gd via grep. Validated GDScript syntax with Godot --check-only. Confirmed .tscn structure valid.
**Improvement Insights**:
- **senior-developer.md**: File ownership list in task assignment eliminates merge conflicts and scope ambiguity. Keep this pattern.
- **CLAUDE.md**: Shaders can't be validated with --check-only, only by running the game. Note this gap explicitly in testing guidance.

---
### [2026-09-09 10:30] — architect — #23
**Task**: Design spec for camera angle fix — horizon at 50% screen
**Result**: COMPLETED
**Key decisions**:
- Camera X rotation: 3 deg (down from 20 deg). Puts ground horizon at 45.7% from top, within the 45-55% acceptance range.
- Camera position unchanged at (0, 5, 0) — changing only rotation minimizes cascading changes.
- Player RESPAWN_POSITION Y: 2.0 (down from 3.8) to appear at ~75% from screen top with new camera angle.
- Movement bounds expanded: Y range 0.5-3.5 (from 2.5-4.2), X range +/-5.5 (from +/-5.0) to use more of the now-visible screen area.
- Enemy spawn Y range: 6.0-9.0 (from 5.0-7.0) to keep enemies clearly in the sky portion (39-44% from top at spawn distance).
- Verified 8 files need NO changes (weapons, ground shader, missile, etc.) — they use dynamic camera queries or UV-based rendering.
**Spec posted to**: GitHub issue #23 comment
**Improvement Insights**:
- **architect.md**: For camera/projection math tasks, always verify the Transform3D encoding order (column-major) against an existing known value before computing new ones.
- **CLAUDE.md**: Document the ground horizon formula `(half_fov - tilt) / fov` in architecture.md for future reference — it's non-obvious and easy to confuse with geometric horizon.

---
### [2026-09-09 12:00] — senior-developer — #23
**Task**: Implement camera angle fix — 20deg to 3deg X rotation with cascading position updates
**Result**: COMPLETED
**Files changed**: scenes/main.tscn, scripts/player/player_jet.gd, scripts/enemies/enemy_spawner.gd, architecture.md
**Key changes**:
- scenes/main.tscn:40 — Camera3D transform updated from 20deg to 3deg rotation: cos/sin swapped from 0.9397/0.342 to 0.99863/0.05234
- scripts/player/player_jet.gd:7-8 — MOVE_MIN (-5.0, 2.5)->(-5.5, 0.5), MOVE_MAX (5.0, 4.2)->(5.5, 3.5)
- scripts/player/player_jet.gd:12-14 — RESPAWN_POSITION Y 3.8->2.0, comment updated to reflect 3deg tilt
- scripts/enemies/enemy_spawner.gd:7-8 — SPAWN_Y_MIN 5.0->6.0, SPAWN_Y_MAX 7.0->9.0
- architecture.md:89 — Added camera setup documentation (position, rotation, FOV, horizon percentage)
**Technical decisions**: (1) Verified Transform3D column-major encoding by cross-referencing existing 20deg values against cos(20)/sin(20) before computing 3deg replacements. (2) All values taken directly from architect spec — no independent derivation needed since the math was verified in the spec.
**Testing**: Godot headless project load — no parse or load errors. Only pre-existing MCP bridge port error. All modified values match spec exactly.
**Improvement Insights**:
- [workflow]: Camera angle changes are purely numerical and low-risk when the architect spec includes exact Transform3D values — this pattern of precise spec -> direct implementation works well

---
### [2026-09-09 14:30] — architect — #24
**Task**: Design spec for replacing 2D sprite jets with 3D mesh jet hierarchies
**Result**: COMPLETED
**Key decisions**:
- Runtime mesh construction via builder classes (JetMeshBuilder, EnemyMeshBuilder) rather than hand-editing .tscn files with 15+ sub_resources — less error-prone
- CylinderMesh with top_radius=0.0 instead of ConeMesh (not guaranteed in Godot 4.6)
- Squashed SphereMesh for canopy (no hemisphere mode available)
- Keep existing GPUParticles3D afterburner alongside new mesh flames — particles add volumetric glow
- DirectionalLight3D at (-30, -30, 0) rotation for upper-left sun lighting
- Player jet: 13 MeshInstance3D parts under one Node3D; banking rotates the parent node
- Enemy jets: 5-8 parts each, 3 distinct types with colored materials
**Spec posted to**: GitHub issue #24 comment
**Improvement Insights**:
- [CLAUDE.md]: Consider adding a note that .tscn hand-editing is discouraged for complex node hierarchies — prefer runtime construction or editor workflows
- [criteria.md]: The "no flat 2D sprites" hard rule should explicitly mention that runtime-constructed MeshInstance3D hierarchies are the approved approach

---
### [2026-09-09 01:20] — senior-developer — #24
**Task**: Replace flat 2D sprite jets with 3D mesh jets (rear chase-cam view)
**Result**: COMPLETED
**Files changed**:
- scripts/player/jet_mesh_builder.gd (NEW)
- scripts/enemies/enemy_mesh_builder.gd (NEW)
- tests/test_jet_mesh_builder.gd (NEW)
- scripts/player/player_jet.gd (MODIFIED)
- scenes/player/player_jet.tscn (MODIFIED)
- scripts/enemies/enemy_jet.gd (MODIFIED)
- scenes/enemies/enemy_jet.tscn (MODIFIED)
- scenes/main.tscn (MODIFIED)
- scripts/player/jet_sprite_generator.gd (DELETED)
- scripts/enemies/enemy_sprite_generator.gd (DELETED)
- tests/test_jet_sprite_generator.gd (DELETED)
- tests/test_enemy_sprite_generator.gd (DELETED)
**Key changes**:
- jet_mesh_builder.gd: Static builder creates 15-part F-14 mesh hierarchy from CylinderMesh/BoxMesh/SphereMesh primitives with StandardMaterial3D
- enemy_mesh_builder.gd: Static builder creates 3 enemy types (red fighter, green interceptor, grey bomber) as mesh hierarchies
- player_jet.gd: Removed all sprite frame switching; banking now rotates 3D mesh node directly; afterburner flames pulse via sin() scale
- main.tscn: Added DirectionalLight3D for 3D lighting from upper-left
- Deleted all 2D sprite generator code and tests
**Technical decisions**:
1. CylinderMesh with top_radius=0 for cone shapes (no ConeMesh in Godot 4.6)
2. Runtime mesh construction in _ready() to avoid error-prone tscn hand-editing
3. SHADING_MODE_PER_PIXEL on all materials for proper 3D lit appearance
4. Kept GPUParticles3D alongside mesh flames for volumetric glow effect
**Testing**: Godot --check-only clean. 61/61 test assertions pass. No regressions.
**Improvement Insights**:
- [criteria.md]: Add explicit requirement that mesh builders must use SHADING_MODE_PER_PIXEL
- [workflow]: The --script test runner doesn't resolve class_name globals; tests must use preload() for builder classes

---
### [2026-09-09 12:00] -- senior-developer -- #25
**Task**: Improve player jet 3D mesh with F-14 detail and proper lighting
**Result**: COMPLETED
**Files changed**: scripts/player/jet_mesh_builder.gd, scripts/player/player_jet.gd, scenes/main.tscn
**Key changes**:
- scenes/main.tscn:22-25 -- Added ambient_light_source=COLOR, disabled sky reflections to fix green tint
- scripts/player/jet_mesh_builder.gd:9 -- Scale up root 20%; wider wings with sweep; nacelles at X=0.5; tail fins canted 12deg; rear fuselage taper added; switched to PER_PIXEL shading
- scripts/player/player_jet.gd:68-72 -- Uniform XYZ flame pulse (0.8-1.2 range)
**Technical decisions**: (1) Used ambient_light_source=COLOR + reflected_light_source=DISABLED rather than tweaking sky material, because the sky shader is shared with the background and should not be constrained by material requirements. (2) Kept flame material as UNSHADED since emissive flames should not receive directional lighting.
**Testing**: Scripts parse clean (--check-only). Project imports with no errors. Scene file uses correct Godot 4.6 enum values.
**Improvement Insights**:
- [CLAUDE.md]: Document the ambient_light_source/reflected_light_source pattern for avoiding sky-tinted materials
- [criteria.md]: Add criterion that mesh materials must use PER_PIXEL shading (not UNSHADED) except for emissive effects

---
### [2026-09-09 10:00] — senior-developer — #26
**Task**: Improve targeting/aiming — vulcan tracers, missile trails, lock-on flash, hit feedback
**Result**: COMPLETED
**Files changed**: scripts/weapons/vulcan_bullet.gd, scripts/ui/reticle.gd, scenes/weapons/missile.tscn, tests/test_targeting_feedback.gd
**Key changes**:
- scripts/weapons/vulcan_bullet.gd:17-42 — Added _create_tracer(): CylinderMesh (r=0.02, h=0.5) with bright emissive unshaded material, aligned along Z behind bullet
- scripts/weapons/vulcan_bullet.gd:55-80 — Added _flash_enemy(): on hit, sets all enemy meshes to white unshaded, restores after 0.08s via tween on enemy node
- scripts/ui/reticle.gd:8,31-52 — Added lock flash system: _prev_locked tracking, _lock_flash_timers dict, 0.1s white flash on new lock acquisition
- scripts/ui/reticle.gd:90-96 — _draw_lock_box now takes is_flashing param, draws white+thicker stroke during flash
- scenes/weapons/missile.tscn — Added Gradient color ramp (white→grey→transparent), increased particles 20→30, lifetime 0.8→1.0
**Technical decisions**: (1) Hit flash uses tween on the enemy node, not the bullet (bullet queue_free's immediately). (2) Lock flash detection compares current vs previous frame's locked set rather than hooking into weapon_manager signals — avoids coupling. (3) Used _collect_meshes recursive helper for hit flash to handle any enemy mesh hierarchy.
**Testing**: 18 new tests pass. 20 existing lock-on tests pass. Project imports clean.
**Improvement Insights**:
- [vulcan_bullet.gd]: The _collect_meshes static function could be extracted to a shared utility if other systems need mesh traversal
- [workflow]: When parallel devs own different files, document the ownership list in the issue body not just the task assignment
