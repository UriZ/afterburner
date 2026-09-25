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
##   printf '[mcp]\ngame_port=9510\n' > mcp_ports.cfg
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tests/sky_stage_preview.gd &
##   # wait for "Listening on 127.0.0.1:9510", then rm mcp_ports.cfg
##   bash .claude/skills/game-capture/capture.sh --port 9510 \
##       --frames 5 --interval 4800 --output-dir /tmp/sky-check
##
## Note the capture interval must be slightly under CYCLE_SECONDS or the frames
## drift a stage behind, and the harness quits once it has shown them all.

const GameWorld := preload("res://scripts/game/game_world.gd")
const StageData := preload("res://scripts/stage/stage_data.gd")
const DepthUtil := preload("res://scripts/game/depth_util.gd")

# All 23, so a single run can be diffed against the verified arcade frames
# stage by stage (#123). Drop to a subset when iterating on one biome.
const STAGES_TO_SHOW := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
const CYCLE_SECONDS := 4.0

var _world: Node2D
var _label: Label
var _elapsed := 0.0
var _index := -1


func _initialize() -> void:
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
	var want := int(_elapsed / CYCLE_SECONDS)
	if want >= STAGES_TO_SHOW.size():
		return true
	if want != _index:
		_index = want
		_apply(STAGES_TO_SHOW[_index])
	return false


func _apply(stage_number: int) -> void:
	var data := StageData.get_stage(stage_number)
	_world.sky_top_color = data["sky_top"]
	_world.sky_horizon_color = data["sky_horizon"]
	_world.ground_color_a = data["ground_a"]
	_world.ground_color_b = data["ground_b"]
	_world.ground_color_c = data["ground_c"]
	# #120: per-stage horizon — same call site game_manager_2d._apply_stage()
	# uses, so this preview shows the real horizon/ground-coverage a stage
	# gets in actual play, not just its palette.
	DepthUtil.set_horizon_fraction(data["horizon_fraction"])
	_label.text = "STAGE %d" % stage_number
	print("stage %d  sky_top=%s  sky_horizon=%s  horizon_fraction=%s" % [stage_number, data["sky_top"], data["sky_horizon"], data["horizon_fraction"]])
