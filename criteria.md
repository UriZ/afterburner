# Quality Criteria

## THE ONE RULE THAT OVERRIDES EVERYTHING

**The game must look and feel as close as possible to the original After Burner II arcade game.**

This is the ONLY criterion that matters. Every decision — mesh design, movement, effects, colors, HUD, sound — must be evaluated against one question: **"Does this look and feel like After Burner II?"** If the answer is no, it fails. Period.

- "The code works" doesn't matter if it doesn't look like AB2.
- "The parameters are correct" doesn't matter if the result doesn't feel like AB2.
- "It technically meets the spec" doesn't matter if a player wouldn't recognize it as AB2.

**Every agent** (designer, developer, judge, QA) must internalize this. Watch the gameplay videos. Study the reference screenshots. Compare EVERY visual element against the original. The gap between our game and AB2 is what we're closing. Nothing else matters.

---

This file defines what the judge agent evaluates against. Three layers: project-level, per-role, and per-task.

## Judge Configuration

```
STRICTNESS: paranoid
GATE_MODE: blocking
SCORE_THRESHOLD: 9
MAX_RETRIES: 5
JUDGE_TL: true
```

## Reference Material

The judge and QA MUST view ALL reference images and videos (Read tool) before every visual evaluation. Compare our game frame-by-frame against these references. If the gap is large, FAIL.

### Reference Screenshots (ALL MANDATORY — view every one before evaluating)

| File | Shows | Key Details |
|------|-------|-------------|
| `assets/reference/ab2-arcade-desert.png` | Desert stage, standard gameplay | Ground colors, horizon position, jet size, HUD layout |
| `assets/reference/ab2-arcade-desert-explosions.png` | Desert stage with multiple explosions | HUGE puffy white/yellow explosion clouds, chaotic screen, multiple enemies |
| `assets/reference/ab2-arcade-night-banking.png` | Night stage, F-14 banking | Dark ground with city lights. NOTE: the large fireball here is a flak burst the jet is flying through, NOT afterburner. Do not cite it as flame reference. |
| `assets/reference/ab2-arcade-closeup-enemies.jpg` | Close-up with enemy jets | Large dark-green enemy jets with detail, massive explosion filling half the screen, F-14 dorsal view with shading |
| `assets/reference/ab2-arcade-coastal-banking.jpg` | Coastal stage, F-14 banking | Rocky terrain, ocean, blue enemy jets, green ground — shows terrain variety and banking |
| `assets/reference/ab2-arcade-night-missiles.jpg` | Night stage with missile trails | Missile smoke trails, enemy approaching. NOTE: the long streak is a missile exhaust trail from a wingtip pylon, NOT engine flame. Do not cite it as flame reference. |
| `assets/reference/ab2-arcade-city-stage.jpg` | City/forest stage with explosions | Buildings below, green terrain, blue enemies, mid-air explosions — shows stage variety |
| `assets/reference/ab2-arcade-reload-dorsal.jpg` | Reload screen, F-14 dorsal close-up | Best reference for F-14 shape from behind — wing sweep, tail fins, canopy, panel lines |
| `assets/reference/ab2-arcade-huge-explosion.jpg` | Massive explosion filling screen | Orange/yellow puffy cloud covering 80%+ of screen — THIS is how big explosions should be |

### Reference Videos (MANDATORY — not optional, not "for context")

**ALL agents doing ANY visual work MUST watch these videos.** Screenshots alone do NOT capture speed, timing, movement, or gameplay feel. Skipping video review = incomplete work = FAIL.

- After Burner II 60 FPS Longplay: `https://www.youtube.com/watch?v=65weTx0haog`
- After Burner II Arcade Gameplay: `https://www.youtube.com/watch?v=8d-S1kcjieA`
- After Burner II Arcade Longplay: `https://www.youtube.com/watch?v=W2loyeq9pDA`

