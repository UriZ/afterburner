# Quality Criteria

This file defines what the judge agent evaluates against. Three layers: project-level, per-role, and per-task.

## Judge Configuration

```
STRICTNESS: high
GATE_MODE: blocking
SCORE_THRESHOLD: 7
MAX_RETRIES: 2
JUDGE_TL: false
```

---

## Project-Level Quality Bar

- Target quality: "Faithful arcade recreation that looks and feels like the original SEGA After Burner II"
- The game must run at 60 FPS on a modern Mac
- Visual style must match the original arcade — sprite scaling, color palette, screen layout
- Controls must feel responsive and tight — no input lag, smooth movement
- No placeholder art or missing features in shipped stages — everything must be complete
- All GDScript must be valid Godot 4.6 — project must open and run without errors in Godot 4.6.2

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

### Developer

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | Matches spec | Critical | Implementation matches the architect's spec — no deviations without justification |
| 2 | Runs in Godot | Critical | Project opens in Godot 4.6 and runs without errors |
| 3 | Feature works | Critical | The implemented feature actually functions as specified |
| 4 | Tests present | High | Implementation has GUT tests for core logic |
| 5 | Code quality | Medium | Clean, readable GDScript following Godot conventions |
| 6 | No scope creep | High | Only what was specified was built — no extra features |
| 7 | Less is more | High | Short concise code. No AI slop |
| 8 | Arcade feel | High | The feature feels like the original After Burner when playing |

### QA

| # | Criterion | Weight | Description |
|---|-----------|--------|-------------|
| 1 | All acceptance criteria tested | Critical | Every criterion from the issue was explicitly verified |
| 2 | Bug reports actionable | High | Each bug has clear repro steps, expected vs actual, and root cause hypothesis |
| 3 | Edge cases covered | Medium | Testing went beyond happy path — boundary conditions, error states |
| 4 | Evidence provided | High | Console output or test results included as evidence |
| 5 | Arcade feel verified | High | Tester compared behavior against original game reference |

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
