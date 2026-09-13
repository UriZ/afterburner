extends Control

## GAME OVER overlay shown by player_jet_2d.gd when the player runs out of
## lives. Uses the HUD's block font so it matches the rest of the arcade UI,
## and is centered clear of the SCORE readout (top-left) and STAGE banner
## (bottom-center). Restarts to the title screen on Enter/Space, or
## automatically after AUTO_RESTART_DELAY seconds. #38, #110

const BlockFont := preload("res://scripts/ui/block_font.gd")
const ConfirmInput := preload("res://scripts/ui/confirm_input.gd")

const SCREEN_W := 960.0
const SCREEN_H := 672.0
const TITLE_PX := 8.0
const PROMPT_PX := 4.0
const PROMPT_DELAY := 1.0    # let GAME OVER register before showing the prompt
const BLINK_INTERVAL := 0.5
const AUTO_RESTART_DELAY := 5.0
const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"

const COLOR_TITLE := Color(1.0, 0.15, 0.1)
const COLOR_PROMPT := Color(1.0, 1.0, 1.0)

var _elapsed: float = 0.0
var _blink_timer: float = 0.0
var _blink_visible: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= AUTO_RESTART_DELAY:
		_restart()
		return
	if _elapsed >= PROMPT_DELAY:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = BLINK_INTERVAL
			_blink_visible = not _blink_visible
			queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and ConfirmInput.is_pressed(event):
		_restart()


func _restart() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	get_tree().change_scene_to_file(TITLE_SCENE)
	# This overlay was added directly under the tree root (see
	# player_jet_2d.gd:_show_game_over_screen) so change_scene_to_file()
	# does not remove it — it isn't part of the scene subtree being swapped.
	# Free the wrapping CanvasLayer explicitly or it lingers on top of the
	# title screen and keeps firing this restart every AUTO_RESTART_DELAY.
	var canvas := get_parent()
	if canvas:
		canvas.queue_free()


func _draw() -> void:
	var title := "GAME OVER"
	var title_w := BlockFont.text_width(title.length(), TITLE_PX)
	BlockFont.draw_text(self, title, Vector2((SCREEN_W - title_w) / 2.0, SCREEN_H / 2.0 - 50.0), TITLE_PX, COLOR_TITLE)

	if _elapsed >= PROMPT_DELAY and _blink_visible:
		var prompt := "PRESS ENTER"
		var prompt_w := BlockFont.text_width(prompt.length(), PROMPT_PX)
		BlockFont.draw_text(self, prompt, Vector2((SCREEN_W - prompt_w) / 2.0, SCREEN_H / 2.0 + 30.0), PROMPT_PX, COLOR_PROMPT)
