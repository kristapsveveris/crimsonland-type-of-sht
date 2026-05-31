extends CanvasLayer

## Minimal heads-up display: health, current weapon, wave, score/kills, and a
## game-over banner that reports the final tally.

@onready var health_label: Label = $HealthLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var wave_label: Label = $WaveLabel
@onready var score_label: Label = $ScoreLabel
@onready var game_over_label: Label = $GameOverLabel

func _ready() -> void:
	game_over_label.hide()

func set_health(current: int, maximum: int) -> void:
	health_label.text = "HP: %d / %d" % [current, maximum]

func set_weapon(weapon: WeaponData) -> void:
	weapon_label.text = "Weapon: %s" % weapon.display_name

func set_wave(wave: int) -> void:
	wave_label.text = "Wave: %d" % wave

func set_score(score: int, kills: int) -> void:
	score_label.text = "Score: %d   Kills: %d" % [score, kills]

func show_game_over(score: int, kills: int) -> void:
	game_over_label.text = "GAME OVER\nScore: %d   Kills: %d" % [score, kills]
	game_over_label.show()
