class_name Player
extends CharacterBody2D

## Top-down twin-stick player: WASD/arrows to move, mouse to aim, click to fire.
## Owns its own health and the transition into death (single terminal owner).

signal died
signal health_changed(current: int, maximum: int)

@export var speed: float = 320.0
@export var max_health: int = 100
@export var fire_cooldown: float = 0.15
@export var bullet_scene: PackedScene
@export var footstep_interval: float = 0.3

const SND_PISTOL := preload("res://assets/audio/pistol.wav")
const SND_DAMAGE := preload("res://assets/audio/damage.wav")
const SND_DEATH := preload("res://assets/audio/death.wav")
const SND_FOOTSTEP := preload("res://assets/audio/grass_footstep.wav")

var health: int
var _fire_timer: float = 0.0
var _step_timer: float = 0.0

@onready var muzzle: Marker2D = $Muzzle
# Autoloads added via MCP aren't registered as GDScript globals in the running
# editor (only on project reload), so reach the singleton by its runtime path.
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
	look_at(get_global_mouse_position())
	_handle_footsteps(delta)

	_fire_timer -= delta
	if Input.is_action_pressed("fire") and _fire_timer <= 0.0:
		_shoot()
		_fire_timer = fire_cooldown

func _handle_footsteps(delta: float) -> void:
	if velocity.length() > 5.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_sfx.play(SND_FOOTSTEP, -8.0, randf_range(0.9, 1.1))
			_step_timer = footstep_interval
	else:
		_step_timer = 0.0  # standing still -> next step plays immediately on move

func _shoot() -> void:
	if bullet_scene == null:
		push_warning("Player.bullet_scene not assigned")
		return
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.rotation = rotation
	if bullet.has_method("set_direction"):
		bullet.set_direction(Vector2.RIGHT.rotated(rotation))
	_sfx.play(SND_PISTOL, -4.0, randf_range(0.95, 1.05))

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	_sfx.play(SND_DAMAGE)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()

func _die() -> void:
	set_physics_process(false)
	hide()
	_sfx.play(SND_DEATH)
	died.emit()
