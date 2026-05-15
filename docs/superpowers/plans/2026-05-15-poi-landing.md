# POI & Landing System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4 typed Points of Interest to the world with a landing screen, auto-refuel, fuel-exempt first flight, and beacon auto-landing when out of fuel.

**Architecture:** A `POIData` resource drives all POI types; `PointOfInterest` replaces `Planet`. A `GameState` autoload tracks first landing to gate fuel burn. A `BeaconSystem` autoload monitors fuel and steers the ship to the nearest POI when stranded. World wires everything together via a `POIs` Node2D group.

**Tech Stack:** Godot 4.3 LTS, GDScript (typed), GUT 9.3.1 for tests.

---

## File Map

| Status | Path | Responsibility |
|--------|------|----------------|
| CREATE | `src/resources/poi_data.gd` | POIData resource (type enum, name, description, threshold) |
| CREATE | `src/resources/kerrath_prime.tres` | Planet POIData instance |
| CREATE | `src/resources/relay_station_7.tres` | Station POIData instance |
| CREATE | `src/resources/asteroid_outpost_k4.tres` | Asteroid POIData instance |
| CREATE | `src/resources/derelict_harvester.tres` | Derelict POIData instance |
| CREATE | `src/scenes/poi/point_of_interest.gd` | Proximity signal logic |
| CREATE | `src/scenes/poi/point_of_interest.tscn` | POI scene (WorldEntity + Sprite) |
| CREATE | `src/systems/game_state.gd` | `has_landed_once` autoload |
| CREATE | `src/systems/beacon_system.gd` | Auto-land when fuel=0 |
| CREATE | `src/scenes/ui/landing_screen.gd` | Landing screen controller |
| CREATE | `src/scenes/ui/landing_screen.tscn` | Landing screen scene |
| CREATE | `tests/unit/test_poi_data.gd` | POIData tests |
| CREATE | `tests/unit/test_point_of_interest.gd` | Proximity signal tests |
| CREATE | `tests/unit/test_game_state.gd` | GameState tests |
| CREATE | `tests/unit/test_beacon_system.gd` | BeaconSystem.find_nearest tests |
| MODIFY | `src/systems/ship_input.gd` | Add `suspended: bool` |
| MODIFY | `src/scenes/ship/ship.gd` | Skip fuel burn before first landing |
| MODIFY | `src/scenes/ui/hud.gd` | Add `show_beacon_active(bool)` |
| MODIFY | `src/scenes/ui/hud.tscn` | Add BeaconLabel node |
| MODIFY | `src/scenes/world/world.gd` | Wire POIs, beacon, landing screen |
| MODIFY | `src/scenes/world/world.tscn` | Replace Planet with POIs group + LandingScreen |
| MODIFY | `project.godot` | Register GameState + BeaconSystem autoloads |
| MODIFY | `tests/unit/test_ship.gd` | Reset GameState in before_each; fix fuel tests |

---

## Task 1: POIData Resource

**Files:**
- Create: `src/resources/poi_data.gd`
- Create: `tests/unit/test_poi_data.gd`

- [ ] **Step 1.1 — Write the failing test**

```gdscript
# tests/unit/test_poi_data.gd
extends GutTest

func test_default_type_is_planet() -> void:
    var d := POIData.new()
    assert_eq(d.type, POIData.POIType.PLANET)

func test_default_landing_threshold_is_positive() -> void:
    var d := POIData.new()
    assert_gt(d.landing_threshold, 0.0)

func test_fields_assignable() -> void:
    var d := POIData.new()
    d.type = POIData.POIType.STATION
    d.poi_name = "Relay Station 7"
    d.description = "A deep-space relay."
    d.landing_threshold = 120.0
    assert_eq(d.type, POIData.POIType.STATION)
    assert_eq(d.poi_name, "Relay Station 7")
    assert_eq(d.landing_threshold, 120.0)
```

- [ ] **Step 1.2 — Run to verify failure**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```
Expected: ERROR — `POIData` not defined.

- [ ] **Step 1.3 — Implement `src/resources/poi_data.gd`**

```gdscript
class_name POIData
extends Resource

enum POIType { PLANET, STATION, ASTEROID, DERELICT }

