extends Node

const DEFAULT_PORT := 9501
const MAX_HOLD_MS := 5000.0
const PORT_CONFIG_PATH := "res://mcp_ports.cfg"

## Exit code when an explicitly requested bridge port cannot be honoured.
## Distinct from Godot's own codes so a launcher can tell "your port request
## failed" apart from "the engine crashed".
const PORT_REQUEST_FAILED_EXIT_CODE := 9

## parse_port_arg() sentinels. Kept distinct because "nobody asked for a port"
## may fall back to DEFAULT_PORT and "asked for one we can't honour" may not.
const PORT_NOT_REQUESTED := -1
const PORT_REQUEST_INVALID := -2

var port := DEFAULT_PORT
var tcp_server: TCPServer
var clients: Array[StreamPeerTCP] = []
var pending_screenshot_client: StreamPeerTCP = null
var _deferred_release: Vector2 = Vector2.ZERO

## Where `port` came from — "default" means nothing asked for a port, which is
## the only case where falling back is legitimate. See _resolve_port().
var _port_source := "default"

## Keys currently held via key_down/hold. keycode(int) -> Timer or null
## (null means held indefinitely until an explicit key_up).
var held_keys: Dictionary = {}
var _last_scene: Node = null


func _ready() -> void:
	var resolved := _resolve_port()
	if resolved < 0:
		return  # _resolve_port() already reported and quit.
	port = resolved

	tcp_server = TCPServer.new()
	var err := tcp_server.listen(port, "127.0.0.1")
	if err != OK:
		# An explicit request that cannot be honoured is fatal (#117). Silently
		# continuing here is what let an instance launched for port 9510 end up
		# on 9501, serving another agent's screenshots to whoever asked first.
		if _port_source != "default":
			_fail_port_request(
				"could not listen on port %d (error %d) — something else is probably already bound to it" % [port, err]
			)
			return
		push_error("MCP Bridge Game: Failed to listen on port %d (error %d)" % [port, err])
	else:
		print("MCP Bridge Game: Listening on 127.0.0.1:%d" % port)
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


## Resolves the bridge port, or returns -1 after reporting a fatal error.
##
## Priority (#117):
##   1. `-- --mcp-port N` (or `--mcp-port=N`) on the command line. This is the
##      race-free channel and what every capture skill uses.
##   2. res://mcp_ports.cfg — legacy path, kept for manual launches.
##   3. DEFAULT_PORT.
##
## A request from (1) or (2) is BINDING: if it cannot be honoured the process
## reports and exits rather than falling back. Only (3) — nobody asked for a
## port at all — may legitimately use the default. The original bug was that a
## missing config was indistinguishable from "no port requested", so a config
## deleted mid-launch by another agent's cleanup silently downgraded the
## instance to 9501.
func _resolve_port() -> int:
	var from_args := parse_port_arg(OS.get_cmdline_user_args())
	if from_args != PORT_NOT_REQUESTED:
		_port_source = "--mcp-port"
		if from_args == PORT_REQUEST_INVALID:
			_fail_port_request("--mcp-port needs a port number in 1-65535")
			return -1
		return from_args

	if FileAccess.file_exists(PORT_CONFIG_PATH):
		_port_source = PORT_CONFIG_PATH
		var config := ConfigFile.new()
		if config.load(PORT_CONFIG_PATH) != OK:
			_fail_port_request("%s exists but could not be parsed" % PORT_CONFIG_PATH)
			return -1
		if not config.has_section_key("mcp", "game_port"):
			_fail_port_request("%s has no [mcp] game_port key" % PORT_CONFIG_PATH)
			return -1
		return int(config.get_value("mcp", "game_port"))

	return DEFAULT_PORT


