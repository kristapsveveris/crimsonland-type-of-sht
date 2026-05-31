# Crimsonland

A Crimsonland-style game built in **Godot 4.6.3**: a top-down, twin-stick
survival shooter — you move with one control axis, aim/shoot with another, and
hold out against escalating waves of enemies while collecting weapon and perk
drops.

This file is the authoritative context for working in this repo. The top-level
`/Users/kristaps/Code/CLAUDE.md` is only a signpost; its **Approach to fixes**
section still applies here (identify root cause vs symptom, name the violated
invariant, don't extract abstractions on first occurrence, no silent failures).

## Current state

**Vertical slice + data-driven weapons + continuous waves/score + weapon
pickups + hit/death/fire juice are in.** The
core twin-stick loop works: WASD/arrows move, mouse aims, left-click fires;
enemies spawn at the arena edges, home in on the player, and deal contact
damage; the player owns its health and death; death triggers a restart after
2s. Firing is now fully data-driven — the player reads its stats from an
equipped `WeaponData` resource and supports multi-projectile spread. Four
weapons (Pistol, Shotgun, SMG, Rifle) are authored as `.tres`; number keys
**1-4** still swap between them (now a debug convenience — the real swap
mechanic is pickups, below). Each weapon has its own fire sound (pistol, plus
MP5/AWP/M3 trimmed from the CS pack — see Assets).

**Waves are continuous escalation** (Crimsonland-survival style, not discrete
clear-the-room rounds): the spawner derives a wave number from elapsed
survival time, tightens the spawn interval per wave (toward a floor), scales
each enemy's HP/speed/worth per wave, and grows the concurrent spawn count
every few waves. Escalation is **procedural** (formulas + exported knobs on
the spawner), not yet `WaveData` `.tres` — real enemy *variety* (distinct
types) waits on `EnemyData`. Score/kills are tracked: each enemy announces its
own kill (it owns its death), the spawner forwards it, and the arena turns it
into score. The HUD shows wave + score/kills live and the final tally on the
game-over banner.

**Weapon pickups close the kill→reward loop** (Crimsonland's hook). The arena
owns loot policy: each kill rolls `drop_chance` (default 0.16) to spawn a
`Pickup` where the enemy died, carrying one `WeaponData` from a drop pool
(defaults to the non-pistol weapons — pistol is the starter, never dropped).
Walking the player over a pickup calls `player.equip_weapon()` and consumes the
pickup. The kill signal chain now carries the death `position` so the arena can
place the drop. Pickup icons are **data-driven**: each `WeaponData` holds an
`icon_region` into the shared 4-frame **`guns_side_view.png`** sheet, and the
pickup slices it — adding a weapon needs no pickup changes. Perks (the other
half of #6) are still **not built**.

**Juice (#7) is in.** A shared `hit_flash.gdshader` tints a sprite toward a
flash colour by a `flash` uniform (0→1, tweened down): enemies flash white on
every hit, the player flashes red on damage. Each character builds its own
`ShaderMaterial` in `_ready()` so the uniform animates per-instance. Enemies
spray a one-shot `BloodBurst` (`CPUParticles2D`, self-freeing) where they die.
The player shows a brief `MuzzleFlash` (a `Polygon2D` pulsed for ~0.05s) on
each shot. The arena's `Camera2D` carries a trauma-based `CameraShake` (decays
itself; offset+roll scale with trauma²) — the player emits `hit`, the arena
adds trauma on hit (0.45) and death (1.0).

What exists (all authored through the Godot MCP):

| Scene / script | Role |
| --- | --- |
| `scenes/arena.tscn` + `scripts/arena.gd` | Main scene. Wires player + spawner → HUD signals (health, weapon, wave, score), owns the run-scoped score/kill tally, the death→restart loop, loot policy (rolls `drop_chance` per kill → spawns a pickup from the drop pool at the death position), and camera-shake wiring (player `hit` → trauma 0.45, death → trauma 1.0). |
| `scenes/player.tscn` + `scripts/player.gd` | `CharacterBody2D`. Move, aim (`look_at` cursor), data-driven fire from the equipped `WeaponData` (cooldown, pellet count, spread). Owns health + `died`; emits `weapon_changed` + `hit` (juice). `equip_weapon()` is the shared equip entry point (number keys + pickups). Juice: red hit-flash material, `MuzzleFlash` polygon on fire. |
| `scripts/weapon_data.gd` | `WeaponData` `Resource` — display_name, sprite, `icon_region` (frame into the gun-icon sheet, for pickups), fire_cooldown, projectile_count, spread_degrees, damage, bullet_speed, bullet_lifetime, `pierce` (enemies one shot passes through), fire_sound. |
| `scenes/pickup.tscn` + `scripts/pickup.gd` | `WeaponPickup` `Area2D` (mask = player layer). A weapon drop lying in the arena; its icon is sliced from `guns_side_view.png` via the weapon's `icon_region`. On player overlap it calls `equip_weapon()` and frees itself (owns its own despawn). |
| `resources/weapons/*.tres` | Pistol / Shotgun / SMG / Rifle definitions (each pairs stats with its `survivor_*` sprite). Rifle is the piercing weapon: slow fire, fast round, `pierce = 5`. |
| `scenes/bullet.tscn` + `scripts/bullet.gd` | `Area2D` projectile. Per-shot speed/damage/lifetime set by the player before spawn; forward travel, lifetime despawn, damages enemies on overlap. |
| `scenes/enemy.tscn` + `scripts/enemy.gd` | Homing `CharacterBody2D`. `Touch` area applies contact damage on a cadence. Owns health + despawn; emits `killed(score_value, position)` on death-by-damage (position lets the arena drop loot there). `score_value` + stats are scaled per wave by the spawner. Juice: white hit-flash material, spawns a `BloodBurst` on death. |
| `scenes/blood_burst.tscn` + `scripts/blood_burst.gd` | One-shot `CPUParticles2D` blood spray. Spawned into the arena at an enemy's death position (not under the enemy, which frees the same frame); emits once and self-frees on `finished`. |
| `scripts/camera_shake.gd` | `CameraShake` (extends `Camera2D`, on the arena camera). Trauma-based shake: `add_trauma()` accumulates, `_process` decays it and applies offset+roll scaled by trauma². Owns its own decay → self-rests at zero. |
| `assets/shaders/hit_flash.gdshader` | Shared `canvas_item` flash shader: mixes the sprite toward `flash_color` by the `flash` uniform, preserving alpha. Player + enemy each build a per-instance `ShaderMaterial` from it. |
| `scripts/spawner.gd` | `Spawner` node in arena. Spawns enemies at random edges and owns continuous difficulty escalation (wave # from elapsed time, shrinking interval, per-wave stat scaling, growing burst size). Emits `wave_changed` and forwards `enemy_killed(score_value, position)`. |
| `scripts/hud.gd` | HP + current-weapon + wave + score/kills readouts and a game-over banner with the final tally (HUD `CanvasLayer` in arena). |

**Collision layers**: player = layer 1, enemies = layer 2; bullets mask
layer 2, the enemy `Touch` area masks layer 1. Enemies now physically block
the player and each other — the enemy body masks layers 1+2 (`collision_mask
= 3`), so each enemy stops at the player's surface and slides around it
(`move_and_slide`) and back rows can't pile through the front, forming a ring
around the player instead of overlapping it. The player's own mask stays 0, so
it walks freely *through* the crowd (it ignores enemies; enemies don't ignore
it) — neither `CharacterBody2D` pushes the other. Contact damage still lands:
the `Touch` area (radius 18) reaches the player body (radius 16) once the two
bodies rest ~32px apart. **Pickups** are an `Area2D` on layer 0, mask 1 — they
scan for the player body (layer 1) but nothing scans for them.

**Not built yet**: perks (the other half of #6) and enemy *variety* via
`EnemyData`. See the build order under Architecture.

## Building through the Godot MCP (`godot-ai`)

The primary way to author scenes, nodes, scripts, and resources here is the
**`godot-ai` MCP server**, which drives a live Godot editor. This is not
optional tooling — prefer it over hand-editing `.tscn`/`.tres` files, because
the editor keeps UIDs, dependencies, and import metadata consistent in ways
raw text edits silently break.

**Hard requirements:**
- The **Godot editor must be running** with this project open. The plugin
  hosts the MCP server; close the editor and every MCP tool goes dead.
- The server runs on **HTTP port 8077** (moved off the default 8000, which is
  taken by another app on this machine). This is set via the global
  EditorSetting `godot_ai/http_port` in `~/Library/Application Support/Godot/`,
  **not** in the repo — a fresh clone defaults back to 8000 until re-set.
- `.mcp.json` (committed) points Claude Code at `http://127.0.0.1:8077/mcp`.

**Workflow:**
- Call `editor_state` first to confirm readiness and the current scene. If a
  write is rejected with `EDITOR_NOT_READY (state=playing)` after you know the
  game stopped, call `editor_state` once to resync, then retry.
- Build scenes with `scene_manage`/`scene_open`/`node_create`/
  `node_set_property`/`script_create`/`script_attach`, then `scene_save`.
- **Verify visually**: `project_run` then `editor_screenshot`, and
  `logs_read` for runtime errors. Don't claim a feature works without running
  it — see the parent rule on silent failures.
- Multiple editors can connect; `session_activate` pins commands to one.

## Architecture

Top-down twin-stick shooter ⇒ this is a **2D** game, using 2D nodes
(`CharacterBody2D`, `Area2D`, `GPUParticles2D`). Config is set for 2D:
1280×720 viewport, `canvas_items` stretch, the 3D Jolt override dropped.
The renderer is still `Forward Plus` (Godot's default) — fine for 2D; switch
to Mobile/Compatibility only if portability/perf calls for it, not preemptively.
Placeholder art is primitive `Polygon2D` shapes; swap for sprites later.

Current layout (create subdirs as needed, don't scaffold empty dirs ahead of use):

```
scenes/        # .tscn — arena (main), player, enemy, bullet, pickup, blood_burst  (+ later: menu)
scripts/       # .gd — gameplay logic + Sfx autoload  (+ later: more singletons)
resources/     # .tres — weapons/ (WeaponData) done; later: EnemyData, PerkData, WaveData
assets/        # sprites/, audio/, shaders/ (hit_flash)
addons/        # godot-ai plugin (vendored, committed)
```

Systems, in rough build order (✓ = done):
1. ✓ **Player** — `CharacterBody2D`, move + aim toward cursor, click-to-fire.
2. ✓ **Enemies (basic)** — edge spawner, homing, contact damage.
3. ✓ **HUD + game loop (basic)** — health readout, death → restart.
4. ✓ **Weapons** — data-driven `WeaponData` resources; fire rate, projectile count, spread. Four weapons authored; keys 1-4 switch (placeholder for pickups).
5. ✓ **Waves + score** — continuous escalation (wave # from elapsed time, shrinking interval, per-wave enemy stat scaling, growing burst), kill/score tally on the HUD. Procedural for now; `WaveData`/`EnemyData` variety deferred.
6. **Pickups / perks** — ✓ weapon drops (kill → `drop_chance` roll → `WeaponPickup` at the death position → walk over to equip). Perks / run-scoped modifiers still deferred.
7. ✓ **Juice** — hit-flash shader (enemy white / player red), one-shot blood particles on death, trauma-based screen shake, muzzle flash, sfx (already wired). Future polish: death particles for the player, bullet impact sparks, hit-stop.

Favor **data-driven** design: enemies, weapons, and perks as `Resource`
(`.tres`) definitions, not hardcoded branches. The component that owns a piece
of state (e.g. the player owns its health) should own all transitions into
terminal states for it (death), rather than relying on external listeners.

## Conventions

- **Node/scene names**: PascalCase (`PlayerShip`, `WaveSpawner`).
- **Files**: `snake_case.gd` / `snake_case.tscn` / `snake_case.tres`.
- **Scripts**: `class_name` for anything instantiated or used as a type;
  static typing on declarations and signatures.
- **Input**: define actions in the Input Map (`input_map_manage`), reference by
  name — never hardcode raw keycodes in gameplay scripts.
- **Signals over polling** for decoupled events (enemy died, pickup grabbed).
- **Sound effects**: `Sfx.play()` spawns a one-shot player per call that runs
  the stream to completion, so source samples must be short or rapid fire
  stacks into mush. Weapon fire sounds are sourced from the Counter-Strike pack
  at `../cstrike/sound/weapons/` (sibling repo) and **trimmed to the transient**
  (CS samples bake a long decay tail) sized to each weapon's fire cadence, with
  a short fade-out — no ffmpeg/sox on this machine, so trim with a stdlib
  `python3` `wave`/`array` script. SMG ≈ 0.18s (MP5), Rifle ≈ 0.5s (AWP),
  Shotgun ≈ 0.55s (M3). Re-trimming an *already-imported* wav hits the stale
  baked-asset gotcha below — delete `.godot/imported/<name>.wav-*.sample` +
  `.md5` and force a rescan, same as textures.
- **Sprite facing**: all character/enemy art must face **+X (right)** — that's
  the axis `look_at()` aims (`local +X` → target). The current art pack
  (`assets/sprites/survivor_*`, `zombie`) was authored facing **−Y (up)**, so
  each used sprite is **rotated 90° CW on import** to match. Rotate the source
  art to the convention; do **not** add per-node `rotation_degrees` offsets to
  compensate (they don't scale and get forgotten). Any new sprite from this
  pack needs the same 90° CW rotation. The multi-frame
  `survivor_spritesheet`/`template` and the gun-icon strips are left unrotated
  (rotating a strip scrambles its frames) — handle orientation per-frame if
  they're ever sliced. **`guns_side_view.png`** (256×64, four 64px frames) **is**
  the weapon-pickup sheet, sliced via per-weapon `WeaponData.icon_region`; frame
  order is **0 pistol, 1 rifle, 2 shotgun, 3 SMG** (a ground pickup has no
  canonical facing, so the frames are used unrotated). Pistol (0) and SMG (3)
  are unambiguous; frames 1/2 are two near-identical wood long-guns, so
  rifle-vs-shotgun is a best-guess — swap the two `icon_region`s if they ever
  look wrong. (The `guns_top_view.png` sheet has a *different* frame order —
  0 pistol, 1 SMG, 2 shotgun, 3 rifle — and is currently unused.)

## Gotchas

- **Editor must stay open** for MCP — see above.
- **Port 8077**, not 8000.
- **Telemetry**: the plugin has `godot_ai/telemetry_enabled = true` and posts
  events to an external endpoint. Disable in editor settings if undesired.
- **`.godot/`** is gitignored (build cache); never commit it.
- **Autoloads added via MCP need a project reload.** `autoload_manage(add)` /
  `project_manage(settings_set "autoload/X")` write the entry to
  `project.godot`, but the *running editor* does not register the singleton as
  a GDScript global identifier until the project is reloaded — so scripts that
  reference it by name (`Sfx.play()`) fail to compile **in the editor** (the
  *game*, a fresh process, works fine). Two responses: (a) reference the
  singleton by its runtime path instead — `@onready var _sfx: Variant =
  get_node_or_null(^"/root/Sfx")` — which compiles regardless and is what the
  `_sfx` refs in player/enemy/arena do; or (b) reload the project. Verify audio
  via `editor_manage(game_eval)` against `/root/Sfx`, not the editor error log.
- **The editor doesn't recompile scripts on MCP file ops.** Editing a `.gd` on
  disk (or via `write_text`/`reimport`) does not make the running editor
  re-parse it — it keeps reporting the *last* compile result (stale line
  numbers are the tell). Only a project reload forces a fresh editor compile.
  The running game always uses the on-disk source, so trust `logs_read(source=
  "game")` + `game_eval` over `logs_read(source="editor")` after script edits.
- The `_mcp_game_helper` autoload in `project.godot` belongs to the plugin —
  leave it.
- **Save the scene after node/script mutations before navigating away.** A
  `node_create` / `script_attach` / `node_set_property` is an *in-memory* edit
  on the open scene. If you `scene_open` a different scene and come back without
  `scene_save`, the editor reloads that scene from disk and the mutation is
  **lost** — and `project_run`'s autosave then persists the disk version, so the
  *running game* never sees it (symptom: a node has no script / an added child
  is missing at runtime, with no error). Caught this when a `CameraShake` attach
  to the arena `Camera2D` vanished after editing `player.tscn` in between. Fix:
  `scene_save` immediately after editing a scene, before opening another.
- **`editor_manage(game_eval)` needs the game window processing.** When the
  running game loses OS focus its main loop can throttle/stall, and evals (esp.
  any that `await get_tree().physics_frame`) time out after 10s even though the
  game is fine — `logs_read(source="game")` shows no error. Prefer no-`await`
  evals; send a trivial `return "ping"` to tell a real runtime error from a
  stalled bridge. To screenshot transient effects (particles, flashes) that
  expire before the capture lands, set `Engine.time_scale` low in the arming
  eval, screenshot, then restore it.
- **Reimport doesn't always rebuild textures.** When you change an image's
  *pixel content* on disk (e.g. rotating a PNG), `filesystem_manage(op=reimport)`
  can report success without regenerating the baked `.godot/imported/*.ctex` —
  the editor and running game then keep rendering the **old** texture. Symptom:
  on-disk PNG looks right, in-game looks stale. Fix: delete the stale
  `.godot/imported/<name>.png-*.ctex` + `.md5`, then force a real scan
  (`filesystem_manage(op=write_text)` of a throwaway file triggers one). Verify
  by checking the `.ctex` mtime is newer than the source PNG before re-running.
  (Adding/moving a *new* file imports fine via the scan trigger; this only bites
  on content changes to an already-imported file.)

## Git

Single repo, branch `main`. The `godot-ai` plugin is vendored (committed) so
the project travels self-contained. Commit/push only when asked.