@export var type: POIType = POIType.PLANET
@export var poi_name: String = "Unknown"
@export var description: String = ""
@export var landing_threshold: float = 60.0
```

- [ ] **Step 1.4 — Run tests; expect all pass**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 1.5 — Commit**

```bash
git add src/resources/poi_data.gd tests/unit/test_poi_data.gd
git commit -m "feat: add POIData resource with type enum"
```

---

## Task 2: GameState Autoload

**Files:**
- Create: `src/systems/game_state.gd`
- Modify: `project.godot` — add autoload entry
- Create: `tests/unit/test_game_state.gd`

- [ ] **Step 2.1 — Create minimal GameState (needed before test can reference it)**

```gdscript
# src/systems/game_state.gd
extends Node

var has_landed_once: bool = false
```

- [ ] **Step 2.2 — Register in `project.godot`**

Find the `[autoload]` section (currently contains `ShipInput=...`) and add:

```ini
GameState="*res://src/systems/game_state.gd"
```

Full `[autoload]` block after edit:
```ini
[autoload]

ShipInput="*res://src/systems/ship_input.gd"
GameState="*res://src/systems/game_state.gd"
```

- [ ] **Step 2.3 — Write the test**

```gdscript
# tests/unit/test_game_state.gd
extends GutTest

func before_each() -> void:
    GameState.has_landed_once = false

func test_starts_false() -> void:
    assert_false(GameState.has_landed_once)

func test_can_be_set_true() -> void:
    GameState.has_landed_once = true
    assert_true(GameState.has_landed_once)
```

- [ ] **Step 2.4 — Run tests; expect all pass**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 2.5 — Commit**

```bash
git add src/systems/game_state.gd tests/unit/test_game_state.gd project.godot
git commit -m "feat: add GameState autoload with has_landed_once flag"
```

---

## Task 3: PointOfInterest Scene

**Files:**
- Create: `src/scenes/poi/point_of_interest.gd`
- Create: `src/scenes/poi/point_of_interest.tscn`
- Create: `tests/unit/test_point_of_interest.gd`

- [ ] **Step 3.1 — Write the failing tests**

```gdscript
# tests/unit/test_point_of_interest.gd
extends GutTest

var poi: PointOfInterest
var data: POIData

func before_each() -> void:
    data = POIData.new()
    data.landing_threshold = 50.0
    poi = preload("res://src/scenes/poi/point_of_interest.tscn").instantiate()
    poi.data = data
    poi.z_depth = 500.0
    add_child(poi)

func after_each() -> void:
    poi.queue_free()

func test_landing_zone_entered_when_ship_in_range() -> void:
    watch_signals(poi)
    poi.check_landing_proximity(520.0)  # 520 <= 500 + 50
    assert_signal_emitted(poi, "landing_zone_entered")

func test_landing_zone_not_entered_when_ship_far() -> void:
    watch_signals(poi)
    poi.check_landing_proximity(600.0)  # 600 > 500 + 50
    assert_signal_not_emitted(poi, "landing_zone_entered")

func test_landing_zone_exited_after_enter_then_leave() -> void:
    poi.check_landing_proximity(520.0)  # enter
    watch_signals(poi)
    poi.check_landing_proximity(600.0)  # exit
    assert_signal_emitted(poi, "landing_zone_exited")

func test_signal_carries_poi_reference() -> void:
    watch_signals(poi)
    poi.check_landing_proximity(520.0)
    assert_signal_emitted_with_parameters(poi, "landing_zone_entered", [poi])

func test_no_signal_without_data() -> void:
    poi.data = null
    watch_signals(poi)
    poi.check_landing_proximity(520.0)
    assert_signal_not_emitted(poi, "landing_zone_entered")
```

- [ ] **Step 3.2 — Run to verify failure**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```
Expected: ERROR — scene not found.

- [ ] **Step 3.3 — Create `src/scenes/poi/point_of_interest.gd`**

```gdscript
class_name PointOfInterest
extends WorldEntity

@export var data: POIData

signal landing_zone_entered(poi: PointOfInterest)
signal landing_zone_exited(poi: PointOfInterest)

var _player_in_range: bool = false

func check_landing_proximity(ship_z_depth: float) -> void:
    if data == null:
        return
    var in_range: bool = ship_z_depth <= z_depth + data.landing_threshold
    if in_range and not _player_in_range:
        _player_in_range = true
        landing_zone_entered.emit(self)
    elif not in_range and _player_in_range:
        _player_in_range = false
        landing_zone_exited.emit(self)
```

