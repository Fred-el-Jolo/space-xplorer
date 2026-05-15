# Landing Button, Fuel Simplification & Space Decorations — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace auto-landing with a HUD button, remove the infinite-fuel-before-first-landing crutch, and add procedural stars and nebula patches to the space background.

**Architecture:** Three independent feature tracks. Fuel simplification touches `ship.gd` and `beacon_system.gd`; landing button touches `hud.gd`/`hud.tscn` and `world.gd`; decorations introduce a new `StarField` node added to existing parallax layers. No new scene files, no external assets.

**Tech Stack:** Godot 4.3 LTS · GDScript (type-hinted) · GUT 9.3.1

---

## Test commands

```bash
# Run full suite headlessly
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected baseline output ends with something like:
```
All tests passed.  22 passed, 0 failed, ...
```

---

## File map

| Action | Path |
|--------|------|
| Modify | `src/systems/beacon_system.gd` |
| Modify | `src/scenes/ship/ship.gd` |
| Modify | `tests/unit/test_ship.gd` |
| Modify | `tests/unit/test_beacon_system.gd` |
| Modify | `tests/unit/test_point_of_interest.gd` |
| Modify | `src/scenes/ui/hud.tscn` |
| Modify | `src/scenes/ui/hud.gd` |
| Modify | `src/scenes/world/world.gd` |
| Create | `src/scenes/world/star_field.gd` |
| Create | `tests/unit/test_hud.gd` |
| Create | `tests/unit/test_star_field.gd` |
| Modify | `src/scenes/world/space_background.tscn` |

---

## Task 1: Fix pre-existing test_point_of_interest.gd API mismatch

The tests in `test_point_of_interest.gd` call `poi.check_landing_proximity(float)` with a single float, but the current API is `check_landing_proximity(ship_pos: Vector2, ship_z_depth: float)`. This causes runtime errors in the full suite.

**Files:**
- Modify: `tests/unit/test_point_of_interest.gd`

- [ ] **Step 1: Run tests to confirm the failures**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Note how many tests fail and which.

- [ ] **Step 2: Update all calls in the test to the two-argument API**

Open `tests/unit/test_point_of_interest.gd`. Replace every `poi.check_landing_proximity(FLOAT)` call with `poi.check_landing_proximity(Vector2.ZERO, FLOAT)`.

The full updated file:

```gdscript
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
	poi.check_landing_proximity(Vector2.ZERO, 520.0)
	assert_signal_emitted(poi, "landing_zone_entered")

func test_landing_zone_not_entered_when_ship_far() -> void:
	watch_signals(poi)
	poi.check_landing_proximity(Vector2.ZERO, 600.0)
	assert_signal_not_emitted(poi, "landing_zone_entered")

func test_landing_zone_exited_after_enter_then_leave() -> void:
	poi.check_landing_proximity(Vector2.ZERO, 520.0)
	watch_signals(poi)
	poi.check_landing_proximity(Vector2.ZERO, 600.0)
	assert_signal_emitted(poi, "landing_zone_exited")

func test_signal_carries_poi_reference() -> void:
	watch_signals(poi)
	poi.check_landing_proximity(Vector2.ZERO, 520.0)
	assert_signal_emitted_with_parameters(poi, "landing_zone_entered", [poi])

func test_no_signal_without_data() -> void:
	poi.data = null
	watch_signals(poi)
	poi.check_landing_proximity(Vector2.ZERO, 520.0)
	assert_signal_not_emitted(poi, "landing_zone_entered")
```

- [ ] **Step 3: Run tests to confirm the suite is now clean**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_point_of_interest.gd
git commit -m "fix: update test_point_of_interest to match two-argument proximity API"
```

---

## Task 2: Rename `_active` → `active` in BeaconSystem

`world.gd` needs to read `BeaconSystem.active` to decide between auto-land and button. The field is currently private (`_active`). Make it public.

**Files:**
- Modify: `src/systems/beacon_system.gd`

- [ ] **Step 1: Rename `_active` to `active` everywhere in the file**

