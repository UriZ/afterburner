extends Control

## Title screen for After Burner.
## Shows game title, blinking "PRESS START", and music selection menu.

enum State { ATTRACT, MUSIC_SELECT }

const BLINK_INTERVAL := 0.5
const TRACK_NAMES := ["Final Take Off", "Super Stripe", "After Burner"]

var _state: State = State.ATTRACT
var _blink_timer: float = 0.0
var _blink_visible: bool = true
var _selected_track: int = 0

@onready var _title_label: Label = %TitleLabel
@onready var _press_start_label: Label = %PressStartLabel
@onready var _music_container: VBoxContainer = %MusicContainer
var _track_labels: Array[Label] = []


func _ready() -> void:
	GameState.reset()
	_music_container.visible = false
	_build_track_labels()
	_update_track_highlight()


func _build_track_labels() -> void:
	for i in range(TRACK_NAMES.size()):
		var label := Label.new()
		label.text = TRACK_NAMES[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Courier New", "Courier", "monospace"])
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(1, 1, 1))

		_music_container.add_child(label)
		_track_labels.append(label)


func _process(delta: float) -> void:
	# Blink "PRESS START"
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = BLINK_INTERVAL
		_blink_visible = not _blink_visible
		_press_start_label.visible = _blink_visible


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return

	match _state:
		State.ATTRACT:
			if _is_start_pressed(event):
				_enter_music_select()
		State.MUSIC_SELECT:
			if event.is_action("move_up"):
				_selected_track = (_selected_track - 1 + TRACK_NAMES.size()) % TRACK_NAMES.size()
				_update_track_highlight()
			elif event.is_action("move_down"):
				_selected_track = (_selected_track + 1) % TRACK_NAMES.size()
				_update_track_highlight()
			elif _is_start_pressed(event):
				_start_game()


func _is_start_pressed(event: InputEvent) -> bool:
	if event.is_action("start"):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		# Check both keycode and physical_keycode since the input map may use either.
		# Accept Enter and Space as common arcade start keys.
		if key_event.keycode in [KEY_ENTER, KEY_SPACE]:
			return true
		if key_event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			return true
	return false


func _enter_music_select() -> void:
	_state = State.MUSIC_SELECT
	_press_start_label.visible = false
	_press_start_label.set_process(false)
	_music_container.visible = true

	# Change prompt
	_press_start_label.text = "SELECT MUSIC"
	_press_start_label.visible = true


func _update_track_highlight() -> void:
	for i in range(_track_labels.size()):
		if i == _selected_track:
			_track_labels[i].add_theme_color_override("font_color", Color(1, 1, 0))
			_track_labels[i].text = "> " + TRACK_NAMES[i] + " <"
		else:
			_track_labels[i].add_theme_color_override("font_color", Color(1, 1, 1))
			_track_labels[i].text = TRACK_NAMES[i]


func _start_game() -> void:
	GameState.reset()
	GameState.phase = GameState.Phase.PLAYING
	AudioManager.play_music(_selected_track)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