- [ ] **Step 3.4 — Create `src/scenes/poi/point_of_interest.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/scenes/poi/point_of_interest.gd" id="1"]

[node name="PointOfInterest" type="Node2D"]
script = ExtResource("1")

[node name="Sprite" type="Sprite2D" parent="."]
```

- [ ] **Step 3.5 — Run tests; expect all pass**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 3.6 — Commit**

```bash
git add src/scenes/poi/ tests/unit/test_point_of_interest.gd
git commit -m "feat: add PointOfInterest scene replacing Planet"
```

---

## Task 4: Ship Fuel Exemption Before First Landing

**Files:**
- Modify: `src/scenes/ship/ship.gd` — `_handle_thrust`
- Modify: `tests/unit/test_ship.gd` — reset GameState, update existing fuel tests, add new tests

- [ ] **Step 4.1 — Update `tests/unit/test_ship.gd`**

Replace the full file content:

```gdscript
extends GutTest

var ship: Ship
var data: ShipData

func before_each() -> void:
    GameState.has_landed_once = false
    data = ShipData.new()
    data.max_fuel = 100.0
    data.max_hull = 100.0
    data.thrust_power = 500.0
    data.depth_speed = 50.0
    data.fuel_burn_rate = 10.0
    data.linear_damp_value = 1.5
    ship = preload("res://src/scenes/ship/ship.tscn").instantiate()
    ship.data = data
    add_child(ship)

func after_each() -> void:
    ship.queue_free()

func test_ship_initializes_fuel_from_data() -> void:
    assert_eq(ship.fuel, 100.0)

func test_ship_initializes_hull_from_data() -> void:
    assert_eq(ship.hull, 100.0)

func test_depth_decreases_when_approaching() -> void:
    ship.z_depth = 1000.0
    ship.depth_input = -1.0
    ship._physics_process(1.0)
    assert_lt(ship.z_depth, 1000.0)

func test_depth_increases_when_retreating() -> void:
    ship.z_depth = 1000.0
    ship.depth_input = 1.0
    ship._physics_process(1.0)
    assert_gt(ship.z_depth, 1000.0)

func test_depth_clamps_at_minimum() -> void:
    ship.z_depth = DepthSystem.MIN_Z_DEPTH
    ship.depth_input = -1.0
    ship._physics_process(1.0)
    assert_eq(ship.z_depth, DepthSystem.MIN_Z_DEPTH)

func test_depth_clamps_at_maximum() -> void:
    ship.z_depth = DepthSystem.MAX_Z_DEPTH
    ship.depth_input = 1.0
    ship._physics_process(1.0)
    assert_eq(ship.z_depth, DepthSystem.MAX_Z_DEPTH)

func test_fuel_not_depleted_before_first_landing() -> void:
    GameState.has_landed_once = false
    ship.thrust_input = Vector2(1.0, 0.0)
    ship._physics_process(1.0)
    assert_eq(ship.fuel, 100.0)

func test_fuel_depletes_after_first_landing() -> void:
    GameState.has_landed_once = true
    ship.thrust_input = Vector2(1.0, 0.0)
    ship._physics_process(1.0)
    assert_lt(ship.fuel, 100.0)

func test_fuel_unchanged_when_empty() -> void:
    GameState.has_landed_once = true
    ship.fuel = 0.0
    ship.thrust_input = Vector2(1.0, 0.0)
    ship._physics_process(1.0)
    assert_eq(ship.fuel, 0.0)
```

- [ ] **Step 4.2 — Run to verify the two new tests fail**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```
Expected: `test_fuel_not_depleted_before_first_landing` FAIL (currently fuel always depletes).

- [ ] **Step 4.3 — Replace `_handle_thrust` in `src/scenes/ship/ship.gd`**

```gdscript
func _handle_thrust(delta: float) -> void:
    if thrust_input == Vector2.ZERO:
        return
    if GameState.has_landed_once and fuel <= 0.0:
        return
    apply_central_force(thrust_input.normalized() * data.thrust_power)
    if GameState.has_landed_once:
        fuel = maxf(0.0, fuel - data.fuel_burn_rate * delta)
        fuel_changed.emit(fuel)
```

- [ ] **Step 4.4 — Run all tests; expect all pass**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 4.5 — Commit**

```bash
git add src/scenes/ship/ship.gd tests/unit/test_ship.gd
git commit -m "feat: skip fuel burn before first landing (onboarding grace)"
```

---

## Task 5: ShipInput Suspension + BeaconSystem

**Files:**
- Modify: `src/systems/ship_input.gd` — add `suspended: bool`
- Create: `src/systems/beacon_system.gd`
- Modify: `project.godot` — add BeaconSystem autoload
- Create: `tests/unit/test_beacon_system.gd`

- [ ] **Step 5.1 — Add `suspended` to `src/systems/ship_input.gd`**

Replace full file:

```gdscript
extends Node