Full updated `src/systems/beacon_system.gd`:

```gdscript
extends Node

const BEACON_SPEED: float = 400.0
const BEACON_DEPTH_SPEED: float = 300.0

var _ship: Ship = null
var _pois: Array = []
var active: bool = false
var _target: PointOfInterest = null

signal beacon_activated
signal beacon_deactivated

func register(ship: Ship, pois: Array) -> void:
	if _ship and _ship.fuel_changed.is_connected(_on_fuel_changed):
		_ship.fuel_changed.disconnect(_on_fuel_changed)
	_ship = ship
	_pois = pois
	ship.fuel_changed.connect(_on_fuel_changed)

func _process(delta: float) -> void:
	if not active or _target == null or _ship == null:
		return
	var dir: Vector2 = _target.position - _ship.position
	if dir.length() > 10.0:
		_ship.linear_velocity = dir.normalized() * BEACON_SPEED
	else:
		_ship.linear_velocity = Vector2.ZERO
	_ship.z_depth = move_toward(_ship.z_depth, _target.z_depth, BEACON_DEPTH_SPEED * delta)
	_ship.depth_changed.emit(_ship.z_depth)
	_target.check_landing_proximity(_ship.position, _ship.z_depth)

func _on_fuel_changed(value: float) -> void:
	if value <= 0.0 and GameState.has_landed_once and not active:
		_activate()

func _activate() -> void:
	_target = find_nearest(_ship.position, _ship.z_depth, _pois)
	if _target == null:
		return
	active = true
	ShipInput.suspended = true
	beacon_activated.emit()

func deactivate() -> void:
	active = false
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

- [ ] **Step 2: Run tests**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all tests still pass.

- [ ] **Step 3: Commit**

```bash
git add src/systems/beacon_system.gd
git commit -m "refactor: make BeaconSystem.active public"
```

---

## Task 3: Ship always depletes fuel

Remove the `GameState.has_landed_once` guards from fuel logic in `ship.gd`. Fuel burns from the first thrust; thrust is blocked at zero fuel from the start.

**Files:**
- Modify: `src/scenes/ship/ship.gd`
- Modify: `tests/unit/test_ship.gd`

- [ ] **Step 1: Write the new failing test**

Add this test to `tests/unit/test_ship.gd` (after the existing tests):

```gdscript
func test_fuel_depletes_even_before_first_landing() -> void:
	GameState.has_landed_once = false
	ship.thrust_input = Vector2(1.0, 0.0)
	ship._physics_process(1.0)
	assert_lt(ship.fuel, 100.0)
```

- [ ] **Step 2: Run the new test to confirm it fails**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: `test_fuel_depletes_even_before_first_landing` FAILS.

- [ ] **Step 3: Remove the `has_landed_once` guards from `ship.gd`**

Replace the `_handle_thrust` method in `src/scenes/ship/ship.gd`:

```gdscript
func _handle_thrust(delta: float) -> void:
	if thrust_input == Vector2.ZERO:
		return
	if fuel <= 0.0:
		return
	apply_central_force(thrust_input.normalized() * data.thrust_power)
	fuel = maxf(0.0, fuel - data.fuel_burn_rate * delta)
	fuel_changed.emit(fuel)
```

- [ ] **Step 4: Remove the now-contradicting test and run the suite**

In `tests/unit/test_ship.gd`, delete the `test_fuel_not_depleted_before_first_landing` function entirely (it tested the old behavior and will now fail). The `test_fuel_depletes_after_first_landing` test still passes since `has_landed_once = true` doesn't affect fuel any more — leave it in place.

Then run:

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all tests pass, including `test_fuel_depletes_even_before_first_landing`.

- [ ] **Step 5: Commit**

```bash
git add src/scenes/ship/ship.gd tests/unit/test_ship.gd
git commit -m "feat: fuel always depletes regardless of first-landing state"
```

---

## Task 4: Beacon activates without `has_landed_once`

Remove the `GameState.has_landed_once` guard from beacon activation. Beacon rescues the player at zero fuel from the very first play session.

**Files:**
- Modify: `src/systems/beacon_system.gd`
- Modify: `tests/unit/test_beacon_system.gd`

- [ ] **Step 1: Write the new failing test**

Replace the full `tests/unit/test_beacon_system.gd` with:

```gdscript
extends GutTest

