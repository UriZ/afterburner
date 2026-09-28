extends Node
## Frame-scheduled input playback for deterministic MovieWriter capture (#114).
##
## Wall-clock input timing cannot work under MovieWriter: game time and real time
## have no fixed relationship (measured at 66%, 74%, 100% and 150% of real-time
## on this machine), so `sleep 1; send Enter` lands on a different game frame
## every run. This autoload schedules input against the FRAME COUNTER instead,
## which is exactly what `--fixed-fps` makes deterministic.
##
## Inert unless `--capture-input <path>` appears in the user args, so normal play
## and every existing tool are unaffected.

## -1 means "not capturing" and is what every normal run sees. >= 0 is a seed
## requested via --capture-seed, which game_manager_2d.gd uses in place of
## randomize(). Static so it can be read before this node's _process starts.
static var requested_seed: int = -1

const SCHEMA := "capture-input/1"
const VALID_ACTIONS := ["key", "key_down", "key_up"]

## Exit code for a timeline the script should have rejected before launch.
const TIMELINE_ERROR_EXIT_CODE := 3

## Frame-scheduled timelines assume this rate — e.g. timelines/start-game.json's
## "frame 30" means "0.5s in" (30/60). Only --fixed-fps holds delta EXACTLY
## constant frame to frame; any other launch mode — real-time rendering,
## unpaced headless — gives an unpredictable delta, which silently desyncs
## every scheduled event from its intended real-world time. THIRD silent
## time-base incident this session (#113, #116, then #141): a live rig on
## this machine measured 142fps and a 69s timeline finished in ~29s wall —
## 0.42x the intended duration, with no error at all.
const ASSUMED_FPS := 60.0
const ASSUMED_DELTA := 1.0 / ASSUMED_FPS
## Loose enough for float rounding under --fixed-fps (measured exact to the
## printed precision), tight enough that a --fixed-fps 30 run (2x off) or an
## unpaced run (single-digit-ms deltas, roughly an order of magnitude off) both
## trip it well clear of any legitimate jitter.
const DELTA_TOLERANCE := 0.001
## Which _process() call the guard trusts (#154 — a #141 follow-up). Frame 1's
## delta is an ENGINE WARM-UP ARTIFACT, not the requested rate: probed
## directly (--headless --fixed-fps N, bare _process, no CaptureInput
## involved) at N=24/30/60/90/120/144/240, frame 1 reads a value that does
## NOT track N (60/90/120 all report exactly 0.016667 on frame 1 alone) while
## frame 2 onward reads the TRUE 1/N exactly, every N tested. Checking frame 1
## alone therefore let --fixed-fps 90 and 120 sail through silently
## (0.016667 == ASSUMED_DELTA by pure coincidence of the warm-up artifact,
## not because either is 60fps) — confirmed at the real guard, not just the
## probe: a --fixed-fps 90 run with start-game.json exited 0 and fired its
## frame-30 event at 0.333s real time instead of the timeline's intended
## 0.5s, silent. #154 filed this against the exact rate #149 pushes capture
## work toward (120fps). Moving the checked frame to 2 uses the only frame
## the probe showed to be reliable for every rate tried.
const CHECK_FRAME := 2

## frame(int) -> Array of event dictionaries, in file order.
var _schedule: Dictionary = {}
## frame(int) -> Array of keycodes to release then (tap implementation).
var _pending_releases: Dictionary = {}
var _frame: int = 0
var _applied: int = 0
var _timeline_path := ""

## --capture-probe <action>: prints "PROBE <frame> <0|1>" per frame for that
## InputMap action. Exists for selftest test 4, which pins the one-frame offset
## through Input.is_action_pressed() — the API the game actually uses. Probing
## via Input.is_key_pressed() instead would pass on an implementation that sets
## only `keycode`, and such an implementation cannot drive this project at all,
## because every action in project.godot binds physical_keycode with keycode: 0.
var _probe_action := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	requested_seed = _parse_int_arg(args, "--capture-seed", -1)
	_timeline_path = _parse_string_arg(args, "--capture-input")
	_probe_action = _parse_string_arg(args, "--capture-probe")

	if _timeline_path.is_empty() and _probe_action.is_empty():
		# Nothing asked for playback. Do not touch input, do not burn a _process.
		set_process(false)
		return
	if _timeline_path.is_empty():
		return  # probe-only run

	if not _load_timeline(_timeline_path):
		return

	print("CaptureInput: %d scheduled frames from %s (seed %d)" % [
		_schedule.size(), _timeline_path, requested_seed,
	])


func _exit_tree() -> void:
	if _timeline_path.is_empty():
		return
	# Events past the end of the run are ignored, not fatal — a timeline reused
	# against a shorter capture must still work. Reporting them here rather than
	# up front means we can name exactly which ones never fired, without needing
	# the engine's --quit-after value plumbed in as a second flag.
	var missed: Array[int] = []
	for frame in _schedule.keys():
		if int(frame) > _frame:
			missed.append(int(frame))
	if missed.size() > 0:
		missed.sort()
		push_warning(
			"CaptureInput: capture ended at frame %d; %d timeline event frame(s) never fired: %s"
			% [_frame, missed.size(), str(missed)]
		)


