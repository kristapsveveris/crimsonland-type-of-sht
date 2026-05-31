class_name Bullet
extends Area2D

## Player projectile. Travels in a fixed direction, despawns after `lifetime`,
## and damages the first enemy it overlaps.

@export var speed: float = 900.0
@export var damage: int = 25
@export var lifetime: float = 1.5
@export var pierce: int = 1  ## enemies this bullet can hit before despawning

var _dir: Vector2 = Vector2.RIGHT
var _hits_left: int = 1

func set_direction(d: Vector2) -> void:
	_dir = d.normalized()

func _ready() -> void:
	_hits_left = maxi(1, pierce)
	body_entered.connect(_on_hit)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += _dir * speed * delta

func _on_hit(body: Node) -> void:
	# Area2D fires body_entered once per enemy, so each is damaged at most once;
	# the bullet survives until it has pierced `pierce` distinct enemies.
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_hits_left -= 1
		if _hits_left <= 0:
			queue_free()
