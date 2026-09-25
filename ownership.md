# File & Port Ownership (TL-maintained — update when issues are created/assigned/closed)

Judge insight (#120-#122 gate): ownership must live in a repo file, not issue prose — issue comments go stale the moment a new issue lands.

## Sequencing decisions (binding)
- **#120 lands before #128** (TL decision 2026-09-25): #120 is a small per-stage horizon constant + shader-uniform fix; #128 (world roll) is the larger projection refactor and rebases on it. #128's spec must define its merge against post-#120 `game_world.gd` explicitly.
- **#128 jet-bank follow-up is SCHEDULED immediately behind #112/#92 landing** (judge: spec's own risk 4 says world-roll-without-jet-change looks worse than today — the gap must be short; amendment 2 carries a ready-to-go mini-spec).
- **#128 SPLIT** (TL decision, per architect): world-roll core (depth_util.gd, game_world.gd, ground_terrain_2d.gdshader) lands as #128; the jet-bank coupling (§3 — deletes `_update_banking()`/`MAX_BANK_ANGLE` in player_jet_2d.gd) is a small FOLLOW-UP after dev-sky-115's #112/#92 diff lands — never merged blind against the open 400-line silhouette rebuild.
- **#120's `stage_data.gd` hunk lands as its own early commit**; #124 (palette re-grade) rebases onto it.
- **#135** (biome structure) after #124 + #120.

## Current assignments
| Issue | Agent | Files owned | Ports |
|---|---|---|---|
| #112+#92 jet | dev-sky-115 | jet draw path (claimed functions in game_world.gd / player script — see its SESSION_LOG claim) | 9510 |
| #130+#134 explosions | dev-125 | scripts/effects/ | 9515 |
| #114 QA | qa-113-116 | read-only | 9620+ |
| #120/#121/#122 spec rework, then #124 spec, then #135 | architect-comp | read-only (specs) | 9575+ |
| #128 spec | architect-113 | read-only (specs); scratch prototypes only | 9570+ |
| judge gates | judge-113-arch / judge-cycle-1 | read-only | 9600+ / 9595 |

## Unassigned queue
#129 (HUD), #131 (enemies), #132 (clouds), #133 (trails), #127 (speed metric — after #114 commits; candidate: dev-113-116), #126 (cycle tracker).

## Shared-file registry (check before assigning)
- `game_world.gd`: #120 (horizon/projection, `_draw_sky()`), #128 (roll — after #120), #121 (appends one new function — disjoint), dev-sky-115 (jet draw functions — claimed)
- `stage_data.gd`: #120 (adds horizon key) → #124 (69 colour values) — strict sequence
- `ground_terrain_2d.gdshader`: #121 explicitly does NOT touch; #135 will; latent `horizon_y` uniform bug fixed by #120
- `scripts/effects/`: dev-125
- capture/metrics skills: stable (committed); #127 will extend motion-metrics
