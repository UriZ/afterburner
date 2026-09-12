extends SceneTree

## Unit tests for game_environment_2d.gd
## Run with: godot --headless --script res://tests/test_environment_2d.gd

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	print("=== GameEnvironment2D Tests ===")

	var env := load("res://scripts/environment/game_environment_2d.gd").new() as Node

	test_defaults(env)
	test_stage_palette_mapping(env)
	test_set_stage_type(env)
	test_city_lights_count(env)

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_eq(a, b, msg: String) -> void:
	if a == b:
		_pass_count += 1
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		print("  FAIL: ", msg, " — expected ", b, " got ", a)


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		print("  FAIL: ", msg)


func test_defaults(env: Node) -> void:
	print("-- defaults --")
	# Default stage type is DESERT (0)
	assert_eq(env.get("_stage_type"), 0, "default stage type is DESERT")
	assert_eq(env.get("_scroll"), 0.0, "scroll starts at 0")


func test_stage_palette_mapping(env: Node) -> void:
	print("-- set_stage_palette mapping --")
	env.call("set_stage_palette", 1)
	assert_eq(env.get("_stage_type"), 0, "stage 1 -> DESERT")
	env.call("set_stage_palette", 5)
	assert_eq(env.get("_stage_type"), 1, "stage 5 -> COASTAL")
	env.call("set_stage_palette", 12)
	assert_eq(env.get("_stage_type"), 3, "stage 12 -> CITY")
	env.call("set_stage_palette", 16)
	assert_eq(env.get("_stage_type"), 2, "stage 16 -> NIGHT")
	env.call("set_stage_palette", 20)
	assert_eq(env.get("_stage_type"), 0, "stage 20 -> DESERT (repeat)")


func test_set_stage_type(env: Node) -> void:
	print("-- set_stage_type --")
	env.call("set_stage_type", 1)  # COASTAL
	assert_eq(env.get("_stage_type"), 1, "set_stage_type(1) -> COASTAL")
	env.call("set_stage_type", 2)  # NIGHT
	assert_eq(env.get("_stage_type"), 2, "set_stage_type(2) -> NIGHT")
	env.call("set_stage_type", 3)  # CITY
	assert_eq(env.get("_stage_type"), 3, "set_stage_type(3) -> CITY")
	env.call("set_stage_type", 0)  # DESERT
	assert_eq(env.get("_stage_type"), 0, "set_stage_type(0) -> DESERT")


func test_city_lights_count(env: Node) -> void:
	print("-- city lights --")
	# Manually call _build_city_lights since _ready doesn't run outside scene tree
	env.call("_build_city_lights")
	var lights = env.get("_city_lights")
	assert_true(lights.size() == 320, "city lights count is 320")
	# All lights should be below horizon
	var all_below_horizon := true
	for pt in lights:
		if pt.y < env.HORIZON_Y:
			all_below_horizon = false
			break
	assert_true(all_below_horizon, "all city lights are below horizon")
