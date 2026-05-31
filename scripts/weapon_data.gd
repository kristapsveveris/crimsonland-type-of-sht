class_name WeaponData
extends Resource

## Data-driven weapon definition. The player reads these stats from whichever
## WeaponData is equipped; pickups (system #6) will swap the equipped resource
## at runtime. No weapon behaviour is hardcoded in player.gd — it all lives here.

@export var display_name: String = "Weapon"
@export var sprite: Texture2D                ## survivor_* sprite shown while equipped
@export_range(0.02, 2.0, 0.01) var fire_cooldown: float = 0.25  ## seconds between shots
@export_range(1, 24) var projectile_count: int = 1             ## pellets per trigger pull
@export_range(0.0, 180.0, 0.5) var spread_degrees: float = 0.0 ## total cone width across pellets
@export var damage: int = 25                 ## per-projectile damage
@export var bullet_speed: float = 900.0
@export_range(0.1, 5.0, 0.05) var bullet_lifetime: float = 1.5 ## seconds alive -> effective range
@export_range(1, 20) var pierce: int = 1     ## enemies one projectile can hit before despawning (1 = stops at first)
@export var fire_sound: AudioStream          ## optional; player falls back to the pistol sfx
