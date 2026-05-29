extends Node

## Fire-and-forget one-shot sound player (autoload singleton "Sfx").
##
## Each call spawns a throwaway AudioStreamPlayer that frees itself when the
## sound finishes. This decouples a sound's lifetime from the node that
## triggered it — e.g. an enemy can play its death sound and immediately
## queue_free() without cutting the audio off. Non-positional (the camera is
## arena-centered), which is fine for this game.

func play(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
