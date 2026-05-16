# Design Spec: Depth-aware HUD POI Clues + Landing Procedure

**Date:** 2026-05-16  
**Status:** Approved  
**Scope:** Two features — HUD depth clues for POIs, and a 4-phase Star Citizen-inspired landing mini-game.

---

## 1. Depth-aware HUD POI Clues

### 1.1 Depth Radar Strip

A thin vertical `Control` node on the left edge of the HUD, drawn via `_draw()`.

- The strip maps the full depth range `[DepthSystem.MIN_Z_DEPTH, DepthSystem.MAX_Z_DEPTH]` to its pixel height.
- **Ship cursor (●):** cyan, moves vertically as `ship.z_depth` changes.
- **POI ticks (◆):** one per POI, colour-coded by `POIData.POIType` (same palette as `MiniMap`). Tick height proportional to `landing_threshold` band (i.e. the safe depth window is visible as a band, not just a point).
- When a POI is within 500 depth units of the ship: the tick glows (alpha pulses) and a small label shows the POI name.
- No failure states; purely informational.

**New file:** `src/scenes/ui/depth_radar_strip.gd` + node added to `hud.tscn`.  
**HUD wiring:** `DepthRadarStrip` receives the same `_ship` and `_pois` references via a `connect_to_world()` call, identical to `MiniMap`.

### 1.2 Mini-map Depth Encoding

Modify `MiniMap._draw()` to compute `depth_dist = abs(ship.z_depth - poi.z_depth)` per POI:

- **Dot radius:** `lerp(6.0, 2.0, clampf(depth_dist / 2000.0, 0.0, 1.0))`
- **Dot alpha:** `lerp(1.0, 0.3, clampf(depth_dist / 2000.0, 0.0, 1.0))`
- Ship dot is unchanged (always full size and opacity).

**Changed file:** `src/scenes/ui/mini_map.gd` — approximately 4 lines of change inside `_draw()`.

---

## 2. Landing Procedure

### 2.1 Design Parameters

| Parameter | Value |
|-----------|-------|
| Target duration | 1–5 minutes total |
| Failure consequence | Hull damage per phase; hull = 0 → ship destroyed |
| Retry granularity | Per phase (checkpoint = phase start, not sequence start) |
| Controls | Touch buttons for macro movement; gyro (mobile) / mouse delta (desktop) for Phase 4 tilt only |
| Phase count | 4 (fallback to 3 if Phase 2 proves too complex) |

### 2.2 `LandingContext` (RefCounted)

```
src/resources/landing_context.gd
```

Fields:
- `poi: PointOfInterest`
- `ship: Ship`
- `assigned_pad: int` — 1-based, randomly picked from available pads
- `checkpoint_phase: int` — phase to re-enter on retry (set at phase start)
- `approach_rng_seed: int` — set once by `LandingOrchestrator` via `randi()` at `begin_landing()`; Phase 2 uses this to seed its hazard RNG so hazards are fresh per landing attempt but identical across retries within the same attempt
- `hull_at_sequence_start: float` — for statistics / future use

### 2.3 `LandingOrchestrator` (Node)

```
src/scenes/landing/landing_orchestrator.gd
```

Added as a child of `World`. Always present, idle until activated.

**API:**
```gdscript
func begin_landing(poi: PointOfInterest, ship: Ship) -> void
signal landing_succeeded
signal ship_destroyed
```

**Responsibilities:**
- Builds `LandingContext`, picks a random pad number.
- Loads each phase scene, calls `phase.begin(ctx)`, awaits `phase_completed` or `phase_failed(damage)`.
- On `phase_failed(damage)`: applies `damage` to `ship.hull`, emits `hull_changed`. If hull ≤ 0, emits `ship_destroyed` and stops. Otherwise re-enters the same phase by calling `begin(ctx)` again.
- On Phase 4 `phase_completed`: calls existing `LandingScreen.show_for(poi, ship)`.
- Suspends `ShipInput` for the duration of the sequence (same pattern as current `LandingScreen`).

**Phase scene contract (every phase must implement):**
```gdscript
func begin(ctx: LandingContext) -> void
signal phase_completed
signal phase_failed(damage: float)
```

**World change:** `_on_land_requested()` calls `orchestrator.begin_landing(_poi_in_range, ship)` instead of `landing_screen.show_for(...)`.

