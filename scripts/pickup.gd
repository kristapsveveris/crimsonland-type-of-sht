class_name WeaponPickup
extends Area2D

## A weapon drop lying in the arena. Walking the player over it swaps the
## player's equipped WeaponData and consumes the pickup. The arena owns drop
## policy (when/what drops, see arena.gd); this node owns only the grab and its
## own despawn — the single terminal owner of "this pickup is gone".
##
## Data-driven: the icon is sliced from the shared side-view gun sheet using the
## equipped weapon's `icon_region`, so adding a weapon needs no pickup changes.

const ICON_SHEET := preload("res://assets/sprites/guns_side_view.png")

## Set by the spawner of this pickup (the arena) before add_child, so it is
## already assigned when _ready runs.
@export var weapon: WeaponData
## Seconds the drop lingers before despawning. It fades over the final
## `fade_time` so an about-to-vanish pickup reads clearly. The pickup owns this
## transition itself — the single terminal owner of "this pickup is gone".
@export var lifetime: float = 8.0
@export var fade_time: float = 2.0

@onready var _icon: Sprite2D = $Icon

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if weapon == null:
		return
	_icon.texture = ICON_SHEET
	_icon.region_enabled = true
	_icon.region_rect = weapon.icon_region
	# Linger, then fade and self-free. A grab (queue_free in _on_body_entered)
	# cancels this by freeing the node, which kills the tween with it.
	var tw := create_tween()
	tw.tween_interval(maxf(0.0, lifetime - fade_time))
	tw.tween_property(self, "modulate:a", 0.0, fade_time)
	tw.tween_callback(queue_free)

func _on_body_entered(body: Node) -> void:
	# Mask is set to the player's layer, so any body that enters is the player;
	# guard anyway rather than assume.
	if weapon == null:
		return
	if body.is_in_group("player") and body.has_method("equip_weapon"):
		body.equip_weapon(weapon)
		queue_free()
