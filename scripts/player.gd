class_name Player
extends CharacterBody2D

## Top-down twin-stick player: WASD/arrows to move, mouse to aim, click to fire.
## Owns its own health and the transition into death (single terminal owner).
## Firing is data-driven: all weapon behaviour comes from the equipped
## WeaponData (see scripts/weapon_data.gd) — nothing about a specific gun is
## hardcoded here. Number keys 1-4 swap weapons (a debug convenience now that
## pickups are the real swap mechanic).

signal died
signal health_changed(current: int, maximum: int)
signal weapon_changed(weapon: WeaponData)
## Emitted when the player takes damage (distinct from health_changed, which can
## fire for non-damage changes). Drives feedback like camera shake.
signal hit
## XP progression. The player owns its XP/level (it owns the stats perks modify,
## so it owns the transition into a level-up). xp_changed drives the HUD bar;
## leveled_up tells the game loop to offer a perk choice.
signal xp_changed(xp: int, xp_to_next: int, level: int)
signal leveled_up(level: int)

@export var speed: float = 320.0
@export var max_health: int = 100
@export var bullet_scene: PackedScene
@export var footstep_interval: float = 0.3
## XP needed to reach level 2, multiplied by xp_curve for each level beyond.
@export var base_xp_to_level: int = 156
@export var xp_curve: float = 1.5
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
## Juice: red hit-flash on damage; brief muzzle flash on each shot.
const HIT_FLASH_SHADER := preload("res://assets/shaders/hit_flash.gdshader")
const MUZZLE_FLASH_TIME := 0.05

var health: int
var weapon: WeaponData
var _fire_timer: float = 0.0
var _step_timer: float = 0.0
var _muzzle_timer: float = 0.0

## XP / leveling state.
var xp: int = 0
var level: int = 1
var xp_to_next: int = 0

## Accumulated perk modifiers. Each perk folds into these in apply_perk(); the
## shoot/move code reads them, so the player never branches on which perk it is.
var perks: Array[PerkData] = []
var _damage_mult: float = 1.0
var _fire_rate_mult: float = 1.0
var _speed_mult: float = 1.0
var _bonus_projectiles: int = 0
var _bonus_pierce: int = 0
var _regen_per_sec: float = 0.0
var _xp_mult: float = 1.0
var _regen_accum: float = 0.0  # fractional HP carried between regen ticks

@onready var muzzle: Marker2D = $Muzzle
@onready var _muzzleflash: Polygon2D = $MuzzleFlash
@onready var _sprite: Sprite2D = $Sprite
# Autoloads added via MCP aren't registered as GDScript globals in the running
# editor (only on project reload), so reach the singleton by its runtime path.
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	xp_to_next = _xp_for_level(level)
	xp_changed.emit(xp, xp_to_next, level)
	# Own flash material (red) so the hit tint animates independently.
	var mat := ShaderMaterial.new()
	mat.shader = HIT_FLASH_SHADER
	mat.set_shader_parameter("flash_color", Color(1.0, 0.2, 0.2))
	_sprite.material = mat
	_muzzleflash.visible = false
	if weapons.is_empty():
		weapons = DEFAULT_WEAPONS
	equip(0)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed * _speed_mult
	move_and_slide()
	look_at(get_global_mouse_position())
	_handle_footsteps(delta)
	_handle_weapon_switch()
	_handle_muzzle_flash(delta)
	_handle_regen(delta)

	_fire_timer -= delta
	if weapon != null and Input.is_action_pressed("fire") and _fire_timer <= 0.0:
		_shoot()
		# Perks shorten the cooldown via the fire-rate multiplier (>1 = faster).
		_fire_timer = weapon.fire_cooldown / _fire_rate_mult

