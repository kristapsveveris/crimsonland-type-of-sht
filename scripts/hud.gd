extends CanvasLayer

## Minimal heads-up display: health readout, current weapon, game-over banner.

@onready var health_label: Label = $HealthLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var game_over_label: Label = $GameOverLabel

func _ready() -> void:
	game_over_label.hide()

func set_health(current: int, maximum: int) -> void:
	health_label.text = "HP: %d / %d" % [current, maximum]

func set_weapon(weapon: WeaponData) -> void:
	weapon_label.text = "Weapon: %s" % weapon.display_name

func show_game_over() -> void:
	game_over_label.show()