**Burst-frame limit (#113)**: extracted burst stills (0.25s apart) are ground truth for **scaling rate, pose, and composition only — never speed**. AB2's ground texture temporally aliases below ~60fps sampling, so no sub-60fps frame comparison supports a speed claim. Speed judgements require the 60fps pipeline (#114) or human review of real video. Do not PASS or FAIL "sense of speed" from burst frames.

Sources: [LaunchBox Games Database](https://gamesdb.launchbox-app.com/games/images/7687-after-burner-ii), [Games Database](https://www.gamesdatabase.org), [Internet Archive](https://archive.org)

## Hard Rules (automatic FAIL if violated)

> **Median rule (#135/#120)**: when an AC or constant leans on a median, publish the per-frame spread beside it — this project's medians sit over distributions with 4-10x spreads.
>
> **Spread rule (#127)**: a measured claim verified on ONE sample is not verified — any gate or calibration that licenses future numbers must be demonstrated across a spread of inputs with the pass rate reported (#125's gate pass was correct, reproducible, and generalized to 3 of 10 windows).
>
> **Measurement publication rule (#120 rework)**: any colour or threshold measurement published as gate evidence must state its distance METRIC and TOLERANCE, and the exact classifier/command so the other side can re-run it. An unpublished classifier cost a full gate cycle — the same estimator legitimately gives 10.2 or 15.6 %H depending on a free parameter neither side had stated.


> TODO (TL, from #120-#122 spec retro): rules 2, 5, 8, 11 + #124's biome identity all partly govern ground/composition and overlap — consolidate into one ground section on the next criteria pass so defects can't fall between rules.


1. **No un-dodgeable deaths** — every death preceded by a visible threat with a >=0.5s avoidance window. Idle-survival time is not itself a criterion.
2. **Ground must show depth-correct parallax STRUCTURE, evaluated as scale — not measured as frame-to-frame speed.** Check that texture features grow and spread correctly with depth within single frames (near features larger and coarser than far), and that features visibly persist and approach across frames rather than regenerating as noise. Do NOT measure per-band pixel shift at sub-60fps — that is a speed measurement, which temporal aliasing makes unreliable (#113: per-band flow on the ARCADE ORIGINAL at 15fps measures higher far than near, so the old monotonic-shift rule fails AB2 itself). Frame-to-frame shift measurement is gated on the 60fps pipeline (#114). The old 'stripe positions must differ' rule passed on pure noise regeneration and must not be reinstated.
3. **Reference screenshots are the primary truth source** — written descriptions can be wrong. Always look at actual images.

## Judge Mandatory Procedure

1. **Read this file** (criteria.md)
2. **View ALL 9 reference screenshots** with the Read tool (every file in `assets/reference/`)
3. **Capture gameplay VIDEO** (MANDATORY — not optional): `bash .claude/skills/game-video/capture-video.sh --start-game --duration 15 --playback-fps 15 --output /tmp/game-capture/judge-video.mp4` — encoded at the rate actually achieved, so playback speed is true (#116); canonical form in `.claude/skills/game-video/SKILL.md`
4. **Build an aligned motion strip** (MANDATORY when the issue touches motion, pacing, or composition): `bash .claude/skills/motion-metrics/compare.sh --ref .reference-cache/video/ab2-longplay.mp4 --ref-window 6:00-6:10 --game /tmp/game-capture/judge-video.mp4 --name judge-<issue>` — then Read every `strip-NN.png` and compare the same cell index across rows. Strips are evidence about composition and pose, NEVER about speed (#113; see `.claude/skills/motion-metrics/SKILL.md`)
5. **Capture frame sequence** for detailed analysis: `bash .claude/skills/game-capture/capture.sh --start-game --frames 10 --interval 500`
6. **View ALL captured frames** with the Read tool
7. **Compare EVERY element** against ALL references — jet appearance, colors, ground, enemies, explosions, screen busyness, HUD
8. **Be brutally honest** about the gap between our game and the references

**Both video AND frame captures are REQUIRED. Skipping either = incomplete evaluation.**

**Code that compiles and passes tests but looks bad is a FAIL.** The judge evaluates the VISUAL RESULT, not the code quality.

**Placeholder quality is not shippable quality.** Geometric primitives (cylinders, boxes) that don't read as aircraft = FAIL.

---

## What After Burner II Actually Looks Like (from the reference screenshot)

The judge MUST internalize these visual standards. This is what we're trying to match:

### Player F-14 Tomcat
- **Viewed from behind and slightly above** — you see the full dorsal surface
- **Bright white/light grey** fuselage with visible panel line shading and color variation
- **Swept wings** clearly visible extending to both sides — NOT rectangles, they have aerodynamic planform
- **Twin vertical tail fins** prominent at the rear
- **Cockpit canopy** visible as a dark bubble on top of the fuselage
- **Non-numeric silhouette checks (numbers alone lie — cycle 1 measured 35.9%W/17.6%H/2.92 aspect, ALL in target, on a jet that read as origami)**: viewed from astern, the topmost pixel region must be the canopy (no projecting needle nose visible from behind); nacelles visually joined to a fuselage with MASS; body shows a value gradient (shaded, not flat 2-tone); verify by 2x crop against `ab2-arcade-reload-dorsal.jpg`. Jet renders fully OPAQUE at all times during normal play.
- **Nose/radome** — applies to enemy jets and any non-astern view only. For the PLAYER jet in the dead-astern chase view, the nose forward-extent is effectively ZERO: the topmost pixel of the aircraft in every clean reference frame is the canopy, not a radome. Drawing a projecting nose on the player jet = FAIL (it is the main cause of the paper-dart silhouette). Where the radome IS visible, it is a wide, smooth, bullet-shaped taper — never a needle or spike.
- **Every major component must be shaped AND proportionally correct.** Nose, canopy, wings, intakes, nacelles, tail fins, nozzles — each needs correct proportions relative to the whole aircraft, verified against real aircraft photos AND arcade references. A mesh with good wings but a wrong-proportioned nose is half-finished = FAIL.
- **Engine nozzles read as large hot-cored glowing discs** — dark rim with a hot orange/red/yellow centre. There is NO exhaust plume or ribbon. Verified across every motion burst and all 9 statics: the original has no engine flame trail. A long flame plume = FAIL.
- The jet is **WIDE and FLAT** — 35-37% of screen WIDTH, aspect ratio ~3.4-3.6:1 (RE-DERIVED #112: the old 2.8-3.1 target was produced by the defect itself — the needle-nose spike added height; the reference's own row scan gives 3.47. When a numeric criterion and a qualitative one contradict, the numeric one is more likely wrong — it was probably measured from our own broken output). Do NOT use a height-only rule; a 25-30%-height jet reads as a paper dart. NOTE: an earlier 50-55% width figure was a measurement error — a value-threshold bbox on burst-c-02 swallowed the stone wall behind the jet.
- The jet has **visual detail and shading** — it is NOT a flat-colored 3D shape. It has highlights, shadows, panel lines, color variation across the surface

### Enemy Jets
- At distance: **tiny bright-colored dots/silhouettes** (2-4 pixels) that are clearly high-contrast against the sky
- As they approach: **scale up smoothly** to medium-large sprites with clear aircraft shapes
- Colors are **VIVID and saturated** — bright red fighters POP against any background
- At close range: recognizable aircraft with wings, fuselage, tail — NOT cylinders with boxes
- Multiple enemies visible simultaneously — the sky should feel crowded

### Ground
- **Dense, textured terrain** with strong perspective compression
- NOT just two-color bands — the original has richly detailed ground with visible terrain features
- **Perspective convergence** — wide bands near camera, compressed at horizon
- The ground creates an overwhelming sense of SPEED — it rushes past

### Explosions
- **HUGE puffy white/yellow clouds** — each explosion fills 15-25% of screen
- Multiple explosions visible simultaneously
- Bright white center, yellow middle, orange/red edges
- They are a major visual feature — satisfying, dramatic, screen-filling

### Screen Composition
- **The screen is NEVER empty.** Every frame has enemies, explosions, missiles, or projectiles
- **Horizon at 60-65% from top** — more sky than ground
- **Colors are saturated and bold** — deep blues, hot oranges, bright reds, vivid greens
- The overall feel is CHAOTIC, FAST, EXCITING

### HUD
- **Arcade typography** — bold, blocky, high-contrast
- Score in bright yellow/gold numbers
- Red and yellow label colors
- Speed bar at bottom with colored segments
- Missile count with visual indicators (not just a number)
- Lives shown as small jet silhouettes

---

## HARD RULES — Automatic FAIL if violated

**RULE ZERO — whole-frame comparison comes first.** Before measuring any attribute, put a full captured frame of our build beside a full reference frame and answer one question: *do these look like the same game?* Name every difference you see, ranked by how much of the screen it affects. Only then measure.

Attribute measurement is a check on a judgement already made by eye — never a substitute for it. Worked example (#121): SEVEN object statistics all matched the arcade while the ground demonstrably read wrong; the three that discriminate (features >=8%W: ours 0 vs arcade 1-5; max width; small-object count ours ~2x arcade) had to be found by measuring, not assumed. SECOND worked example (#121 amendment 2): after fixing the window operator and normalizing by band area, ALL TWELVE metrics overlap — no near-band object statistic discriminates our ground from the arcade at all, while the eye still does instantly; the whole-frame gate is therefore judgement-binding with measurements as context, and any future attempt to re-automate it must first demonstrate a discriminator the reference passes. A build can pass every numeric target and still look wrong: aspect 2.92 vs 2.95, wingspan 36.25% vs 35.6%, saturation 0.853 vs 0.867 all passed while the ground read as foam bubbles and the jet read as a sticker. Measuring a proxy cannot detect a defect the proxy does not cover, and no attribute rule covered ground feature size — the single most damaging error on screen.

Never evaluate a cropped subject alone. Composition defects live between elements.


0. **No un-dodgeable deaths.** Every death must be preceded by a visible approaching threat with a >=0.5s reachable avoidance window. Idle-survival duration is NOT a criterion — an arcade game may legitimately kill a player who never moves. For visual evaluation, use a capture mode so lethality never truncates a review.

1. **Jets must look like aircraft with visual detail.** A flat-shaded cylinder with box wings is NOT acceptable even if it's "recognizable." The jet must have visible surface detail: color variation across the body, highlight/shadow areas, panel-line-like color breaks. Compare to the reference screenshot — the original sprites had shading and detail despite being 320x224 pixels. Our 3D meshes at modern resolution should look AT LEAST as detailed.

2. **Engine nozzles must read as hot-cored glowing discs.** Dark rim, hot orange/red/yellow core — NOT a white disc with an orange ring (that is inverted). There is no exhaust plume in the original; drawing one = FAIL.

3. **The ground must create speed.** If the ground looks static or slowly drifting, FAIL. The original made players feel "nauseated" from speed.

4. **Screen must be busy.** At any point during gameplay, the screen should feel chaotic with enemies, projectiles, or explosions. Empty sky with just one jet = FAIL.

5. **Horizon position must match the reference for the SAME kind of stage — it is stage-dependent, not fixed.** Level cruise stages measure 60-65% from top (burst-a-02, burst-b-03: more sky than ground), but e.g. Stage 8 desert canyon puts the horizon near 10% with ground filling ~85% of frame (#113 judge measurement at 6:00-6:10). Compare against the matching biome/flight-attitude reference, per-biome like rule 7 does for saturation. The jet sits in the bottom 25% in level cruise.

6. **Sky matches the reference's real shape: flat fill + optional tight glow + hard horizon.** Measured from all 50 longplay frames (#115): AB2's sky is a FLAT fill; many stages are flat edge-to-edge with NO glow and NO haze band (snow `#b7d3d6`, blue day `#0092f7`, pixel-identical top to ground). Where a glow exists it occupies only the last ~20% of sky height and is a HUE shift at held saturation (desert H29°→H52°, S pinned 1.00, V 0.90→0.98), not a brightness ramp. The horizon is a hard 6-20px cut. Per-biome measured anchors live in the `stage_data.gd` header. A whole-sky smooth gradient, a soft/hazy horizon, or an RGB-lerp passing through desaturated grey = FAIL.

7. **Colors must match the reference stage-for-stage — and "the equivalent reference stage" must be PROVEN, not assumed.** Before any per-stage color validation, establish the reference frame's stage identity with evidence (HUD stage number visible in frame, score continuity, or verified position in the longplay timeline) and cite it. Matching our stage N pixel-perfectly to an UNIDENTIFIED reference frame is how #115 passed two gates while stage 1 shipped a brown sky the user caught in seconds — the arcade's stage 1 is blue (#123). Then measure mean HSV saturation against that verified stage — do NOT apply a flat floor. Desert measures S~0.87-0.90; snow measures S~0.14. A flat threshold wrongly fails a correct snow stage. Muted output on a stage whose reference is vivid = FAIL. A biome/palette match to the wrong stage = FAIL.

9. **No rendering artifacts.** Seams, tearing, Z-fighting, flickering, or visual glitches of any kind = FAIL.

8. **Enemies must occupy the SKY.** They appear at the horizon and scale up through the sky above it. A sustained stretch of capture with zero enemy pixels above the horizon line = FAIL. Measure it: count enemy pixels above the horizon across a capture. The original's action happens in the sky, not along the ground. PER-BIOME QUALIFICATION (like rule 5): on low-horizon canyon stages (8, 17 — sky ~4-14%H per verified frames) measure enemy presence against the MATCHING reference stage, not the cruise-stage expectation; a correct canyon stage must not fail this rule for having little sky.

10. **Explosion type must match the target.** Aircraft kills are pale cream/near-white cauliflower puffs at ~10-12% screen height with NO orange or red (desert-explosions.png, closeup-enemies.jpg). Orange/red fireballs are for ground and large impacts ONLY (huge-explosion.jpg, burst-c-10). Using a fireball for every kill = FAIL.

11. **Ground feature size, edge hardness, brightness — measured against the reference IN THE SAME EVALUATION.** STANDING RULE (three baked literals have now pushed the shader the wrong way): any numeric target in a ground criterion must be a TWO-SIDED comparison against a gate-time reference measurement — never a one-sided floor or a baked constant. Do not bake numeric literals into this file; two successive gates produced conflicting brightness targets (0.67-0.69 vs a directly measured 0.569) and the baked number drove the shader brighter than the arcade original. At gate time: measure the equivalent reference band (feature diameter distribution, mean |grad| and frac(|grad|>0.05) for edge hardness, mean V) and compare ours to it. Shape regularity is part of this rule: matching size/edge/brightness proxies while every feature is the same lozenge still fails — require varied feature outlines. COLOUR: one dominant hue family with variation expressed as VALUE steps within it — but measure the dominance FRACTION on the verified matching reference stage AT GATE TIME, never against a baked number: a previously-baked '89.2% in one 20-degree bin' did not reproduce (cycle-1 independent measure on verified stage-2 desert: 72.0% and 53.6%) and would have passed ours at 99.4% — MORE monochrome than the arcade. Being more uniform than the reference is also a FAIL. A prior '>=3 hue clusters' version produced a confetti ground and is retired; this is the second baked literal in this rule to push the shader the wrong way. Round-5 reference near-band data points: median feature ~0.7-0.9%W, mean|grad| 0.078-0.090, frac>0.05 0.64-0.73, mean V 0.569.

12. **Effects must be OPAQUE with fine-grained fringes.** Banning draw_circle was too narrow — polygons reproduced the same defect. The real requirements: (a) explosion bodies are opaque AND carry no translucent halo discs or geometric circles beneath/around them — and an ALPHA-FADE over a saturated background IS this violation (cream at partial alpha over blue sky reads as a cyan halo, #134); effects dissolve by shrinking GEOMETRICALLY at full opacity, never by alpha — 'body is opaque' alone let a cyan halo disc through (cycle-1 gap 11); background must not show through centres, gaps, or halos — reference puffs are solid cream on nothing, (b) perimeter detail at the 4-6px bump scale, not 40px facets, (c) death fireballs are irregular ROUNDED lobes, fully opaque, with 2-4px internal mottle — NOT a geometric starburst polygon; 'tongues' implemented as straight triangular spikes is exactly the failure mode this rule exists to stop. Measure fringe bump scale against the reference explosion crops. Interior: explosion bodies must contain >=8 distinct value levels by histogram — dozens of overlapping blobs with scattered hot cores and dark shading, per the reference; a 2-3 flat-fill construction is an automatic FAIL regardless of outline shape.

14. **HUD element parity.** Any HUD element present in 100% of reference frames must exist in ours. Example: the bracketed target box (~13% of screen width) was missing for five rounds because no rule named it. The reference has BOTH: a fixed top-right bracketed scope box (every frame; measured 77.3-87.6%W x 10.4-21.7%H with four 17x17px L-brackets, #129 median composite) AND moving in-field lock brackets. Require both — a prior amendment treating them as one moving element caused the fixed box to be dropped. HUD geometry acceptance tests must constrain BOTH axes — a spec published y extents and tested only x, invisible until ACs were read against the measurements side by side (#129 gate). Also: 'HI <score>' does not appear top-right on AB2's play screen.

16. **Weapons must demonstrably work.** Firing the vulcan must produce a visible tracer within 2 frames, and a 15s active-fire capture must produce at least one scoring kill. Three gates passed visual work while the guns did nothing — no visual criterion is meaningful if the player cannot shoot.

17. **The world must ROLL with bank — measured in DEGREES, the unit the renderer controls.** Measured on verified stage-1 footage (42 clean fits, #128 spec): rigid rotation about screen centre (0.51W, 0.49H), roll spanning −6.2° to +67.9°, saturating 65–68°, median rate while rolling 74.5°/s; HUD stays screen-fixed. Requirement (CRUISE stages only — canyon stages 8/17 measure just −8.2° to +16.2°, mostly ±2°, per 37 fits; demanding cruise roll there would demand something the arcade doesn't do): peak world roll ≥50° during a held turn (reference reaches 68°); level cruise within ±5°; never exceeding ~2° under held bank on a cruise stage = FAIL. On canyon stages, compare against the canyon reference range. (The rule's original %W statement was tan-based and non-linear — its own cited maximum was only 30°; a build at half the arcade's roll would have passed. State visual thresholds in the units the code sets.)

18. **Clouds are objects in the sky, not a sky gradient.** Stages whose verified reference frames show cloud banks must render them, scaling/scrolling consistently with depth. Rule 6's flat-fill sky is not licence for an empty sky.

15. **Sky population.** Enemies-above-horizon is not enough: the reference shows 4-6 enemy silhouettes simultaneously at varied sizes and bank angles, plus flak and tracer fire. Measure enemy pixel counts in the sky region across a capture; a sky that is empty or near-empty in a meaningful fraction of frames = FAIL.

13. **Player screen occupancy.** The player jet must be on screen in >=90% of frames across a capture. Composition cannot be evaluated, and the game does not read as AB2, when the death/respawn gap leaves the frame empty for long stretches.

8. **Player jet must move freely across the screen.** The jet must be able to reach all areas of the viewport, not be stuck at the bottom. Compare to AB2 — the jet roams the full screen.

---

### Visual Fidelity (Critical — all must pass)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Player jet has visual detail | Must have color variation, shading, highlights — NOT a single flat color. Multiple material colors on the fuselage (light top, darker sides). Canopy must be a distinct color. Wing undersides slightly different from tops. |
| 2 | Player jet proportions | Span 35-37% of screen width; aspect ~3.4-3.6:1 (re-derived from the reference row scan, #112 — the old 2.8-3.1 encoded the needle-nose defect) — measured at LEVEL pose only. An axis-aligned bbox balloons under bank from rigid rotation alone (bank=15 reads ~22%H on correct geometry); control for bank before failing this. |
| 3 | Engine nozzles correct | Dark rim, hot orange/red/yellow core. No exhaust plume or ribbon of any length. |
| 4 | Enemy jets are vivid | Saturated colors that POP against any background. Red fighters should be BRIGHT red (not dark red). At close range, clearly aircraft shapes. |
| 5 | Ground creates speed | Strong perspective compression. Dense pattern. Fast scrolling. "Nauseating" speed sensation. |
| 6 | Explosions are dramatic | Aircraft-kill puffs ~10-12% screen height (opaque cream cauliflower); death/large-impact fireballs 15-25% with radiating tongues. Multiple visible simultaneously. |
| 7 | Bold arcade colors | Compare to reference. Vivid saturated colors throughout. No grey, muted, or washed-out areas. |
| 8 | Composition matches AB2 | Horizon 60-65% from top (more sky than ground). Jet in bottom 25%. |
| 9 | Super Scaler scaling | Enemies scale from dots at horizon to large aircraft. Smooth, dramatic. |
| 10 | Screen is chaotic | Never calm. Multiple visual elements competing for attention. Arcade energy. |

### Gameplay Feel (Critical)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Arcade energy | Screen BUSY — multiple enemies, projectiles, explosions simultaneously. Never calm or empty. |
| 2 | Lock-on feedback | Clear visual + audio when missile lock acquired. Single target lock with crosshair color change. |
| 3 | Weapon satisfaction | Vulcan tracers visible, missiles trail smoke, enemies react on hit. |
| 4 | Responsive controls | Zero input lag. Jet moves immediately with input. |
| 5 | Aiming works correctly | Single crosshair, locks one enemy, missiles track locked target. |

### Audio (High)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Music plays | Selected track plays and loops. Energetic tempo. |
| 2 | SFX match actions | Weapon fire, explosion, lock-on all have distinct sounds. |

---

## Per-Role Criteria

### Developer

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Matches spec | Critical | Implementation matches spec exactly |
| 2 | Runs in Godot | Critical | Opens and runs without errors in 4.6.2 |
| 3 | Feature works | Critical | Actually functions as specified |
| 4 | LOOKS RIGHT | Critical | View ALL references in `assets/reference/` AND gameplay videos. Does your output look like After Burner II? If not, FAIL. Code that works but looks wrong = FAIL. |
| 5 | Tests present | High | Tests for core logic. Any NEW test must be shown to FAIL on the broken input it guards against (negative control) — this caught real defects three times in one session (motion-metrics race, #118 suite guard, #114 keycode probe) |
| 6 | No scope creep | High | Only what was specified |
| 7 | Idempotent outputs | High | Re-running a tool into an existing output directory must not leave artifacts from the previous run — the directory must match the latest run alone (#113: stale strips read as current evidence). If the workflow allows concurrent reuse of a stable output name, concurrent runs must not silently corrupt outputs (#119) — test sequential AND concurrent reuse. Any tool producing judge/QA evidence must be checked for "can it ever exit 0 with output an agent cannot use" — silent success with unusable output is worse than a crash (#113 stale strips, #119 torn strips) |

### QA

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | View ALL references | Critical | Must view ALL 4 reference screenshots in `assets/reference/` AND watch AB2 gameplay videos (URLs in Reference Material section above). Internalize what the game should look and feel like before testing. |
| 2 | Capture gameplay evidence | Critical | Must capture video with game-video skill AND frame sequence with game-capture skill. Both are required. |
| 3 | List EVERY difference | Critical | Compare our game against ALL references (screenshots AND videos). List EVERY visible difference — jet shape, colors, flames, explosions, ground, sky, enemies, HUD, screen busyness, speed sensation, enemy behavior. Nothing is too small to note. |
| 4 | All acceptance criteria tested | Critical | Every criterion from the issue explicitly verified with evidence |
| 5 | Bug reports actionable | High | Each bug: severity, repro steps, expected (citing which reference), actual (citing which frame), root cause hypothesis with file:line |

### Architect

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Spec completeness | Critical | Covers ALL requirements — nothing missing |
| 2 | No scope creep | Critical | Only what's requested — no gold-plating |
| 3 | Clear interfaces | High | Unambiguous — developer needs no design decisions |
| 4 | Godot-native approach | Critical | Uses Godot built-in nodes. **N/A for non-game-code issues** (tooling, infra, scripts) — judge marks N/A, does not fail or fudge it |
| 5 | Risks identified | Medium | Edge cases and constraints called out |

---

## Verdict Rules

- **PASS**: Score >= 9/10. ALL critical criteria met. Looks like After Burner II when compared to the reference screenshot and videos, same look and feel 
- **FAIL**: Any critical criterion not met. Or it doesn't look like the reference. Period.
- **When in doubt, FAIL.** The cost of passing bad work is higher than sending it back.

### Fail feedback must be specific

Every FAIL must include:
- Which criteria failed and why
- Screenshot evidence compared to the reference
- Exact files/lines/values that need to change
- What the correct result should look like (citing the reference)
- No vague "needs improvement" — name the gap and the fix
