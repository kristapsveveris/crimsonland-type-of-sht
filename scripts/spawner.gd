extends Node2D

## Spawns enemies at random points just outside the arena edges on an interval.

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.2
@export var arena_size: Vector2 = Vector2(1280, 720)
@export var margin: float = 60.0

var _timer: float = 0.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_spawn()
		_timer = spawn_interval

func _spawn() -> void:
	if enemy_scene == null:
		push_warning("Spawner.enemy_scene not assigned")
		return
	var enemy := enemy_scene.instantiate()
	enemy.global_position = _edge_point()
	add_child(enemy)

func _edge_point() -> Vector2:
	match randi() % 4:
		0:
			return Vector2(randf() * arena_size.x, -margin)
		1:
			return Vector2(randf() * arena_size.x, arena_size.y + margin)
		2:
			return Vector2(-margin, randf() * arena_size.y)
		_:
			return Vector2(arena_size.x + margin, randf() * arena_size.y)
