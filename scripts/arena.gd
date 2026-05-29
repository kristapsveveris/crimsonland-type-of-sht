extends Node2D

## Wires the player to the HUD and handles the death -> restart loop.

@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)

func _on_player_died() -> void:
	hud.show_game_over()
	get_tree().create_timer(2.0).timeout.connect(_restart)

func _restart() -> void:
	get_tree().reload_current_scene()
