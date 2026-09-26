extends SceneTree

## Visual harness for spot-checking the per-stage sky/ground palette (#115).
##
## Renders GameWorld's sky + ground for one stage's palette at a time with no
## player, enemies or HUD in the way, cycling through STAGES_TO_SHOW every
## CYCLE_SECONDS and captioning each with its stage number.
##
## This exists because verifying a late stage by actually playing to it is not
## viable: stages advance on a 30s timer, so stage 19 is ~9 minutes in, and
## unattended play loses all lives around stage 3 and drops back to the title
## screen. Headless screenshots are also not an option (the texture readback
## fails, which is the source of the familiar exit code 144), so this runs
## WINDOWED and is captured over the MCP bridge like any other frame:
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tests/sky_stage_preview.gd -- --mcp-port 9515 &
##   # wait for "Listening on 127.0.0.1:9515"
##   bash .claude/skills/game-capture/capture.sh --port 9515 \
##       --frames 5 --interval 4800 --output-dir /tmp/afterburner-capture/sky-check
##
## The port goes on the command line as `-- --mcp-port N`. This comment used to
## tell you to write the project-wide `mcp_ports.cfg` instead; #117 deleted that
## mechanism precisely because it was a shared mutable file that concurrent
## agents clobbered — do not reintroduce it.
##
## FRAME IDENTITY (#120 gate): when cycling, the capture interval must be
## slightly under CYCLE_SECONDS or the frames drift a stage behind, and a drift
## of 0.1 s per cycle silently mislabels every later frame. Do not trust capture
## ORDER. Either read each frame's burnt-in "STAGE N" caption, or — the reliable
## option for a measurement — pass `--preview-stages N` and run one stage per
## process, which makes identity a property of the process rather than of the
## timing:
##
##   ... --script res://tests/sky_stage_preview.gd -- --mcp-port 9515 --preview-stages 8
##
## `--preview-stages 1,2,4` also works. Omitted, it cycles all 23 as before.

const GameWorld := preload("res://scripts/game/game_world.gd")
const StageData := preload("res://scripts/stage/stage_data.gd")
const DepthUtil := preload("res://scripts/game/depth_util.gd")

# All 23, so a single run can be diffed against the verified arcade frames
# stage by stage (#123). Drop to a subset when iterating on one biome.
const STAGES_TO_SHOW := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
const CYCLE_SECONDS := 4.0
# A single requested stage holds still instead of flashing past in 4s — the
# point of asking for one stage is to capture it without racing a timer.
const SINGLE_STAGE_SECONDS := 30.0

var _world: Node2D
var _label: Label
var _elapsed := 0.0
var _index := -1
var _stages: Array = STAGES_TO_SHOW
var _hold_seconds := CYCLE_SECONDS


func _parse_requested_stages() -> Array:
	# `-- --preview-stages 8` or `--preview-stages 1,2,4`. Unparseable or
	# out-of-range entries are dropped loudly rather than silently, so a typo
	# cannot quietly hand back a different stage than the one being measured.
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--preview-stages")
	if idx < 0 or idx + 1 >= args.size():
		return STAGES_TO_SHOW
	var wanted: Array = []
	for part in String(args[idx + 1]).split(","):
		var s := part.strip_edges()
		if not s.is_valid_int():
			push_error("sky_stage_preview: --preview-stages entry '%s' is not an integer" % s)
			continue
		var n := int(s)
		if n < 1 or n > StageData.stage_count():
			push_error("sky_stage_preview: stage %d is out of range 1-%d" % [n, StageData.stage_count()])
			continue
		wanted.append(n)
	if wanted.is_empty():
		push_error("sky_stage_preview: --preview-stages selected nothing; showing all 23")
		return STAGES_TO_SHOW
	return wanted


func _initialize() -> void:
	_stages = _parse_requested_stages()
	_hold_seconds = SINGLE_STAGE_SECONDS if _stages.size() == 1 else CYCLE_SECONDS
	print("sky_stage_preview: showing stages %s at %.1fs each" % [str(_stages), _hold_seconds])
	_world = Node2D.new()
	_world.set_script(GameWorld)
	root.add_child(_world)

	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16.0, 8.0)
	_label.add_theme_font_size_override("font_size", 28)
	layer.add_child(_label)


func _process(delta: float) -> bool:
	_elapsed += delta
	var want := int(_elapsed / _hold_seconds)
	if want >= _stages.size():
		return true
	if want != _index:
		_index = want
		_apply(_stages[_index])
	return false


func _apply(stage_number: int) -> void:
	var data := StageData.get_stage(stage_number)
	_world.sky_top_color = data["sky_top"]
	_world.sky_horizon_color = data["sky_horizon"]
	_world.ground_color_a = data["ground_a"]
	_world.ground_color_b = data["ground_b"]
	_world.ground_color_c = data["ground_c"]
	# #139: the preview shows the stage's real world velocity too, so a capture
	# taken here is the same motion the stage renders in play. Pushed alongside
	# the horizon because apparent flow depends on both.
	_world.ground_scroll_speed = data["scroll_speed"]
	# #120: per-stage horizon — same call site game_manager_2d._apply_stage()
	# uses, so this preview shows the real horizon/ground-coverage a stage
	# gets in actual play, not just its palette.
	DepthUtil.set_horizon_fraction(data["horizon_fraction"])
	_label.text = "STAGE %d" % stage_number
	print("stage %d  sky_top=%s  sky_horizon=%s  horizon_fraction=%s" % [stage_number, data["sky_top"], data["sky_horizon"], data["horizon_fraction"]])
