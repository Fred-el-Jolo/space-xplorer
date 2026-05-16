# HUD POI Clues + Landing Procedure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add depth-aware HUD indicators for POIs and replace the instant-land screen with a 4-phase Star Citizen-inspired landing mini-game (ATC → Approach Corridor → Bay Entry → Touchdown).

**Architecture:** A `LandingOrchestrator` node in World runs phases sequentially via `await` on a unified `_phase_done` signal; each phase is a `CanvasLayer` script that builds its UI programmatically and emits `phase_completed` or `phase_failed(damage)`. The HUD gets a new `DepthRadarStrip` Control drawn via `_draw()` alongside enhanced mini-map depth encoding.

**Tech Stack:** Godot 4.3 LTS, GDScript (typed), GUT 9.3.1 for tests, GL Compatibility renderer.

**Test command:**
```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

**Spec:** `docs/superpowers/specs/2026-05-16-hud-poi-clues-and-landing-procedure-design.md`

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `src/resources/landing_context.gd` | **Create** | Data passed between orchestrator and phases |
| `src/scenes/ui/depth_radar_strip.gd` | **Create** | Vertical depth strip drawn on HUD left edge |
| `src/scenes/ui/hud.tscn` | **Modify** | Add DepthRadarStrip node |
| `src/scenes/ui/hud.gd` | **Modify** | Wire DepthRadarStrip via connect_to_world |
| `src/scenes/ui/mini_map.gd` | **Modify** | Depth-encode POI dots (size + alpha) |
| `src/scenes/landing/landing_orchestrator.gd` | **Create** | Phase state machine, hull damage, ShipInput gating |
| `src/scenes/landing/phase_atc.gd` | **Create** | Phase 1: ATC comms typewriter + pad schematic |
| `src/scenes/landing/phase_approach.gd` | **Create** | Phase 2: Side-scroll approach corridor |
| `src/scenes/landing/phase_bay_entry.gd` | **Create** | Phase 3: Top-down bay navigation |
| `src/scenes/landing/phase_touchdown.gd` | **Create** | Phase 4: Tilt + alignment precision landing |
| `src/scenes/world/world.gd` | **Modify** | Route land_requested → orchestrator |
| `src/scenes/world/world.tscn` | **Modify** | Add LandingOrchestrator node |
| `tests/unit/test_landing_context.gd` | **Create** | Unit tests for LandingContext |
| `tests/unit/test_mini_map_depth.gd` | **Create** | Unit tests for depth encoding math |
| `tests/unit/test_depth_radar_strip.gd` | **Create** | Unit tests for strip depth-to-y mapping |
| `tests/unit/test_landing_orchestrator.gd` | **Create** | Unit tests for pad selection + hull damage |
| `tests/unit/test_phase_approach.gd` | **Create** | Unit tests for corridor + hazard logic |
| `tests/unit/test_phase_bay_entry.gd` | **Create** | Unit tests for speed limit + pad collision |
| `tests/unit/test_phase_touchdown.gd` | **Create** | Unit tests for tilt + descent window logic |

All phase scripts build their own child nodes programmatically — no complex `.tscn` files needed for phases.

---

## Task 1: LandingContext

**Files:**
- Create: `src/resources/landing_context.gd`
- Create: `tests/unit/test_landing_context.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_landing_context.gd
extends GutTest

func test_default_checkpoint_phase_is_one() -> void:
    var ctx := LandingContext.new()
    assert_eq(ctx.checkpoint_phase, 1)

func test_assigned_pad_settable() -> void:
    var ctx := LandingContext.new()
    ctx.assigned_pad = 3
    assert_eq(ctx.assigned_pad, 3)

func test_approach_rng_seed_settable() -> void:
    var ctx := LandingContext.new()
    ctx.approach_rng_seed = 42
    assert_eq(ctx.approach_rng_seed, 42)

func test_hull_at_sequence_start_settable() -> void:
    var ctx := LandingContext.new()
    ctx.hull_at_sequence_start = 75.0
    assert_almost_eq(ctx.hull_at_sequence_start, 75.0, 0.001)
```

- [ ] **Step 2: Run tests — expect FAIL (class not found)**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 3: Create LandingContext**

```gdscript
# src/resources/landing_context.gd
class_name LandingContext
extends RefCounted

var poi: PointOfInterest = null
var ship: Ship = null
var assigned_pad: int = 0
var checkpoint_phase: int = 1
var approach_rng_seed: int = 0
var hull_at_sequence_start: float = 0.0
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/resources/landing_context.gd tests/unit/test_landing_context.gd
git commit -m "feat: add LandingContext resource for landing phase state"
```

---

## Task 2: MiniMap depth encoding

**Files:**
- Modify: `src/scenes/ui/mini_map.gd`
- Create: `tests/unit/test_mini_map_depth.gd`

- [ ] **Step 1: Write failing tests for the depth encoding math**

The math will be extracted into a static helper so it's testable without the full scene.

```gdscript
# tests/unit/test_mini_map_depth.gd
extends GutTest

func test_radius_at_zero_depth_dist_is_max() -> void:
    var r := MiniMap.depth_dot_radius(0.0)
    assert_almost_eq(r, 6.0, 0.01)

func test_radius_at_2000_depth_dist_is_min() -> void:
    var r := MiniMap.depth_dot_radius(2000.0)
    assert_almost_eq(r, 2.0, 0.01)

func test_radius_at_1000_depth_dist_is_midpoint() -> void:
    var r := MiniMap.depth_dot_radius(1000.0)
    assert_almost_eq(r, 4.0, 0.01)

func test_alpha_at_zero_depth_dist_is_one() -> void:
    var a := MiniMap.depth_dot_alpha(0.0)
    assert_almost_eq(a, 1.0, 0.01)

func test_alpha_at_2000_depth_dist_is_min() -> void:
    var a := MiniMap.depth_dot_alpha(2000.0)
    assert_almost_eq(a, 0.3, 0.01)

func test_radius_clamped_beyond_2000() -> void:
    var r := MiniMap.depth_dot_radius(5000.0)
    assert_almost_eq(r, 2.0, 0.01)
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Add static helpers and update `_draw()` in MiniMap**

Open `src/scenes/ui/mini_map.gd`. Add two static functions before `_draw()`:

```gdscript
static func depth_dot_radius(depth_dist: float) -> float:
    return lerpf(6.0, 2.0, clampf(depth_dist / 2000.0, 0.0, 1.0))

static func depth_dot_alpha(depth_dist: float) -> float:
    return lerpf(1.0, 0.3, clampf(depth_dist / 2000.0, 0.0, 1.0))
```

Replace the existing POI draw loop inside `_draw()`:

