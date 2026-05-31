class_name CameraShake
extends Camera2D

## Trauma-based screen shake. Callers add_trauma() on impactful events; the
## camera owns the decay and the per-frame offset, so no external process has to
## tick it. Offset/rotation scale with trauma² so small hits stay subtle and big
## hits really kick. Trauma always decays back to zero -> the camera self-rests.

@export var decay: float = 1.6           ## trauma units shed per second
@export var max_offset: Vector2 = Vector2(20, 16)
@export var max_roll: float = 0.05       ## radians at full trauma (kept small for top-down)

var _trauma: float = 0.0

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(_delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO or rotation != 0.0:
			offset = Vector2.ZERO
			rotation = 0.0
		return
	_trauma = maxf(_trauma - decay * _delta, 0.0)
	var shake := _trauma * _trauma
	offset = Vector2(
		max_offset.x * randf_range(-1.0, 1.0) * shake,
		max_offset.y * randf_range(-1.0, 1.0) * shake)
	rotation = max_roll * randf_range(-1.0, 1.0) * shake
