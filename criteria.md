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

Sources: [LaunchBox Games Database](https://gamesdb.launchbox-app.com/games/images/7687-after-burner-ii), [Games Database](https://www.gamesdatabase.org), [Internet Archive](https://archive.org)

## Hard Rules (automatic FAIL if violated)

1. **No un-dodgeable deaths** — every death preceded by a visible threat with a >=0.5s avoidance window. Idle-survival time is not itself a criterion.
2. **Ground per-band frame-to-frame shift must increase monotonically with depth** — near bands move more than far bands. The old 'stripe positions must differ' rule passed on pure noise regeneration and must not be reinstated.
3. **Reference screenshots are the primary truth source** — written descriptions can be wrong. Always look at actual images.

## Judge Mandatory Procedure

1. **Read this file** (criteria.md)
2. **View ALL 9 reference screenshots** with the Read tool (every file in `assets/reference/`)
3. **Capture gameplay VIDEO** (MANDATORY — not optional): `bash .claude/skills/game-video/capture-video.sh --start-game --duration 15 --playback-fps 8 --output /tmp/game-capture/judge-video.mp4`
4. **Capture frame sequence** for detailed analysis: `bash .claude/skills/game-capture/capture.sh --start-game --frames 10 --interval 500`
5. **View ALL captured frames** with the Read tool
6. **Compare EVERY element** against ALL references — jet appearance, colors, ground, enemies, explosions, screen busyness, HUD
7. **Be brutally honest** about the gap between our game and the references

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
- **Nose/radome** — applies to enemy jets and any non-astern view only. For the PLAYER jet in the dead-astern chase view, the nose forward-extent is effectively ZERO: the topmost pixel of the aircraft in every clean reference frame is the canopy, not a radome. Drawing a projecting nose on the player jet = FAIL (it is the main cause of the paper-dart silhouette). Where the radome IS visible, it is a wide, smooth, bullet-shaped taper — never a needle or spike.
- **Every major component must be shaped AND proportionally correct.** Nose, canopy, wings, intakes, nacelles, tail fins, nozzles — each needs correct proportions relative to the whole aircraft, verified against real aircraft photos AND arcade references. A mesh with good wings but a wrong-proportioned nose is half-finished = FAIL.
- **Engine nozzles read as large hot-cored glowing discs** — dark rim with a hot orange/red/yellow centre. There is NO exhaust plume or ribbon. Verified across every motion burst and all 9 statics: the original has no engine flame trail. A long flame plume = FAIL.
- The jet is **WIDE and FLAT** — 35-37% of screen WIDTH by 16-18% of screen HEIGHT, aspect ratio 2.8-3.1:1. Measured by nozzle-centroid-anchored segmentation on burst-c-11, burst-c-12 and ab2-arcade-reload-dorsal. Do NOT use a height-only rule; a 25-30%-height jet reads as a paper dart. NOTE: an earlier 50-55% width figure was a measurement error — a value-threshold bbox on burst-c-02 swallowed the stone wall behind the jet.
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

Attribute measurement is a check on a judgement already made by eye — never a substitute for it. A build can pass every numeric target and still look wrong: aspect 2.92 vs 2.95, wingspan 36.25% vs 35.6%, saturation 0.853 vs 0.867 all passed while the ground read as foam bubbles and the jet read as a sticker. Measuring a proxy cannot detect a defect the proxy does not cover, and no attribute rule covered ground feature size — the single most damaging error on screen.

Never evaluate a cropped subject alone. Composition defects live between elements.


0. **No un-dodgeable deaths.** Every death must be preceded by a visible approaching threat with a >=0.5s reachable avoidance window. Idle-survival duration is NOT a criterion — an arcade game may legitimately kill a player who never moves. For visual evaluation, use a capture mode so lethality never truncates a review.

1. **Jets must look like aircraft with visual detail.** A flat-shaded cylinder with box wings is NOT acceptable even if it's "recognizable." The jet must have visible surface detail: color variation across the body, highlight/shadow areas, panel-line-like color breaks. Compare to the reference screenshot — the original sprites had shading and detail despite being 320x224 pixels. Our 3D meshes at modern resolution should look AT LEAST as detailed.

2. **Engine nozzles must read as hot-cored glowing discs.** Dark rim, hot orange/red/yellow core — NOT a white disc with an orange ring (that is inverted). There is no exhaust plume in the original; drawing one = FAIL.

3. **The ground must create speed.** If the ground looks static or slowly drifting, FAIL. The original made players feel "nauseated" from speed.

4. **Screen must be busy.** At any point during gameplay, the screen should feel chaotic with enemies, projectiles, or explosions. Empty sky with just one jet = FAIL.

5. **Horizon at 60-65% from top.** Measured from reference burst-a-02 and burst-b-03 — the original has MORE sky than ground. The jet sits in the bottom 25%.

6. **Sky matches the reference's real shape: flat fill + optional tight glow + hard horizon.** Measured from all 50 longplay frames (#115): AB2's sky is a FLAT fill; many stages are flat edge-to-edge with NO glow and NO haze band (snow `#b7d3d6`, blue day `#0092f7`, pixel-identical top to ground). Where a glow exists it occupies only the last ~20% of sky height and is a HUE shift at held saturation (desert H29°→H52°, S pinned 1.00, V 0.90→0.98), not a brightness ramp. The horizon is a hard 6-20px cut. Per-biome measured anchors live in the `stage_data.gd` header. A whole-sky smooth gradient, a soft/hazy horizon, or an RGB-lerp passing through desaturated grey = FAIL.

7. **Colors must match the reference stage-for-stage.** Measure mean HSV saturation against the equivalent reference stage — do NOT apply a flat floor. Desert measures S~0.87-0.90; snow measures S~0.14. A flat threshold wrongly fails a correct snow stage. Muted output on a stage whose reference is vivid = FAIL.

9. **No rendering artifacts.** Seams, tearing, Z-fighting, flickering, or visual glitches of any kind = FAIL.

8. **Enemies must occupy the SKY.** They appear at the horizon and scale up through the sky above it. A sustained stretch of capture with zero enemy pixels above the horizon line = FAIL. Measure it: count enemy pixels above the horizon across a capture. The original's action happens in the sky, not along the ground.

10. **Explosion type must match the target.** Aircraft kills are pale cream/near-white cauliflower puffs at ~10-12% screen height with NO orange or red (desert-explosions.png, closeup-enemies.jpg). Orange/red fireballs are for ground and large impacts ONLY (huge-explosion.jpg, burst-c-10). Using a fireball for every kill = FAIL.

11. **Ground feature size, edge hardness, brightness — measured against the reference IN THE SAME EVALUATION.** Do not bake numeric literals into this file; two successive gates produced conflicting brightness targets (0.67-0.69 vs a directly measured 0.569) and the baked number drove the shader brighter than the arcade original. At gate time: measure the equivalent reference band (feature diameter distribution, mean |grad| and frac(|grad|>0.05) for edge hardness, mean V) and compare ours to it. Shape regularity is part of this rule: matching size/edge/brightness proxies while every feature is the same lozenge still fails — require varied feature outlines. COLOUR: one dominant hue family must hold >=80% of saturated band pixels, with variation expressed as VALUE steps within that hue (measured reference: 89.2% of saturated near-band pixels in one 20-degree bin). A prior '>=3 hue clusters' version of this rule produced a confetti ground and is retired. Round-5 reference near-band data points: median feature ~0.7-0.9%W, mean|grad| 0.078-0.090, frac>0.05 0.64-0.73, mean V 0.569.

12. **Effects must be OPAQUE with fine-grained fringes.** Banning draw_circle was too narrow — polygons reproduced the same defect. The real requirements: (a) explosion bodies are opaque (background must not show through centres or gaps — reference puffs are solid cream), (b) perimeter detail at the 4-6px bump scale, not 40px facets, (c) death fireballs are irregular ROUNDED lobes, fully opaque, with 2-4px internal mottle — NOT a geometric starburst polygon; 'tongues' implemented as straight triangular spikes is exactly the failure mode this rule exists to stop. Measure fringe bump scale against the reference explosion crops. Interior: explosion bodies must contain >=8 distinct value levels by histogram — dozens of overlapping blobs with scattered hot cores and dark shading, per the reference; a 2-3 flat-fill construction is an automatic FAIL regardless of outline shape.

14. **HUD element parity.** Any HUD element present in 100% of reference frames must exist in ours. Example: the bracketed target box (~13% of screen width) was missing for five rounds because no rule named it. The reference has BOTH: a fixed top-right bracketed scope box (every frame) AND moving in-field lock brackets. Require both — a prior amendment treating them as one moving element caused the fixed box to be dropped. Also: 'HI <score>' does not appear top-right on AB2's play screen.

16. **Weapons must demonstrably work.** Firing the vulcan must produce a visible tracer within 2 frames, and a 15s active-fire capture must produce at least one scoring kill. Three gates passed visual work while the guns did nothing — no visual criterion is meaningful if the player cannot shoot.

15. **Sky population.** Enemies-above-horizon is not enough: the reference shows 4-6 enemy silhouettes simultaneously at varied sizes and bank angles, plus flak and tracer fire. Measure enemy pixel counts in the sky region across a capture; a sky that is empty or near-empty in a meaningful fraction of frames = FAIL.

13. **Player screen occupancy.** The player jet must be on screen in >=90% of frames across a capture. Composition cannot be evaluated, and the game does not read as AB2, when the death/respawn gap leaves the frame empty for long stretches.

8. **Player jet must move freely across the screen.** The jet must be able to reach all areas of the viewport, not be stuck at the bottom. Compare to AB2 — the jet roams the full screen.

---

### Visual Fidelity (Critical — all must pass)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Player jet has visual detail | Must have color variation, shading, highlights — NOT a single flat color. Multiple material colors on the fuselage (light top, darker sides). Canopy must be a distinct color. Wing undersides slightly different from tops. |
| 2 | Player jet proportions | Span 35-37% of screen width; height 16-18%; aspect 2.8-3.1:1 — measured at LEVEL pose only. An axis-aligned bbox balloons under bank from rigid rotation alone (bank=15 reads ~22%H on correct geometry); control for bank before failing this. |
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
| 5 | Tests present | High | Tests for core logic |
| 6 | No scope creep | High | Only what was specified |

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