### 2.4 Pad Layout per POI Type

Defined as a `Dictionary` in `LandingOrchestrator` (or a shared const):

| POI Type | Pad count | Layout |
|----------|-----------|--------|
| PLANET | 4 | 2×2 grid |
| STATION | 6 | 2×3 grid |
| ASTEROID | 2 | 1×2 |
| DERELICT | 1 | single |

---

## 3. Phase 1 — ATC Request & Slot Assignment

**File:** `src/scenes/landing/phase_atc.tscn` + `phase_atc.gd`  
**Duration:** 10–20 seconds  
**Failure states:** None — pure narrative setup.

### Layout

A `CanvasLayer` panel containing:
- `RichTextLabel` for ATC comms (typewriter effect via `Tween`, ~0.4 s/line, coloured with `[color]` tags)
- Pad schematic (`Node2D` drawn via `_draw()` — top-down grid of squares, assigned pad pulsing gold via `modulate` tween loop)
- "ACKNOWLEDGED" `Button` — visible only after all ATC lines have typed in

### Behaviour

1. `begin(ctx)` starts the typewriter tween.
2. Lines: "Clearance request received…" / "Checking pad availability…" / "PAD {n} ASSIGNED. Approach vector set." / "Reduce speed below 80 u/s on entry."
3. After last line: pad schematic fades in, assigned pad pulses.
4. Player presses ACKNOWLEDGED → `phase_completed`.

---

## 4. Phase 2 — Approach Corridor

**File:** `src/scenes/landing/phase_approach.tscn` + `phase_approach.gd`  
**Duration:** 30–90 seconds  
**Failure damage:** 20 hull (corridor boundary or obstacle hit)

### Layout

Full-screen `CanvasLayer`. Background reuses `space_background.tscn` (parallax).

- Ship: `Sprite2D` positioned at left-centre, auto-scrolls rightward (world moves left).
- Two `Line2D` corridor boundaries — funnel shape, narrowing as approach progresses.
- Distance markers: vertical tick `Line2D`s scrolling left.
- Progress bar at bottom.
- HUD overlay: speed readout, distance to structure.

### Behaviour

- Ship X position is fixed; only Y is player-controlled (up/down touch buttons).
- World scroll speed is constant — player cannot slow or stop forward progress.
- Corridor boundaries narrow from 300px gap at start to 120px at end.
- **Hazards** (2–4, spawned from a seeded RNG using `ctx.approach_rng_seed` — fresh per landing attempt, consistent across retries):
  - Wind shear zone (coloured horizontal band, 80px tall): pushes ship ±60px/s while inside.
  - Debris/traffic: a static `Rect2` obstacle — must fly above or below.
- Collision detection: AABB overlap check each frame between ship `Rect2` and boundary/obstacle rects.
- On boundary/obstacle hit: `phase_failed(20.0)`.
- Ship reaches right edge (structure entrance): `phase_completed`.

### Ship representation

Simple `Sprite2D` + `Vector2 velocity` driven by script. No `RigidBody2D` or physics engine. Drag applied each frame: `velocity.y = lerp(velocity.y, 0.0, 0.1)`.

---

## 5. Phase 3 — Bay Entry

**File:** `src/scenes/landing/phase_bay_entry.tscn` + `phase_bay_entry.gd`  
**Duration:** 20–45 seconds  
**Failure damage:** 25 hull (wall), 15 hull (overspeed on pad arrival), 5 hull (wrong pad)

### Layout

Full-screen `CanvasLayer`. Top-down view of the bay interior.

- Bay walls drawn via `_draw()` as thick `Rect2` outlines.
- Pad zones: `Rect2` grid, assigned pad coloured gold and pulsing.
- Ship: top-down `Sprite2D`, rotates to face movement direction.
- Speed bar: prominent `ProgressBar` with a red zone above the limit (80 u/s). Flashes when over limit.

### Behaviour

- Ship enters from the top edge.
- All 4 directional touch buttons active.
- Speed: `float velocity` per axis; thrust adds to velocity; drag decays it each frame.
- Speed limit enforced only at the moment of pad zone entry (not in transit).
- Wrong pad entry: `phase_failed(5.0)` + ATC line "Wrong pad, pilot" flashes on screen.
- Bay wall collision: `phase_failed(25.0)`.
- Correct pad entry at valid speed: `phase_completed`.