```gdscript
for poi: PointOfInterest in _pois:
    if poi.data == null:
        continue
    var mp := _world_to_map(poi.position)
    var depth_dist := absf(_ship.z_depth - poi.z_depth) if _ship else 0.0
    var col := _poi_color(poi.data.type)
    col.a = depth_dot_alpha(depth_dist)
    draw_circle(mp, depth_dot_radius(depth_dist), col)
    draw_string(font, mp + Vector2(4.0, 3.0), poi.data.poi_name,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col)
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/scenes/ui/mini_map.gd tests/unit/test_mini_map_depth.gd
git commit -m "feat: depth-encode minimap POI dots by size and opacity"
```

---

## Task 3: DepthRadarStrip

**Files:**
- Create: `src/scenes/ui/depth_radar_strip.gd`
- Create: `tests/unit/test_depth_radar_strip.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_depth_radar_strip.gd
extends GutTest

var strip: DepthRadarStrip

func before_each() -> void:
    strip = DepthRadarStrip.new()
    strip.custom_minimum_size = Vector2(14.0, 400.0)
    strip.size = Vector2(14.0, 400.0)
    add_child(strip)

func after_each() -> void:
    strip.queue_free()

func test_depth_to_y_min_depth_maps_to_zero() -> void:
    var y := strip.depth_to_y(DepthSystem.MIN_Z_DEPTH)
    assert_almost_eq(y, 0.0, 0.5)

func test_depth_to_y_max_depth_maps_to_height() -> void:
    var y := strip.depth_to_y(DepthSystem.MAX_Z_DEPTH)
    assert_almost_eq(y, 400.0, 0.5)

func test_depth_to_y_midpoint() -> void:
    var mid_depth := (DepthSystem.MIN_Z_DEPTH + DepthSystem.MAX_Z_DEPTH) / 2.0
    var y := strip.depth_to_y(mid_depth)
    assert_almost_eq(y, 200.0, 1.0)

func test_is_near_threshold_within_500() -> void:
    assert_true(DepthRadarStrip.is_near_depth(100.0, 400.0))

func test_is_near_threshold_beyond_500() -> void:
    assert_false(DepthRadarStrip.is_near_depth(100.0, 700.0))
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Create DepthRadarStrip**

```gdscript
# src/scenes/ui/depth_radar_strip.gd
class_name DepthRadarStrip
extends Control

const STRIP_WIDTH: float = 14.0
const GLOW_THRESHOLD: float = 500.0
const DEPTH_RANGE: float = DepthSystem.MAX_Z_DEPTH - DepthSystem.MIN_Z_DEPTH

var _ship: Ship = null
var _pois: Array[PointOfInterest] = []

func connect_to_world(ship: Ship, pois: Array[PointOfInterest]) -> void:
    _ship = ship
    _pois = pois

func depth_to_y(depth: float) -> float:
    return ((depth - DepthSystem.MIN_Z_DEPTH) / DEPTH_RANGE) * size.y

static func is_near_depth(ship_depth: float, poi_depth: float) -> bool:
    return absf(ship_depth - poi_depth) <= GLOW_THRESHOLD

