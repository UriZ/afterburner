# Quality Criteria

This file defines what the judge agent evaluates against. Three layers: project-level, per-role, and per-task.

## Judge Configuration

```
STRICTNESS: paranoid
GATE_MODE: blocking
SCORE_THRESHOLD: 8
MAX_RETRIES: 2
JUDGE_TL: false
```

---

## Project-Level Quality Bar

- Target quality: "Indistinguishable from the original SEGA After Burner II arcade experience"
- The game must run at 60 FPS on a modern Mac
- Controls must feel responsive and tight — no input lag, smooth movement
- All GDScript must be valid Godot 4.6 — project must open and run without errors in Godot 4.6.2
- No placeholder art — every visual element must look finished and arcade-quality

### Visual Fidelity (Critical — all must pass)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Player jet reads as 3D F-14 | The sprite must create the illusion of a 3D jet — shading, highlights, shadows, depth. NOT a flat colored silhouette. Must have specular highlights on canopy, shadow under fuselage, lit/dark sides on banking. |
| 2 | Player jet occupies 25-30% screen height | Measured: `(sprite_height_px × pixel_size) / (2 × Z_distance × tan(FOV/2))`. Must dominate bottom quarter. |
| 3 | Enemy jets are recognizable aircraft at ALL distances | At spawn distance: small but clearly a jet shape. At mid-range: type-distinguishable. At close range: detailed with visible wings, body, cockpit. |
| 4 | Wing surfaces are filled regions, not lines | Any implementation where wings are single-pixel diagonals or unfilled outlines automatically FAILS. |
| 5 | Ground creates intense speed sensation | Reviewer must feel forward motion is fast/aggressive. Bands must be dramatically wider near camera, hairline at horizon. Original AB2 reviewers used words like "nauseating" and "dizzying". |
| 6 | Explosions are dramatic screen-filling events | At detonation point, explosion must be at least 15% of screen height. Duration ≥ 0.8s. Must have orange fireball → smoke progression. |
| 7 | Color palette is bold arcade saturated | No muted/realistic greys. Vivid reds, deep blues, hot oranges, bright whites. Colors must pop on screen. |
| 8 | Sprites have shading and depth | Flat single-color fills FAIL. Every sprite must have at least highlight, base, and shadow tones to create 3D illusion. |
| 9 | Screen composition matches original | Horizon at 45-55% from top. Sky fills upper half. Ground fills lower half. Player in bottom 25%. |
| 10 | Super Scaler feel | Enemies must smoothly scale from small dots at horizon to large detailed sprites flying past. The scaling must feel continuous and dramatic. |

### Gameplay Feel (Critical)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Arcade energy | Screen should feel BUSY — multiple enemies, projectiles, explosions happening simultaneously. Not calm or empty. |
| 2 | Camera responds to player | World tilts when banking. Camera movement adds to immersion. |
| 3 | Lock-on feedback | Clear visual and audio feedback when missile lock is acquired. |
| 4 | Weapon satisfaction | Firing vulcan and missiles must feel impactful — visual tracers, sound, enemy reactions. |

### Audio (High)

| # | Criterion | Description |
|---|-----------|-------------|
| 1 | Music plays during gameplay | Selected track plays and loops. Must be energetic/driving tempo. |
| 2 | SFX match actions | Every weapon fire, explosion, lock-on has a sound. Sounds are punchy, not thin. |

---

## Per-Role Criteria

### Architect

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Spec completeness | Critical | Design covers ALL requirements in the task — nothing missing |
| 2 | No scope creep | Critical | Design covers ONLY what's requested — no unrequested features, no gold-plating |
| 3 | Clear interfaces | High | All public interfaces are unambiguous — developer should not need to make design decisions |
| 4 | Consistent with architecture | High | Design aligns with existing architecture.md and established patterns |
| 5 | Risks identified | Medium | Edge cases, failure modes, and constraints are called out explicitly |
| 6 | Implementation actionable | High | Spec is detailed enough that a developer can implement without asking questions |
| 7 | Godot-native approach | High | Uses Godot built-in nodes and patterns, not fighting the engine |

### UI Designer

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | References original game | Critical | Must cite specific original After Burner II screenshots/sprites as reference |
| 2 | Diagnoses broken code | Critical | Must identify the specific functions/lines that produce bad output before writing spec |
| 3 | Pixel-level specificity | High | Exact coordinates, exact colors, exact dimensions — not vague descriptions |
| 4 | 3D illusion techniques | High | Spec must describe shading, highlights, shadows that create depth — not flat color fills |
| 5 | Measurable targets | High | Screen percentages, pixel counts, color values — not "bigger" or "more detailed" |

### Developer

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Matches spec | Critical | Implementation matches the spec — no deviations without justification |
| 2 | Runs in Godot | Critical | Project opens in Godot 4.6 and runs without errors |
| 3 | Feature works | Critical | The implemented feature actually functions as specified |
| 4 | Sprites have depth/shading | Critical | No flat single-color fills. Must have highlight, base, shadow tones. |
| 5 | Tests present | High | Implementation has GUT tests for core logic |
| 6 | Code quality | Medium | Clean, readable GDScript following Godot conventions |
| 7 | No scope creep | High | Only what was specified was built — no extra features |
| 8 | Less is more | High | Short concise code. No AI slop |
| 9 | Arcade feel | Critical | The feature feels like the original After Burner when playing |
| 10 | On-screen size math | High | Developer must calculate and verify screen coverage before declaring visual work done |

### QA

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | All acceptance criteria tested | Critical | Every criterion from the issue was explicitly verified |
| 2 | Bug reports actionable | High | Each bug has clear repro steps, expected vs actual, and root cause hypothesis |
| 3 | Edge cases covered | Medium | Testing went beyond happy path — boundary conditions, error states |
| 4 | Evidence provided | High | Console output or test results included as evidence |
| 5 | Visual comparison to original | Critical | Tester must compare screenshot against original AB2 reference and note differences |

### Security

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | No hardcoded secrets | Critical | No API keys, tokens, or passwords in code or git history |
| 2 | Safe file operations | High | No path traversal or arbitrary file access |
| 3 | Input validation | Medium | Player input is bounds-checked |

---

## Per-Task Acceptance Criteria

Defined on each GitHub issue at creation time. Format:

```markdown
## Acceptance Criteria
- [ ] [Specific, verifiable criterion]
- [ ] [Specific, verifiable criterion]
```

The judge evaluates each criterion as PASS/FAIL. All acceptance criteria must pass for the final gate to pass.

---

## Verdict Rules

- **PASS**: All critical criteria met. High/medium criteria are substantially met. Work proceeds.
- **FAIL**: Any critical criterion not met, OR multiple high criteria have significant gaps. Work returns to agent with specific feedback.

### Weight Definitions

- **Critical** — Must pass. A FAIL on any critical criterion means overall FAIL regardless of everything else.
- **High** — Important. A single high failure is a warning. Multiple high failures → FAIL.
- **Medium** — Nice to have. Failures noted in feedback but don't block on their own.

### Fail feedback must be specific

Every FAIL must include:
- Which criteria failed and why
- Specific evidence (file, line, output)
- What needs to change to pass
- No vague "needs improvement" — name the gap
