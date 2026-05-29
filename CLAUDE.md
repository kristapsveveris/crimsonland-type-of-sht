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

The project is a **bare scaffold** — Godot project + the `godot-ai` editor
plugin, no game scenes or scripts yet. There is no main scene set. Everything
below the "Architecture" heading describes the *intended* shape to build
toward, not what exists. Update this file as real structure lands.

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

## Architecture (intended)

Top-down twin-stick shooter ⇒ this is a **2D** game. Note the scaffold still
carries Godot's default 3D config (`3d/physics_engine="Jolt Physics"`,
`Forward Plus` renderer); the gameplay will use 2D nodes
(`CharacterBody2D`, `Area2D`, `GPUParticles2D`). Switch the renderer/physics
defaults toward 2D when it matters; leave them until then rather than
churning config preemptively.

Proposed layout (create as needed, don't scaffold empty dirs ahead of use):

```
scenes/        # .tscn — main_menu, arena, player, enemies/, pickups/, hud
scripts/       # .gd — gameplay logic, autoload singletons
resources/     # .tres — WeaponData, EnemyData, PerkData, WaveData
assets/        # art, audio, fonts (sprites/, sfx/, music/)
addons/        # godot-ai plugin (vendored, committed)
```

Likely systems, in rough build order:
1. **Player** — `CharacterBody2D`, move (keyboard/stick) + aim toward cursor.
2. **Weapons** — data-driven `WeaponData` resources; firing, projectiles, cooldown.
3. **Enemies** — wave spawner, steering toward player, contact damage.
4. **Pickups / perks** — weapon and perk drops, run-scoped modifiers.
5. **HUD + game loop** — health, ammo, wave/score, death + restart.

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

## Gotchas

- **Editor must stay open** for MCP — see above.
- **Port 8077**, not 8000.
- **Telemetry**: the plugin has `godot_ai/telemetry_enabled = true` and posts
  events to an external endpoint. Disable in editor settings if undesired.
- **`.godot/`** is gitignored (build cache); never commit it.
- The `_mcp_game_helper` autoload in `project.godot` belongs to the plugin —
  leave it.

## Git

Single repo, branch `main`. The `godot-ai` plugin is vendored (committed) so
the project travels self-contained. Commit/push only when asked.