func _process(_delta: float) -> void:
    if _ship:
        queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(0.0, 0.0, STRIP_WIDTH, size.y), Color(0.04, 0.07, 0.18, 0.82))
    draw_rect(Rect2(0.0, 0.0, STRIP_WIDTH, size.y), Color(0.3, 0.5, 0.9, 0.5), false, 1.0)
    if _ship == null:
        return
    var font := ThemeDB.fallback_font
    for poi: PointOfInterest in _pois:
        if poi.data == null:
            continue
        var col := _poi_color(poi.data.type)
        var y := depth_to_y(poi.z_depth)
        var band_px := (poi.data.landing_threshold / DEPTH_RANGE) * size.y
        var near := is_near_depth(_ship.z_depth, poi.z_depth)
        col.a = 1.0 if near else 0.5
        draw_rect(Rect2(1.0, y - band_px * 0.5, STRIP_WIDTH - 2.0, maxf(band_px, 3.0)), col)
        if near:
            draw_string(font, Vector2(STRIP_WIDTH + 2.0, y + 4.0), poi.data.poi_name,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
    var ship_y := depth_to_y(_ship.z_depth)
    draw_circle(Vector2(STRIP_WIDTH * 0.5, ship_y), 4.0, Color(0.1, 1.0, 0.8, 1.0))

func _poi_color(type: POIData.POIType) -> Color:
    match type:
        POIData.POIType.PLANET:   return Color(0.3, 0.9, 0.4)
        POIData.POIType.STATION:  return Color(0.3, 0.6, 1.0)
        POIData.POIType.ASTEROID: return Color(1.0, 0.6, 0.2)
        POIData.POIType.DERELICT: return Color(0.7, 0.7, 0.7)
    return Color.WHITE
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/scenes/ui/depth_radar_strip.gd tests/unit/test_depth_radar_strip.gd
git commit -m "feat: add DepthRadarStrip HUD element showing POI depth positions"
```

---

## Task 4: Wire DepthRadarStrip into HUD

**Files:**
- Modify: `src/scenes/ui/hud.tscn`
- Modify: `src/scenes/ui/hud.gd`

- [ ] **Step 1: Open `src/scenes/ui/hud.tscn` and add the DepthRadarStrip node**

Add at the end of the file, as a direct child of the root CanvasLayer:

```
[ext_resource type="Script" path="res://src/scenes/ui/depth_radar_strip.gd" id="3"]
```

Then add before the closing `[node ... MiniMap]` entry (or at the end):

```
[node name="DepthRadarStrip" type="Control" parent="."]
script = ExtResource("3")
anchors_preset = 0
offset_left = 0.0
offset_top = 80.0
offset_right = 14.0
offset_bottom = 480.0
custom_minimum_size = Vector2(14, 400)
```

Increment `load_steps` by 1 at the top of the file.

- [ ] **Step 2: Add `@onready` and wire in `hud.gd`**

In `src/scenes/ui/hud.gd`, add the onready:

```gdscript
@onready var depth_radar_strip: DepthRadarStrip = $DepthRadarStrip
```

In `connect_to_world()`, add one line after the `mini_map.connect_to_world(...)` call:

```gdscript
depth_radar_strip.connect_to_world(ship, pois)
```

- [ ] **Step 3: Run tests — expect all PASS (existing HUD tests must not regress)**

- [ ] **Step 4: Launch game and verify visually**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --path . 2>&1 | head -20
```

Check: thin vertical strip on HUD left edge moves as you press Q/E (depth change). POI ticks visible on strip.

- [ ] **Step 5: Commit**

```bash
git add src/scenes/ui/hud.tscn src/scenes/ui/hud.gd
git commit -m "feat: wire DepthRadarStrip into HUD"
```

---

## Task 5: LandingOrchestrator

**Files:**
- Create: `src/scenes/landing/landing_orchestrator.gd`
- Create: `tests/unit/test_landing_orchestrator.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_landing_orchestrator.gd
extends GutTest

var orch: LandingOrchestrator
var ship: Ship
var ship_data: ShipData

func before_each() -> void:
    orch = LandingOrchestrator.new()
    add_child(orch)
    ship_data = ShipData.new()
    ship_data.max_hull = 100.0
    ship_data.max_fuel = 100.0
    ship_data.thrust_power = 500.0
    ship_data.depth_speed = 50.0
    ship_data.fuel_burn_rate = 10.0
    ship_data.linear_damp_value = 1.5
    ship = preload("res://src/scenes/ship/ship.tscn").instantiate()
    ship.data = ship_data
    add_child(ship)

func after_each() -> void:
    orch.queue_free()
    ship.queue_free()

func test_pick_pad_planet_in_range() -> void:
    var pad := orch.pick_pad(POIData.POIType.PLANET)
    assert_gte(pad, 1)
    assert_lte(pad, 4)

func test_pick_pad_station_in_range() -> void:
    var pad := orch.pick_pad(POIData.POIType.STATION)
    assert_gte(pad, 1)
    assert_lte(pad, 6)

func test_pick_pad_derelict_is_one() -> void:
    var pad := orch.pick_pad(POIData.POIType.DERELICT)
    assert_eq(pad, 1)

func test_apply_damage_reduces_hull() -> void:
    ship.hull = 80.0
    orch.apply_damage(ship, 20.0)
    assert_almost_eq(ship.hull, 60.0, 0.01)

func test_apply_damage_clamps_at_zero() -> void:
    ship.hull = 10.0
    orch.apply_damage(ship, 50.0)
    assert_almost_eq(ship.hull, 0.0, 0.01)

func test_is_ship_destroyed_true_when_hull_zero() -> void:
    ship.hull = 0.0
    assert_true(LandingOrchestrator.is_ship_destroyed(ship))

func test_is_ship_destroyed_false_when_hull_positive() -> void:
    ship.hull = 1.0
    assert_false(LandingOrchestrator.is_ship_destroyed(ship))
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Create LandingOrchestrator**

First create the landing directory:

```bash
mkdir -p /home/ubuntu/Projects/space-xplorer/src/scenes/landing
```

```gdscript
# src/scenes/landing/landing_orchestrator.gd
class_name LandingOrchestrator
extends Node

signal landing_succeeded
signal ship_destroyed

const PAD_COUNTS: Dictionary = {
    POIData.POIType.PLANET: 4,
    POIData.POIType.STATION: 6,
    POIData.POIType.ASTEROID: 2,
    POIData.POIType.DERELICT: 1,
}

signal _phase_done(result: Dictionary)

var _ctx: LandingContext = null
var _landing_screen: LandingScreen = null

func init(landing_screen: LandingScreen) -> void:
    _landing_screen = landing_screen

func begin_landing(poi: PointOfInterest, ship: Ship) -> void:
    _ctx = LandingContext.new()
    _ctx.poi = poi
    _ctx.ship = ship
    _ctx.assigned_pad = pick_pad(poi.data.type)
    _ctx.approach_rng_seed = randi()
    _ctx.checkpoint_phase = 1
    _ctx.hull_at_sequence_start = ship.hull
    ShipInput.suspended = true
    _run_from_phase(1)

func pick_pad(type: POIData.POIType) -> int:
    return randi_range(1, PAD_COUNTS.get(type, 1))

static func is_ship_destroyed(ship: Ship) -> bool:
    return ship.hull <= 0.0

func apply_damage(ship: Ship, damage: float) -> void:
    ship.hull = maxf(0.0, ship.hull - damage)
    ship.hull_changed.emit(ship.hull)

func _run_from_phase(phase_num: int) -> void:
    _ctx.checkpoint_phase = phase_num
    var phase := _instantiate_phase(phase_num)
    add_child(phase)
    phase.phase_completed.connect(func(): _phase_done.emit({"ok": true, "damage": 0.0}), CONNECT_ONE_SHOT)
    phase.phase_failed.connect(func(dmg: float): _phase_done.emit({"ok": false, "damage": dmg}), CONNECT_ONE_SHOT)
    phase.begin(_ctx)
    var result: Dictionary = await _phase_done
    phase.queue_free()
    if result.ok:
        if phase_num == 4:
            _finish()
        else:
            _run_from_phase(phase_num + 1)
    else:
        apply_damage(_ctx.ship, result.damage)
        if is_ship_destroyed(_ctx.ship):
            ShipInput.suspended = false
            ship_destroyed.emit()
        else:
            _run_from_phase(phase_num)

func _instantiate_phase(phase_num: int) -> Node:
    match phase_num:
        1: return PhaseATC.new()
        2: return PhaseApproach.new()
        3: return PhaseBayEntry.new()
        4: return PhaseTouchdown.new()
    push_error("LandingOrchestrator: unknown phase %d" % phase_num)
    return Node.new()

func _finish() -> void:
    ShipInput.suspended = false
    _landing_screen.show_for(_ctx.poi, _ctx.ship)
    landing_succeeded.emit()
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/scenes/landing/landing_orchestrator.gd tests/unit/test_landing_orchestrator.gd
git commit -m "feat: add LandingOrchestrator phase state machine"
```

---

## Task 6: Phase 1 — ATC

**Files:**
- Create: `src/scenes/landing/phase_atc.gd`

No unit tests for this phase — it is pure UI/narrative with no branching logic to test. Verified by play-test in Task 10.

- [ ] **Step 1: Create PhaseATC**

```gdscript
# src/scenes/landing/phase_atc.gd
class_name PhaseATC
extends CanvasLayer

signal phase_completed
signal phase_failed(damage: float)

const ATC_LINES: Array[String] = [
    "Clearance request received...",
    "Checking pad availability...",
    "PAD %d ASSIGNED. Approach vector set.",
    "Reduce speed below 80 u/s on entry.",
]
const LINE_DELAY: float = 0.5

var _ctx: LandingContext = null
var _panel: PanelContainer
var _vbox: VBoxContainer
var _comms_label: RichTextLabel
var _schematic: Node2D
var _ack_button: Button

func begin(ctx: LandingContext) -> void:
    _ctx = ctx
    _build_ui()
    _start_typewriter()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.0, 0.0, 0.0, 0.75)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    _panel = PanelContainer.new()
    _panel.set_anchors_preset(Control.PRESET_CENTER)
    _panel.custom_minimum_size = Vector2(560.0, 420.0)
    add_child(_panel)

    _vbox = VBoxContainer.new()
    _vbox.add_theme_constant_override("separation", 16)
    _panel.add_child(_vbox)

    var title := Label.new()
    title.text = "ATC COMMS — %s" % _ctx.poi.data.poi_name.to_upper()
    title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
    _vbox.add_child(title)

    var sep := HSeparator.new()
    _vbox.add_child(sep)

    _comms_label = RichTextLabel.new()
    _comms_label.bbcode_enabled = true
    _comms_label.custom_minimum_size = Vector2(0.0, 120.0)
    _comms_label.fit_content = true
    _vbox.add_child(_comms_label)

    _schematic = _build_schematic()
    _schematic.visible = false
    _vbox.add_child(_schematic)

    _ack_button = Button.new()
    _ack_button.text = "ACKNOWLEDGED"
    _ack_button.visible = false
    _ack_button.pressed.connect(_on_acknowledged)
    _vbox.add_child(_ack_button)

