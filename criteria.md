# Quality Criteria

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

**Reference screenshot**: `assets/reference/ab2-arcade-desert.png` — an actual After Burner II arcade screenshot.

The judge and QA MUST view this reference image (Read tool) before every visual evaluation. Compare our game frame-by-frame against this reference. If the gap is large, FAIL.

Source: [LaunchBox Games Database](https://gamesdb.launchbox-app.com/games/images/7687-after-burner-ii)

## Judge Mandatory Procedure

1. **Read this file** (criteria.md)
2. **View the reference screenshot** at `assets/reference/ab2-arcade-desert.png`
3. **Capture gameplay** using the game-capture or game-video skill with `--start-game`
4. **View ALL captured frames** with the Read tool
5. **Compare EVERY element** against the reference — jet appearance, colors, ground, enemies, screen busyness, HUD
6. **Be brutally honest** about the gap between our game and the reference

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
- **Afterburner flames are MASSIVE** — bright yellow/white core, orange outer, nearly as long as the jet body itself. They are the most eye-catching element. If the flames aren't dramatic and large, FAIL.
- The jet fills **25-30% of screen height** and dominates the bottom quarter
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
- **Horizon at ~50% from top** — sky and ground roughly equal
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

0. **Game must be playable for evaluation.** The player must survive at least 15 seconds without input on Stage 01. All GAME OVER frames = automatic FAIL.

1. **Jets must look like aircraft with visual detail.** A flat-shaded cylinder with box wings is NOT acceptable even if it's "recognizable." The jet must have visible surface detail: color variation across the body, highlight/shadow areas, panel-line-like color breaks. Compare to the reference screenshot — the original sprites had shading and detail despite being 320x224 pixels. Our 3D meshes at modern resolution should look AT LEAST as detailed.

2. **Afterburner flames must be dramatic.** In the reference, flames are nearly as long as the jet body and are the brightest element on screen. Tiny orange nubs = FAIL. The flames should be eye-catching from across the room.

3. **The ground must create speed.** If the ground looks static or slowly drifting, FAIL. The original made players feel "nauseated" from speed.

4. **Screen must be busy.** At any point during gameplay, the screen should feel chaotic with enemies, projectiles, or explosions. Empty sky with just one jet = FAIL.

5. **Horizon at 40-55% from top.** Ground fills the bottom half. The jet sits in the bottom 25%.

6. **Colors must be vivid and saturated.** Muted greys, washed-out pastels, or low-contrast color schemes = FAIL. Compare to the reference: hot oranges, deep blues, bright reds.

---

### Visual Fidelity (Critical — all must pass)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Player jet has visual detail | Must have color variation, shading, highlights — NOT a single flat color. Multiple material colors on the fuselage (light top, darker sides). Canopy must be a distinct color. Wing undersides slightly different from tops. |
| 2 | Player jet is large | Occupies 25-30% screen height. Dominates bottom quarter. |
| 3 | Afterburner flames are dramatic | Flames extend at least 50% of jet body length. White/yellow core, orange outer. Bright enough to be the most eye-catching element. |
| 4 | Enemy jets are vivid | Saturated colors that POP against any background. Red fighters should be BRIGHT red (not dark red). At close range, clearly aircraft shapes. |
| 5 | Ground creates speed | Strong perspective compression. Dense pattern. Fast scrolling. "Nauseating" speed sensation. |
| 6 | Explosions are dramatic | Each explosion fills 15-25% screen height. Puffy white/yellow clouds. Multiple visible simultaneously. |
| 7 | Bold arcade colors | Compare to reference. Vivid saturated colors throughout. No grey, muted, or washed-out areas. |
| 8 | Composition matches AB2 | Horizon ~50% from top. Ground fills bottom. Jet in bottom 25%. Sky above. |
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
| 4 | LOOKS RIGHT | Critical | View the reference at `assets/reference/ab2-arcade-desert.png`. Does your output look like that? If not, FAIL. Code that works but looks wrong = FAIL. |
| 5 | Tests present | High | Tests for core logic |
| 6 | No scope creep | High | Only what was specified |

### QA

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Reference comparison | Critical | Must view `assets/reference/ab2-arcade-desert.png` AND capture gameplay video. List EVERY visible difference between our game and the reference. |
| 2 | All acceptance criteria tested | Critical | Every criterion explicitly verified |
| 3 | Bug reports actionable | High | Repro steps, expected vs actual, root cause |
| 4 | Video evidence | Critical | Must capture video with game-video skill. Static frames are insufficient. |

### Architect

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Spec completeness | Critical | Covers ALL requirements — nothing missing |
| 2 | No scope creep | Critical | Only what's requested — no gold-plating |
| 3 | Clear interfaces | High | Unambiguous — developer needs no design decisions |
| 4 | Godot-native approach | Critical | Uses Godot built-in nodes |
| 5 | Risks identified | Medium | Edge cases and constraints called out |

---

## Verdict Rules

- **PASS**: Score >= 9/10. ALL critical criteria met. Looks like After Burner II when compared to the reference screenshot.
- **FAIL**: Any critical criterion not met. Or it doesn't look like the reference. Period.
- **When in doubt, FAIL.** The cost of passing bad work is higher than sending it back.

### Fail feedback must be specific

Every FAIL must include:
- Which criteria failed and why
- Screenshot evidence compared to the reference
- Exact files/lines/values that need to change
- What the correct result should look like (citing the reference)
- No vague "needs improvement" — name the gap and the fix
