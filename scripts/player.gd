class_name Player
extends CharacterBody2D

## Top-down twin-stick player: WASD/arrows to move, mouse to aim, click to fire.
## Owns its own health and the transition into death (single terminal owner).
## Firing is data-driven: all weapon behaviour comes from the equipped
## WeaponData (see scripts/weapon_data.gd) — nothing about a specific gun is
## hardcoded here. Number keys 1-4 swap weapons (a stand-in until pickups land).

signal died
signal health_changed(current: int, maximum: int)
signal weapon_changed(weapon: WeaponData)

@export var speed: float = 320.0
@export var max_health: int = 100
@export var bullet_scene: PackedScene
@export var footstep_interval: float = 0.3
## Equippable arsenal. Left empty in the editor -> falls back to the four
## bundled weapons below so the scene works out of the box.
@export var weapons: Array[WeaponData] = []

const DEFAULT_WEAPONS: Array[WeaponData] = [
	preload("res://resources/weapons/pistol.tres"),
	preload("res://resources/weapons/shotgun.tres"),
	preload("res://resources/weapons/smg.tres"),
	preload("res://resources/weapons/rifle.tres"),
]

const SND_PISTOL := preload("res://assets/audio/pistol.wav")
const SND_DAMAGE := preload("res://assets/audio/damage.wav")
const SND_DEATH := preload("res://assets/audio/death.wav")
const SND_FOOTSTEP := preload("res://assets/audio/grass_footstep.wav")

var health: int
var weapon: WeaponData
var _fire_timer: float = 0.0
var _step_timer: float = 0.0

@onready var muzzle: Marker2D = $Muzzle
@onready var _sprite: Sprite2D = $Sprite
# Autoloads added via MCP aren't registered as GDScript globals in the running
# editor (only on project reload), so reach the singleton by its runtime path.
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	if weapons.is_empty():
		weapons = DEFAULT_WEAPONS
	equip(0)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
	look_at(get_global_mouse_position())
	_handle_footsteps(delta)
	_handle_weapon_switch()

	_fire_timer -= delta
	if weapon != null and Input.is_action_pressed("fire") and _fire_timer <= 0.0:
		_shoot()
		_fire_timer = weapon.fire_cooldown

func equip(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	var next := weapons[index]
	if next == null or next == weapon:
		return
	weapon = next
	if weapon.sprite != null:
		_sprite.texture = weapon.sprite
	_fire_timer = 0.0
	weapon_changed.emit(weapon)

func _handle_weapon_switch() -> void:
	for i in mini(weapons.size(), 4):
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			equip(i)

func _handle_footsteps(delta: float) -> void:
	if velocity.length() > 5.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_sfx.play(SND_FOOTSTEP, -8.0, randf_range(0.9, 1.1))
			_step_timer = footstep_interval
	else:
		_step_timer = 0.0  # standing still -> next step plays immediately on move

func _shoot() -> void:
	if bullet_scene == null:
		push_warning("Player.bullet_scene not assigned")
		return
	var count := maxi(1, weapon.projectile_count)
	var spread := deg_to_rad(weapon.spread_degrees)
	for i in count:
		# Spread pellets evenly across the cone; a single pellet fires dead centre.
		var offset := 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5) * spread
		var angle := rotation + offset
		var bullet := bullet_scene.instantiate()
		bullet.speed = weapon.bullet_speed
		bullet.damage = weapon.damage
		bullet.lifetime = weapon.bullet_lifetime
		bullet.pierce = weapon.pierce
		bullet.rotation = angle
		bullet.set_direction(Vector2.RIGHT.rotated(angle))
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle.global_position
	var snd: AudioStream = weapon.fire_sound if weapon.fire_sound != null else SND_PISTOL
	_sfx.play(snd, -4.0, randf_range(0.95, 1.05))

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	_sfx.play(SND_DAMAGE)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()

func _die() -> void:
	set_physics_process(false)
	hide()
	_sfx.play(SND_DEATH)
	died.emit()