func after_each() -> void:
	BeaconSystem.deactivate()
	ShipInput.suspended = false

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

func test_beacon_activates_at_zero_fuel_before_first_landing() -> void:
	var ship := preload("res://src/scenes/ship/ship.tscn").instantiate()
	var data := ShipData.new()
	data.max_fuel = 100.0
	data.max_hull = 100.0
	ship.data = data
	add_child(ship)
	var poi := preload("res://src/scenes/poi/point_of_interest.tscn").instantiate()
	poi.data = POIData.new()
	add_child(poi)
	GameState.has_landed_once = false
	BeaconSystem.register(ship, [poi])
	ship.fuel_changed.emit(0.0)
	assert_true(BeaconSystem.active)
	ship.queue_free()
	poi.queue_free()
	GameState.has_landed_once = false
```

- [ ] **Step 2: Run the new test to confirm it fails**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: `test_beacon_activates_at_zero_fuel_before_first_landing` FAILS.

- [ ] **Step 3: Remove the `has_landed_once` guard in `beacon_system.gd`**

Change `_on_fuel_changed` in `src/systems/beacon_system.gd`:

```gdscript
func _on_fuel_changed(value: float) -> void:
	if value <= 0.0 and not active:
		_activate()
```

- [ ] **Step 4: Run tests**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/systems/beacon_system.gd tests/unit/test_beacon_system.gd
git commit -m "feat: beacon activates at zero fuel regardless of first-landing state"
```

---

## Task 5: HUD LandButton

Replace the passive `LandingLabel` in the HUD with an active `Button` that emits `land_requested` when pressed.

**Files:**
- Modify: `src/scenes/ui/hud.tscn`
- Modify: `src/scenes/ui/hud.gd`
- Create: `tests/unit/test_hud.gd`

- [ ] **Step 1: Write the failing HUD tests**

Create `tests/unit/test_hud.gd`:

```gdscript
extends GutTest

var hud: HUD

func before_each() -> void:
	hud = preload("res://src/scenes/ui/hud.tscn").instantiate()
	add_child(hud)

func after_each() -> void:
	hud.queue_free()

func test_land_button_emits_land_requested_when_pressed() -> void:
	watch_signals(hud)
	hud.land_button.emit_signal("pressed")
	assert_signal_emitted(hud, "land_requested")

func test_show_land_button_true_makes_button_visible() -> void:
	hud.show_land_button(true)
	assert_true(hud.land_button.visible)

func test_show_land_button_false_hides_button() -> void:
	hud.show_land_button(true)
	hud.show_land_button(false)
	assert_false(hud.land_button.visible)
```

- [ ] **Step 2: Run the new tests to confirm they fail**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all three new HUD tests FAIL (node/method not found).

- [ ] **Step 3: Update `hud.tscn` — replace LandingLabel with LandButton**

In `src/scenes/ui/hud.tscn`, find and replace the `LandingLabel` node block:

Old:
```
[node name="LandingLabel" type="Label" parent="."]
anchor_left = 0.5
anchor_right = 0.5
anchor_bottom = 1.0
anchor_top = 1.0
offset_top = -60.0
text = "▼ APPROACH TO LAND"
visible = false
```

New:
```
[node name="LandButton" type="Button" parent="."]
anchor_left = 0.5
anchor_right = 0.5
anchor_bottom = 1.0
anchor_top = 1.0
offset_left = -80.0
offset_right = 80.0
offset_top = -80.0
offset_bottom = -45.0
text = "▼ LAND"
visible = false
```

- [ ] **Step 4: Update `hud.gd`**

Full updated `src/scenes/ui/hud.gd`:

