class_name Bullet
extends Area2D

## Player projectile. Travels in a fixed direction, despawns after `lifetime`,
## and damages the first enemy it overlaps.

@export var speed: float = 900.0
@export var damage: int = 25
@export var lifetime: float = 1.5

var _dir: Vector2 = Vector2.RIGHT

func set_direction(d: Vector2) -> void:
	_dir = d.normalized()

func _ready() -> void:
	body_entered.connect(_on_hit)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += _dir * speed * delta

func _on_hit(body: Node) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
