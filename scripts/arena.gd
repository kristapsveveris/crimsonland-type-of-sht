extends Node2D

## Wires the player and spawner to the HUD and handles the death -> restart
## loop. Owns the run-scoped score/kill tally: kills originate at the enemy
## (which owns its death) and arrive here via the spawner, and this node is the
## single place those events turn into score. A scene reload (restart) resets
## the tally for free.

const SND_ROUND_START := preload("res://assets/audio/round_start.wav")
const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

## Loot policy lives here (the run-scoped game-loop owner): each kill rolls a
## chance to drop one of these weapons where the enemy died. Left empty in the
## editor -> falls back to the non-pistol weapons below, so it works out of the
## box. The pistol is the starter and intentionally not in the drop pool.
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.16
@export var weapon_drops: Array[WeaponData] = []

## Flat XP granted per kill. Deliberately decoupled from score_value (which is
## wave-scaled and inflates): leveling pace should be governed by the player's
## XP curve, not by how much a kill happens to be worth this wave.
@export var xp_per_kill: int = 17

const DEFAULT_DROPS: Array[WeaponData] = [
	preload("res://resources/weapons/shotgun.tres"),
	preload("res://resources/weapons/smg.tres"),
	preload("res://resources/weapons/rifle.tres"),
]

## Perk policy. On each level-up the player is offered PERK_CHOICES random perks
## drawn from this pool (minus any non-stackable ones already taken). Left empty
## in the editor -> falls back to the bundled set below, so it works out of the box.
@export var perk_pool: Array[PerkData] = []
const PERK_CHOICES := 3

const DEFAULT_PERKS: Array[PerkData] = [
	preload("res://resources/perks/sharpshooter.tres"),
	preload("res://resources/perks/rapid_fire.tres"),
	preload("res://resources/perks/adrenaline.tres"),
	preload("res://resources/perks/tough_hide.tres"),
	preload("res://resources/perks/regeneration.tres"),
	preload("res://resources/perks/perforator.tres"),
	preload("res://resources/perks/extra_barrel.tres"),
	preload("res://resources/perks/fast_learner.tres"),
	preload("res://resources/perks/bandage.tres"),
]

@onready var player: Player = $Player
@onready var spawner: Node2D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var camera: CameraShake = $Camera2D
@onready var _sfx: Variant = get_node_or_null(^"/root/Sfx")

var score: int = 0
var kills: int = 0

## Level-up choices queue up: a kill can cross several thresholds at once, and
## the player keeps no input while paused, so each pending level-up is resolved
## one perk-choice at a time before the action resumes.
var _pending_levelups: int = 0
var _choosing: bool = false
var _choice_armed: bool = false

## Beat between the killing blow and the perk menu, run unpaused so the kill
## resolves visibly (blood spray + sound) before the action freezes for the
## choice — otherwise those effects sit frozen under the menu and the dead enemy
## looks alive until you pick.
const LEVELUP_DELAY := 0.35

func _ready() -> void:
	player.health_changed.connect(hud.set_health)
	player.weapon_changed.connect(hud.set_weapon)
	player.died.connect(_on_player_died)
	player.xp_changed.connect(hud.set_xp)
	player.leveled_up.connect(_on_player_leveled_up)
	hud.perk_chosen.connect(_on_perk_chosen)
	spawner.wave_changed.connect(hud.set_wave)
	spawner.enemy_killed.connect(_on_enemy_killed)
	player.hit.connect(_on_player_hit)
	hud.set_score(score, kills)
	_sfx.play(SND_ROUND_START)

func _on_enemy_killed(score_value: int, position: Vector2) -> void:
	kills += 1
	score += score_value
	hud.set_score(score, kills)
	player.add_xp(xp_per_kill)
	_maybe_drop(position)

func _maybe_drop(position: Vector2) -> void:
	var pool := weapon_drops if not weapon_drops.is_empty() else DEFAULT_DROPS
	if pool.is_empty() or randf() > drop_chance:
		return
	var pickup := PICKUP_SCENE.instantiate()
	pickup.weapon = pool[randi() % pool.size()]
	pickup.global_position = position
	add_child(pickup)

func _on_player_hit() -> void:
	camera.add_trauma(0.45)

func _on_player_leveled_up(_level: int) -> void:
	_pending_levelups += 1
	# Let the kill finish playing out, then present. Only arm one timer; further
	# level-ups in the meantime just add to the queue the timer will drain.
	if not _choosing and not _choice_armed:
		_choice_armed = true
		get_tree().create_timer(LEVELUP_DELAY).timeout.connect(_arm_choices)

func _arm_choices() -> void:
	_choice_armed = false
	_present_next_choice()

## Resolve one queued level-up: pause and show the choice. When the queue is
## empty, drop the pause and hide the overlay. Re-entered from _on_perk_chosen,
## so several level-ups from one kill chain through without ever unpausing.
func _present_next_choice() -> void:
	# Never interrupt a death (or an empty queue) with the menu.
	if _pending_levelups <= 0 or not is_instance_valid(player) or player.health <= 0:
		_pending_levelups = 0
		_choosing = false
		hud.hide_perk_choice()
		get_tree().paused = false
		return
	_choosing = true
	get_tree().paused = true
	hud.show_perk_choice(_roll_perks())

func _roll_perks() -> Array[PerkData]:
	var pool := perk_pool if not perk_pool.is_empty() else DEFAULT_PERKS
	var available: Array[PerkData] = []
	for p in pool:
		if p.stackable or not player.has_perk(p):
			available.append(p)
	available.shuffle()
	var chosen: Array[PerkData] = []
	for i in mini(PERK_CHOICES, available.size()):
		chosen.append(available[i])
	return chosen

func _on_perk_chosen(perk: PerkData) -> void:
	player.apply_perk(perk)
	_pending_levelups -= 1
	_present_next_choice()

func _on_player_died() -> void:
	camera.add_trauma(1.0)
	hud.show_game_over(score, kills)
	get_tree().create_timer(2.0).timeout.connect(_restart)

func _restart() -> void:
	get_tree().reload_current_scene()
