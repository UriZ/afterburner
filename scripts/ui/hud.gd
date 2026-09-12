extends CanvasLayer

## HUD overlay for After Burner.
## Owns score/stage/missiles/lives/speed state; drawing of the arcade-style
## bold block-font look is delegated to the child HudCanvas (hud_canvas.gd).

@onready var canvas: Control = %HudCanvas

var score: int = 0
var high_score: int = 0
var current_stage: int = 1
var missile_count: int = 0
var lives: int = 0
var speed_ratio: float = 0.5  ## 0.0 to 1.0, for future throttle integration


func _ready() -> void:
	layer = 10
	_connect_signals()
	score = GameState.score
	current_stage = GameState.current_stage
	missile_count = GameState.missile_count
	lives = GameState.lives
	canvas.queue_redraw()


func _connect_signals() -> void:
	GameState.score_changed.connect(_update_score)
	GameState.lives_changed.connect(_update_lives)
	GameState.missile_count_changed.connect(_update_missiles)
	GameState.stage_changed.connect(_update_stage)


func _update_score(new_score: int) -> void:
	score = new_score
	if new_score > high_score:
		high_score = new_score
	canvas.queue_redraw()


func _update_stage(new_stage: int) -> void:
	current_stage = new_stage
	canvas.queue_redraw()


func _update_missiles(new_count: int) -> void:
	missile_count = new_count
	canvas.queue_redraw()


func _update_lives(new_lives: int) -> void:
	lives = new_lives
	canvas.queue_redraw()


## Call this from gameplay code to update the speed indicator.
func set_speed(ratio: float) -> void:
	speed_ratio = clampf(ratio, 0.0, 1.0)
	canvas.queue_redraw()
