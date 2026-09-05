extends Node

## GameState autoload singleton.
## Tracks persistent game state: score, lives, missiles, stage, phase.

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal missile_count_changed(new_count: int)
signal stage_changed(new_stage: int)

enum Phase { TITLE, PLAYING, GAME_OVER, BONUS_STAGE }

const DEFAULT_LIVES := 3
const DEFAULT_MISSILES := 50
const DEFAULT_STAGE := 1

var score: int = 0:
	set(value):
		score = value
		score_changed.emit(score)

var lives: int = DEFAULT_LIVES:
	set(value):
		lives = value
		lives_changed.emit(lives)

var missile_count: int = DEFAULT_MISSILES:
	set(value):
		missile_count = maxi(value, 0)
		missile_count_changed.emit(missile_count)

var current_stage: int = DEFAULT_STAGE:
	set(value):
		current_stage = value
		stage_changed.emit(current_stage)

var phase: Phase = Phase.TITLE


func reset() -> void:
	score = 0
	lives = DEFAULT_LIVES
	missile_count = DEFAULT_MISSILES
	current_stage = DEFAULT_STAGE
	phase = Phase.TITLE


func add_score(points: int) -> void:
	score += points


func use_missile() -> bool:
	if missile_count <= 0:
		return false
	missile_count -= 1
	return true


func add_missiles(count: int) -> void:
	missile_count += count


func lose_life() -> bool:
	lives -= 1
	return lives >= 0
