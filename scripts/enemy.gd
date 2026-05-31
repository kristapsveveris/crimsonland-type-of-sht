class_name Enemy
extends CharacterBody2D

## Walks straight toward the player and deals contact damage on a cooldown.
## Owns its own health and despawn (single terminal owner). When killed by
## damage it announces the kill (and its point value) via `killed` so the
## game loop can score it — the enemy still owns the death; listeners only
## observe it.

## Emitted once, when this enemy is killed by damage (not on any other
## despawn). Carries the points the kill is worth.
signal killed(score_value: int)

@export var speed: float = 96.0  # 20% slower than the original 120
@export var max_health: int = 50
@export var contact_damage: int = 10
@export var contact_interval: float = 0.5
@export var score_value: int = 100

## Played on death. "headshot" is the only kill sound in the pack for now;
## swap for a dedicated crit sound once a headshot/crit system exists.
const SND_KILL := preload("res://assets/audio/headshot.wav")

var health: int
var _target: Node2D
var _touch_timer: float = 0.0

@onready var touch: Area2D = $Touch
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
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
		_sfx.play(SND_KILL, -3.0, randf_range(0.95, 1.08))
		killed.emit(score_value)
		queue_free()
