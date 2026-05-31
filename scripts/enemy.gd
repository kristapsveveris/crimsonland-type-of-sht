class_name Enemy
extends CharacterBody2D

## Walks straight toward the player and deals contact damage on a cooldown.
## Owns its own health and despawn (single terminal owner). When killed by
## damage it announces the kill (and its point value) via `killed` so the
## game loop can score it — the enemy still owns the death; listeners only
## observe it.

## Emitted once, when this enemy is killed by damage (not on any other
## despawn). Carries the points the kill is worth and where it died, so the
## game loop can both score it and decide whether to drop loot there.
signal killed(score_value: int, position: Vector2)

@export var speed: float = 96.0  # 20% slower than the original 120
@export var max_health: int = 50
@export var contact_damage: int = 10
@export var contact_interval: float = 0.5
@export var score_value: int = 100

## Played on death. "headshot" is the only kill sound in the pack for now;
## swap for a dedicated crit sound once a headshot/crit system exists.
const SND_KILL := preload("res://assets/audio/headshot.wav")

## Juice: a white hit-flash on every damaging hit, and a blood spray on death.
const HIT_FLASH_SHADER := preload("res://assets/shaders/hit_flash.gdshader")
const BLOOD_BURST := preload("res://scenes/blood_burst.tscn")

var health: int
var _target: Node2D
var _touch_timer: float = 0.0
var _flash_tween: Tween

@onready var touch: Area2D = $Touch
@onready var _sprite: Sprite2D = $Sprite
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	# Each enemy owns its own flash material so its uniform animates independently.
	var mat := ShaderMaterial.new()
	mat.shader = HIT_FLASH_SHADER
	_sprite.material = mat
	_acquire_target()

func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_target = players[0]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		_acquire_target()
		return
	var dir := (_target.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	look_at(_target.global_position)

	_touch_timer -= delta
	if _touch_timer <= 0.0:
		for body in touch.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(contact_damage)
				_touch_timer = contact_interval
				break

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_spawn_blood()
		_sfx.play(SND_KILL, -3.0, randf_range(0.95, 1.08))
		killed.emit(score_value, global_position)
		queue_free()
	else:
		_flash()

## Punch the sprite white, then ease it back over a short window.
func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.material.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(
		func(v: float) -> void: _sprite.material.set_shader_parameter("flash", v),
		1.0, 0.0, 0.14)

func _spawn_blood() -> void:
	var blood: CPUParticles2D = BLOOD_BURST.instantiate()
	blood.global_position = global_position
	# Parent to the arena, not self — this node frees the same frame.
	get_tree().current_scene.add_child(blood)