func _process(delta: float) -> void:
	_frame += 1

	# Time-base guard (#141, frame moved to CHECK_FRAME by #154): checked once,
	# on CHECK_FRAME (frame 2) — frame 1's delta is an engine warm-up artifact
	# that does not track the requested rate (see CHECK_FRAME's comment), so
	# checking it alone let --fixed-fps 90/120 through silently. Scoped to
	# timeline playback only (not bare probing, which makes no real-world-time
	# claim) — by the time _timeline_path is non-empty here, _load_timeline()
	# already succeeded, since a parse failure quits the engine from _ready()
	# before any frame runs. Any event scheduled at frame 1 itself still
	# dispatches normally below before this check ever runs on frame 2 — the
	# guard cannot retroactively undo a frame-1 dispatch, only catch a wrong
	# time base before frame 2 onward compounds it.
	if _frame == CHECK_FRAME and not _timeline_path.is_empty():
		if absf(delta - ASSUMED_DELTA) > DELTA_TOLERANCE:
			_fail(
				"timeline playback requires a fixed %.0ffps time base (launch under --fixed-fps %d) — measured a %.5fs frame delta (~%.1ffps) on frame %d, not the assumed %.5fs. See #141/#154." % [
					ASSUMED_FPS, int(ASSUMED_FPS), delta, 1.0 / maxf(delta, 0.0001), _frame, ASSUMED_DELTA,
				]
			)
			return

	# Probe at the TOP of the frame, before this frame's events are applied, so
	# the reading is "what the action system holds entering frame N" — which is
	# what every other node in this frame will also see.
	if not _probe_action.is_empty():
		print("PROBE %d %d" % [_frame, 1 if Input.is_action_pressed(_probe_action) else 0])

	# Releases first: a tap pressed at F is released at F+1, and that release
	# must land before any new press scheduled for the same frame.
	if _pending_releases.has(_frame):
		for keycode: int in _pending_releases[_frame]:
			_send_key(keycode, false)
		_pending_releases.erase(_frame)

	if not _schedule.has(_frame):
		return

	for event: Dictionary in _schedule[_frame]:
		var keycode: int = event["keycode"]
		match event["action"]:
			"key":
				# Press now, release next frame. Pressing and releasing within one
				# frame makes level-triggered reads (is_action_pressed, get_axis)
				# miss the input entirely — the #91 finding the bridge's
				# key_down/key_up split already encodes.
				_send_key(keycode, true)
				var release_frame := _frame + 1
				if not _pending_releases.has(release_frame):
					_pending_releases[release_frame] = []
				_pending_releases[release_frame].append(keycode)
			"key_down":
				_send_key(keycode, true)
			"key_up":
				_send_key(keycode, false)
		_applied += 1


## Builds and dispatches a key event.
##
## BOTH keycode and physical_keycode are set, and physical_keycode is the one
## that matters: every action in project.godot binds `physical_keycode` with
## `keycode: 0`, so an event carrying only `keycode` is completely inert for
## gameplay — Input.is_action_pressed() never fires — while still reading as
## pressed via Input.is_key_pressed(). That asymmetry is why selftest test 4
## asserts through the action system (#114 judge gate).
func _send_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _load_timeline(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return _fail("timeline not found: %s" % path)

	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("timeline %s is not valid JSON: %s at line %d" % [
			path, json.get_error_message(), json.get_error_line(),
		])

	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return _fail("timeline %s must be a JSON object" % path)
	if data.get("schema", "") != SCHEMA:
		return _fail("timeline %s has schema %s, expected %s" % [
			path, str(data.get("schema", "<missing>")), SCHEMA,
		])
	var events: Variant = data.get("events", null)
	if typeof(events) != TYPE_ARRAY:
		return _fail("timeline %s has no events array" % path)

	for i in range(events.size()):
		var event: Variant = events[i]
		if typeof(event) != TYPE_DICTIONARY:
			return _fail("timeline %s event %d is not an object" % [path, i])

		var raw_frame: Variant = event.get("frame", null)
		# JSON numbers arrive as floats; require an exact integer >= 1.
		if typeof(raw_frame) != TYPE_FLOAT and typeof(raw_frame) != TYPE_INT:
			return _fail("timeline %s event %d has no numeric 'frame'" % [path, i])
		var frame := int(raw_frame)
		if float(frame) != float(raw_frame) or frame < 1:
			return _fail("timeline %s event %d frame must be an integer >= 1, got %s" % [
				path, i, str(raw_frame),
			])

		var action: String = str(event.get("action", ""))
		if not VALID_ACTIONS.has(action):
			return _fail("timeline %s event %d has action %s, expected one of %s" % [
				path, i, str(event.get("action", "<missing>")), str(VALID_ACTIONS),
			])

		var key_name: String = str(event.get("key", ""))
		var keycode := OS.find_keycode_from_string(key_name)
		if keycode == KEY_NONE:
			return _fail("timeline %s event %d has unknown key %s" % [path, i, key_name])

		if not _schedule.has(frame):
			_schedule[frame] = []
		_schedule[frame].append({"action": action, "keycode": keycode, "key": key_name})

	return true


func _fail(reason: String) -> bool:
	# Backstop only — capture-movie.sh validates the timeline before launching, so
	# reaching here means the two validators disagree, which is worth shouting about.
	push_error("CaptureInput: %s" % reason)
	printerr("CaptureInput: FATAL %s" % reason)
	get_tree().quit(TIMELINE_ERROR_EXIT_CODE)
	return false


static func _parse_string_arg(args: PackedStringArray, flag: String) -> String:
	for i in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with(flag + "="):
			return args[i].trim_prefix(flag + "=")
	return ""


static func _parse_int_arg(args: PackedStringArray, flag: String, fallback: int) -> int:
	var raw := _parse_string_arg(args, flag)
	if raw.is_valid_int():
		return raw.to_int()
	return fallback