```gdscript
class_name HUD
extends CanvasLayer

@onready var depth_label: Label = $VBoxContainer/DepthLabel
@onready var fuel_bar: ProgressBar = $VBoxContainer/FuelBar
@onready var hull_bar: ProgressBar = $VBoxContainer/HullBar
@onready var speed_label: Label = $VBoxContainer/SpeedLabel
@onready var land_button: Button = $LandButton
@onready var nav_label: Label = $NavLabel
@onready var beacon_label: Label = $BeaconLabel
@onready var mini_map: MiniMap = $MiniMap

signal land_requested

var _ship: Ship = null
var _pois: Array[PointOfInterest] = []

func _ready() -> void:
	land_button.pressed.connect(func(): land_requested.emit())

func connect_to_ship(ship: Ship) -> void:
	assert(ship.data != null, "HUD.connect_to_ship: Ship must have ShipData assigned")
	_ship = ship
	fuel_bar.max_value = ship.data.max_fuel
	hull_bar.max_value = ship.data.max_hull
	fuel_bar.value = ship.fuel
	hull_bar.value = ship.hull
	depth_label.text = "Depth: %d" % int(ship.z_depth)
	ship.fuel_changed.connect(_on_fuel_changed)
	ship.hull_changed.connect(_on_hull_changed)
	ship.depth_changed.connect(_on_depth_changed)

func connect_to_world(ship: Ship, pois: Array[PointOfInterest]) -> void:
	_pois = pois
	mini_map.connect_to_world(ship, pois)
	nav_label.visible = not pois.is_empty()

func show_land_button(show: bool) -> void:
	land_button.visible = show

func show_beacon_active(active: bool) -> void:
	beacon_label.visible = active

func _process(_delta: float) -> void:
	if _ship == null:
		return
	speed_label.text = "SPD %d" % int(_ship.linear_velocity.length())
	if not _pois.is_empty():
		_update_nav()

func _update_nav() -> void:
	var nearest := _find_nearest_poi()
	if nearest == null or nearest.data == null:
		return
	var dir := nearest.position - _ship.position
	var dist := int(dir.length())
	var depth_diff := nearest.z_depth - _ship.z_depth
	var depth_hint: String
	var z_close := absf(depth_diff) <= nearest.data.landing_threshold
	var xy_close := dir.length() <= nearest.data.landing_xy_radius
	if z_close and xy_close:
		depth_hint = "LAND"
	elif depth_diff > 0:
		depth_hint = "▲Far"
	else:
		depth_hint = "▼Near"
	nav_label.text = "%s %s  %dm  %s" % [_dir_arrow(dir), nearest.data.poi_name, dist, depth_hint]

func _find_nearest_poi() -> PointOfInterest:
	var nearest: PointOfInterest = null
	var min_d := INF
	for poi: PointOfInterest in _pois:
		var d := Vector3(_ship.position.x, _ship.position.y, _ship.z_depth).distance_to(
			Vector3(poi.position.x, poi.position.y, poi.z_depth))
		if d < min_d:
			min_d = d
			nearest = poi
	return nearest

func _dir_arrow(dir: Vector2) -> String:
	if dir.length_squared() < 1.0:
		return "●"
	const ARROWS: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var idx := int(round(dir.angle() / (PI / 4.0))) % 8
	if idx < 0:
		idx += 8
	return ARROWS[idx]

func _on_fuel_changed(value: float) -> void:
	fuel_bar.value = value

func _on_hull_changed(value: float) -> void:
	hull_bar.value = value

func _on_depth_changed(value: float) -> void:
	depth_label.text = "Depth: %d" % int(value)
```

- [ ] **Step 5: Run tests**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all tests pass, including the three new HUD tests.

- [ ] **Step 6: Commit**

```bash
git add src/scenes/ui/hud.tscn src/scenes/ui/hud.gd tests/unit/test_hud.gd
git commit -m "feat: replace HUD landing label with LAND button emitting land_requested"
```

---

## Task 6: World manual/auto landing flow

Update `world.gd` to show the LAND button on proximity, auto-land when beacon is active, and trigger landing on button press.