var ship: Ship = null
var suspended: bool = false

func _process(_delta: float) -> void:
    if not ship or suspended:
        return
    ship.thrust_input = _read_thrust()
    ship.depth_input = _read_depth()

func _read_thrust() -> Vector2:
    var dir := Vector2.ZERO
    if Input.is_action_pressed("ship_left"):
        dir.x -= 1.0
    if Input.is_action_pressed("ship_right"):
        dir.x += 1.0
    if Input.is_action_pressed("ship_up"):
        dir.y -= 1.0
    if Input.is_action_pressed("ship_down"):
        dir.y += 1.0
    return dir.normalized()

func _read_depth() -> float:
    var d := 0.0
    if Input.is_action_pressed("ship_depth_in"):
        d -= 1.0
    if Input.is_action_pressed("ship_depth_out"):
        d += 1.0
    return d
```

- [ ] **Step 5.2 — Write the failing BeaconSystem tests**

```gdscript
# tests/unit/test_beacon_system.gd
extends GutTest

func before_each() -> void:
    GameState.has_landed_once = true

func after_each() -> void:
    GameState.has_landed_once = false

func test_find_nearest_returns_closest_by_3d_distance() -> void:
    var poi_near := preload("res://src/scenes/poi/point_of_interest.tscn").instantiate()
    var poi_far := preload("res://src/scenes/poi/point_of_interest.tscn").instantiate()
    poi_near.data = POIData.new()
    poi_far.data = POIData.new()
    add_child(poi_near)
    add_child(poi_far)
    poi_near.position = Vector2(100.0, 0.0)
    poi_near.z_depth = 500.0
    poi_far.position = Vector2(2000.0, 0.0)
    poi_far.z_depth = 3000.0
    var nearest := BeaconSystem.find_nearest(Vector2.ZERO, 600.0, [poi_near, poi_far])
    assert_eq(nearest, poi_near)
    poi_near.queue_free()
    poi_far.queue_free()

func test_find_nearest_returns_null_when_list_empty() -> void:
    var result := BeaconSystem.find_nearest(Vector2.ZERO, 0.0, [])
    assert_null(result)
```

- [ ] **Step 5.3 — Run to verify failure**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```
Expected: ERROR — `BeaconSystem` not defined.

- [ ] **Step 5.4 — Create `src/systems/beacon_system.gd`**

```gdscript
extends Node

const BEACON_SPEED: float = 400.0
const BEACON_DEPTH_SPEED: float = 300.0

var _ship: Ship = null
var _pois: Array = []
var _active: bool = false
var _target: PointOfInterest = null

signal beacon_activated
signal beacon_deactivated

func register(ship: Ship, pois: Array) -> void:
    _ship = ship
    _pois = pois
    ship.fuel_changed.connect(_on_fuel_changed)

func _process(delta: float) -> void:
    if not _active or _target == null or _ship == null:
        return
    var dir: Vector2 = _target.position - _ship.position
    if dir.length() > 10.0:
        _ship.linear_velocity = dir.normalized() * BEACON_SPEED
    _ship.z_depth = move_toward(_ship.z_depth, _target.z_depth, BEACON_DEPTH_SPEED * delta)
    _ship.depth_changed.emit(_ship.z_depth)
    _target.check_landing_proximity(_ship.z_depth)

func _on_fuel_changed(value: float) -> void:
    if value <= 0.0 and GameState.has_landed_once and not _active:
        _activate()

func _activate() -> void:
    _target = find_nearest(_ship.position, _ship.z_depth, _pois)
    if _target == null:
        return
    _active = true
    ShipInput.suspended = true
    beacon_activated.emit()

func deactivate() -> void:
    _active = false
    _target = null
    beacon_deactivated.emit()

static func find_nearest(ship_pos: Vector2, ship_z: float, pois: Array) -> PointOfInterest:
    var nearest: PointOfInterest = null
    var min_dist: float = INF
    for poi in pois:
        var d: float = Vector3(ship_pos.x, ship_pos.y, ship_z).distance_to(
            Vector3(poi.position.x, poi.position.y, poi.z_depth))
        if d < min_dist:
            min_dist = d
            nearest = poi
    return nearest
```

