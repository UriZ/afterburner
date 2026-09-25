extends SceneTree
## Negative control for selftest test 4 (#114 judge correction 1).
##
## Proves that an InputEventKey carrying ONLY `keycode` is inert for gameplay,
## which is why capture_input.gd sets physical_keycode too and why test 4 probes
## through Input.is_action_pressed() rather than Input.is_key_pressed(). A test
## written the obvious way goes green on an implementation that cannot drive the
## game at all.

var _frame := 0
var _keycode_only_action := false
var _keycode_only_rawkey := false
var _both_action := false


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		1:
			var ev := InputEventKey.new()
			ev.keycode = KEY_Z      # deliberately NOT setting physical_keycode
			ev.pressed = true
			Input.parse_input_event(ev)
		2:
			_keycode_only_action = Input.is_action_pressed("fire_vulcan")
			_keycode_only_rawkey = Input.is_key_pressed(KEY_Z)
			var off := InputEventKey.new()
			off.keycode = KEY_Z
			off.physical_keycode = KEY_Z
			off.pressed = false
			Input.parse_input_event(off)
		3:
			var ev2 := InputEventKey.new()
			ev2.keycode = KEY_Z
			ev2.physical_keycode = KEY_Z   # the way capture_input.gd does it
			ev2.pressed = true
			Input.parse_input_event(ev2)
		4:
			_both_action = Input.is_action_pressed("fire_vulcan")
			print("CONTROL keycode_only_action=%d keycode_only_rawkey=%d both_action=%d" % [
				int(_keycode_only_action), int(_keycode_only_rawkey), int(_both_action),
			])
			quit(0)
	return false
