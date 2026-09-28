# File & Port Ownership (TL-maintained — update when issues are created/assigned/closed)

Judge insight (#120-#122 gate): ownership must live in a repo file, not issue prose — issue comments go stale the moment a new issue lands.

## Sequencing decisions (binding)
- **#120 lands before #128** (TL decision 2026-09-25): #120 is a small per-stage horizon constant + shader-uniform fix; #128 (world roll) is the larger projection refactor and rebases on it. #128's spec must define its merge against post-#120 `game_world.gd` explicitly.
- **#122/#128 adjacency**: #122's `_process_demo_flight()` calls `_update_banking()`, which the #128 follow-up deletes — #122's implementer is NOT blocked: re-point the call if the follow-up hasn't landed; the follow-up adapts.
- **#128 jet-bank follow-up is SCHEDULED immediately behind #112/#92 landing** (judge: spec's own risk 4 says world-roll-without-jet-change looks worse than today — the gap must be short; amendment 2 carries a ready-to-go mini-spec).
- **#128 SPLIT** (TL decision, per architect): world-roll core (depth_util.gd, game_world.gd, ground_terrain_2d.gdshader) lands as #128; the jet-bank coupling (§3 — deletes `_update_banking()`/`MAX_BANK_ANGLE` in player_jet_2d.gd) is a small FOLLOW-UP after dev-sky-115's #112/#92 diff lands — never merged blind against the open 400-line silhouette rebuild.
- **#120's `stage_data.gd` hunk lands as its own early commit**; #124 (palette re-grade) rebases onto it.
- **#135** (biome structure) after #124 + #120.
- **#132 (clouds) lands after #128** (clouds must inherit world roll; a level cloud over a rolled horizon is worse than none) — and #128/#124's detectors re-validate on cloud-bearing frames before quoting numbers again.

## Pending combined commit
- #112+#92 (jet rebuild + opacity): QA-PASSED, but player_jet_2d.gd also carries in-progress #122 work (same owner dev-sky-115) — commits together when #122 completes+passes QA.

## Current assignments (REBUILT after outage #5, 2026-09-29)
| Issue | Agent | Files owned | Ports |
|---|---|---|---|
| #121+biome retune → #135 retune | dev-tune | ground_features_2d + canyon_walls_2d + shader aniso constant | 9636 |
| #132 close-out | dev-132b | clouds_2d + its tests + cloud hooks | 9670 |
| #152 close-out | dev-152b | composition-metrics skill | 9655 |
| re-checks on deck | vqa-131 / qa-139b (dead — respawn fresh QA when deliveries land) | read-only | 9656/9690 |

## Prior assignments (outage #4/#5 waves — sessions dead)
| Issue | Agent | Files owned | Ports |
|---|---|---|---|
| #128 CORE assess+complete | dev-128b | depth_util, game_world draw/rotation, shader contract check, reparenting sites | 9670+ |
| #133 assess+complete | dev-133b | scripts/weapons trail drawing (projectile_renderer + call sites) | 9636 |
| #131 assess+complete | dev-131b | enemy_sprite_renderer + constants + enemy_jet | 9655 |
| #139 QA | qa-139b | read-only | 9690+ |

## Prior assignments (outage #3 wave — sessions dead)
| Issue | Agent | Files owned | Ports |
|---|---|---|---|
| #129 HUD QA | vqa-129 | read-only | 9635 |
| #124 assess+complete → #139 impl | dev-124-139 | stage_data ground values + measurement scripts; then game_world speed constant + stage speed keys (functions claimed in SESSION_LOG) | 9515 / 9660+ |
| #140 close-out → #128 CORE impl | dev-140-128 | composition-metrics skill; then depth_util + game_world draw/rotation + reparenting sites | 9670+ |
| #127+#136 final verify | qa-127-final | read-only | 9650+ |

## Superseded assignments (sessions dead)
| Issue | Agent | Files owned | Ports |
|---|---|---|---|
| #112+#92 jet | dev-sky-115 | jet draw path (claimed functions in game_world.gd / player script — see its SESSION_LOG claim) | 9510 |
| #130+#134 explosions | dev-125 | scripts/effects/ | 9515 |
| #127+#136 speed metric | dev-113-116 | motion-metrics skill + game-movie selftest/SKILL.md | 9640+ |
| #112+#92 jet QA | vqa-123 | read-only | 9630 |
| #120/#121/#122 spec rework, then #124 spec, then #135 | architect-comp | read-only (specs) | 9575+ |
| #128 spec | architect-113 | read-only (specs); scratch prototypes only | 9570+ |
| judge gates | judge-113-arch / judge-cycle-1 | read-only | 9600+ / 9595 |

## Unassigned queue
#129 (HUD), #131 (enemies), #132 (clouds), #133 (trails), #126 (cycle tracker).

## Shared-file registry (check before assigning — list claimed FUNCTIONS, not just files: #128's follow-up deletes _update_banking() which #122's _process_demo_flight() calls, a collision no file-level view caught)
- `game_world.gd`: #120 (horizon/projection, `_draw_sky()`), #128 (roll — after #120), #121 (appends one new function — disjoint), dev-sky-115 (jet draw functions — claimed)
- `stage_data.gd`: #120 (adds horizon key) → #124 (69 colour values) — strict sequence
- `ground_terrain_2d.gdshader`: #121 explicitly does NOT touch; #135 will; latent `horizon_y` uniform bug fixed by #120
- `scripts/effects/`: dev-125
- capture/metrics skills: stable (committed); #127 will extend motion-metrics
