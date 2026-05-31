extends Node2D

## Wires the player and spawner to the HUD and handles the death -> restart
## loop. Owns the run-scoped score/kill tally: kills originate at the enemy
## (which owns its death) and arrive here via the spawner, and this node is the
## single place those events turn into score. A scene reload (restart) resets
## the tally for free.

const SND_ROUND_START := preload("res://assets/audio/round_start.wav")
const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

## Loot policy lives here (the run-scoped game-loop owner): each kill rolls a
## chance to drop one of these weapons where the enemy died. Left empty in the
## editor -> falls back to the non-pistol weapons below, so it works out of the
## box. The pistol is the starter and intentionally not in the drop pool.
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.16
@export var weapon_drops: Array[WeaponData] = []

const DEFAULT_DROPS: Array[WeaponData] = [
	preload("res://resources/weapons/shotgun.tres"),
	preload("res://resources/weapons/smg.tres"),
	preload("res://resources/weapons/rifle.tres"),
]

@onready var player: Player = $Player
@onready var spawner: Node2D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var camera: CameraShake = $Camera2D
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

var score: int = 0
var kills: int = 0

func _ready() -> void:
	player.health_changed.connect(hud.set_health)
	player.weapon_changed.connect(hud.set_weapon)
	player.died.connect(_on_player_died)
	spawner.wave_changed.connect(hud.set_wave)
	spawner.enemy_killed.connect(_on_enemy_killed)
	player.hit.connect(_on_player_hit)
	hud.set_score(score, kills)
	_sfx.play(SND_ROUND_START)

func _on_enemy_killed(score_value: int, position: Vector2) -> void:
	kills += 1
	score += score_value
	hud.set_score(score, kills)
	_maybe_drop(position)

func _maybe_drop(position: Vector2) -> void:
	var pool := weapon_drops if not weapon_drops.is_empty() else DEFAULT_DROPS
	if pool.is_empty() or randf() > drop_chance:
		return
	var pickup := PICKUP_SCENE.instantiate()
	pickup.weapon = pool[randi() % pool.size()]
	pickup.global_position = position
	add_child(pickup)

func _on_player_hit() -> void:
	camera.add_trauma(0.45)

func _on_player_died() -> void:
	camera.add_trauma(1.0)
	hud.show_game_over(score, kills)
	get_tree().create_timer(2.0).timeout.connect(_restart)

func _restart() -> void:
	get_tree().reload_current_scene()
