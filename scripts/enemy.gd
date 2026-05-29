class_name Enemy
extends CharacterBody2D

## Walks straight toward the player and deals contact damage on a cooldown.
## Owns its own health and despawn (single terminal owner).

@export var speed: float = 120.0
@export var max_health: int = 50
@export var contact_damage: int = 10
@export var contact_interval: float = 0.5

var health: int
var _target: Node2D
var _touch_timer: float = 0.0

@onready var touch: Area2D = $Touch

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
		queue_free()