- [ ] **Step 5.5 — Register BeaconSystem in `project.godot`**

Add after the GameState line in `[autoload]`:

```ini
BeaconSystem="*res://src/systems/beacon_system.gd"
```

Full `[autoload]` block after edit:
```ini
[autoload]

ShipInput="*res://src/systems/ship_input.gd"
GameState="*res://src/systems/game_state.gd"
BeaconSystem="*res://src/systems/beacon_system.gd"
```

- [ ] **Step 5.6 — Run all tests; expect all pass**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 5.7 — Commit**

```bash
git add src/systems/ship_input.gd src/systems/beacon_system.gd project.godot tests/unit/test_beacon_system.gd
git commit -m "feat: add BeaconSystem autoload and ShipInput suspension"
```

---

## Task 6: LandingScreen UI

**Files:**
- Create: `src/scenes/ui/landing_screen.gd`
- Create: `src/scenes/ui/landing_screen.tscn`

No GUT tests — verified by playing the game. Landing screen is auto-shown when the ship enters a POI's proximity zone and auto-refuels on display.

- [ ] **Step 6.1 — Create `src/scenes/ui/landing_screen.gd`**

```gdscript
class_name LandingScreen
extends CanvasLayer

@onready var type_badge: Label = $Panel/VBox/TypeBadge
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var refueled_label: Label = $Panel/VBox/RefueledLabel
@onready var depart_button: Button = $Panel/VBox/DepartButton

const TYPE_LABELS: Dictionary = {
    POIData.POIType.PLANET:   "PLANET",
    POIData.POIType.STATION:  "SPACE STATION",
    POIData.POIType.ASTEROID: "ASTEROID OUTPOST",
    POIData.POIType.DERELICT: "DERELICT SHIP",
}

const TYPE_COLORS: Dictionary = {
    POIData.POIType.PLANET:   Color(0.2, 0.8, 0.3),
    POIData.POIType.STATION:  Color(0.3, 0.6, 1.0),
    POIData.POIType.ASTEROID: Color(1.0, 0.6, 0.1),
    POIData.POIType.DERELICT: Color(0.6, 0.6, 0.6),
}

func show_for(poi: PointOfInterest, ship: Ship) -> void:
    type_badge.text = TYPE_LABELS[poi.data.type]
    type_badge.add_theme_color_override("font_color", TYPE_COLORS[poi.data.type])
    name_label.text = poi.data.poi_name
    description_label.text = poi.data.description
    _refuel(ship)
    if not GameState.has_landed_once:
        GameState.has_landed_once = true
    BeaconSystem.deactivate()
    ShipInput.suspended = true
    visible = true

func _refuel(ship: Ship) -> void:
    ship.fuel = ship.data.max_fuel
    ship.fuel_changed.emit(ship.fuel)
    refueled_label.visible = true
    var tween := create_tween()
    tween.tween_interval(1.5)
    tween.tween_callback(func(): refueled_label.visible = false)

func _on_depart_pressed() -> void:
    ShipInput.suspended = false
    visible = false
```

- [ ] **Step 6.2 — Create `src/scenes/ui/landing_screen.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/scenes/ui/landing_screen.gd" id="1"]

[node name="LandingScreen" type="CanvasLayer"]
visible = false
script = ExtResource("1")

[node name="Panel" type="Panel" parent="."]
anchor_left = 0.2
anchor_top = 0.1
anchor_right = 0.8
anchor_bottom = 0.9
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="Panel"]
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 32.0
offset_top = 32.0
offset_right = -32.0
offset_bottom = -32.0
theme_override_constants/separation = 16

[node name="TypeBadge" type="Label" parent="Panel/VBox"]
text = "PLANET"
theme_override_font_sizes/font_size = 13

[node name="NameLabel" type="Label" parent="Panel/VBox"]
text = "Unknown"
theme_override_font_sizes/font_size = 36

[node name="DescriptionLabel" type="Label" parent="Panel/VBox"]
text = ""
autowrap_mode = 3
size_flags_vertical = 3

[node name="RefueledLabel" type="Label" parent="Panel/VBox"]
visible = false
text = "Fuel replenished."
theme_override_colors/font_color = Color(0.2, 0.8, 0.3, 1.0)

[node name="DepartButton" type="Button" parent="Panel/VBox"]
text = "Depart"

[connection signal="pressed" from="Panel/VBox/DepartButton" to="." method="_on_depart_pressed"]
```

