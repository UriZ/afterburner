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

## Judge Mandatory Procedure

**The judge MUST take a screenshot before evaluating any visual work.** Use the MCP bridge:
```
printf '{"cmd":"screenshot"}\n' | nc -w 3 127.0.0.1 9501
```
If the game is not running, the judge MUST launch it, navigate to gameplay, and screenshot. Visual work that has not been screenshot-verified is an automatic FAIL.

**The judge MUST compare the screenshot against the original After Burner II.** If the result does not look like After Burner II to a reasonable person, it FAILS — regardless of whether the code "works" or tests pass.

**Code that compiles and passes tests but looks bad is a FAIL.** The judge evaluates the VISUAL RESULT, not the code quality. Tests passing means nothing if the game looks wrong.

**Interactive features require functional verification, not just code review.** The TCP bridge can send single key presses but CANNOT hold keys. For features like vulcan firing (hold to fire) or continuous movement, the judge must:
1. Verify the code logic is correct by reading it
2. Check that input bindings exist and are wired correctly
3. Look for obvious bugs (wrong action names, missing connections, broken state machines)
4. If the feature cannot be screenshot-verified, the judge must explicitly state this limitation and evaluate more critically on code correctness

**Placeholder quality is not shippable quality.** If the visual output looks like programmer art / geometric primitives / debug shapes, it FAILS — even if the code is clean and well-structured. The bar is "would this pass in an indie game jam?" not "does the code work?"

---

## Project-Level Quality Bar

- Target quality: "A person seeing this for the first time would say 'that looks like After Burner'"
- The game must run at 60 FPS on a modern Mac
- Controls must feel responsive and tight
- All GDScript must be valid Godot 4.6

### HARD RULES — Automatic FAIL if violated

0. **Game must be playable for evaluation.** The player must survive at least 15 seconds without input on Stage 01. If the judge captures frames and they all show GAME OVER, the evaluation is an automatic FAIL with recommendation to fix survivability first. No visual feature can pass if it can't be seen.

1. **Jets must look like actual aircraft, not geometric primitives.** A cylinder with boxes for wings is NOT an aircraft — it's a placeholder. The jet mesh must have: tapered fuselage with smooth contours, delta/swept wing shapes (not rectangles), visible intake geometry, detailed tail section, cockpit canopy that sits flush. If you can describe the jet as "a cylinder with boxes stuck on it", it FAILS. Compare mentally to the original After Burner II sprites — those had clear aircraft silhouettes with panel lines, shading, and distinct fighter jet shapes. Our 3D meshes must achieve at least that level of recognizability.

2. **Rear chase-cam perspective.** The player jet is viewed from BEHIND and SLIGHTLY BELOW. You see the REAR of the jet: twin engine nozzles with afterburner flames, vertical tail fins, swept wings. NOT a top-down dorsal view. NOT a front view.

3. **The ground must move.** When playing, you must feel intense forward speed. If the ground looks static or slowly drifting, FAIL.

4. **Screen must be busy.** At any point during gameplay, there should be multiple enemies, projectiles, or explosions visible. An empty screen with just the jet and sky is FAIL.

5. **Horizon at 40-55% from top.** Ground fills the bottom half. The jet sits in the bottom 25%.