### Pad layout

`Dictionary[POIType, Array[Rect2]]` defined as a const in the scene script.

---

## 6. Phase 4 — Touchdown

**File:** `src/scenes/landing/phase_touchdown.tscn` + `phase_touchdown.gd`  
**Duration:** 20–40 seconds  
**Failure damage:** 30 hull (tilt crash), 20 hull (overspeed descent)

### Layout

Full-screen `CanvasLayer`. Camera zoomed in — only the assigned pad visible.

- Pad zone: gold `Rect2`, centred on screen.
- Ship shadow: `Sprite2D` positioned within the pad, drifts due to crosswind.
- **Roll indicator:** horizontal track + bubble `Control` (drawn via `_draw()`). Track has a green centre zone (±20% of width). Bubble X driven by `roll_tilt` float.
- **Pitch indicator:** same, vertical orientation, driven by `pitch_tilt`.
- **Descent bar:** `ProgressBar` counting down. Green zone marks the safe cut-thrust window.
- "CUT THRUST" button — single large touch target.

### Three simultaneous demands

**1. Horizontal alignment (touch buttons)**
- Ship shadow drifts from crosswind: `crosswind = sin(Time.get_ticks_msec() * 0.001) * wind_strength`
- Wind strength seeded from `ctx.assigned_pad` — same drift pattern on every retry.
- Player nudges ship shadow back toward pad centre with directional buttons.

**2. Tilt alignment (gyro / mouse delta)**
- Mobile: `Input.get_accelerometer()` remapped to `roll_tilt` and `pitch_tilt` in `[-1.0, 1.0]`.
- Desktop: mouse X/Y delta per frame, clamped to `[-200, 200]` pixels and divided by 200 to produce the same `[-1.0, 1.0]` range.
- Both values smoothed each frame: `roll_tilt = lerp(roll_tilt, raw_roll, 0.15)`.
- Both bubbles must be within `±0.2` (green zone) at touchdown moment.

**3. Descent timing (CUT THRUST button)**
- Descent bar counts down automatically.
- Green window = last 25% of bar.
- Player must press CUT THRUST while bar is in the green zone.
- Too early: ship hovers, bar resets (can retry cut, no damage).
- Too late (bar hits 0): `phase_failed(20.0)`.

### Success condition

All 3 checks must pass simultaneously for 2 continuous seconds:
- Ship shadow inside pad `Rect2`
- `abs(roll_tilt) <= 0.2` and `abs(pitch_tilt) <= 0.2`
- Thrust cut in green window

After 2-second hold: success animation (`Tween` — ship settles, scale tiny bounce), "PAD {n} LOCKED" flashes green, fade to `LandingScreen`.

### Failure feel

Screen flashes red, ship `Sprite2D` shakes (small offset tween), hull damage applied. Re-enter Phase 4 — same pad, same wind seed. No restart from Phase 1.

---

## 7. New Files Summary

```
src/
  resources/
    landing_context.gd              (new)
  scenes/
    ui/
      depth_radar_strip.gd          (new)
    landing/
      landing_orchestrator.gd       (new)
      phase_atc.tscn                (new)
      phase_atc.gd                  (new)
      phase_approach.tscn           (new)
      phase_approach.gd             (new)
      phase_bay_entry.tscn          (new)
      phase_bay_entry.gd            (new)
      phase_touchdown.tscn          (new)
      phase_touchdown.gd            (new)

Changed:
  src/scenes/ui/mini_map.gd         (~4 lines in _draw())
  src/scenes/ui/hud.tscn            (add DepthRadarStrip node)
  src/scenes/ui/hud.gd              (wire DepthRadarStrip)
  src/scenes/world/world.gd         (_on_land_requested routes to orchestrator)
  src/scenes/world/world.tscn       (add LandingOrchestrator node)
```

---

## 8. Out of Scope (this spec)

- Ship destruction / game-over screen (hull = 0 mid-landing emits `ship_destroyed`; handling TBD)
- ATC voice audio
- Animated sprites for ship or hazards (placeholder `Sprite2D` + `ColorRect` shapes for MVP)
- Multiplayer / concurrent pad conflicts
