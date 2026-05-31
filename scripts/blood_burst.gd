extends CPUParticles2D

## One-shot blood spray spawned where an enemy dies, then self-frees. It lives
## in the arena rather than under the dying enemy (which despawns the same
## frame), so it owns its own lifetime: emit once, free when the burst finishes.

func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