- [ ] **Step 6.3 — Commit**

```bash
git add src/scenes/ui/landing_screen.gd src/scenes/ui/landing_screen.tscn
git commit -m "feat: add LandingScreen UI with auto-refuel and Depart"
```

---

## Task 7: HUD Beacon Label

**Files:**
- Modify: `src/scenes/ui/hud.gd`
- Modify: `src/scenes/ui/hud.tscn`

- [ ] **Step 7.1 — Read `hud.tscn` to locate where to insert the new node**

```bash
cat /home/ubuntu/Projects/space-xplorer/src/scenes/ui/hud.tscn
```

- [ ] **Step 7.2 — Add `BeaconLabel` node to `hud.tscn`**

After the `[node name="LandingLabel" ...]` block, append:

```ini
[node name="BeaconLabel" type="Label" parent="."]
visible = false
anchor_left = 0.5
anchor_top = 0.6
anchor_right = 0.5
anchor_bottom = 0.6
offset_left = -160.0
offset_right = 160.0
offset_top = -16.0
offset_bottom = 16.0
horizontal_alignment = 1
text = "BEACON ACTIVE — auto-landing"
theme_override_colors/font_color = Color(1.0, 0.45, 0.1, 1.0)
```

- [ ] **Step 7.3 — Add `beacon_label` and `show_beacon_active` to `hud.gd`**

Add this onready after the existing ones:

```gdscript
@onready var beacon_label: Label = $BeaconLabel
```

Add this method:

```gdscript
func show_beacon_active(active: bool) -> void:
    beacon_label.visible = active
```

- [ ] **Step 7.4 — Run all tests; expect all pass**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 7.5 — Commit**

```bash
git add src/scenes/ui/hud.gd src/scenes/ui/hud.tscn
git commit -m "feat: add beacon active indicator to HUD"
```

---

## Task 8: POI Data Files + World Wiring

**Files:**
- Create: `src/resources/kerrath_prime.tres`
- Create: `src/resources/relay_station_7.tres`
- Create: `src/resources/asteroid_outpost_k4.tres`
- Create: `src/resources/derelict_harvester.tres`
- Modify: `src/scenes/world/world.tscn`
- Modify: `src/scenes/world/world.gd`

- [ ] **Step 8.1 — Create `src/resources/kerrath_prime.tres`**

```ini
[gd_resource type="Resource" script_class="POIData" format=3]

[ext_resource type="Script" path="res://src/resources/poi_data.gd" id="1"]

[resource]
script = ExtResource("1")
type = 0
poi_name = "Kerrath Prime"
description = "A rocky world orbiting a red dwarf. Rich in minerals, home to scattered mining colonies."
landing_threshold = 80.0
```

- [ ] **Step 8.2 — Create `src/resources/relay_station_7.tres`**

```ini
[gd_resource type="Resource" script_class="POIData" format=3]

[ext_resource type="Script" path="res://src/resources/poi_data.gd" id="1"]

[resource]
script = ExtResource("1")
type = 1
poi_name = "Relay Station 7"
description = "A UEE relay converted into a traveller rest stop. Fuel, minimal repairs, and a vending machine."
landing_threshold = 60.0
```

- [ ] **Step 8.3 — Create `src/resources/asteroid_outpost_k4.tres`**

```ini
[gd_resource type="Resource" script_class="POIData" format=3]

[ext_resource type="Script" path="res://src/resources/poi_data.gd" id="1"]

[resource]
script = ExtResource("1")
type = 2
poi_name = "Outpost K-4"
description = "A mining camp wedged into an asteroid. Rough crowd, cheap fuel, no questions asked."
landing_threshold = 50.0
```

- [ ] **Step 8.4 — Create `src/resources/derelict_harvester.tres`**

```ini
[gd_resource type="Resource" script_class="POIData" format=3]

[ext_resource type="Script" path="res://src/resources/poi_data.gd" id="1"]

[resource]
script = ExtResource("1")
type = 3
poi_name = "Harvester's End"
description = "A derelict ore hauler, drifting for decades. Salvagers occasionally camp here between runs."
landing_threshold = 45.0
```

- [ ] **Step 8.5 — Replace `src/scenes/world/world.tscn`**