func _build_schematic() -> Node2D:
    var container := Control.new()
    container.custom_minimum_size = Vector2(0.0, 160.0)
    # Pad layout drawn via _draw override on a subnode
    var draw_node := _PadSchematic.new()
    draw_node.assigned_pad = _ctx.assigned_pad
    draw_node.poi_type = _ctx.poi.data.type
    draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    container.add_child(draw_node)
    return container

func _start_typewriter() -> void:
    var tween := create_tween()
    tween.set_sequential(true)
    for i in ATC_LINES.size():
        var line: String = ATC_LINES[i]
        if line.contains("%d"):
            line = line % _ctx.assigned_pad
        tween.tween_callback(_append_line.bind(line))
        tween.tween_interval(LINE_DELAY)
    tween.tween_callback(_reveal_schematic)

func _append_line(line: String) -> void:
    _comms_label.append_text("[color=#88ccff]> %s[/color]\n" % line)

func _reveal_schematic() -> void:
    _schematic.visible = true
    _ack_button.visible = true

func _on_acknowledged() -> void:
    phase_completed.emit()


# Inner class for pad drawing — keeps PhaseATC self-contained
class _PadSchematic extends Control:
    var assigned_pad: int = 1
    var poi_type: POIData.POIType = POIData.POIType.PLANET

    const PAD_GRIDS: Dictionary = {
        POIData.POIType.PLANET:   Vector2i(2, 2),
        POIData.POIType.STATION:  Vector2i(3, 2),
        POIData.POIType.ASTEROID: Vector2i(2, 1),
        POIData.POIType.DERELICT: Vector2i(1, 1),
    }
    const PAD_SIZE := Vector2(60.0, 50.0)
    const PAD_GAP := Vector2(12.0, 10.0)

    var _pulse_t: float = 0.0

    func _process(delta: float) -> void:
        _pulse_t += delta * 3.0
        queue_redraw()

    func _draw() -> void:
        var grid: Vector2i = PAD_GRIDS.get(poi_type, Vector2i(1, 1))
        var total_w := grid.x * PAD_SIZE.x + (grid.x - 1) * PAD_GAP.x
        var total_h := grid.y * PAD_SIZE.y + (grid.y - 1) * PAD_GAP.y
        var origin := (size - Vector2(total_w, total_h)) * 0.5
        var pad_idx := 1
        for row in grid.y:
            for col in grid.x:
                var pos := origin + Vector2(col * (PAD_SIZE.x + PAD_GAP.x), row * (PAD_SIZE.y + PAD_GAP.y))
                var is_assigned := pad_idx == assigned_pad
                var pulse := (sin(_pulse_t) * 0.5 + 0.5) if is_assigned else 0.0
                var col_color := Color(1.0, 0.8 + pulse * 0.2, 0.0) if is_assigned else Color(0.4, 0.4, 0.4)
                draw_rect(Rect2(pos, PAD_SIZE), col_color, not is_assigned)
                if is_assigned:
                    draw_rect(Rect2(pos, PAD_SIZE), col_color.lightened(0.3), false, 2.0)
                var font := ThemeDB.fallback_font
                draw_string(font, pos + Vector2(4.0, 14.0), str(pad_idx),
                    HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
                pad_idx += 1
```

- [ ] **Step 2: Commit**

```bash
git add src/scenes/landing/phase_atc.gd
git commit -m "feat: add Phase 1 ATC comms with typewriter and pad schematic"
```

---

## Task 7: Phase 2 — Approach Corridor

**Files:**
- Create: `src/scenes/landing/phase_approach.gd`
- Create: `tests/unit/test_phase_approach.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_phase_approach.gd
extends GutTest

func test_corridor_boundary_at_start_is_300() -> void:
    var gap := PhaseApproach.corridor_gap(0.0)
    assert_almost_eq(gap, 300.0, 0.1)

func test_corridor_boundary_at_end_is_120() -> void:
    var gap := PhaseApproach.corridor_gap(1.0)
    assert_almost_eq(gap, 120.0, 0.1)

func test_corridor_boundary_midpoint() -> void:
    var gap := PhaseApproach.corridor_gap(0.5)
    assert_almost_eq(gap, 210.0, 0.5)

func test_ship_rect_from_position() -> void:
    var r := PhaseApproach.ship_rect(Vector2(100.0, 200.0))
    assert_almost_eq(r.position.x, 84.0, 0.1)
    assert_almost_eq(r.position.y, 184.0, 0.1)
    assert_almost_eq(r.size.x, 32.0, 0.1)
    assert_almost_eq(r.size.y, 32.0, 0.1)

func test_outside_corridor_above() -> void:
    # corridor centre_y=360, gap=300 → upper=210, lower=510
    assert_true(PhaseApproach.outside_corridor(200.0, 360.0, 300.0))

func test_inside_corridor() -> void:
    assert_false(PhaseApproach.outside_corridor(360.0, 360.0, 300.0))
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Create PhaseApproach**

```gdscript
# src/scenes/landing/phase_approach.gd
class_name PhaseApproach
extends CanvasLayer

signal phase_completed
signal phase_failed(damage: float)

const SCROLL_SPEED: float = 180.0
const THRUST_ACCEL: float = 260.0
const DRAG: float = 0.12
const APPROACH_LENGTH: float = 2400.0
const SHIP_SIZE: float = 32.0
const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const SHIP_X: float = 200.0
const CENTRE_Y: float = 360.0

var _ctx: LandingContext = null
var _progress: float = 0.0
var _ship_y: float = CENTRE_Y
var _ship_vy: float = 0.0
var _scroll_x: float = 0.0
var _rng := RandomNumberGenerator.new()
var _hazards: Array[Rect2] = []

var _bg: ColorRect
var _ship_rect_node: ColorRect
var _upper_line: Line2D
var _lower_line: Line2D
var _progress_bar: ProgressBar
var _speed_label: Label

static func corridor_gap(t: float) -> float:
    return lerpf(300.0, 120.0, t)

static func ship_rect(pos: Vector2) -> Rect2:
    return Rect2(pos - Vector2(SHIP_SIZE * 0.5, SHIP_SIZE * 0.5), Vector2(SHIP_SIZE, SHIP_SIZE))

static func outside_corridor(ship_y: float, centre_y: float, gap: float) -> bool:
    return ship_y < centre_y - gap * 0.5 or ship_y > centre_y + gap * 0.5

func begin(ctx: LandingContext) -> void:
    _ctx = ctx
    _rng.seed = ctx.approach_rng_seed
    _build_ui()
    _spawn_hazards()

func _build_ui() -> void:
    _bg = ColorRect.new()
    _bg.color = Color(0.02, 0.02, 0.08)
    _bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_bg)

    _upper_line = Line2D.new()
    _upper_line.width = 2.0
    _upper_line.default_color = Color(0.3, 0.6, 1.0, 0.8)
    add_child(_upper_line)

    _lower_line = Line2D.new()
    _lower_line.width = 2.0
    _lower_line.default_color = Color(0.3, 0.6, 1.0, 0.8)
    add_child(_lower_line)

    _ship_rect_node = ColorRect.new()
    _ship_rect_node.color = Color(0.1, 1.0, 0.8)
    _ship_rect_node.size = Vector2(SHIP_SIZE, SHIP_SIZE)
    add_child(_ship_rect_node)

    var hud_bar := HBoxContainer.new()
    hud_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    hud_bar.add_theme_constant_override("separation", 16)
    add_child(hud_bar)

    var approach_label := Label.new()
    approach_label.text = "APPROACH — PAD %d" % _ctx.assigned_pad
    approach_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
    hud_bar.add_child(approach_label)

    _speed_label = Label.new()
    hud_bar.add_child(_speed_label)

    _progress_bar = ProgressBar.new()
    _progress_bar.max_value = APPROACH_LENGTH
    _progress_bar.value = 0.0
    _progress_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _progress_bar.custom_minimum_size = Vector2(0.0, 18.0)
    add_child(_progress_bar)

func _spawn_hazards() -> void:
    _hazards.clear()
    var count := _rng.randi_range(2, 4)
    for i in count:
        var hx := APPROACH_LENGTH * (float(i + 1) / float(count + 1))
        var hy := CENTRE_Y + _rng.randf_range(-80.0, 80.0)
        var hw := _rng.randf_range(60.0, 100.0)
        var hh := _rng.randf_range(40.0, 70.0)
        _hazards.append(Rect2(hx - hw * 0.5, hy - hh * 0.5, hw, hh))

func _process(delta: float) -> void:
    _scroll_x += SCROLL_SPEED * delta
    _progress = clampf(_scroll_x / APPROACH_LENGTH, 0.0, 1.0)
    _progress_bar.value = _scroll_x

    var thrust := 0.0
    if Input.is_action_pressed("ship_up"):
        thrust = -1.0
    elif Input.is_action_pressed("ship_down"):
        thrust = 1.0
    _ship_vy += thrust * THRUST_ACCEL * delta
    _ship_vy = lerpf(_ship_vy, 0.0, DRAG)
    _ship_y = clampf(_ship_y + _ship_vy * delta, 20.0, SCREEN_H - 20.0)

    _speed_label.text = "SPD %.0f" % absf(_ship_vy)

    var t := _progress
    var gap := corridor_gap(t)
    _update_corridor_lines(gap)

    var ship_pos := Vector2(SHIP_X, _ship_y)
    var sr := ship_rect(ship_pos)
    _ship_rect_node.position = sr.position

    if outside_corridor(_ship_y, CENTRE_Y, gap):
        phase_failed.emit(20.0)
        return

    for hz in _hazards:
        var world_hz := Rect2(hz.position.x - _scroll_x + SCREEN_W, hz.position.y, hz.size.x, hz.size.y)
        if sr.intersects(world_hz):
            phase_failed.emit(20.0)
            return

    if _progress >= 1.0:
        phase_completed.emit()

func _update_corridor_lines(gap: float) -> void:
    var upper_y := CENTRE_Y - gap * 0.5
    var lower_y := CENTRE_Y + gap * 0.5
    _upper_line.clear_points()
    _lower_line.clear_points()
    for i in 6:
        var px := float(i) / 5.0 * SCREEN_W
        _upper_line.add_point(Vector2(px, upper_y))
        _lower_line.add_point(Vector2(px, lower_y))
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/scenes/landing/phase_approach.gd tests/unit/test_phase_approach.gd
git commit -m "feat: add Phase 2 approach corridor mini-game"
```

---

## Task 8: Phase 3 — Bay Entry

**Files:**
- Create: `src/scenes/landing/phase_bay_entry.gd`
- Create: `tests/unit/test_phase_bay_entry.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_phase_bay_entry.gd
extends GutTest

func test_pad_rects_planet_has_four() -> void:
    var rects := PhaseBayEntry.pad_rects_for(POIData.POIType.PLANET)
    assert_eq(rects.size(), 4)

func test_pad_rects_station_has_six() -> void:
    var rects := PhaseBayEntry.pad_rects_for(POIData.POIType.STATION)
    assert_eq(rects.size(), 6)

func test_pad_rects_derelict_has_one() -> void:
    var rects := PhaseBayEntry.pad_rects_for(POIData.POIType.DERELICT)
    assert_eq(rects.size(), 1)

func test_overspeed_at_limit() -> void:
    assert_true(PhaseBayEntry.is_overspeed(Vector2(80.1, 0.0)))

func test_not_overspeed_below_limit() -> void:
    assert_false(PhaseBayEntry.is_overspeed(Vector2(79.9, 0.0)))

func test_pad_rect_for_index_one() -> void:
    var rects := PhaseBayEntry.pad_rects_for(POIData.POIType.PLANET)
    # Pad 1 is first element
    assert_true(rects[0].size.x > 0.0)
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Create PhaseBayEntry**

```gdscript
# src/scenes/landing/phase_bay_entry.gd
class_name PhaseBayEntry
extends CanvasLayer

signal phase_completed
signal phase_failed(damage: float)

const SPEED_LIMIT: float = 80.0
const THRUST_ACCEL: float = 220.0
const DRAG: float = 0.10
const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const PAD_W: float = 160.0
const PAD_H: float = 130.0
const PAD_GAP: float = 20.0
const SHIP_SIZE: float = 28.0
const WALL_MARGIN: float = 60.0

var _ctx: LandingContext = null
var _velocity: Vector2 = Vector2.ZERO
var _ship_pos: Vector2 = Vector2.ZERO
var _pads: Array[Rect2] = []
var _ship_node: ColorRect
var _speed_bar: ProgressBar
var _warning_label: Label

static func pad_rects_for(type: POIData.POIType) -> Array[Rect2]:
    var grids: Dictionary = {
        POIData.POIType.PLANET:   Vector2i(2, 2),
        POIData.POIType.STATION:  Vector2i(3, 2),
        POIData.POIType.ASTEROID: Vector2i(2, 1),
        POIData.POIType.DERELICT: Vector2i(1, 1),
    }
    var grid: Vector2i = grids.get(type, Vector2i(1, 1))
    var total_w := grid.x * PAD_W + (grid.x - 1) * PAD_GAP
    var total_h := grid.y * PAD_H + (grid.y - 1) * PAD_GAP
    var origin := Vector2((SCREEN_W - total_w) * 0.5, (SCREEN_H - total_h) * 0.5 + 40.0)
    var result: Array[Rect2] = []
    for row in grid.y:
        for col in grid.x:
            var pos := origin + Vector2(col * (PAD_W + PAD_GAP), row * (PAD_H + PAD_GAP))
            result.append(Rect2(pos, Vector2(PAD_W, PAD_H)))
    return result

static func is_overspeed(velocity: Vector2) -> bool:
    return velocity.length() > SPEED_LIMIT

func begin(ctx: LandingContext) -> void:
    _ctx = ctx
    _pads = pad_rects_for(ctx.poi.data.type)
    _ship_pos = Vector2(SCREEN_W * 0.5, WALL_MARGIN + SHIP_SIZE)
    _build_ui()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.04, 0.04, 0.10)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var draw_node := _BayDrawer.new()
    draw_node.pads = _pads
    draw_node.assigned_pad = _ctx.assigned_pad
    draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(draw_node)

    _ship_node = ColorRect.new()
    _ship_node.color = Color(0.1, 1.0, 0.8)
    _ship_node.size = Vector2(SHIP_SIZE, SHIP_SIZE)
    add_child(_ship_node)

    var hud := HBoxContainer.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    add_child(hud)

    var lbl := Label.new()
    lbl.text = "BAY ENTRY — PAD %d" % _ctx.assigned_pad
    lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
    hud.add_child(lbl)

    _warning_label = Label.new()
    _warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
    _warning_label.visible = false
    hud.add_child(_warning_label)

    _speed_bar = ProgressBar.new()
    _speed_bar.max_value = SPEED_LIMIT * 1.5
    _speed_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _speed_bar.custom_minimum_size = Vector2(0.0, 18.0)
    add_child(_speed_bar)

