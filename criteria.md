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
| `assets/reference/ab2-arcade-night-banking.png` | Night stage, F-14 banking with fire | Massive afterburner flames, dark ground with city lights, dramatic fire effect |
| `assets/reference/ab2-arcade-closeup-enemies.jpg` | Close-up with enemy jets | Large dark-green enemy jets with detail, massive explosion filling half the screen, F-14 dorsal view with shading |
| `assets/reference/ab2-arcade-coastal-banking.jpg` | Coastal stage, F-14 banking | Rocky terrain, ocean, blue enemy jets, green ground — shows terrain variety and banking |
| `assets/reference/ab2-arcade-night-missiles.jpg` | Night stage with missile trails | F-14 with massive flames, missile smoke trails, enemy approaching — shows combat feel |
| `assets/reference/ab2-arcade-city-stage.jpg` | City/forest stage with explosions | Buildings below, green terrain, blue enemies, mid-air explosions — shows stage variety |
| `assets/reference/ab2-arcade-reload-dorsal.jpg` | Reload screen, F-14 dorsal close-up | Best reference for F-14 shape from behind — wing sweep, tail fins, canopy, panel lines |
| `assets/reference/ab2-arcade-huge-explosion.jpg` | Massive explosion filling screen | Orange/yellow puffy cloud covering 80%+ of screen — THIS is how big explosions should be |

### Reference Videos (for context — agents should understand the feel/speed)

- After Burner II 60 FPS Longplay: `https://www.youtube.com/watch?v=65weTx0haog`
- After Burner II Arcade Gameplay: `https://www.youtube.com/watch?v=8d-S1kcjieA`
- After Burner II Arcade Longplay: `https://www.youtube.com/watch?v=W2loyeq9pDA`

Sources: [LaunchBox Games Database](https://gamesdb.launchbox-app.com/games/images/7687-after-burner-ii), [Games Database](https://www.gamesdatabase.org), [Internet Archive](https://archive.org)

## Judge Mandatory Procedure

1. **Read this file** (criteria.md)
2. **View ALL 9 reference screenshots** with the Read tool (every file in `assets/reference/`)
3. **Capture gameplay** using the game-capture or game-video skill with `--start-game`
4. **View ALL captured frames** with the Read tool
5. **Compare EVERY element** against ALL 4 references — jet appearance, colors, ground, enemies, explosions, screen busyness, HUD
6. **Be brutally honest** about the gap between our game and the references

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
- **Nose/radome** must be a WIDE, SMOOTH, bullet-shaped taper — like a real F-14 (it houses a 36-inch AWG-9 radar dish). NOT a needle, NOT a spike, NOT a thin antenna, NOT a blunt cone. It has substantial width at the base (nearly fuselage width) and tapers gradually to a slightly rounded tip over ~25% of total aircraft length. A needle/spike nose = FAIL. A stubby cone = FAIL. Compare against real F-14 photos.
- **Every major component must be shaped AND proportionally correct.** Nose, canopy, wings, intakes, nacelles, tail fins, nozzles — each needs correct proportions relative to the whole aircraft, verified against real aircraft photos AND arcade references. A mesh with good wings but a wrong-proportioned nose is half-finished = FAIL.
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

7. **No rendering artifacts.** Seams, tearing, Z-fighting, flickering, or visual glitches of any kind = FAIL.

8. **Player jet must move freely across the screen.** The jet must be able to reach all areas of the viewport, not be stuck at the bottom. Compare to AB2 — the jet roams the full screen.

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
| 4 | Godot-native approach | Critical | Uses Godot built-in nodes |
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
