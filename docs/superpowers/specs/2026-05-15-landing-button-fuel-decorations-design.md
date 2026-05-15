# Design: Landing Button, Fuel Simplification & Space Decorations

**Date:** 2026-05-15
**Status:** Approved

## Scope

Three independent gameplay and visual improvements:
1. Replace auto-land on proximity with a manual LAND button (beacon arrival still auto-lands)
2. Remove the "infinite fuel before first landing" mechanic — fuel always depletes
3. Add procedural stars and nebula patches to the space background

---

## Feature 1 — Manual Landing Button

### Problem

`world.gd` currently calls `landing_screen.show_for(poi, ship)` immediately when the ship enters a POI's landing zone. There is no player agency — proximity equals landing.

### Design

When the ship enters a landing zone:
- If **beacon is active** (auto-navigation rescue mode): auto-land immediately, same as current behavior.
- Otherwise: show a **LAND button** in the HUD at bottom-center. The player must press it to land.

When the ship exits the landing zone: hide the button without landing.

### Changes

**`src/scenes/ui/hud.tscn`**
- Remove `LandingLabel` node.
- Add `Button` node named `LandButton`, anchored bottom-center (same position as the old label). Text: `"▼ LAND"`. Hidden by default.

**`src/scenes/ui/hud.gd`**
- `@onready var land_button: Button = $LandButton`
- Add `signal land_requested`
- Connect `land_button.pressed` → emit `land_requested`
- Replace `show_landing_prompt(show: bool)` with `show_land_button(show: bool)` — sets `land_button.visible`

**`src/scenes/world/world.gd`**
- Add `var _poi_in_range: PointOfInterest = null`
- `_on_landing_zone_entered(poi)`:
  - Store `_poi_in_range = poi`
  - If `BeaconSystem.active`: call `landing_screen.show_for(poi, ship)` directly
  - Else: call `hud.show_land_button(true)`
- `_on_landing_zone_exited(_poi)`:
  - Clear `_poi_in_range = null`
  - Call `hud.show_land_button(false)`
- In `_ready()`: connect `hud.land_requested` to a new handler `_on_land_requested`
- `_on_land_requested()`: guard `if _poi_in_range == null: return`; call `landing_screen.show_for(_poi_in_range, ship)`, then `hud.show_land_button(false)`

**`src/systems/beacon_system.gd`**
- Rename `_active` → `active` (public property) so `world.gd` can read it.
- Update all internal references from `_active` to `active`.

---

## Feature 2 — Always-Deplete Fuel

### Problem

`ship.gd` and `beacon_system.gd` gate fuel burn and beacon activation behind `GameState.has_landed_once`. Before first landing, fuel is infinite — an implicit tutorial crutch that complicates the state machine and feels inconsistent.

### Design

Remove the `has_landed_once` guards from fuel mechanics. Fuel depletes from the very first thrust. If it hits zero, the beacon activates regardless of play history. `GameState.has_landed_once` is preserved — it is still set by `LandingScreen` and may be used by future tutorial/UI logic.

### Changes

**`src/scenes/ship/ship.gd`** — `_handle_thrust`:
```
Before:
  if GameState.has_landed_once and fuel <= 0.0:
      return
  apply_central_force(...)
  if GameState.has_landed_once:
      fuel = maxf(0.0, fuel - data.fuel_burn_rate * delta)
      fuel_changed.emit(fuel)

After:
  if fuel <= 0.0:
      return
  apply_central_force(...)
  fuel = maxf(0.0, fuel - data.fuel_burn_rate * delta)
  fuel_changed.emit(fuel)
```

**`src/systems/beacon_system.gd`** — `_on_fuel_changed`:
```
Before:
  if value <= 0.0 and GameState.has_landed_once and not active:

After:
  if value <= 0.0 and not active:
```

---

## Feature 3 — Space Decorations

### Problem

The space background consists of 6 solid `ColorRect` parallax layers. It is visually empty — no stars, no depth, no sense of being in space.

### Design

Add procedural stars across 3 parallax layers using a new `StarField` node, and two nebula patches as large semi-transparent `ColorRect`s. The existing dark background layers remain — they provide the black void.

Star count and size increase with parallax scale (closer layers = fewer, larger stars). Nebula patches use very low alpha (5–7%) so they are felt rather than seen.

### New File: `src/scenes/world/star_field.gd`

```
class_name StarField
extends Node2D

@export var star_count: int = 100
@export var area: Vector2 = Vector2(2560, 1440)
@export var base_color: Color = Color(1, 1, 1, 1)
@export var min_size: float = 0.5
@export var max_size: float = 1.5
@export var seed_val: int = 0
```

- `_ready()`: use seeded `RandomNumberGenerator` to generate `star_count` entries, each with a random position within `area`, a random size in `[min_size, max_size]`, and a random brightness in `[0.4, 1.0]`.
- `_draw()`: draw each star as a filled circle, modulating `base_color.a` by per-star brightness.

### Changes to `src/scenes/world/space_background.tscn`

| Layer | Parallax | Addition | Config |
|-------|----------|----------|--------|
| Layer1 | 0.05 | `StarField` | 80 stars, size 0.5–1.0, white, seed 1 |
| Layer2 | 0.12 | `ColorRect` (nebula) | 800×400, `Color(0.05, 0.08, 0.25, 0.07)`, position (300, 200) |
| Layer3 | 0.25 | `StarField` | 150 stars, size 0.5–1.5, warm white `Color(1, 0.97, 0.9)`, seed 2 |
| Layer3 | 0.25 | `ColorRect` (nebula) | 600×500, `Color(0.12, 0.04, 0.18, 0.06)`, position (1400, 600) |
| Layer5 | 0.90 | `StarField` | 40 stars, size 1.0–2.0, blue-white `Color(0.85, 0.9, 1)`, seed 3 |

Existing `ColorRect` base layers (Bg0–Bg5) are untouched.

---

## Files Changed Summary

| File | Change type |
|------|------------|
| `src/scenes/ui/hud.tscn` | Modify: replace LandingLabel with LandButton |
| `src/scenes/ui/hud.gd` | Modify: land_requested signal, show_land_button |
| `src/scenes/world/world.gd` | Modify: _poi_in_range, beacon branch, land_requested handler |
| `src/systems/beacon_system.gd` | Modify: _active → active |
| `src/scenes/ship/ship.gd` | Modify: remove has_landed_once fuel guards |
| `src/scenes/world/star_field.gd` | New: procedural star field node |
| `src/scenes/world/space_background.tscn` | Modify: add StarField + nebula ColorRect nodes |

## Out of Scope

- Nav label "LAND" hint stays as-is (useful feedback that you're in range)
- No changes to `LandingScreen`, `POIData`, `DepthSystem`, or `TouchControls`
- No shader-based nebulae or external textures