## Extracts `--mcp-port N` or `--mcp-port=N` from user args. Pure, so the
## precedence and validation rules are testable — see tests/test_mcp_port.gd.
##
## Returns the port number, PORT_NOT_REQUESTED when no such flag is present, or
## PORT_REQUEST_INVALID when one is present but unusable. The last two must stay
## distinct: "nobody asked" may fall back to DEFAULT_PORT, "asked and we can't"
## must not (#117).
static func parse_port_arg(args: PackedStringArray) -> int:
	for i in range(args.size()):
		var arg := args[i]
		var raw := ""
		if arg == "--mcp-port":
			raw = args[i + 1] if i + 1 < args.size() else ""
		elif arg.begins_with("--mcp-port="):
			raw = arg.trim_prefix("--mcp-port=")
		else:
			continue
		if not raw.is_valid_int():
			return PORT_REQUEST_INVALID
		var value := raw.to_int()
		if value <= 0 or value > 65535:
			return PORT_REQUEST_INVALID
		return value
	return PORT_NOT_REQUESTED


## Reports a port request that cannot be satisfied and quits. Writes to stderr
## as well as the error log because launchers grep the process output, and
## never leaves the process running on some other port.
func _fail_port_request(reason: String) -> void:
	var message := "MCP Bridge Game: FATAL port request via %s failed: %s. Refusing to fall back to %d." % [
		_port_source, reason, DEFAULT_PORT,
	]
	printerr(message)
	push_error(message)
	get_tree().quit(PORT_REQUEST_FAILED_EXIT_CODE)


func _exit_tree() -> void:
	for client in clients:
		client.disconnect_from_host()
	clients.clear()
	if tcp_server:
		tcp_server.stop()


func _process(_delta: float) -> void:
	# Any scene swap (title <-> game, game over <-> title) means a fresh run;
	# don't let a held key leak across it and get stuck.
	var current_scene := get_tree().current_scene
	if current_scene != _last_scene:
		_last_scene = current_scene
		_release_all_held_keys()

	if not tcp_server or not tcp_server.is_listening():
		return

	# Accept new connections
	while tcp_server.is_connection_available():
		var peer := tcp_server.take_connection()
		if peer:
			clients.append(peer)

	# Process existing clients
	var to_remove: Array[int] = []
	for i in range(clients.size()):
		var client := clients[i]
		client.poll()
		var status := client.get_status()

		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			to_remove.append(i)
			continue

		if status != StreamPeerTCP.STATUS_CONNECTED:
			continue

		if client.get_available_bytes() > 0:
			var data := client.get_utf8_string(client.get_available_bytes())
			if data.length() > 0:
				_handle_request(client, data)

	# Remove disconnected clients (reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		clients.remove_at(to_remove[i])


func _handle_request(client: StreamPeerTCP, data: String) -> void:
	var json := JSON.new()
	var err := json.parse(data)
	if err != OK:
		_send_response(client, {"error": "Invalid JSON: %s" % json.get_error_message()})
		return

	var request: Dictionary = json.data
	var cmd: String = request.get("cmd", "")

	match cmd:
		"screenshot":
			# Defer to frame_post_draw for correct viewport capture
			pending_screenshot_client = client
			# Force a frame draw in case low_processor_mode is active
			RenderingServer.force_draw()
		"get_runtime_tree":
			_send_response(client, _cmd_get_runtime_tree())
		"click":
			var x: float = request.get("x", 0.0)
			var y: float = request.get("y", 0.0)
			_send_response(client, _cmd_click(x, y))
		"key":
			var key_name: String = request.get("key", "")
			_send_response(client, _cmd_key(key_name))
		"key_down":
			var key_name: String = request.get("key", "")
			_send_response(client, _cmd_key_down(key_name))
		"key_up":
			var key_name: String = request.get("key", "")
			_send_response(client, _cmd_key_up(key_name))
		"hold":
			var key_name: String = request.get("key", "")
			var ms: float = request.get("ms", 200.0)
			_send_response(client, _cmd_hold(key_name, ms))
		"set_capture_invincible":
			var enabled: bool = request.get("enabled", true)
			var game_state := get_node_or_null("/root/GameState")
			if game_state:
				game_state.capture_invincible = enabled
			_send_response(client, {"ok": game_state != null, "capture_invincible": enabled})
		_:
			_send_response(client, {"error": "Unknown command: %s" % cmd})


