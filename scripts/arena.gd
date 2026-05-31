extends Node2D

## Wires the player and spawner to the HUD and handles the death -> restart
## loop. Owns the run-scoped score/kill tally: kills originate at the enemy
## (which owns its death) and arrive here via the spawner, and this node is the
## single place those events turn into score. A scene reload (restart) resets
## the tally for free.

const SND_ROUND_START := preload("res://assets/audio/round_start.wav")

@onready var player: Player = $Player
@onready var spawner: Node2D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

var score: int = 0
var kills: int = 0

func _ready() -> void:
	player.health_changed.connect(hud.set_health)
	player.weapon_changed.connect(hud.set_weapon)
	player.died.connect(_on_player_died)
	spawner.wave_changed.connect(hud.set_wave)
	spawner.enemy_killed.connect(_on_enemy_killed)
	hud.set_score(score, kills)
	_sfx.play(SND_ROUND_START)

func _on_enemy_killed(score_value: int) -> void:
	kills += 1
	score += score_value
	hud.set_score(score, kills)

func _on_player_died() -> void:
	hud.show_game_over(score, kills)
	get_tree().create_timer(2.0).timeout.connect(_restart)

func _restart() -> void:
	get_tree().reload_current_scene()