func _process(delta: float) -> void:
    var thrust := Vector2.ZERO
    if Input.is_action_pressed("ship_left"):  thrust.x = -1.0
    if Input.is_action_pressed("ship_right"): thrust.x = 1.0
    if Input.is_action_pressed("ship_up"):    thrust.y = -1.0
    if Input.is_action_pressed("ship_down"):  thrust.y = 1.0
    if thrust.length() > 0.0:
        thrust = thrust.normalized()
    _velocity += thrust * THRUST_ACCEL * delta
    _velocity = _velocity.lerp(Vector2.ZERO, DRAG)
    _ship_pos = (_ship_pos + _velocity * delta).clamp(
        Vector2(WALL_MARGIN, WALL_MARGIN),
        Vector2(SCREEN_W - WALL_MARGIN, SCREEN_H - WALL_MARGIN)
    )
    _ship_node.position = _ship_pos - Vector2(SHIP_SIZE * 0.5, SHIP_SIZE * 0.5)
    _speed_bar.value = _velocity.length()

    var overspeed := is_overspeed(_velocity)
    _warning_label.visible = overspeed
    if overspeed:
        _warning_label.text = "⚠ REDUCE SPEED"

    var ship_rect := Rect2(_ship_pos - Vector2(SHIP_SIZE * 0.5, SHIP_SIZE * 0.5), Vector2(SHIP_SIZE, SHIP_SIZE))
    for i in _pads.size():
        if ship_rect.intersects(_pads[i]):
            var pad_num := i + 1
            if pad_num != _ctx.assigned_pad:
                phase_failed.emit(5.0)
                return
            if overspeed:
                phase_failed.emit(15.0)
                return
            phase_completed.emit()
            return


