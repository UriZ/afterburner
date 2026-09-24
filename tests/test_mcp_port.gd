extends SceneTree

## Unit tests for the MCP bridge's port-argument parsing (#117).
##
## The bug these lock in: a Godot instance launched for a specific port used to
## fall back to DEFAULT_PORT whenever its port config was missing, because
## "config deleted out from under me" and "nobody asked for a port" were
## indistinguishable. Another agent's capture script deleting the shared
## mcp_ports.cfg on exit was enough to silently move an instance onto 9501,
## where it served a different agent's screenshots.
##
## The fix moves the port onto the command line and keeps "not requested" and
## "requested but unusable" as separate outcomes. Only the former may default.
##
## Run with: godot --headless --script res://tests/test_mcp_port.gd

const McpBridge := preload("res://mcp_bridge_game.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== MCP Port Argument Tests ===")

	test_absent_flag_is_not_a_request()
	test_space_separated_form()
	test_equals_form()
	test_invalid_values_are_requests_not_defaults()
	test_out_of_range_ports_rejected()
	test_flag_found_among_other_args()
	test_sentinels_are_distinct()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_eq(actual: int, expected: int, message: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s (got %d, expected %d)" % [message, actual, expected])


func test_absent_flag_is_not_a_request() -> void:
	print("\ntest_absent_flag_is_not_a_request:")
	# This is the /screenshot and manual-launch path — it must stay able to
	# fall back to 9501, which is why PORT_NOT_REQUESTED exists at all.
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray([])),
		McpBridge.PORT_NOT_REQUESTED,
		"empty args request no port"
	)
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray(["--something-else", "7"])),
		McpBridge.PORT_NOT_REQUESTED,
		"unrelated args request no port"
	)


func test_space_separated_form() -> void:
	print("\ntest_space_separated_form:")
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray(["--mcp-port", "9510"])),
		9510,
		"--mcp-port 9510 parses"
	)


func test_equals_form() -> void:
	print("\ntest_equals_form:")
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray(["--mcp-port=9510"])),
		9510,
		"--mcp-port=9510 parses"
	)


func test_invalid_values_are_requests_not_defaults() -> void:
	print("\ntest_invalid_values_are_requests_not_defaults:")
	# The important half of #117: these must NOT read as "no port requested",
	# or a typo silently lands the instance on 9501 alongside someone else's.
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray(["--mcp-port", "banana"])),
		McpBridge.PORT_REQUEST_INVALID,
		"non-numeric value is an invalid request, not a missing one"
	)
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray(["--mcp-port"])),
		McpBridge.PORT_REQUEST_INVALID,
		"trailing --mcp-port with no value is an invalid request"
	)
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray(["--mcp-port="])),
		McpBridge.PORT_REQUEST_INVALID,
		"--mcp-port= with an empty value is an invalid request"
	)


func test_out_of_range_ports_rejected() -> void:
	print("\ntest_out_of_range_ports_rejected:")
	for bad in ["0", "-1", "65536", "99999"]:
		assert_eq(
			McpBridge.parse_port_arg(PackedStringArray(["--mcp-port", bad])),
			McpBridge.PORT_REQUEST_INVALID,
			"port '%s' is out of range" % bad
		)
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray(["--mcp-port", "65535"])),
		65535,
		"port 65535 is the top of the valid range"
	)


func test_flag_found_among_other_args() -> void:
	print("\ntest_flag_found_among_other_args:")
	assert_eq(
		McpBridge.parse_port_arg(PackedStringArray(["--verbose", "--mcp-port", "9520", "--other"])),
		9520,
		"flag is found when it is not first"
	)


func test_sentinels_are_distinct() -> void:
	print("\ntest_sentinels_are_distinct:")
	# Guards the whole premise: if these ever collapse to one value, _resolve_port()
	# can no longer tell a missing request from an unusable one and #117 returns.
	var distinct := McpBridge.PORT_NOT_REQUESTED != McpBridge.PORT_REQUEST_INVALID
	assert_eq(1 if distinct else 0, 1, "PORT_NOT_REQUESTED and PORT_REQUEST_INVALID differ")
	var both_invalid_as_ports := McpBridge.PORT_NOT_REQUESTED < 0 and McpBridge.PORT_REQUEST_INVALID < 0
	assert_eq(1 if both_invalid_as_ports else 0, 1, "both sentinels are negative, so neither can be mistaken for a port")
