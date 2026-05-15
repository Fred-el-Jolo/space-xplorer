# POI & Landing System — Design Spec
Date: 2026-05-15

## Overview

Add Points of Interest (POI) to the game world: planets, space stations, asteroid outposts, and derelict ships. Players can land on any of them, triggering a landing screen with auto-refuel. A beacon safety system auto-lands the ship on the nearest POI when fuel runs out. Fuel consumption is disabled until the player lands for the first time (onboarding grace).

## Data & Entities

### `POIData` resource (`src/resources/poi_data.gd`)
- `type: POIType` — enum: `PLANET`, `STATION`, `ASTEROID`, `DERELICT`
- `poi_name: String`
- `description: String`
- `landing_threshold: float` — z_depth proximity to trigger landing zone

One `.tres` file per POI instance. Planet is retired; all types share one base.

### `PointOfInterest` (`src/scenes/poi/point_of_interest.gd` + `.tscn`)
- Extends `WorldEntity`
- `@export var data: POIData`
- Signals: `landing_zone_entered(poi)`, `landing_zone_exited(poi)`
- `check_landing_proximity(ship_z_depth)` — same logic as old Planet

## State & Systems

### `GameState` autoload (`src/systems/game_state.gd`)
- `has_landed_once: bool = false`
- Ship's `_handle_thrust` skips fuel burn while this is false
- Set to `true` on first landing screen show

### `BeaconSystem` autoload (`src/systems/beacon_system.gd`)
- World registers ship + POI array on `_ready`
- Listens to `ship.fuel_changed`
- Activates when `fuel == 0` and `GameState.has_landed_once == true`
- Finds nearest POI via 3D distance: `Vector3(position.x, position.y, z_depth)`
- Each `_process` frame: steers ship (sets `linear_velocity`, lerps `z_depth`) until POI landing threshold reached
- Suspends ShipInput during beacon mode
- HUD shows "BEACON ACTIVE — auto-landing" label while active

## Landing Screen UI

`LandingScreen` (`src/scenes/ui/landing_screen.gd` + `.tscn`) — CanvasLayer above HUD.

Content:
- Type badge (color-coded: green=PLANET, blue=STATION, orange=ASTEROID, gray=DERELICT)
- POI name (large)
- Description (1–2 lines)
- "Refueled" flash label — triggers `ship.fuel = ship.data.max_fuel`
- "Depart" button — hides screen, restores ShipInput

Triggered by: player pressing Q (or tap) when HUD landing prompt is visible. On first show: sets `GameState.has_landed_once = true`.

## World Wiring

`world.tscn`:
- Adds `POIs` Node2D parent with 4 `PointOfInterest` children (planet z≈500, station z≈800, asteroid z≈2000, derelict z≈3500)
- Removes old `$Planet`

`world.gd`:
- Collects POIs via `$POIs.get_children()`
- Connects all POI signals on `_ready`, passes array + ship to `BeaconSystem`
- Loops POIs in `_process` for proximity checks

## Testing

| Test file | What it covers |
|---|---|
| `test_poi_data.gd` | POIData fields per type |
| `test_point_of_interest.gd` | Proximity signals at correct z_depth thresholds |
| `test_game_state.gd` | No fuel burn before first landing; normal burn after |
| `test_beacon_system.gd` | Nearest POI calculation; beacon activates at fuel=0 |

## Out of scope (future)
- Trade menus, mission boards, crafting
- Dynamic POI spawning
- Per-type landing screen content beyond badge/description
- Networking / persistent universe state
