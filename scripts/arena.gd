extends Node2D

## Wires the player to the HUD and handles the death -> restart loop.

const SND_ROUND_START := preload("res://assets/audio/round_start.wav")

@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

func _ready() -> void:
	player.health_changed.connect(hud.set_health)
	player.weapon_changed.connect(hud.set_weapon)
	player.died.connect(_on_player_died)
	_sfx.play(SND_ROUND_START)

func _on_player_died() -> void:
	hud.show_game_over()
	get_tree().create_timer(2.0).timeout.connect(_restart)

func _restart() -> void:
	get_tree().reload_current_scene()
