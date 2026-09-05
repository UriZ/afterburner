extends CanvasLayer

## HUD overlay for After Burner.
## Displays score, stage, high score, missiles, speed, lives, and reticle.

@onready var score_label: Label = %ScoreLabel
@onready var stage_label: Label = %StageLabel
@onready var hi_score_label: Label = %HiScoreLabel
@onready var missile_label: Label = %MissileLabel
@onready var speed_bar: Label = %SpeedBar
@onready var lives_label: Label = %LivesLabel
@onready var reticle: Control = %Reticle

var high_score: int = 0
var speed_ratio: float = 0.5  ## 0.0 to 1.0, for future throttle integration

const SPEED_BAR_SEGMENTS := 10
const LIFE_SYMBOL := "♦"


func _ready() -> void:
	layer = 10
	_connect_signals()
	_update_score(GameState.score)
	_update_stage(GameState.current_stage)
	_update_missiles(GameState.missile_count)
	_update_lives(GameState.lives)
	_update_hi_score()
	_update_speed_bar()


func _connect_signals() -> void:
	GameState.score_changed.connect(_update_score)
	GameState.lives_changed.connect(_update_lives)
	GameState.missile_count_changed.connect(_update_missiles)
	GameState.stage_changed.connect(_update_stage)


func _update_score(new_score: int) -> void:
	score_label.text = "SCORE: %08d" % new_score
	if new_score > high_score:
		high_score = new_score
		_update_hi_score()


func _update_hi_score() -> void:
	hi_score_label.text = "HI: %08d" % high_score


func _update_stage(new_stage: int) -> void:
	stage_label.text = "STAGE %02d" % new_stage


func _update_missiles(new_count: int) -> void:
	missile_label.text = "MISSILES: %d" % new_count


func _update_lives(new_lives: int) -> void:
	var symbols := ""
	for i in range(new_lives):
		symbols += LIFE_SYMBOL
	lives_label.text = "LIVES: %s" % symbols


func _update_speed_bar() -> void:
	var filled := int(speed_ratio * SPEED_BAR_SEGMENTS)
	var empty := SPEED_BAR_SEGMENTS - filled
	speed_bar.text = "SPEED: %s%s" % ["█".repeat(filled), "░".repeat(empty)]


## Call this from gameplay code to update the speed indicator.
func set_speed(ratio: float) -> void:
	speed_ratio = clampf(ratio, 0.0, 1.0)
	_update_speed_bar()