```ini
[gd_scene load_steps=14 format=3]

[ext_resource type="Script" path="res://src/scenes/world/world.gd" id="1"]
[ext_resource type="PackedScene" path="res://src/scenes/world/space_background.tscn" id="2"]
[ext_resource type="PackedScene" path="res://src/scenes/poi/point_of_interest.tscn" id="3"]
[ext_resource type="PackedScene" path="res://src/scenes/ship/ship.tscn" id="4"]
[ext_resource type="Resource" path="res://src/resources/default_ship.tres" id="5"]
[ext_resource type="PackedScene" path="res://src/scenes/ui/hud.tscn" id="6"]
[ext_resource type="PackedScene" path="res://src/scenes/ui/touch_controls.tscn" id="7"]
[ext_resource type="PackedScene" path="res://src/scenes/ui/landing_screen.tscn" id="8"]
[ext_resource type="Resource" path="res://src/resources/kerrath_prime.tres" id="9"]
[ext_resource type="Resource" path="res://src/resources/relay_station_7.tres" id="10"]
[ext_resource type="Resource" path="res://src/resources/asteroid_outpost_k4.tres" id="11"]
[ext_resource type="Resource" path="res://src/resources/derelict_harvester.tres" id="12"]

[node name="World" type="Node2D"]
script = ExtResource("1")

[node name="SpaceBackground" parent="." instance=ExtResource("2")]

[node name="POIs" type="Node2D" parent="."]

[node name="KerrathPrime" parent="POIs" instance=ExtResource("3")]
position = Vector2(400, 250)
data = ExtResource("9")
z_depth = 500.0

[node name="RelayStation7" parent="POIs" instance=ExtResource("3")]
position = Vector2(1100, 200)
data = ExtResource("10")
z_depth = 800.0

[node name="OutpostK4" parent="POIs" instance=ExtResource("3")]
position = Vector2(-100, 550)
data = ExtResource("11")
z_depth = 2000.0

[node name="HarvestersEnd" parent="POIs" instance=ExtResource("3")]
position = Vector2(900, 650)
data = ExtResource("12")
z_depth = 3500.0

[node name="Ship" parent="." instance=ExtResource("4")]
position = Vector2(640, 500)
data = ExtResource("5")

[node name="Camera" type="Camera2D" parent="Ship"]
position_smoothing_enabled = true

[node name="StarLight" type="PointLight2D" parent="."]
position = Vector2(-400, -300)
energy = 1.2
height = 0.0

[node name="HUD" parent="." instance=ExtResource("6")]

[node name="TouchControls" parent="." instance=ExtResource("7")]

[node name="LandingScreen" parent="." instance=ExtResource("8")]
```

- [ ] **Step 8.6 — Replace `src/scenes/world/world.gd`**

```gdscript
extends Node2D

@onready var ship: Ship = $Ship
@onready var hud: HUD = $HUD
@onready var landing_screen: LandingScreen = $LandingScreen

var _pois: Array[PointOfInterest] = []

func _ready() -> void:
    for child in $POIs.get_children():
        var poi := child as PointOfInterest
        if poi == null:
            continue
        _pois.append(poi)
        poi.landing_zone_entered.connect(_on_landing_zone_entered)
        poi.landing_zone_exited.connect(_on_landing_zone_exited)
    ShipInput.ship = ship
    hud.connect_to_ship(ship)
    BeaconSystem.register(ship, _pois)
    BeaconSystem.beacon_activated.connect(func(): hud.show_beacon_active(true))
    BeaconSystem.beacon_deactivated.connect(func(): hud.show_beacon_active(false))

func _process(_delta: float) -> void:
    for poi in _pois:
        poi.check_landing_proximity(ship.z_depth)

func _on_landing_zone_entered(poi: PointOfInterest) -> void:
    hud.show_landing_prompt(true)
    landing_screen.show_for(poi, ship)

func _on_landing_zone_exited(_poi: PointOfInterest) -> void:
    hud.show_landing_prompt(false)
```

- [ ] **Step 8.7 — Run all tests; expect all pass**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 8.8 — Commit**

```bash
git add src/resources/ src/scenes/world/world.gd src/scenes/world/world.tscn
git commit -m "feat: wire 4 POIs, BeaconSystem, and LandingScreen into World"
```

---

## Task 9: Final Verification + Push

- [ ] **Step 9.1 — Full test suite**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit 2>&1 | tail -30
```
Expected: All tests pass, 0 failures.

- [ ] **Step 9.2 — Push**

```bash
git push origin main
```
