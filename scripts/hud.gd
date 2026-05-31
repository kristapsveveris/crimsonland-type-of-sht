extends CanvasLayer

## Minimal heads-up display: health, current weapon, wave, score/kills, an XP bar
## with level, a game-over banner, and the level-up perk choice overlay. The
## XP bar sits top-centre. The overlay is the only interactive HUD element: it processes
## while the tree is paused (set process_mode = ALWAYS on the PerkChoice node) so
## the player can pick a perk with the action frozen behind it.

## Emitted when the player clicks one of the offered perk buttons. The arena
## listens, applies the perk, and unpauses.
signal perk_chosen(perk: PerkData)

## Emitted when the player clicks RETRY on the game-over screen. The arena
## listens and reloads the scene.
signal retry_pressed

@onready var health_label: Label = $HealthLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var wave_label: Label = $WaveLabel
@onready var score_label: Label = $ScoreLabel
@onready var level_label: Label = $LevelLabel
@onready var xp_bar: ProgressBar = $XPBar
@onready var game_over: Control = $GameOver
@onready var game_over_stats: Label = $GameOver/Stats
@onready var retry_button: Button = $GameOver/RetryButton
@onready var perk_choice: Control = $PerkChoice
@onready var button_box: VBoxContainer = $PerkChoice/ButtonBox

func _ready() -> void:
	game_over.hide()
	perk_choice.hide()
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())

func set_health(current: int, maximum: int) -> void:
	health_label.text = "HP: %d / %d" % [current, maximum]

func set_weapon(weapon: WeaponData) -> void:
	weapon_label.text = "Weapon: %s" % weapon.display_name

func set_wave(wave: int) -> void:
	wave_label.text = "Wave: %d" % wave

func set_score(score: int, kills: int) -> void:
	score_label.text = "Score: %d   Kills: %d" % [score, kills]

func set_xp(xp: int, xp_to_next: int, level: int) -> void:
	level_label.text = "Level: %d" % level
	xp_bar.max_value = xp_to_next
	xp_bar.value = xp

## Build a button per offered perk and reveal the overlay. The arena pauses the
## tree around this; the overlay's ALWAYS process mode keeps the buttons live.
func show_perk_choice(perks: Array[PerkData]) -> void:
	for child in button_box.get_children():
		child.queue_free()
	for perk in perks:
		var button := Button.new()
		button.text = "%s\n%s" % [perk.display_name, perk.description]
		button.custom_minimum_size = Vector2(0, 64)
		button.pressed.connect(_on_perk_button_pressed.bind(perk))
		button_box.add_child(button)
	perk_choice.show()

func hide_perk_choice() -> void:
	perk_choice.hide()

func _on_perk_button_pressed(perk: PerkData) -> void:
	perk_chosen.emit(perk)

func show_game_over(score: int, kills: int) -> void:
	game_over_stats.text = "Score: %d\nKills: %d" % [score, kills]
	game_over.show()