**Files:**
- Modify: `src/scenes/world/world.gd`

- [ ] **Step 1: Update `world.gd`**

Full updated `src/scenes/world/world.gd`:

```gdscript
extends Node2D

@onready var ship: Ship = $Ship
@onready var hud: HUD = $HUD
@onready var landing_screen: LandingScreen = $LandingScreen

var _pois: Array[PointOfInterest] = []
var _poi_in_range: PointOfInterest = null

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
	hud.connect_to_world(ship, _pois)
	hud.land_requested.connect(_on_land_requested)
	BeaconSystem.register(ship, _pois)
	BeaconSystem.beacon_activated.connect(func(): hud.show_beacon_active(true))
	BeaconSystem.beacon_deactivated.connect(func(): hud.show_beacon_active(false))

func _process(_delta: float) -> void:
	for poi in _pois:
		poi.check_landing_proximity(ship.position, ship.z_depth)

func _on_landing_zone_entered(poi: PointOfInterest) -> void:
	_poi_in_range = poi
	if BeaconSystem.active:
		landing_screen.show_for(poi, ship)
	else:
		hud.show_land_button(true)

func _on_landing_zone_exited(_poi: PointOfInterest) -> void:
	_poi_in_range = null
	hud.show_land_button(false)

func _on_land_requested() -> void:
	if _poi_in_range == null:
		return
	landing_screen.show_for(_poi_in_range, ship)
	hud.show_land_button(false)
```

- [ ] **Step 2: Run full test suite**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add src/scenes/world/world.gd
git commit -m "feat: manual LAND button on proximity, auto-land on beacon arrival"
```

---

## Task 7: StarField class

New procedural `Node2D` that draws stars as filled circles at seeded-random positions. Added to parallax layers in the next task.

**Files:**
- Create: `src/scenes/world/star_field.gd`
- Create: `tests/unit/test_star_field.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_star_field.gd`:

```gdscript
extends GutTest

var sf: StarField

func before_each() -> void:
	sf = StarField.new()
	sf.star_count = 50
	sf.area = Vector2(1000.0, 500.0)
	sf.base_color = Color(1, 1, 1, 1)
	sf.min_size = 0.5
	sf.max_size = 2.0
	sf.seed_val = 42
	add_child(sf)

func after_each() -> void:
	sf.queue_free()

func test_generates_correct_star_count() -> void:
	assert_eq(sf._stars.size(), 50)

func test_all_stars_within_area() -> void:
	for star in sf._stars:
		assert_true(star["pos"].x >= 0.0 and star["pos"].x <= sf.area.x)
		assert_true(star["pos"].y >= 0.0 and star["pos"].y <= sf.area.y)

func test_different_seeds_produce_different_positions() -> void:
	var sf2 := StarField.new()
	sf2.star_count = 50
	sf2.area = Vector2(1000.0, 500.0)
	sf2.seed_val = 99
	add_child(sf2)
	assert_ne(sf._stars[0]["pos"], sf2._stars[0]["pos"])
	sf2.queue_free()
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all three StarField tests FAIL (class not found).

- [ ] **Step 3: Create `star_field.gd`**

Create `src/scenes/world/star_field.gd`:

```gdscript
class_name StarField
extends Node2D

@export var star_count: int = 100
@export var area: Vector2 = Vector2(2560, 1440)
@export var base_color: Color = Color(1, 1, 1, 1)
@export var min_size: float = 0.5
@export var max_size: float = 1.5
@export var seed_val: int = 0

var _stars: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	_stars.clear()
	for i in star_count:
		_stars.append({
			"pos": Vector2(rng.randf_range(0.0, area.x), rng.randf_range(0.0, area.y)),
			"size": rng.randf_range(min_size, max_size),
			"brightness": rng.randf_range(0.4, 1.0),
		})
	queue_redraw()

func _draw() -> void:
	for star in _stars:
		var c := Color(base_color.r, base_color.g, base_color.b,
			base_color.a * star["brightness"])
		draw_circle(star["pos"], star["size"], c)
```