### Visual Fidelity (Critical — all must pass)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Player jet is 3D | Must be a detailed 3D mesh that reads as a fighter jet, not a cylinder with boxes. Smooth fuselage taper, swept wing planform (not rectangles), visible twin vertical stabilizers, engine nacelles with intake scoops. A real person looking at it should say "that's a jet" without being told. Primitive geometric shapes = FAIL. |
| 2 | Player jet is large | Occupies 25-30% screen height. Dominates bottom quarter. |
| 3 | Enemy jets are 3D | Must be 3D meshes that scale naturally as they approach. At close range, must be recognizable aircraft — not cylinders with flat box wings. Same standard as player jet: if it looks like geometric primitives, FAIL. |
| 4 | Ground creates speed | Perspective-compressed bands/texture rushing toward camera. Must feel FAST. "Nauseating" speed. |
| 5 | Explosions are dramatic | Screen-filling fireballs. At least 15% screen height. Orange → smoke progression. |
| 6 | Bold arcade colors | Vivid saturated colors. No washed-out pastels. Deep blues, hot oranges, bright whites. |
| 7 | World tilts on banking | When the jet banks left/right, the camera rolls, tilting the entire horizon. |
| 8 | Composition matches AB2 | Horizon ~50% from top. Ground fills bottom. Jet in bottom 25%. Sky with clouds above. |
| 9 | Super Scaler scaling | Enemies scale smoothly from dots at horizon to large sprites flying past. Continuous, dramatic. |
| 10 | Afterburner flames | Twin engine flames visible on player jet. Hot white/yellow core, orange/red outer. |

### Gameplay Feel (Critical)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Arcade energy | Screen BUSY — multiple enemies, projectiles, explosions simultaneously. Never calm or empty. |
| 2 | Lock-on feedback | Clear visual + audio when missile lock acquired. Per-enemy lock markers. |
| 3 | Weapon satisfaction | Vulcan tracers visible, missiles trail smoke, enemies react on hit. |
| 4 | Responsive controls | Zero input lag. Jet moves immediately with input. |
| 5 | Aiming works correctly | Crosshair moves independently or with jet. Vulcan bullets go where the crosshair points. Missiles track locked targets. If aiming is broken (bullets go wrong direction, crosshair stuck, locks don't work), FAIL. |

### Audio (High)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Music plays | Selected track plays and loops. Energetic tempo. |
| 2 | SFX match actions | Weapon fire, explosion, lock-on all have distinct sounds. |

---

## Per-Role Criteria

### Architect

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Spec completeness | Critical | Covers ALL requirements — nothing missing |
| 2 | No scope creep | Critical | Only what's requested — no gold-plating |
| 3 | Clear interfaces | High | Unambiguous — developer needs no design decisions |
| 4 | Godot-native approach | Critical | Uses Godot built-in nodes. 3D meshes for 3D objects, not sprite hacks. |
| 5 | Risks identified | Medium | Edge cases and constraints called out |

### UI Designer

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | References original game | Critical | Must cite original AB2 visuals as reference |
| 2 | Diagnoses broken code | Critical | Must identify specific functions/lines producing bad output |
| 3 | Pixel-level specificity | High | Exact dimensions, colors, coordinates |
| 4 | Measurable targets | High | Screen percentages, pixel counts — not "bigger" |

### Developer

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Matches spec | Critical | Implementation matches spec exactly |
| 2 | Runs in Godot | Critical | Opens and runs without errors in 4.6.2 |
| 3 | Feature works | Critical | Actually functions as specified |
| 4 | LOOKS RIGHT | Critical | The visual result looks like After Burner II. Judge MUST screenshot and verify. Code that works but looks wrong = FAIL. |
| 5 | Tests present | High | Tests for core logic |
| 6 | No scope creep | High | Only what was specified |
| 7 | Less is more | High | Concise code. No AI slop. |

### QA

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Screenshot comparison | Critical | Must take screenshot and compare against original AB2. List every visible difference. |
| 2 | All acceptance criteria tested | Critical | Every criterion explicitly verified |
| 3 | Bug reports actionable | High | Repro steps, expected vs actual, root cause |
| 4 | Evidence provided | High | Screenshots and console output included |

---

## Verdict Rules

- **PASS**: Score ≥ 9/10. All critical criteria met. Looks like After Burner II.
- **FAIL**: Any critical criterion not met. Or it doesn't look like After Burner II. Period.

### Fail feedback must be specific

Every FAIL must include:
- Which criteria failed and why
- Screenshot evidence
- Exact files/lines/values that need to change
- What the correct result should look like
- No vague "needs improvement" — name the gap and the fix
