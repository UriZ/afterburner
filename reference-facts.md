# Reference Facts (verified — cite, don't re-derive)

Facts about After Burner II established with proven methodology this project keeps rediscovering. Specs and gates CITE these; add new ones with their evidence pointer. (Origin: #128 retro — two specs independently re-derived the horizon-tilt fact in one day.)

| Fact | Evidence (append '· re-verified: <agent/gate>' as facts survive independent checks — strength at a glance) |
|---|---|
| The HUD prints the stage number CONTINUOUSLY at bottom-centre (x=376..414, y=426..450 of 686x480) — stage identity is provable from any single frame | #120-#122 specs; #123 |
| Verified stage↔timestamp map for the cached longplay; attract ends ~84s, run starts ~88s; stage-1 FLIGHT starts ~1:34 | stage_data.gd header (#123) |
| Sky is a flat fill with ZERO local variance (t=94: 1 unique colour, std 0.00); the sea/ground has 1600+ unique colours — texture, not colour, separates sky from ground on blue-sea stages | #128 spec · re-verified: #128 gate (controlled A/B — loose colour mask returns confident 60°-wrong answers) |
| The horizon/world TILTS with bank: rigid rotation about screen centre, −6.2° to +67.9°, saturating 65-68°, median rate 74.5°/s; HUD screen-fixed | #128 spec (42 fits, verified stage 1) · re-verified: #128 gate (independent re-fit <1° on all key values) |
| Never use a horizontal split line for sky/ground masking — banked frames leak a wedge | #124 methodology note |
| Skies: flat fill on most stages; hue-shift glow at held saturation on stages 2,14,17,20,22 only; hard 6-20px horizon cut | #123 (proven identities) |
| Ground colour dominance varies by stage — measure at gate time; arcade desert measured 72.0%/53.6% single-bin (NOT the once-baked 89.2%); being MORE uniform than the arcade is also wrong | cycle-1 eval (#126) |
| AB2 stage 1 ground is open OCEAN with directional wave streaks + occasional island — structure, not palette | #124/#135 (proven frames t=92-116) |
| Canyon stages (8, 17) put the horizon at ~6-14%H with ground ~85%+ of frame; cruise stages 60-65%H | #120 spec + judge re-measure |
| project.godot InputMap binds physical_keycode ONLY (keycode:0 everywhere); is_key_pressed falsely accepts keycode-only events | #114 gate (CLAUDE.md) |
| AB2 ground texture temporally aliases below ~60fps sampling — no sub-60fps frame comparison supports a speed claim | #113 (criteria.md) |
| Enemy scale-up: an approaching feature grows x1.45-1.69 per 0.25s; our depth_to_scale() already predicts this within 5-11% | #121 spec |
| Player jet screen-position distribution (arcade): cx sd 10.44pp, cy sd 11.99pp, 41% of frames >5pp off-centre; two regimes (cruise sd 12.88, canyon 2.59) | #122 spec + judge re-measure |
| Modal colour estimation works on flat fills (sky mode share 97.8%) and FAILS on dithered grounds (mode share 5.7%; 10% sky contamination flips the mode) — methods don't transfer sky→ground | #124 spec |
| Sky reaches the near-ground band on 69% of sampled frames (roll) — NO fixed screen region is reliably ground; use frame SELECTION, not masking | #124 spec |
| Arcade stage-1 ground band hue swings 100° between frames (deep-blue sea + cyan crests + green island); stage 7 swings 80° — some grounds are genuinely two-hue | #124 spec |
| Canyon stages barely roll: stage 8 measures −8.2° to +16.2°, mostly ±2° (37 fits) — the ≥50° roll target applies to CRUISE stages only | #128 amendment |
| ground_terrain_2d.gdshader reconstructs from UV, not SCREEN_UV — terrain rotates rigidly with the quad for free; switching to SCREEN_UV/FRAGCOORD silently breaks roll (guarded by a negative-control AC) | #128 amendment |
| A tilted horizon crosses different heights in different columns — horizon-height estimates are column-dependent unless tilt is fitted out first (line fit does; row-coverage profile doesn't); explains 3-methods-3-answers on stage 8 | #128 amendment |
