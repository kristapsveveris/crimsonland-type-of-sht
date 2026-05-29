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

**First playable vertical slice is in.** The core twin-stick loop works:
WASD/arrows move, mouse aims, left-click fires; enemies spawn at the arena
edges, home in on the player, and deal contact damage; the player owns its
health and death; death triggers a restart after 2s.

What exists (all authored through the Godot MCP):

| Scene / script | Role |
| --- | --- |
| `scenes/arena.tscn` + `scripts/arena.gd` | Main scene. Wires player→HUD signals and the death→restart loop. |
| `scenes/player.tscn` + `scripts/player.gd` | `CharacterBody2D`. Move, aim (`look_at` cursor), click-to-fire on cooldown. Owns health + `died`. |
| `scenes/bullet.tscn` + `scripts/bullet.gd` | `Area2D` projectile. Forward travel, lifetime despawn, damages enemies on overlap. |
| `scenes/enemy.tscn` + `scripts/enemy.gd` | Homing `CharacterBody2D`. `Touch` area applies contact damage on a cadence. Owns health + despawn. |
| `scripts/spawner.gd` | Spawns enemies at random arena edges on an interval (`Spawner` node in arena). |
| `scripts/hud.gd` | HP readout + game-over banner (HUD `CanvasLayer` in arena). |

**Collision layers**: player = layer 1, enemies = layer 2; bullets mask
layer 2, the enemy `Touch` area masks layer 1. Bodies don't physically block
each other yet (masks are 0) — enemies overlap freely, which is acceptable
for now.

**Not built yet**: weapon variety, waves/score, pickups/perks, audio, hit/death
juice. See the build order under Architecture.

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
scenes/        # .tscn — arena (main), player, enemy, bullet  (+ later: menu, pickups/)
scripts/       # .gd — gameplay logic  (+ later: autoload singletons)
resources/     # .tres — WeaponData, EnemyData, PerkData, WaveData  (not yet created)
assets/        # art, audio, fonts  (not yet created)
addons/        # godot-ai plugin (vendored, committed)
```

Systems, in rough build order (✓ = done):
1. ✓ **Player** — `CharacterBody2D`, move + aim toward cursor, click-to-fire.
2. ✓ **Enemies (basic)** — edge spawner, homing, contact damage.
3. ✓ **HUD + game loop (basic)** — health readout, death → restart.
4. **Weapons** — data-driven `WeaponData` resources; fire rate, projectile count, spread.
5. **Waves + score** — escalating spawn rate/variety, kill count.
6. **Pickups / perks** — weapon and perk drops, run-scoped modifiers.
7. **Juice** — hit flash, death particles, screen shake, sfx.

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
- **Sprite facing**: all character/enemy art must face **+X (right)** — that's
  the axis `look_at()` aims (`local +X` → target). The current art pack
  (`assets/sprites/survivor_*`, `zombie`) was authored facing **−Y (up)**, so
  each used sprite is **rotated 90° CW on import** to match. Rotate the source
  art to the convention; do **not** add per-node `rotation_degrees` offsets to
  compensate (they don't scale and get forgotten). Any new sprite from this
  pack needs the same 90° CW rotation. The multi-frame
  `survivor_spritesheet`/`template` and the gun-icon strips are left unrotated
  (rotating a strip scrambles its frames) — handle orientation per-frame if
  they're ever sliced.

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