class _BayDrawer extends Control:
    var pads: Array[Rect2] = []
    var assigned_pad: int = 1
    var _pulse_t: float = 0.0

    func _process(delta: float) -> void:
        _pulse_t += delta * 2.5
        queue_redraw()

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        for i in pads.size():
            var pad_num := i + 1
            var is_assigned := pad_num == assigned_pad
            var pulse := (sin(_pulse_t) * 0.5 + 0.5) if is_assigned else 0.0
            var col := Color(1.0, 0.75 + pulse * 0.25, 0.0, 1.0) if is_assigned else Color(0.3, 0.3, 0.4, 0.8)
            draw_rect(pads[i], col, false, 2.0 + pulse * 1.0)
            draw_string(font, pads[i].position + Vector2(6.0, 18.0), "PAD %d" % pad_num,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/scenes/landing/phase_bay_entry.gd tests/unit/test_phase_bay_entry.gd
git commit -m "feat: add Phase 3 bay entry top-down navigation"
```

---

## Task 9: Phase 4 — Touchdown

**Files:**
- Create: `src/scenes/landing/phase_touchdown.gd`
- Create: `tests/unit/test_phase_touchdown.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_phase_touchdown.gd
extends GutTest

func test_tilt_in_green_zone() -> void:
    assert_true(PhaseTouchdown.tilt_ok(0.0))
    assert_true(PhaseTouchdown.tilt_ok(0.19))

func test_tilt_outside_green_zone() -> void:
    assert_false(PhaseTouchdown.tilt_ok(0.21))
    assert_false(PhaseTouchdown.tilt_ok(-0.21))

func test_descent_bar_green_window_last_25_percent() -> void:
    assert_true(PhaseTouchdown.in_cut_window(0.76))
    assert_true(PhaseTouchdown.in_cut_window(1.0))

func test_descent_bar_outside_green_window() -> void:
    assert_false(PhaseTouchdown.in_cut_window(0.74))
    assert_false(PhaseTouchdown.in_cut_window(0.0))

func test_ship_centred_in_pad() -> void:
    var pad := Rect2(100.0, 100.0, 160.0, 130.0)
    var ship_pos := Vector2(180.0, 165.0)
    assert_true(PhaseTouchdown.ship_centred(ship_pos, pad, 14.0))

func test_ship_outside_pad() -> void:
    var pad := Rect2(100.0, 100.0, 160.0, 130.0)
    var ship_pos := Vector2(50.0, 165.0)
    assert_false(PhaseTouchdown.ship_centred(ship_pos, pad, 14.0))
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Create PhaseTouchdown**

```gdscript
# src/scenes/landing/phase_touchdown.gd
class_name PhaseTouchdown
extends CanvasLayer

signal phase_completed
signal phase_failed(damage: float)

const TILT_LIMIT: float = 0.2
const CUT_WINDOW_START: float = 0.75
const DESCENT_DURATION: float = 12.0
const SHIP_HALF: float = 14.0
const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const THRUST_ACCEL: float = 160.0
const DRAG: float = 0.10
const SUCCESS_HOLD: float = 2.0
const MOUSE_TILT_SCALE: float = 1.0 / 200.0

var _ctx: LandingContext = null
var _pad_rect: Rect2
var _ship_pos: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _roll_tilt: float = 0.0
var _pitch_tilt: float = 0.0
var _descent_t: float = 0.0
var _thrust_cut: bool = false
var _success_hold_t: float = 0.0
var _failed: bool = false

var _draw_node: Control
var _roll_indicator: _TiltIndicator
var _pitch_indicator: _TiltIndicator
var _descent_bar: ProgressBar
var _cut_button: Button
var _status_label: Label

static func tilt_ok(tilt: float) -> bool:
    return absf(tilt) <= TILT_LIMIT

static func in_cut_window(t: float) -> bool:
    return t >= CUT_WINDOW_START

static func ship_centred(ship_pos: Vector2, pad: Rect2, half_size: float) -> bool:
    return pad.has_point(ship_pos - Vector2(half_size, half_size)) and \
           pad.has_point(ship_pos + Vector2(half_size, half_size))

func begin(ctx: LandingContext) -> void:
    _ctx = ctx
    var pads := PhaseBayEntry.pad_rects_for(ctx.poi.data.type)
    _pad_rect = pads[ctx.assigned_pad - 1]
    _ship_pos = _pad_rect.get_center()
    _build_ui()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.03, 0.03, 0.08)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    _draw_node = _PadView.new()
    (_draw_node as _PadView).pad_rect = _pad_rect
    _draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_draw_node)

    var top_label := Label.new()
    top_label.text = "TOUCHDOWN — PAD %d" % _ctx.assigned_pad
    top_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
    top_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    add_child(top_label)

    _status_label = Label.new()
    _status_label.text = "⚠ ALIGN SHIP BEFORE TOUCHDOWN"
    _status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
    _status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _status_label.position.y = 30.0
    add_child(_status_label)

    _roll_indicator = _TiltIndicator.new()
    _roll_indicator.label = "ROLL"
    _roll_indicator.horizontal = true
    _roll_indicator.custom_minimum_size = Vector2(300.0, 32.0)
    _roll_indicator.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _roll_indicator.position = Vector2(40.0, -140.0)
    add_child(_roll_indicator)

    _pitch_indicator = _TiltIndicator.new()
    _pitch_indicator.label = "PITCH"
    _pitch_indicator.horizontal = false
    _pitch_indicator.custom_minimum_size = Vector2(32.0, 180.0)
    _pitch_indicator.set_anchors_preset(Control.PRESET_CENTER_LEFT)
    _pitch_indicator.position = Vector2(40.0, -90.0)
    add_child(_pitch_indicator)

    _descent_bar = ProgressBar.new()
    _descent_bar.max_value = 1.0
    _descent_bar.value = 0.0
    _descent_bar.custom_minimum_size = Vector2(0.0, 28.0)
    _descent_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _descent_bar.offset_top = -60.0
    add_child(_descent_bar)

    _cut_button = Button.new()
    _cut_button.text = "CUT THRUST"
    _cut_button.custom_minimum_size = Vector2(200.0, 48.0)
    _cut_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _cut_button.position = Vector2(-240.0, -80.0)
    _cut_button.pressed.connect(_on_cut_thrust)
    add_child(_cut_button)

func _process(delta: float) -> void:
    if _failed:
        return
    _update_tilt(delta)
    _update_ship_pos(delta)
    _update_descent(delta)
    _update_indicators()
    if _thrust_cut:
        _check_success(delta)

func _update_tilt(delta: float) -> void:
    var raw_roll: float
    var raw_pitch: float
    if OS.has_feature("mobile"):
        var accel := Input.get_accelerometer()
        raw_roll = clampf(accel.x / 9.8, -1.0, 1.0)
        raw_pitch = clampf(accel.y / 9.8, -1.0, 1.0)
    else:
        var mouse_delta := Input.get_last_mouse_velocity() * delta
        raw_roll = clampf(mouse_delta.x * MOUSE_TILT_SCALE, -1.0, 1.0)
        raw_pitch = clampf(mouse_delta.y * MOUSE_TILT_SCALE, -1.0, 1.0)
    _roll_tilt = lerpf(_roll_tilt, raw_roll, 0.15)
    _pitch_tilt = lerpf(_pitch_tilt, raw_pitch, 0.15)

func _update_ship_pos(delta: float) -> void:
    var thrust := Vector2.ZERO
    if Input.is_action_pressed("ship_left"):  thrust.x = -1.0
    if Input.is_action_pressed("ship_right"): thrust.x = 1.0
    if Input.is_action_pressed("ship_up"):    thrust.y = -1.0
    if Input.is_action_pressed("ship_down"):  thrust.y = 1.0
    if thrust.length() > 0.0:
        thrust = thrust.normalized()
    # Crosswind — seeded from pad number for consistency across retries
    var wind := sin(Time.get_ticks_msec() * 0.001 + _ctx.assigned_pad) * 25.0
    _velocity += (thrust * THRUST_ACCEL + Vector2(wind, 0.0)) * delta
    _velocity = _velocity.lerp(Vector2.ZERO, DRAG)
    _ship_pos += _velocity * delta
    _ship_pos = _ship_pos.clamp(Vector2(SHIP_HALF, SHIP_HALF), Vector2(SCREEN_W - SHIP_HALF, SCREEN_H - SHIP_HALF))
    (_draw_node as _PadView).ship_pos = _ship_pos
    (_draw_node as _PadView).queue_redraw()

func _update_descent(delta: float) -> void:
    if _thrust_cut:
        return
    _descent_t = minf(_descent_t + delta / DESCENT_DURATION, 1.0)
    _descent_bar.value = _descent_t
    if _descent_t >= 1.0:
        _fail(20.0)

func _update_indicators() -> void:
    _roll_indicator.tilt = _roll_tilt
    _roll_indicator.queue_redraw()
    _pitch_indicator.tilt = _pitch_tilt
    _pitch_indicator.queue_redraw()

func _on_cut_thrust() -> void:
    if not in_cut_window(_descent_t):
        return
    _thrust_cut = true
    _cut_button.disabled = true

func _check_success(delta: float) -> void:
    var centred := ship_centred(_ship_pos, _pad_rect, SHIP_HALF)
    var roll_ok := tilt_ok(_roll_tilt)
    var pitch_ok := tilt_ok(_pitch_tilt)
    if centred and roll_ok and pitch_ok:
        _success_hold_t += delta
        _status_label.text = "HOLD STEADY... %.1f" % (SUCCESS_HOLD - _success_hold_t)
        if _success_hold_t >= SUCCESS_HOLD:
            phase_completed.emit()
    else:
        _success_hold_t = 0.0
        _status_label.text = "⚠ ALIGN SHIP BEFORE TOUCHDOWN"

func _fail(damage: float) -> void:
    if _failed:
        return
    _failed = true
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2), 0.1)
    tween.tween_property(self, "modulate", Color.WHITE, 0.2)
    tween.tween_callback(func(): phase_failed.emit(damage))


class _PadView extends Control:
    var pad_rect: Rect2 = Rect2()
    var ship_pos: Vector2 = Vector2.ZERO
    var _pulse_t: float = 0.0

    func _process(delta: float) -> void:
        _pulse_t += delta * 2.0
        queue_redraw()

    func _draw() -> void:
        var pulse := sin(_pulse_t) * 0.5 + 0.5
        draw_rect(pad_rect, Color(1.0, 0.75 + pulse * 0.25, 0.0, 0.6))
        draw_rect(pad_rect, Color(1.0, 0.9, 0.0, 0.9), false, 2.0)
        var ship_rect := Rect2(ship_pos - Vector2(14.0, 14.0), Vector2(28.0, 28.0))
        draw_rect(ship_rect, Color(0.1, 1.0, 0.8, 0.9))


class _TiltIndicator extends Control:
    var tilt: float = 0.0
    var label: String = ""
    var horizontal: bool = true
    const GREEN_ZONE: float = 0.2

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        draw_string(font, Vector2(2.0, 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.8))
        var track_start := Vector2(0.0, 20.0) if horizontal else Vector2(0.0, 16.0)
        var track_end := Vector2(size.x, 20.0) if horizontal else Vector2(0.0, size.y)
        draw_line(track_start, track_end, Color(0.3, 0.3, 0.4), 2.0)
        # green zone band
        if horizontal:
            var centre_x := size.x * 0.5
            var hw := size.x * GREEN_ZONE * 0.5
            draw_rect(Rect2(centre_x - hw, 14.0, hw * 2.0, 12.0), Color(0.0, 0.8, 0.2, 0.4))
            var bx := centre_x + tilt * size.x * 0.5
            draw_circle(Vector2(bx, 20.0), 7.0, Color.WHITE if absf(tilt) <= GREEN_ZONE else Color(1.0, 0.3, 0.2))
        else:
            var centre_y := size.y * 0.5
            var hh := size.y * GREEN_ZONE * 0.5
            draw_rect(Rect2(2.0, centre_y - hh, 10.0, hh * 2.0), Color(0.0, 0.8, 0.2, 0.4))
            var by := centre_y + tilt * size.y * 0.5
            draw_circle(Vector2(7.0, by), 7.0, Color.WHITE if absf(tilt) <= GREEN_ZONE else Color(1.0, 0.3, 0.2))
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/scenes/landing/phase_touchdown.gd tests/unit/test_phase_touchdown.gd
git commit -m "feat: add Phase 4 touchdown with tilt indicators and descent timing"
```

---

## Task 10: Wire World

**Files:**
- Modify: `src/scenes/world/world.gd`
- Modify: `src/scenes/world/world.tscn`

- [ ] **Step 1: Add LandingOrchestrator to `world.tscn`**

Open `src/scenes/world/world.tscn`. Add an ext_resource for the orchestrator script and a node entry.

Increment `load_steps` by 1, add at end of ext_resource block:

```
[ext_resource type="Script" path="res://src/scenes/landing/landing_orchestrator.gd" id="<next_id>"]
```

Add at the end of the node list:

```
[node name="LandingOrchestrator" type="Node" parent="."]
script = ExtResource("<next_id>")
```

Replace `<next_id>` with the next available integer (check current highest `id` in the file).

- [ ] **Step 2: Update `world.gd`**

Add `@onready` reference:

```gdscript
@onready var landing_orchestrator: LandingOrchestrator = $LandingOrchestrator
```

In `_ready()`, after `hud.land_requested.connect(...)`, add:

```gdscript
landing_orchestrator.init(landing_screen)
```

Replace `_on_land_requested()`:

```gdscript
func _on_land_requested() -> void:
    if _poi_in_range == null:
        return
    hud.show_land_button(false)
    landing_orchestrator.begin_landing(_poi_in_range, ship)
```

- [ ] **Step 3: Run full test suite — expect all PASS**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -30
```

- [ ] **Step 4: Play-test the full landing sequence**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --path . 2>&1 | head -5
```

Verify the golden path:
1. Fly near a POI — depth strip and mini-map depth encoding visible.
2. Press LAND — ATC screen appears, typewriter runs, pad assigned.
3. Press ACKNOWLEDGED — approach corridor starts. Use up/down to stay in lane.
4. Reach corridor end — bay entry starts. Steer to assigned pad at low speed.
5. Enter pad — touchdown starts. Move mouse to level indicators. Press CUT THRUST in green window.
6. Hold steady 2 seconds — LandingScreen appears (existing refuel screen).
7. Press DEPART — back to open space.

Verify failure path:
- Hit corridor boundary → red flash, hull bar drops, Phase 2 retries.
- Wrong pad in bay → red flash, small hull drop, Phase 3 retries.
- Miss cut thrust window → red flash, hull drop, Phase 4 retries.

- [ ] **Step 5: Commit**

```bash
git add src/scenes/world/world.gd src/scenes/world/world.tscn
git commit -m "feat: wire LandingOrchestrator into World, completing landing procedure"
```

---

## Self-Review Notes

- **Spec coverage:** All 8 spec sections covered: depth radar (Task 3), mini-map depth encoding (Task 2), LandingContext (Task 1), LandingOrchestrator (Task 5), Phase 1–4 (Tasks 6–9), World wiring (Task 10), HUD wiring (Task 4).
- `approach_rng_seed` set by Orchestrator in `begin_landing()` — consistent with spec.
- `is_ship_destroyed` signal emitted by Orchestrator but game-over handling is out of scope per spec §8 — orchestrator emits `ship_destroyed`, World can connect a handler later.
- Phase 4 crosswind seeded with `_ctx.assigned_pad` (not `approach_rng_seed`) per spec §6.1 — same wind pattern on every retry for learnability.
- Static helper functions (`corridor_gap`, `ship_rect`, `outside_corridor`, `pad_rects_for`, etc.) are all unit-tested without requiring scene instantiation.
- `PhaseBayEntry.pad_rects_for()` is reused by `PhaseTouchdown.begin()` — no duplication.
