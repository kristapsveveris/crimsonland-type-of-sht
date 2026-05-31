class_name PerkData
extends Resource

## A run-scoped modifier earned on level-up (Crimsonland's perk system). Fully
## data-driven, like WeaponData: the player folds each field into its stat
## accumulators in Player.apply_perk(), so adding a perk is just a new .tres with
## the right fields set — no code branches. Every field defaults to neutral
## (x1.0 / +0), so a perk only changes what it explicitly sets.

@export var display_name: String = "Perk"
@export_multiline var description: String = ""
## When false the perk is offered at most once per run: already-taken copies are
## filtered out of the choice. Stackable perks can be picked repeatedly.
@export var stackable: bool = true

@export_group("Modifiers")
@export var damage_mult: float = 1.0        ## multiplies per-projectile damage
@export var fire_rate_mult: float = 1.0     ## >1 = faster (shortens fire cooldown)
@export var move_speed_mult: float = 1.0    ## multiplies move speed
@export var max_health_add: int = 0         ## raises max HP (and heals by the same)
@export var bonus_projectiles: int = 0      ## extra pellets per trigger pull
@export var bonus_pierce: int = 0           ## extra enemies each bullet punches through
@export var regen_per_sec: float = 0.0      ## passive HP regen per second
@export var xp_mult: float = 1.0            ## multiplies XP gained from kills
@export var heal_on_pickup: int = 0         ## one-time heal applied when taken
