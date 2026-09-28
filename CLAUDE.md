# After Burner

A faithful recreation of SEGA's classic 1987 After Burner II arcade game, built with Godot Engine 4.6.

## THE PRIMARY DIRECTIVE — ALL AGENTS MUST READ THIS

**The game must look and feel as close as possible to the original After Burner II arcade game.** This overrides everything else. Every design decision, every implementation, every review must be evaluated against: "Does this look and feel like AB2?" If no, it fails.

Study the motion reference AND ALL 9 reference screenshots in `assets/reference/`. The gap between our game and the original AB2 is what we're closing. Code quality, test coverage, and technical correctness are secondary to visual and gameplay fidelity to the original.

**Destructive tests on the shared tree**: run them in an rsync'd scratchpad COPY of the repo (delete the line, run the test, zero risk to concurrent agents' uncommitted work — one rsync of cost; #120 gate pattern).

**Shared working tree** — never run `git stash`, `git checkout .`, `git restore`, or `git reset` on this tree while other agents are active: it silently destroys their uncommitted work (this happened; a stash pulled six agents' edits off disk at once). For A/B comparison against the committed state, use `git show HEAD:<file>` or `git diff HEAD -- <file>` — read-only, no disk mutation.

**Concurrent capture** — when multiple agents run at once, pass `--port N` (e.g. 9502+) to the `game-capture`/`game-video` SCRIPTS; each script then launches, tracks, and kills only its own Godot instance. Direct Godot launches take `--mcp-port N` instead (#117 renamed it) — passing the old `--port` to Godot does NOT error, it silently binds 9501 and collides with whoever owns it (#114 nearly spec'd around a phantom failure because of this). Never run a blanket `pkill -f Godot`. An instance that cannot honour its requested port **exits code 9 with a FATAL stderr line** (#117) — if a capture reports "did not confirm listening", grep for FATAL rather than assuming a slow start. Cleanup traps in capture tooling may only remove paths the script itself created under `/tmp/afterburner-capture/`, never anything in the project directory.

**Concurrency rule (general)**: any tool that writes a named output path needs a per-agent-unique name — `--port N` for game-capture/game-video instances, `--output` for video files, `--name`/`--out` for motion-metrics runs. Sharing a name across concurrent agents produces silent corruption, not errors (#117, #119). New tools inherit this rule; don't rediscover it through a corrupted artifact — it is a STANDARD pre-close-out check for any script with a fixed default output path (three tools caught in one session: #119, #136, #151), not something QA's probe budget should have to find. Reference implementation for safe shared-output handling: `out_dir_lock()` + staging/atomic-replace in `.claude/skills/motion-metrics/motion_metrics.py` (#119) — and for port allocation, `next_port()` in `.claude/skills/game-movie/selftest.sh` (#114 — note #136: a state-mutating bash function invoked via `$(...)` runs in a subshell and silently discards the mutation; echo results via stdout only from functions that mutate nothing, or restructure) — copy the patterns, don't invent them. Test HARNESSES must allocate ports (scan upward, skip bound, never kill what they didn't start) — a suite that assumes a port is free can silently pass against a neighbour's process (#114: a probe counted another agent's instance as its own bridge).

**Capture time base (#116)**: bridge-capture videos are encoded at the rate the capture actually achieved (recorded in the `<output>.mp4.json` sidecar), so playback speed is true — but only for captures made after #116; older mp4s have fictional container fps. `--playback-fps` is a pacing *target* whose ceiling depends on scene content (~12fps during gameplay, ~30fps on the flat title screen), so a `pacing_slip` warning at 15fps is the normal case for gameplay, not a failure.

**How to study motion** — agents cannot stream video, and `WebFetch` on a YouTube URL returns page text, not frames. Use the `youtube-reference` skill, which converts footage into frame sequences any agent can Read:

```bash
bash .claude/skills/youtube-reference/fetch-reference.sh --list
bash .claude/skills/youtube-reference/fetch-reference.sh --url "<AB2 gameplay URL>" --name ab2-longplay
```

Read the `burst-*` frames **in order** — they are 0.25s apart, and motion lives in the differences between them. Extracted frames are gitignored local reference; never commit them.

**InputMap binds `physical_keycode` ONLY** (#114 gate finding): every action in project.godot has `keycode: 0`. Constructed InputEventKey events must set `physical_keycode` or `is_action_pressed` never fires — and a probe via `is_key_pressed` will falsely pass with `keycode` alone. Any input-injection tooling must test through the action system, not the raw-key API.

**Reparenting confounds A/B captures by construction** (#128): node parentage changes _process order → global-RNG interleaving → procedural content re-randomises (250k px apart while the subject is pixel-identical). Use an isolation harness; to prove the PIPELINE is sound, run a null control — identical code in a separate directory must render identical.

**Harnesses should PRINT their internal ground truth per frame** (position, phase, regime weight) — capturing it beside each screenshot beats post-hoc phase fitting, which produced a degenerate result on its first #122 attempt. **`set_capture_invincible` is the standard tool for live-capture verification that isn't itself testing death** (#122 QA); **to QA a specific stage directly, a scratch GameState.DEFAULT_STAGE edit + game-movie --fps 120 jumps straight there** (#139 QA — canyon verification recurs for #132/#135). **Isolation harnesses are first-class tools for visual measurement**: render the subject ALONE on a key colour (magenta) before measuring — three in-game measurements of one jet gave 2.94/3.87/4.26 because enemies, reticle, haze and ground leaked into segmentation; isolated, every number is exact. Existing: `tests/jet_silhouette_preview.gd`, `tests/sky_stage_preview.gd` (the DEFAULT tool for any per-stage visual AC — extend it additively rather than writing parallel one-offs; it now pushes horizon as well as palette, #120). Build one for any new subject.

**BlockFont.draw_text is square-pixel only** — any HUD glyph whose box is far from the font's 5:7 (the arcade stage digit is 1:2.2) silently renders at 1px/cell under width-constrained sizing: present in source, invisible on screen, passing %W-only checks (#129). Use a per-axis path for non-5:7 boxes. **Godot .uid files are COMMITTED** (project policy — they've been landing with their scripts all session).

**A negative-control perturbation must VERIFY it changed the file** — macOS sed silently no-ops the `0,/re/` address form (exit 0, file unchanged), and a no-op perturbation is indistinguishable from a vacuous guard: the natural response is deleting a GOOD test (#139 hit this twice).

**A test that SKIPs by default does not exist** (#140): a selftest's primary negative control may not gate on an env var — commit the fixtures and run it always; the skip line read as a pass in the summary. Dead-session handoffs: run the selftest AND read what it SKIPS and what it REFUSES — both #140 defects were visible there, in no failing assertion. **Developers do NOT commit — work stays in the tree for QA; the TL commits after verification** (one pre-QA self-commit this session; verification then ran against committed state, fix-forward only).

**Multi-arm regex guards (#127's four rounds)**: each arm must be checked for BOTH operand orders and against non-fixture phrasings before it's trusted — the same guard was beaten by phrasing, an unrendered branch, a second regex engine, and word order in successive rounds. And for any regex/guard verification task, the off-checklist phrasing probe is a STANDARD step, not optional (3 real bugs in 3 passes on one skill).

**Audio traps (#138)**: this machine's ffmpeg has NO libvorbis — `-q:a` on a .ogg silently produces FLAC-in-Ogg, which Godot refuses; check `ffprobe codec_name=vorbis` before committing audio (or ship WAV: native import gives sample-exact gapless loops, better than Vorbis padding anyway). Godot import enums are not guessable (`edit/loop_mode`: 1=Disabled, 2=Forward) — load the imported resource and print its properties. Autoload scripts must resolve OTHER autoloads at runtime (never bare-name) or they can't be unit-tested in isolation — two bugs this session (#118, #138). Audio is now AUDIBLE by default (the Master bus had been muted for the project's entire history) — capture instances play sound; `-- --mute-audio` silences one.

**Running tests — use the runner**: `bash tests/run_all.sh` is the single entry point (#118). It fails on compile/parse errors even when counts look plausible, on `0 passed, 0 failed`, on missing summaries, and on non-zero exits; the 13 known legacy `test_jet_mesh_builder.gd` failures report as KNOWN. Never run one file with bare `--script` and call the suite green. Godot rule behind #118: in a SceneTree test script, `_init()` and top-level `preload()` run BEFORE the autoload bootstrap — anything touching a script that references `GameState`/`AudioManager` by bare name needs `_initialize()` + `load()`. And `assert(script != null)` on a loaded GDScript is near-vacuous: a failed-compile script is still non-null.

**Frames are UNLABELLED (#123 finding)**: extracted frames in `assets/reference/motion/` carry no stage identity and must NOT anchor per-stage work on their own — #115 shipped a brown stage-1 sky by matching an unidentified frame that turned out to be stage 2. To get a frame whose stage you can PROVE, extract from `.reference-cache/video/ab2-longplay.mp4` with ffmpeg at an exact timestamp and verify identity (HUD stage number, score continuity). The verified stage↔timestamp map lives in `stage_data.gd`'s header. Note: a stage's first seconds may be cinematic (t=88-94 is the carrier launch; stage-1 FLIGHT starts ~1:34) — for comparisons use flight windows, and record good per-stage flight windows next to the map as they're established. The burst sampler is for motion, not identity.

**Hard limit on what burst frames can tell you (#113 finding)**: AB2's ground texture temporally aliases below ~60fps sampling — even 15fps is past the Nyquist limit, so 4fps burst stills support **pose, scale, and composition judgements only, never speed**. Do not assert "the speed feels right/wrong" from burst frames; speed claims require the 60fps pipeline (#114) or human review of actual video.

Reference sources: search for After Burner II arcade longplay footage on YouTube and pass the URL to the skill. Any full-playthrough recording works.

## Concept

Third-person "into the screen" rail shooter. The player pilots an F-14 Tomcat fighter jet through 23 stages, destroying enemy aircraft with a vulcan cannon and heat-seeking missiles. The game uses sprite-scaling (pseudo-3D) to create a convincing sense of speed and depth — the hallmark "Super Scaler" visual style SEGA pioneered.

The goal is to look and feel exactly like the original arcade game: the same camera perspective, the same sense of speed, the same enemy patterns, barrel rolls, missile lock-on, ground rushing below, and the iconic soundtrack feel.

## Project Structure

```
afterburner/
  project.godot              — Godot project file
  CLAUDE.md                  — This file
  BACKLOG.md                 — Work items
  architecture.md            — System architecture
  criteria.md                — Quality criteria for judge
  SESSION_LOG.md             — Activity log
  scenes/
    main.tscn                — Main game scene
    player/                  — Player jet scenes & scripts
    enemies/                 — Enemy jet scenes & scripts
    hud/                     — HUD overlay
    menus/                   — Title screen, game over
    stages/                  — Stage definitions
  scripts/
    autoload/                — Singletons (game state, input, audio)
    player/                  — Player scripts
    enemies/                 — Enemy AI scripts
    weapons/                 — Missiles, vulcan cannon
    stage/                   — Stage manager, scrolling, spawning
    effects/                 — Explosions, smoke, afterburner flames
    ui/                      — HUD, menus
  assets/
    sprites/                 — All sprite assets
    audio/                   — Music & SFX
    shaders/                 — Visual effect shaders
    fonts/                   — Arcade-style fonts
  tests/                     — GUT unit tests
```

## Key Files

- `BACKLOG.md` — the starting point. User adds work items here, TL picks them up
- `architecture.md` — system architecture doc
- `criteria.md` — quality criteria for judge evaluations
- `SESSION_LOG.md` — activity log for all agent work

## Agent Behaviour

- be concise. no ai slop
- apply critical thinking. don't tell me what i want to hear
- read existing code before modifying it — never blind-edit
- work in small chunks — one logical change at a time; small prs
- **an honest BOUND or refusal is an accepted deliverable** — when a point estimate would carry a large systematic error, state the bound and why (#127's '<=61% of arcade speed' beats an invented number); pressure to 'post the headline figure' is not a reason to fabricate one
- **a comment deriving a numeric consequence from a const must be re-checked when that const becomes a fallback/default** — the premise silently stops matching the live value (#139: a ~708s anti-repeat margin comment now describes pre-#139 behavior; real margin 354s)
- **measure, don't eyeball**: any colour/geometry constant derived from the reference must cite its actual measurement in the comment (source frame, coordinates, sampled value). A comment citing a measurement that was never taken is worse than no comment — the next agent trusts it (#115 root cause).
- **per-stage visual checks need a harness**: stages advance on a 30s timer and unattended play dies around stage 3 (title screen by ~90s). Use `tests/sky_stage_preview.gd`-style palette harnesses for late stages, never a long unattended capture.

## Team Agents

Agents are defined in `.claude/agents/`. The team lead (TL) orchestrates all work.

### Core Roles

| Agent | Role |
|-------|------|
| `tl` | Orchestrates the team — breaks down work, assigns tasks, runs the pipeline, applies retrospective improvements |
| `architect` | Designs architecture, API contracts, data models, implementation specs |
| `developer` | Implements features from specs |
| `qa` | Tests the app, finds bugs, verifies fixes |
| `judge` | Evaluates agent output against acceptance criteria — quality gate |

### Optional Roles (add as needed)

| Agent | Role |
|-------|------|
| `senior-developer` | Handles complex/high-risk implementation tasks |
| `ui-designer` | Produces visual design specs |
| `visual-qa` | Screenshot-based visual QA testing |

### Backlog → Pipeline

The `BACKLOG.md` file is the entry point for all work. The user adds items with acceptance criteria. The TL reads the backlog, picks items by priority, creates GitHub issues, and feeds them into the pipeline.

```
BACKLOG.md (user adds items)
    │
    ▼
TL picks item → creates GitHub issue with acceptance criteria
    │
    ▼
architect ──► JUDGE GATE ──► developer ──► JUDGE GATE ──► qa ──► JUDGE GATE
                                                                      │
                                                              FINAL JUDGE GATE
                                                                      │
                                                                    done
```

1. **Architect designs** — creates spec, posts to GitHub issue
2. **Judge evaluates architect output** — checks spec completeness, no scope creep, clear interfaces
3. **Developer implements** — builds from spec, relabels issue to `qa`
4. **Judge evaluates developer output** — checks implementation matches spec, builds, tests pass
5. **QA verifies** — tests the implementation, files bugs if found
6. **Judge evaluates QA output** — checks test coverage, bug reports actionable
7. **Final judge gate** — evaluates the complete feature against acceptance criteria

If a judge gate **FAILs**, work is sent back to the responsible agent with specific feedback. The TL does NOT override judge decisions without user approval.

**After every judge gate PASSES**: apply retro improvements from the judge and agent insights BEFORE moving to the next pipeline stage. This is not optional — update agent definitions, CLAUDE.md, criteria.md as needed, and log what was applied in SESSION_LOG.md.

### Judge System

The judge is a separate agent (`.claude/agents/judge.md`) that evaluates work quality at pipeline gates.

#### Three layers of criteria (see `criteria.md`):

1. **Project-level** — overall quality bar, target standard, non-negotiables
2. **Per-role** — generic quality requirements for each agent type
3. **Per-task** — acceptance criteria defined on each GitHub issue

#### Judge configuration (in `criteria.md`):

- `STRICTNESS`: low / medium / high / paranoid
- `GATE_MODE`: blocking / advisory
- `SCORE_THRESHOLD`: minimum score to pass (1-10)
- `JUDGE_TL`: whether to evaluate TL orchestration at end of cycle

#### Judge output format:

```markdown
## Judge Evaluation — [agent-name] — #ISSUE
**Verdict**: PASS / FAIL
**Score**: N/10
**Threshold**: N/10

| # | Criterion | Result | Notes |
|---|-----------|--------|-------|
| 1 | ... | PASS/FAIL | ... |

**Gaps**: [specific shortcomings]
**Recommendation**: [next action]
```

### Task Tracking via GitHub Issues (MANDATORY)

All tasks MUST be tracked as GitHub issues on `UriZ/afterburner`. GitHub issues are the **sole source of truth** for task state. Do NOT use internal task systems as the primary tracker.

#### GitHub repo: `UriZ/afterburner`

#### Labels:
- `enhancement` — new feature or feature request
- `bug` — something broken found by QA
- `architect` — needs architect design before implementation
- `ui-design` — needs UI/visual design spec
- `developer` — ready for developer implementation
- `qa` — needs QA verification
- `in-progress` — currently being worked on
- `judge-fail` — failed a judge gate, needs rework
- `won't fix` — decided not to fix (with reasoning in comment)

#### Issue lifecycle:
1. **Feature request**: Create issue with `enhancement` + `architect` labels. MUST include acceptance criteria.
2. **Architect designs**: Posts spec as comment, relabels to `developer` (or `ui-design` first)
3. **Developer implements**: Posts implementation notes, relabels to `qa`
4. **QA verifies**: Reports findings. Bugs → new `bug` issues. Clean → done
5. **Judge gates**: Run between stages. On FAIL → `judge-fail` label + feedback comment, back to previous stage
6. **User approves**: UriZ is the FINAL approver

#### How to create issues:
```bash
gh issue create --title "Title" --body "Description" --label "enhancement,architect"
```

#### How to update issues:
```bash
gh issue comment NUMBER --body "Update text"
gh issue edit NUMBER --add-label "developer" --remove-label "architect"
```

### Session Log (MANDATORY)

Every agent MUST log to `SESSION_LOG.md` (root) throughout and at the end of their work. The file is NEWEST-FIRST: insert your entry at the top, directly under the `# Session Log` header — do not append to the end. See `SESSION_LOG.md` for the format guide.

### Continuous Self-Improvement (MANDATORY)

Every agent MUST include an **Improvement Insights** section at the end of their TLDR:

```
## Improvement Insights
- **[agent-name.md]**: [specific suggestion]
- **[CLAUDE.md]**: [specific suggestion]
- **[criteria.md]**: [specific suggestion]
- **[workflow]**: [specific suggestion]
```

Only include actionable, specific suggestions — not generic praise or complaints.

### Team Lead Retrospective (MANDATORY — after every agent completes):
1. **Capture the agent's full TLDR verbatim** in SESSION_LOG.md
2. **Read the agent's Improvement Insights**
3. **Evaluate each suggestion** — is it valid? Would it save time next run?
4. **Apply valid suggestions immediately** — edit agent definitions, CLAUDE.md, criteria, or workflow docs
5. **Log what was applied** in SESSION_LOG.md under a "Retrospective" heading

### Deployment Policy (MANDATORY)

NEVER deploy to production or push code without explicit user approval. Always present a summary and wait for confirmation.

### Git Push Policy (MANDATORY)

NEVER push code (`git push`) without explicit user approval.