- [ ] **Step 4: Run tests**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/scenes/world/star_field.gd tests/unit/test_star_field.gd
git commit -m "feat: add procedural StarField node for parallax star layers"
```

---

## Task 8: Space background decorations

Add three `StarField` nodes and two nebula `ColorRect`s to the existing parallax background.

**Files:**
- Modify: `src/scenes/world/space_background.tscn`

- [ ] **Step 1: Update `space_background.tscn`**

Replace the entire file content with:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/scenes/world/star_field.gd" id="1"]

[node name="SpaceBackground" type="ParallaxBackground"]

[node name="Layer0" type="ParallaxLayer" parent="."]
motion_scale = Vector2(0.02, 0.02)
motion_mirroring = Vector2(2560, 1440)

[node name="Bg0" type="ColorRect" parent="Layer0"]
color = Color(0.024, 0.024, 0.063, 1)
size = Vector2(2560, 1440)

[node name="Layer1" type="ParallaxLayer" parent="."]
motion_scale = Vector2(0.05, 0.05)
motion_mirroring = Vector2(2560, 1440)

[node name="Bg1" type="ColorRect" parent="Layer1"]
color = Color(0.031, 0.031, 0.125, 1)
size = Vector2(2560, 1440)

[node name="Stars1" type="Node2D" parent="Layer1"]
script = ExtResource("1")
star_count = 80
area = Vector2(2560, 1440)
base_color = Color(1, 1, 1, 1)
min_size = 0.5
max_size = 1.0
seed_val = 1

[node name="Layer2" type="ParallaxLayer" parent="."]
motion_scale = Vector2(0.12, 0.12)
motion_mirroring = Vector2(2560, 1440)

[node name="Bg2" type="ColorRect" parent="Layer2"]
color = Color(0.039, 0.039, 0.157, 1)
size = Vector2(2560, 1440)

[node name="Nebula1" type="ColorRect" parent="Layer2"]
color = Color(0.05, 0.08, 0.25, 0.07)
size = Vector2(800, 400)
position = Vector2(300, 200)

[node name="Layer3" type="ParallaxLayer" parent="."]
motion_scale = Vector2(0.25, 0.25)
motion_mirroring = Vector2(2560, 1440)

[node name="Bg3" type="ColorRect" parent="Layer3"]
color = Color(0.051, 0.031, 0.125, 1)
size = Vector2(2560, 1440)

[node name="Stars3" type="Node2D" parent="Layer3"]
script = ExtResource("1")
star_count = 150
area = Vector2(2560, 1440)
base_color = Color(1, 0.97, 0.9, 1)
min_size = 0.5
max_size = 1.5
seed_val = 2

[node name="Nebula2" type="ColorRect" parent="Layer3"]
color = Color(0.12, 0.04, 0.18, 0.06)
size = Vector2(600, 500)
position = Vector2(1400, 600)

[node name="Layer4" type="ParallaxLayer" parent="."]
motion_scale = Vector2(0.5, 0.5)
motion_mirroring = Vector2(2560, 1440)

[node name="Bg4" type="ColorRect" parent="Layer4"]
color = Color(0.031, 0.031, 0.031, 1)
size = Vector2(2560, 1440)

[node name="Layer5" type="ParallaxLayer" parent="."]
motion_scale = Vector2(0.9, 0.9)
motion_mirroring = Vector2(2560, 1440)

[node name="Bg5" type="ColorRect" parent="Layer5"]
color = Color(0.02, 0.02, 0.02, 1)
size = Vector2(2560, 1440)

[node name="Stars5" type="Node2D" parent="Layer5"]
script = ExtResource("1")
star_count = 40
area = Vector2(2560, 1440)
base_color = Color(0.85, 0.9, 1, 1)
min_size = 1.0
max_size = 2.0
seed_val = 3
```

- [ ] **Step 2: Run full test suite**

```bash
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add src/scenes/world/space_background.tscn
git commit -m "feat: add procedural stars and nebula patches to space background"
```