func _on_frame_post_draw() -> void:
	if pending_screenshot_client == null:
		return

	var client := pending_screenshot_client
	pending_screenshot_client = null

	var image := get_viewport().get_texture().get_image()
	if not image:
		_send_response(client, {"error": "Failed to capture viewport"})
		return

	var png_bytes := image.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)
	_send_response(client, {"ok": true, "image_base64": b64})


func _cmd_click(x: float, y: float) -> Dictionary:
	# Simulate mouse press
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(x, y)
	press.global_position = Vector2(x, y)
	press.pressed = true
	get_viewport().push_input(press)
	# Defer the release to next frame so the UI processes the press first
	_deferred_release = Vector2(x, y)
	call_deferred("_send_mouse_release")
	return {"ok": true, "x": x, "y": y}


func _send_mouse_release() -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = _deferred_release
	release.global_position = _deferred_release
	release.pressed = false
	get_viewport().push_input(release)


func _cmd_key(key_name: String) -> Dictionary:
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return {"error": "Unknown key: %s" % key_name}
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	# Use Input.parse_input_event to update both Input singleton action state
	# AND viewport input chain (push_input only updates the viewport chain)
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	call_deferred("_send_deferred_key_release", release)
	return {"ok": true, "key": key_name}


func _send_deferred_key_release(event: InputEventKey) -> void:
	Input.parse_input_event(event)


## Press-and-hold with no auto-release. Pairs with key_up. Unlike the legacy
## "key" command, the release does NOT land in the same Input flush batch as
## the press, so level-triggered reads (is_action_pressed, get_axis) see the
## key as held on the frames in between.
func _cmd_key_down(key_name: String) -> Dictionary:
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return {"error": "Unknown key: %s" % key_name}
	_press_key(keycode)
	held_keys[keycode] = null
	return {"ok": true, "key": key_name}


func _cmd_key_up(key_name: String) -> Dictionary:
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return {"error": "Unknown key: %s" % key_name}
	_release_held_key(keycode)
	return {"ok": true, "key": key_name}


## Press now, auto-release after ms via a real Timer (not call_deferred) so
## the release lands several frames after the press.
func _cmd_hold(key_name: String, ms: float) -> Dictionary:
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return {"error": "Unknown key: %s" % key_name}
	var duration_ms := clampf(ms, 0.0, MAX_HOLD_MS)

	_press_key(keycode)
	if held_keys.has(keycode) and held_keys[keycode] != null:
		(held_keys[keycode] as Timer).queue_free()

	var timer := Timer.new()
	timer.wait_time = maxf(duration_ms / 1000.0, 0.001)
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_hold_timeout.bind(keycode, timer))
	timer.start()
	held_keys[keycode] = timer
	return {"ok": true, "key": key_name, "ms": duration_ms}


func _on_hold_timeout(keycode: int, timer: Timer) -> void:
	_release_held_key(keycode)
	timer.queue_free()


func _press_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)


func _release_held_key(keycode: Key) -> void:
	if held_keys.has(keycode):
		var timer: Timer = held_keys[keycode]
		if timer != null:
			timer.queue_free()
		held_keys.erase(keycode)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)


func _release_all_held_keys() -> void:
	for keycode in held_keys.keys():
		_release_held_key(keycode)


func _cmd_get_runtime_tree() -> Dictionary:
	return {"ok": true, "tree": _serialize_node(get_tree().root)}


func _serialize_node(node: Node) -> Dictionary:
	var result := {
		"name": node.name,
		"type": node.get_class(),
	}
	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(_serialize_node(child))
	if children.size() > 0:
		result["children"] = children
	return result


func _send_response(client: StreamPeerTCP, response: Dictionary) -> void:
	var json_str := JSON.stringify(response)
	client.put_data((json_str + "\n").to_utf8_buffer())