func equip(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	equip_weapon(weapons[index])

## Equip a WeaponData directly. The single transition into "weapon equipped",
## shared by the number-key switcher (equip by index) and weapon pickups.
func equip_weapon(next: WeaponData) -> void:
	if next == null or next == weapon:
		return
	weapon = next
	if weapon.sprite != null:
		_sprite.texture = weapon.sprite
	# Move the bullet spawn + muzzle flash to this gun's barrel tip. Each sprite
	# holds its weapon at a different offset/length, so the muzzle is data-driven.
	muzzle.position = weapon.muzzle_offset
	_muzzleflash.position = weapon.muzzle_offset
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

func _handle_muzzle_flash(delta: float) -> void:
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
		if _muzzle_timer <= 0.0:
			_muzzleflash.visible = false

func _handle_regen(delta: float) -> void:
	if _regen_per_sec <= 0.0 or health <= 0 or health >= max_health:
		return
	_regen_accum += _regen_per_sec * delta
	if _regen_accum >= 1.0:
		var whole := int(_regen_accum)
		_regen_accum -= whole
		health = mini(max_health, health + whole)
		health_changed.emit(health, max_health)

## Grant XP (kills feed this via the arena). Crosses any number of level
## thresholds in one go, announcing each — the player owns the level-up
## transition; the game loop only observes leveled_up to offer a perk.
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += int(round(amount * _xp_mult))
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = _xp_for_level(level)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

func _xp_for_level(lvl: int) -> int:
	return int(round(base_xp_to_level * pow(xp_curve, lvl - 1)))

func has_perk(perk: PerkData) -> bool:
	return perks.has(perk)

## Fold a perk's modifiers into the running stat accumulators. The single entry
## point for "a perk took effect" — shoot/move/regen read the accumulators, so
## no gameplay code branches on a specific perk.
func apply_perk(perk: PerkData) -> void:
	if perk == null:
		return
	perks.append(perk)
	_damage_mult *= perk.damage_mult
	_fire_rate_mult *= perk.fire_rate_mult
	_speed_mult *= perk.move_speed_mult
	_bonus_projectiles += perk.bonus_projectiles
	_bonus_pierce += perk.bonus_pierce
	_regen_per_sec += perk.regen_per_sec
	_xp_mult *= perk.xp_mult
	if perk.max_health_add != 0:
		max_health += perk.max_health_add
		health = mini(max_health, health + maxi(0, perk.max_health_add))
	if perk.heal_on_pickup > 0:
		health = mini(max_health, health + perk.heal_on_pickup)
	health_changed.emit(health, max_health)

func _shoot() -> void:
	if bullet_scene == null:
		push_warning("Player.bullet_scene not assigned")
		return
	var count := maxi(1, weapon.projectile_count + _bonus_projectiles)
	var spread_deg := weapon.spread_degrees
	# Perk-granted extra pellets need somewhere to go: if the gun fires a tight
	# stream, fan the widened volley out so the bonus shots aren't stacked dead on.
	if count > weapon.projectile_count and spread_deg <= 0.0:
		spread_deg = 6.0 * (count - 1)
	var spread := deg_to_rad(spread_deg)
	var shot_damage := int(round(weapon.damage * _damage_mult))
	for i in count:
		# Spread pellets evenly across the cone; a single pellet fires dead centre.
		var offset := 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5) * spread
		var angle := rotation + offset
		var bullet := bullet_scene.instantiate()
		bullet.speed = weapon.bullet_speed
		bullet.damage = shot_damage
		bullet.lifetime = weapon.bullet_lifetime
		bullet.pierce = weapon.pierce + _bonus_pierce
		bullet.rotation = angle
		bullet.set_direction(Vector2.RIGHT.rotated(angle))
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle.global_position
	var snd: AudioStream = weapon.fire_sound if weapon.fire_sound != null else SND_PISTOL
	_sfx.play(snd, -4.0, randf_range(0.95, 1.05))
	_flash_muzzle()

func _flash_muzzle() -> void:
	_muzzleflash.scale = Vector2.ONE * randf_range(0.8, 1.25)
	_muzzleflash.visible = true
	_muzzle_timer = MUZZLE_FLASH_TIME

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	_sfx.play(SND_DAMAGE)
	_flash()
	hit.emit()
	health_changed.emit(health, max_health)
	if health == 0:
		_die()

## Red flash on the player sprite when hit.
func _flash() -> void:
	_sprite.material.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: _sprite.material.set_shader_parameter("flash", v),
		1.0, 0.0, 0.18)

func _die() -> void:
	set_physics_process(false)
	hide()
	_sfx.play(SND_DEATH)
	died.emit()
