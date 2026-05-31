extends Node2D

## Spawns enemies at random points just outside the arena edges, and owns the
## continuous difficulty escalation: as the run goes on the spawn cadence
## tightens and each enemy gets tougher. The "wave" is a derived readout of
## elapsed survival time, not a discrete clear-the-room round — there are no
## pauses, the pressure just keeps climbing (Crimsonland-survival style).
##
## True enemy *variety* (distinct types) is deferred until EnemyData resources
## exist; for now escalation scales the single enemy's stats per wave.

## Emitted when the derived wave number ticks up (and once on _ready for wave 1).
signal wave_changed(wave: int)
## Forwarded from each spawned enemy when it is killed, so the game loop can
## score it without the spawner itself caring what a kill is worth.
signal enemy_killed(score_value: int, position: Vector2)

@export var enemy_scene: PackedScene
@export var arena_size: Vector2 = Vector2(1280, 720)
@export var margin: float = 60.0

@export_group("Escalation")
## Seconds of survival per wave step.
@export var wave_duration: float = 20.0
## Spawn interval at wave 1, and the floor it decays toward.
@export var base_spawn_interval: float = 1.2
@export var min_spawn_interval: float = 0.28
## Multiplier applied to the interval per wave (0.85 => 15% faster each wave).
@export var interval_decay: float = 0.85
## Per-wave fractional bump to enemy health/speed/worth (0.18 => +18% per wave
## over wave 1). Speed is bumped at a third of this rate so enemies don't
## outrun the player.
@export var stat_growth_per_wave: float = 0.18
## Concurrent enemies per spawn tick grows by 1 every this-many waves, capped.
@export var waves_per_extra_spawn: int = 4
@export var max_per_spawn: int = 4

var _elapsed: float = 0.0
var _wave: int = 0
var _timer: float = 0.0

func _ready() -> void:
	_set_wave(1)

func _process(delta: float) -> void:
	_elapsed += delta
	var wave_now := int(_elapsed / wave_duration) + 1
	if wave_now != _wave:
		_set_wave(wave_now)

	_timer -= delta
	if _timer <= 0.0:
		for _i in _spawns_this_tick():
			_spawn()
		_timer = _current_interval()

func _set_wave(wave: int) -> void:
	_wave = wave
	wave_changed.emit(_wave)

func _current_interval() -> float:
	return maxf(min_spawn_interval, base_spawn_interval * pow(interval_decay, _wave - 1))

func _spawns_this_tick() -> int:
	return clampi(1 + (_wave - 1) / waves_per_extra_spawn, 1, max_per_spawn)

func _spawn() -> void:
	if enemy_scene == null:
		push_warning("Spawner.enemy_scene not assigned")
		return
	var enemy: Enemy = enemy_scene.instantiate()
	# Scale the scene defaults rather than hardcoding base stats here, so the
	# numbers stay single-sourced in enemy.tscn. _ready() reads max_health when
	# the enemy enters the tree, so set it before add_child.
	var mult := 1.0 + stat_growth_per_wave * (_wave - 1)
	enemy.max_health = int(round(enemy.max_health * mult))
	enemy.speed *= 1.0 + stat_growth_per_wave / 3.0 * (_wave - 1)
	enemy.score_value = int(round(enemy.score_value * mult))
	enemy.killed.connect(_on_enemy_killed)
	enemy.global_position = _edge_point()
	add_child(enemy)

func _on_enemy_killed(score_value: int, position: Vector2) -> void:
	enemy_killed.emit(score_value, position)

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
