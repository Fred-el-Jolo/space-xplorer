# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project vision

**Space Xplorer** is an ambitious mobile game drawing from Star Citizen's design philosophy — large-scale space exploration, player-driven economy, ship combat, and a living universe — adapted for mobile constraints (touch input, shorter sessions, battery/performance budgets).

Key pillars:
- Deep, systemic gameplay over shallow gatcha loops
- Persistent universe with player economy and factions
- High-fidelity visuals within mobile hardware limits
- Session-aware design: meaningful 5–15 min play windows alongside longer engagement options

## Tech stack

**Engine: Godot 4.3 LTS** — chosen after MVP validation (2026-05-14).

| Setting | Value |
|---------|-------|
| Engine | Godot 4.3 LTS |
| Renderer | GL Compatibility (OpenGL ES 3 — broadest Android coverage) |
| Language | GDScript (type-hinted) |
| Test framework | GUT 9.3.1 |
| Target platforms | Android (primary), iOS (future) |
| Viewport | 1280×720, `canvas_items` stretch, `expand` aspect |

Godot binary lives at `~/godot/Godot_v4.3-stable_linux.x86_64` on the dev machine (not committed — download from `https://github.com/godotengine/godot/releases/tag/4.3-stable`).

## Development commands

```bash
# Run all tests headlessly (CI)
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit

# Re-import assets after adding new files (required before headless test run on a fresh clone)
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --import .

# Open the project in the editor
~/godot/Godot_v4.3-stable_linux.x86_64 --editor .

# Play the game (desktop)
~/godot/Godot_v4.3-stable_linux.x86_64 --path .
```

**Android export** — requires manual steps in the editor:
1. Install Android SDK and point Godot to it via Editor → Editor Settings → Export → Android
2. Project → Export → Add → Android, configure package name `com.spacexplorer.game`
3. Install Android build template, then Export Project → `space-xplorer-debug.apk`
4. `adb install space-xplorer-debug.apk`

## Architecture

### Implemented (MVP — ship control prototype)

**DepthSystem** (`src/systems/depth_system.gd`) — Static utility class. Pure pseudo-3D math: maps `z_depth: float` to visual scale, draw order, visibility, and Y-offset. `compute_draw_order` maps the full depth range [0, MAX_Z_DEPTH=10000] linearly to z_index [0, −4096] to stay within Godot's clamp limits. No dependencies; used by WorldEntity and Ship.

**WorldEntity** (`src/entities/world_entity.gd`) — Base class (extends `Node2D`) for depth-aware non-physics entities. Exports `z_depth: float`; applies DepthSystem each frame via `_apply_depth()`. Planet extends this.

**Planet** (`src/scenes/planets/planet.gd`) — Extends WorldEntity. Emits `landing_zone_entered(planet)` / `landing_zone_exited(planet)` signals based on ship z_depth proximity. World calls `check_landing_proximity(ship_z_depth)` each frame.

**ShipData** (`src/resources/ship_data.gd`) — Resource with 6 exports: `max_fuel`, `max_hull`, `thrust_power`, `depth_speed`, `fuel_burn_rate`, `linear_damp_value`. Default values in `src/resources/default_ship.tres`.

**Ship** (`src/scenes/ship/ship.gd`) — Extends `RigidBody2D` (cannot extend WorldEntity — physics constraint). Reads `thrust_input: Vector2` and `depth_input: float` from ShipInput each frame; applies thrust force, depletes fuel, clamps z_depth, emits `fuel_changed` / `depth_changed` signals. Mirrors DepthSystem depth-visual logic directly since it can't inherit WorldEntity.

**ShipInput** (`src/systems/ship_input.gd`) — Autoload singleton (no `class_name` — Godot 4 parse error when autoload name matches class_name). Reads 6 input actions each frame, writes normalised `thrust_input` and accumulated `depth_input` to the active `Ship`. Actions: `ship_left/right/up/down` (WASD + arrows), `ship_depth_in` (Q), `ship_depth_out` (E).

**World** (`src/scenes/world/world.gd`) — Top-level controller. On `_ready`: wires `ShipInput.ship` and connects planet landing signals to HUD. Each frame: calls `planet.check_landing_proximity(ship.z_depth)`.

**HUD** (`src/scenes/ui/hud.gd`) — CanvasLayer. `connect_to_ship(ship)` seeds bars from ship state and subscribes to `fuel_changed` / `hull_changed` / `depth_changed`. `show_landing_prompt(bool)` toggles the "▼ APPROACH TO LAND" label. Note: `hull_changed` is declared but not yet emitted (damage system not implemented).

**TouchControls** (`src/scenes/ui/touch_controls.gd`) — CanvasLayer, hidden on non-mobile/web. Six `TouchScreenButton` nodes fire the same input actions as the keyboard — ShipInput picks them up automatically. Each button has a `RectangleShape2D` hit area (100×100 for D-pad, 130×60 for depth buttons).

**Space background** (`src/scenes/world/space_background.tscn`) — `ParallaxBackground` with 6 `ParallaxLayer` children (motion scales 0.02–0.9). Each layer has `motion_mirroring = Vector2(2560, 1440)` to prevent seams during long flights.

### Planned (not yet built)

- **Universe / world state** — server-authoritative persistent simulation, tick rate, shard model
- **Session management** — how players enter/exit without disrupting the persistent world
- **Economy engine** — supply/demand simulation, player trade, crafting
- **Combat system** — ship physics, weapon mechanics, hit detection
- **Progression** — reputation, skills, ship/gear upgrades; no pay-to-win
- **Networking** — real-time vs. eventual consistency trade-offs per subsystem
