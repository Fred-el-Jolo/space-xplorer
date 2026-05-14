# Space Xplorer MVP — Engine Setup & Ship Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Validate Godot 4 as the game engine by building a playable ship-control prototype — a ship that moves in 2D space with pseudo-3D depth simulation and can perform a landing approach on a planet, running on Android.

**Architecture:** The pseudo-3D effect is a pure math layer (`DepthSystem`) that scales sprites and sets draw order based on a `z_depth: float` per entity. Ship physics use Godot's `RigidBody2D` for X/Y momentum; depth (Z) is a custom float updated each frame. `WorldEntity` is a base class for depth-aware non-physics entities (Planet, etc.); Ship applies depth logic directly since it must extend `RigidBody2D`. A `ShipInput` autoload maps keyboard/touch actions to the ship each frame.

**Tech Stack:** Godot 4.3 LTS, GDScript (type-hinted), GUT 9.x (unit testing), Android SDK

**Scope:** MVP only — engine validation and ship control. Simulation systems (Economy, Factions, Universe, Missions) and Persistence are separate plans.

---

## File Map

| File | Responsibility |
|------|---------------|
| `project.godot` | Godot project config (created by editor, modified for settings/input map) |
| `.gitignore` | Exclude `.godot/` cache and build artefacts |
| `addons/gut/` | GUT 9.x test framework plugin |
| `tests/unit/smoke_test.gd` | GUT smoke test |
| `tests/unit/test_depth_system.gd` | DepthSystem unit tests |
| `tests/unit/test_world_entity.gd` | WorldEntity unit tests |
| `tests/unit/test_ship.gd` | Ship unit tests |
| `src/systems/depth_system.gd` | Static class — pure pseudo-3D math |
| `src/systems/ship_input.gd` | Autoload — maps input actions to active ship each frame |
| `src/entities/world_entity.gd` | Base class (extends Node2D) for depth-aware non-physics entities |
| `src/resources/ship_data.gd` | ShipData Resource definition |
| `src/resources/default_ship.tres` | Default ship configuration values |
| `src/scenes/ship/ship.gd` | Ship logic: thrust, fuel, hull, depth |
| `src/scenes/ship/ship.tscn` | Ship scene: RigidBody2D + CollisionShape2D + Sprite2D |
| `src/scenes/planets/planet.gd` | Planet: extends WorldEntity, emits landing proximity signals |
| `src/scenes/planets/planet.tscn` | Planet scene: WorldEntity + Sprite2D |
| `src/scenes/world/space_background.tscn` | ParallaxBackground with 6 depth layers |
| `src/scenes/world/world.gd` | World controller: wires ship → input → HUD, checks landing |
| `src/scenes/world/world.tscn` | Main scene: background + planet + ship + camera + HUD + touch controls |
| `src/scenes/ui/hud.gd` | HUD logic: connects to ship signals |
| `src/scenes/ui/hud.tscn` | HUD: CanvasLayer with depth/fuel/hull labels and landing prompt |
| `src/scenes/ui/touch_controls.gd` | Touch controls: hidden on desktop, shown on mobile |
| `src/scenes/ui/touch_controls.tscn` | On-screen D-pad and depth buttons via TouchScreenButton |

---

## Task 1: Bootstrap the Godot project

**Files:**
- Create: `project.godot` (via editor)
- Create/update: `.gitignore`

- [ ] **Step 1: Download Godot 4.3 LTS**

Go to `https://godotengine.org/download/archive/` and download **Godot 4.3 LTS — Standard (64-bit Linux)**. It's a single executable — extract it to wherever you keep your tools.

- [ ] **Step 2: Create the Godot project in the existing repo**

Launch Godot. In the Project Manager:
1. Click **New Project**
2. Set **Project Path** to `/home/ubuntu/Projects/space-xplorer`
3. Set **Project Name**: `space-xplorer`
4. Select **Renderer: Compatibility** (OpenGL ES 3 — broadest Android device coverage)
5. Click **Create & Edit**

Godot creates `project.godot` and opens the editor.

- [ ] **Step 3: Configure project display settings**

**Project → Project Settings → Display → Window:**

| Setting | Value |
|---------|-------|
| Size > Viewport Width | `1280` |
| Size > Viewport Height | `720` |
| Stretch > Mode | `canvas_items` |
| Stretch > Aspect | `expand` |

Close Project Settings.

- [ ] **Step 4: Create folder structure**

In the Godot **FileSystem** panel (bottom-left), right-click `res://` → **New Folder** to create:

```
addons/
src/
  systems/
  entities/
  resources/
  scenes/
    ship/
    planets/
    world/
    ui/
tests/
  unit/
assets/
  sprites/
    ships/
    planets/
    backgrounds/
```

- [ ] **Step 5: Update .gitignore**

```
# Godot cache (auto-generated, not source)
.godot/

# Android build artefacts
android/build/
*.apk
*.aab
```

- [ ] **Step 6: Commit**

```bash
git add project.godot .gitignore
git commit -m "feat: bootstrap Godot 4.3 LTS project"
```

---

## Task 2: Install GUT testing framework

**Files:**
- Create: `addons/gut/` (plugin files)
- Create: `tests/unit/smoke_test.gd`

- [ ] **Step 1: Download GUT 9.x**

Download the latest GUT 9.x release from `https://github.com/bitwes/Gut/releases`. Get the `.zip` asset (e.g. `gut-9.3.0.zip`) and extract it. Inside you'll find `addons/gut/`.

- [ ] **Step 2: Copy GUT into the project**

Substitute `~/Downloads/gut-9.3.0` with wherever you extracted the zip:

```bash
cp -r ~/Downloads/gut-9.3.0/addons/gut /home/ubuntu/Projects/space-xplorer/addons/
```

- [ ] **Step 3: Enable GUT in the editor**

**Project → Project Settings → Plugins** — find **GUT** and set status to **Enabled**. Close.

A **GUT** tab appears in the bottom panel of the editor.

- [ ] **Step 4: Write the smoke test**

Create `tests/unit/smoke_test.gd`:

```gdscript
extends GutTest

func test_gut_is_working() -> void:
    assert_true(true, "GUT is installed and running")

func test_basic_math() -> void:
    assert_eq(1 + 1, 2, "Basic arithmetic works")
```

- [ ] **Step 5: Run the smoke test**

In the **GUT** panel:
1. Set **Directories** to `res://tests/`
2. Click **Run All**

Expected output:
```
smoke_test.gd
  test_gut_is_working  PASSED
  test_basic_math      PASSED
2 passed  0 failed
```

- [ ] **Step 6: Commit**

```bash
git add addons/gut/ tests/unit/smoke_test.gd
git commit -m "feat: add GUT 9.x testing framework"
```

---

## Task 3: Implement DepthSystem

**Files:**
- Create: `src/systems/depth_system.gd`
- Create: `tests/unit/test_depth_system.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_depth_system.gd`:

```gdscript
extends GutTest

func test_scale_at_base_depth() -> void:
    # BASE_SCALE is 100.0, so at z_depth=100 scale should be 1.0
    assert_almost_eq(DepthSystem.compute_scale(100.0), 1.0, 0.001)

func test_scale_nearer_is_larger() -> void:
    var near: float = DepthSystem.compute_scale(50.0)
    var far: float = DepthSystem.compute_scale(200.0)
    assert_gt(near, far)

func test_scale_does_not_divide_by_zero() -> void:
    var result: float = DepthSystem.compute_scale(0.0)
    assert_gt(result, 0.0)

func test_draw_order_farther_is_lower() -> void:
    var near: int = DepthSystem.compute_draw_order(100.0)
    var far: int = DepthSystem.compute_draw_order(500.0)
    assert_lt(far, near)

func test_visible_within_max_depth() -> void:
    assert_true(DepthSystem.is_visible(5000.0))

func test_invisible_beyond_max_depth() -> void:
    assert_false(DepthSystem.is_visible(15000.0))

func test_y_offset_deeper_is_higher_on_screen() -> void:
    var shallow: float = DepthSystem.compute_y_offset(0.0, 100.0)
    var deep: float = DepthSystem.compute_y_offset(0.0, 500.0)
    assert_lt(deep, shallow)
```

- [ ] **Step 2: Run tests — verify they fail**

Click **Run All** in the GUT panel.

Expected: 7 errors — `DepthSystem` identifier not found.

- [ ] **Step 3: Implement DepthSystem**

Create `src/systems/depth_system.gd`:

```gdscript
class_name DepthSystem

const BASE_SCALE: float = 100.0
const PERSPECTIVE_FACTOR: float = 0.3
const MAX_Z_DEPTH: float = 10000.0
const MIN_Z_DEPTH: float = 1.0

static func compute_scale(z_depth: float) -> float:
    return BASE_SCALE / maxf(z_depth, MIN_Z_DEPTH)

static func compute_y_offset(world_y: float, z_depth: float) -> float:
    return world_y - (z_depth * PERSPECTIVE_FACTOR)

static func compute_draw_order(z_depth: float) -> int:
    return -int(z_depth)

static func is_visible(z_depth: float) -> bool:
    return z_depth <= MAX_Z_DEPTH
```

- [ ] **Step 4: Run tests — verify they pass**

Expected:
```
test_depth_system.gd
  test_scale_at_base_depth           PASSED
  test_scale_nearer_is_larger        PASSED
  test_scale_does_not_divide_by_zero PASSED
  test_draw_order_farther_is_lower   PASSED
  test_visible_within_max_depth      PASSED
  test_invisible_beyond_max_depth    PASSED
  test_y_offset_deeper_is_higher_on_screen  PASSED
7 passed  0 failed
```

- [ ] **Step 5: Commit**

```bash
git add src/systems/depth_system.gd tests/unit/test_depth_system.gd
git commit -m "feat: implement DepthSystem pseudo-3D math"
```

---

## Task 4: Create WorldEntity base class and Planet scene

**Files:**
- Create: `src/entities/world_entity.gd`
- Create: `src/scenes/planets/planet.gd`
- Create: `src/scenes/planets/planet.tscn`
- Create: `tests/unit/test_world_entity.gd`

- [ ] **Step 1: Write failing tests for WorldEntity**

Create `tests/unit/test_world_entity.gd`:

```gdscript
extends GutTest

var entity: WorldEntity

func before_each() -> void:
    entity = WorldEntity.new()
    entity.z_depth = 100.0
    add_child(entity)

func after_each() -> void:
    entity.queue_free()

func test_apply_depth_scale_at_100() -> void:
    entity.z_depth = 100.0
    entity._apply_depth()
    assert_almost_eq(entity.scale.x, 1.0, 0.001)

func test_apply_depth_scale_at_200() -> void:
    entity.z_depth = 200.0
    entity._apply_depth()
    assert_almost_eq(entity.scale.x, 0.5, 0.001)

func test_apply_depth_sets_z_index() -> void:
    entity.z_depth = 250.0
    entity._apply_depth()
    assert_eq(entity.z_index, -250)

func test_entity_hidden_beyond_max_depth() -> void:
    entity.z_depth = 15000.0
    entity._apply_depth()
    assert_false(entity.visible)

func test_entity_visible_within_max_depth() -> void:
    entity.z_depth = 500.0
    entity._apply_depth()
    assert_true(entity.visible)
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: errors — `WorldEntity` not found.

- [ ] **Step 3: Implement WorldEntity**

Create `src/entities/world_entity.gd`:

```gdscript
class_name WorldEntity
extends Node2D

@export var z_depth: float = 1000.0

func _process(_delta: float) -> void:
    _apply_depth()

func _apply_depth() -> void:
    scale = Vector2.ONE * DepthSystem.compute_scale(z_depth)
    z_index = DepthSystem.compute_draw_order(z_depth)
    visible = DepthSystem.is_visible(z_depth)
```

- [ ] **Step 4: Run tests — verify they pass**

Expected: 5 passed, 0 failed.

- [ ] **Step 5: Create the Planet scene in the editor**

1. **Scene → New Scene**, root node: **Node2D**, rename to `Planet`
2. Right-click `Planet` → **Attach Script** → path: `res://src/scenes/planets/planet.gd` → Create
3. Add child node: **Sprite2D**, rename to `Sprite`
   - In inspector under `Texture`: create a **New PlaceholderTexture2D** sized `128×128`
4. Save as `res://src/scenes/planets/planet.tscn`

- [ ] **Step 6: Implement planet.gd**

Create `src/scenes/planets/planet.gd`:

```gdscript
class_name Planet
extends WorldEntity

@export var planet_name: String = "Unknown Planet"
@export var landing_threshold: float = 50.0

signal landing_zone_entered(planet: Planet)
signal landing_zone_exited(planet: Planet)

var _player_in_range: bool = false

func check_landing_proximity(ship_z_depth: float) -> void:
    var in_range: bool = ship_z_depth <= z_depth + landing_threshold
    if in_range and not _player_in_range:
        _player_in_range = true
        landing_zone_entered.emit(self)
    elif not in_range and _player_in_range:
        _player_in_range = false
        landing_zone_exited.emit(self)
```

- [ ] **Step 7: Commit**

```bash
git add src/entities/world_entity.gd src/scenes/planets/ tests/unit/test_world_entity.gd
git commit -m "feat: add WorldEntity base class and Planet scene"
```

---

## Task 5: Create ShipData resource and Ship scene

**Files:**
- Create: `src/resources/ship_data.gd`
- Create: `src/resources/default_ship.tres`
- Create: `src/scenes/ship/ship.gd`
- Create: `src/scenes/ship/ship.tscn`
- Create: `tests/unit/test_ship.gd`

- [ ] **Step 1: Write failing tests for Ship**

Create `tests/unit/test_ship.gd`:

```gdscript
extends GutTest

var ship: Ship
var data: ShipData

func before_each() -> void:
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

func test_fuel_depletes_when_thrusting() -> void:
    ship.thrust_input = Vector2(1.0, 0.0)
    ship._physics_process(1.0)
    assert_lt(ship.fuel, 100.0)

func test_fuel_unchanged_when_empty() -> void:
    ship.fuel = 0.0
    ship.thrust_input = Vector2(1.0, 0.0)
    ship._physics_process(1.0)
    assert_eq(ship.fuel, 0.0)
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: errors — `Ship` and `ShipData` not found.

- [ ] **Step 3: Implement ShipData**

Create `src/resources/ship_data.gd`:

```gdscript
class_name ShipData
extends Resource

@export var max_fuel: float = 100.0
@export var max_hull: float = 100.0
@export var thrust_power: float = 500.0
@export var depth_speed: float = 50.0
@export var fuel_burn_rate: float = 5.0
@export var linear_damp_value: float = 1.5
```

- [ ] **Step 4: Create the Ship scene in the editor**

1. **Scene → New Scene**, root node: **RigidBody2D**, rename to `Ship`
2. In the RigidBody2D inspector:
   - **Gravity Scale**: `0` (zero gravity — we're in space)
   - **Linear Damp**: `1.5`
3. Add child: **CollisionShape2D** — in inspector, Shape: **New CapsuleShape2D** (radius `20`, height `60`)
4. Add child: **Sprite2D**, rename to `Sprite` — assign a **New PlaceholderTexture2D** sized `64×64`
5. Right-click `Ship` root → **Attach Script** → `res://src/scenes/ship/ship.gd` → Create
6. Save as `res://src/scenes/ship/ship.tscn`

- [ ] **Step 5: Implement ship.gd**

Create `src/scenes/ship/ship.gd`:

```gdscript
class_name Ship
extends RigidBody2D

@export var data: ShipData

var z_depth: float = 5000.0
var fuel: float = 0.0
var hull: float = 0.0

var thrust_input: Vector2 = Vector2.ZERO
var depth_input: float = 0.0

signal fuel_changed(value: float)
signal hull_changed(value: float)
signal depth_changed(value: float)

func _ready() -> void:
    if data:
        fuel = data.max_fuel
        hull = data.max_hull
        linear_damp = data.linear_damp_value

func _physics_process(delta: float) -> void:
    _handle_thrust(delta)
    _handle_depth(delta)
    _apply_depth_visual()

func _handle_thrust(delta: float) -> void:
    if thrust_input == Vector2.ZERO or fuel <= 0.0:
        return
    apply_central_force(thrust_input.normalized() * data.thrust_power)
    fuel = maxf(0.0, fuel - data.fuel_burn_rate * delta)
    fuel_changed.emit(fuel)

func _handle_depth(delta: float) -> void:
    if depth_input == 0.0:
        return
    z_depth = clampf(
        z_depth + depth_input * data.depth_speed * delta,
        DepthSystem.MIN_Z_DEPTH,
        DepthSystem.MAX_Z_DEPTH
    )
    depth_changed.emit(z_depth)

func _apply_depth_visual() -> void:
    scale = Vector2.ONE * DepthSystem.compute_scale(z_depth)
    z_index = DepthSystem.compute_draw_order(z_depth)
    visible = DepthSystem.is_visible(z_depth)
```

- [ ] **Step 6: Create default_ship.tres in the editor**

In the Godot **FileSystem** panel:
1. Right-click `res://src/resources/` → **New Resource**
2. Search for and select **ShipData**
3. In the inspector, set the values:
   - max_fuel: `100.0`, max_hull: `100.0`, thrust_power: `500.0`
   - depth_speed: `50.0`, fuel_burn_rate: `5.0`, linear_damp_value: `1.5`
4. **Ctrl+S** → save as `res://src/resources/default_ship.tres`

- [ ] **Step 7: Run tests — verify they pass**

Expected: 8 passed, 0 failed.

- [ ] **Step 8: Commit**

```bash
git add src/resources/ src/scenes/ship/ tests/unit/test_ship.gd
git commit -m "feat: add ShipData resource and Ship scene with physics"
```

---

## Task 6: Implement input handling

**Files:**
- Modify: `project.godot` (input map — via editor)
- Create: `src/systems/ship_input.gd`

- [ ] **Step 1: Define input actions**

**Project → Project Settings → Input Map** tab. For each row below: type the action name → **Add** → click **+** → press the key(s).

| Action | Keys |
|--------|------|
| `ship_left` | A, Left Arrow |
| `ship_right` | D, Right Arrow |
| `ship_up` | W, Up Arrow |
| `ship_down` | S, Down Arrow |
| `ship_depth_in` | Q |
| `ship_depth_out` | E |

Close Project Settings.

- [ ] **Step 2: Implement ship_input.gd**

Create `src/systems/ship_input.gd`:

```gdscript
class_name ShipInput
extends Node

var ship: Ship = null

func _process(_delta: float) -> void:
    if not ship:
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
    return dir

func _read_depth() -> float:
    if Input.is_action_pressed("ship_depth_in"):
        return -1.0
    if Input.is_action_pressed("ship_depth_out"):
        return 1.0
    return 0.0
```

- [ ] **Step 3: Register ShipInput as an Autoload**

**Project → Project Settings → Autoloads** tab:
1. Click the folder icon → select `res://src/systems/ship_input.gd`
2. Name: `ShipInput`
3. Click **Add**

It is now available globally as `ShipInput` in every script.

- [ ] **Step 4: Commit**

```bash
git add src/systems/ship_input.gd project.godot
git commit -m "feat: add ShipInput autoload with keyboard actions"
```

---

## Task 7: Assemble world scene with parallax background and star light

**Files:**
- Create: `src/scenes/world/space_background.tscn`
- Create: `src/scenes/world/world.gd`
- Create: `src/scenes/world/world.tscn`

- [ ] **Step 1: Create the SpaceBackground scene**

1. **Scene → New Scene**, root: **ParallaxBackground**, rename to `SpaceBackground`
2. Add 6 **ParallaxLayer** child nodes (`Layer0`–`Layer5`)
3. For each, set **Motion > Scale** in the inspector:

| Node | Motion Scale | Child node | Size | Color |
|------|-------------|------------|------|-------|
| Layer0 | `(0.02, 0.02)` | ColorRect | 2560×1440 | `#060610` (near-black deep space) |
| Layer1 | `(0.05, 0.05)` | ColorRect | 2560×1440 | `#080820` (faint far stars — use sprite later) |
| Layer2 | `(0.12, 0.12)` | ColorRect | 2560×1440 | `#0a0a28` |
| Layer3 | `(0.25, 0.25)` | ColorRect | 2560×1440 | `#0d0820` (gas cloud tint) |
| Layer4 | `(0.5, 0.5)` | ColorRect | 2560×1440 | `#080808` |
| Layer5 | `(0.9, 0.9)` | ColorRect | 2560×1440 | `#050505` |

The ColorRect placeholder — each one sized at 2×viewport so it doesn't show edges when panning.

4. Save as `res://src/scenes/world/space_background.tscn`

- [ ] **Step 2: Create the World scene**

1. **Scene → New Scene**, root: **Node2D**, rename to `World`
2. Add children (order matters for draw layering):
   - Instance `res://src/scenes/world/space_background.tscn`
   - Instance `res://src/scenes/planets/planet.tscn` — rename to `Planet`, position `(640, 360)`
   - Instance `res://src/scenes/ship/ship.tscn` — rename to `Ship`, position `(640, 500)`
     - In Ship inspector, set **Data** → `res://src/resources/default_ship.tres`
   - **Camera2D** — rename to `Camera`
     - Enable **Position Smoothing** (toggle the checkbox)
     - Drag the `Camera2D` node onto the `Ship` node in the scene tree to make it a child of Ship (the camera follows the ship)
3. Right-click `World` root → **Attach Script** → `res://src/scenes/world/world.gd` → Create
4. Save as `res://src/scenes/world/world.tscn`

- [ ] **Step 3: Add star lighting (PointLight2D)**

In the World scene:
1. Add a **PointLight2D** node as child of World, rename to `StarLight`
2. Position at `(-400, -300)` (off-screen, simulates a distant star from top-left)
3. In inspector:
   - **Texture**: built-in `WhiteCircle` gradient texture
   - **Energy**: `1.2`
   - **Range > Height**: `0` (directional-ish at height 0)
   - **Range > Item Cull Mask**: `1`
4. Normal maps on sprites will be lit by this automatically when real sprites are added.

- [ ] **Step 4: Implement world.gd**

Create `src/scenes/world/world.gd`:

```gdscript
extends Node2D

@onready var ship: Ship = $Ship
@onready var planet: Planet = $Planet

func _ready() -> void:
    ShipInput.ship = ship
    planet.landing_zone_entered.connect(_on_landing_zone_entered)
    planet.landing_zone_exited.connect(_on_landing_zone_exited)

func _process(_delta: float) -> void:
    planet.check_landing_proximity(ship.z_depth)

func _on_landing_zone_entered(p: Planet) -> void:
    print("Entering landing zone: ", p.planet_name)

func _on_landing_zone_exited(p: Planet) -> void:
    print("Exiting landing zone: ", p.planet_name)
```

- [ ] **Step 5: Set world.tscn as the main scene**

**Project → Project Settings → Application → Run → Main Scene** → select `res://src/scenes/world/world.tscn`

- [ ] **Step 6: Run in the editor — verify basic flight**

Press **F5**. Verify:
- Dark space background visible
- Ship placeholder at center
- Planet placeholder at center
- WASD/arrows move the ship with momentum (it drifts and slows — that's the linear damp)
- Q: planet sprite grows (approaching) — E: shrinks (retreating)
- Parallax background layers move at different rates as the ship moves
- Console prints "Entering landing zone" when Q is held long enough

- [ ] **Step 7: Commit**

```bash
git add src/scenes/world/ project.godot
git commit -m "feat: assemble world scene with parallax background, star light, and ship flight"
```

---

## Task 8: Add HUD

**Files:**
- Create: `src/scenes/ui/hud.gd`
- Create: `src/scenes/ui/hud.tscn`
- Modify: `src/scenes/world/world.tscn` (add HUD as child)
- Modify: `src/scenes/world/world.gd` (wire HUD)

- [ ] **Step 1: Create the HUD scene**

1. **Scene → New Scene**, root: **CanvasLayer** (renders above game world), rename to `HUD`
2. Add a **VBoxContainer** child — anchor preset: **Top Left**, position `(20, 20)`
   - Add **Label**, name `DepthLabel`, text: `Depth: 5000`
   - Add **Label**, name `FuelLabel`, text: `Fuel`
   - Add **ProgressBar**, name `FuelBar`, min `0`, max `100`, value `100`, size `(200, 20)`
   - Add **Label**, name `HullLabel`, text: `Hull`
   - Add **ProgressBar**, name `HullBar`, min `0`, max `100`, value `100`, size `(200, 20)`
3. Add a **Label** child of `HUD` (not VBox), name `LandingLabel`, text: `▼ APPROACH TO LAND`
   - Anchor preset: **Bottom Center**, position `(0, -60)`
   - Visible: `false`
4. Right-click `HUD` → **Attach Script** → `res://src/scenes/ui/hud.gd` → Create
5. Add `class_name HUD` at the top of the script (needed so world.gd can type-hint it)
6. Save as `res://src/scenes/ui/hud.tscn`

- [ ] **Step 2: Implement hud.gd**

Create `src/scenes/ui/hud.gd`:

```gdscript
class_name HUD
extends CanvasLayer

@onready var depth_label: Label = $VBoxContainer/DepthLabel
@onready var fuel_bar: ProgressBar = $VBoxContainer/FuelBar
@onready var hull_bar: ProgressBar = $VBoxContainer/HullBar
@onready var landing_label: Label = $LandingLabel

func connect_to_ship(ship: Ship) -> void:
    fuel_bar.max_value = ship.data.max_fuel
    hull_bar.max_value = ship.data.max_hull
    fuel_bar.value = ship.fuel
    hull_bar.value = ship.hull
    depth_label.text = "Depth: %d" % int(ship.z_depth)
    ship.fuel_changed.connect(_on_fuel_changed)
    ship.hull_changed.connect(_on_hull_changed)
    ship.depth_changed.connect(_on_depth_changed)

func show_landing_prompt(show: bool) -> void:
    landing_label.visible = show

func _on_fuel_changed(value: float) -> void:
    fuel_bar.value = value

func _on_hull_changed(value: float) -> void:
    hull_bar.value = value

func _on_depth_changed(value: float) -> void:
    depth_label.text = "Depth: %d" % int(value)
```

- [ ] **Step 3: Add HUD to World scene and wire it**

In `src/scenes/world/world.tscn`: instance `res://src/scenes/ui/hud.tscn` as a child of `World`, rename to `HUD`.

Update `src/scenes/world/world.gd`:

```gdscript
extends Node2D

@onready var ship: Ship = $Ship
@onready var planet: Planet = $Planet
@onready var hud: HUD = $HUD

func _ready() -> void:
    ShipInput.ship = ship
    hud.connect_to_ship(ship)
    planet.landing_zone_entered.connect(_on_landing_zone_entered)
    planet.landing_zone_exited.connect(_on_landing_zone_exited)

func _process(_delta: float) -> void:
    planet.check_landing_proximity(ship.z_depth)

func _on_landing_zone_entered(p: Planet) -> void:
    hud.show_landing_prompt(true)
    print("Entering landing zone: ", p.planet_name)

func _on_landing_zone_exited(p: Planet) -> void:
    hud.show_landing_prompt(false)
    print("Exiting landing zone: ", p.planet_name)
```

- [ ] **Step 4: Run in the editor — verify HUD**

Press **F5**. Verify:
- Fuel bar fills the full width initially
- Fuel bar depletes as you hold WASD
- Depth label counts down as you press Q
- "APPROACH TO LAND" label appears near the bottom when sufficiently close to planet

- [ ] **Step 5: Commit**

```bash
git add src/scenes/ui/hud.tscn src/scenes/ui/hud.gd src/scenes/world/
git commit -m "feat: add HUD with fuel, hull, depth, and landing prompt"
```

---

## Task 9: Add touch controls and export to Android

**Files:**
- Create: `src/scenes/ui/touch_controls.gd`
- Create: `src/scenes/ui/touch_controls.tscn`
- Modify: `src/scenes/world/world.tscn`

- [ ] **Step 1: Create the TouchControls scene**

`TouchScreenButton` nodes fire the same input actions already defined — `ShipInput` reads them automatically, no code changes needed.

1. **Scene → New Scene**, root: **CanvasLayer**, rename to `TouchControls`
2. Add 6 **TouchScreenButton** nodes. For each:
   - Set **Action** to the action name
   - Enable **Passby Press** (allows sliding between buttons without lifting finger)
   - Add a **Label** child for the button text (set to `Anchor: Center`)
   - Set a **Normal** texture or leave as default (Godot renders a default shape)

| Name | Action | Position | Label text |
|------|--------|----------|-----------|
| `BtnLeft` | `ship_left` | `(60, 580)` | `←` |
| `BtnRight` | `ship_right` | `(180, 580)` | `→` |
| `BtnUp` | `ship_up` | `(120, 500)` | `↑` |
| `BtnDown` | `ship_down` | `(120, 660)` | `↓` |
| `BtnApproach` | `ship_depth_in` | `(1100, 540)` | `▼ Near` |
| `BtnRetreat` | `ship_depth_out` | `(1100, 620)` | `▲ Far` |

3. Attach script `res://src/scenes/ui/touch_controls.gd`
4. Save as `res://src/scenes/ui/touch_controls.tscn`

- [ ] **Step 2: Implement touch_controls.gd**

Create `src/scenes/ui/touch_controls.gd`:

```gdscript
extends CanvasLayer

func _ready() -> void:
    # Show only on mobile — keyboard controls handle desktop
    visible = OS.has_feature("mobile") or OS.has_feature("web")
```

- [ ] **Step 3: Add TouchControls to World scene**

In `src/scenes/world/world.tscn`: instance `res://src/scenes/ui/touch_controls.tscn` as a child of `World`. No code change to world.gd needed.

- [ ] **Step 4: Configure Android export in Godot**

First, verify Android SDK is installed on the machine:

```bash
# Check for common SDK location
ls ~/Android/Sdk/platform-tools/adb
```

If missing, install via Android Studio or `sdkmanager`.

In Godot:
1. **Editor → Editor Settings → Export → Android**:
   - **Android SDK Path**: set to your SDK root (e.g., `/home/ubuntu/Android/Sdk`)
   - **Debug Keystore**: click **Generate** if empty
2. **Project → Export → Add → Android**
3. In the export preset configure:
   - **Package/Unique Name**: `com.spacexplorer.game`
   - **Version/Name**: `0.1.0`
   - **Version/Code**: `1`
   - **Min SDK**: `26`
   - **Target SDK**: `34`
4. Under **Gradle Build**, click **Install Android Build Template** (first time only — downloads Gradle wrapper)

- [ ] **Step 5: Build and install the APK**

In the Export dialog: click **Export Project** → save as `space-xplorer-debug.apk` in the project root.

Then install:

```bash
adb install /home/ubuntu/Projects/space-xplorer/space-xplorer-debug.apk
```

Expected: `Success` message from adb.

- [ ] **Step 6: Validate on device**

Launch the game. Test all of the following:

- [ ] Ship moves with D-pad buttons
- [ ] Near/Far buttons change planet scale
- [ ] Parallax background shifts as ship moves
- [ ] Fuel bar depletes when thrusting
- [ ] Depth label updates as planet is approached
- [ ] "APPROACH TO LAND" appears at close range
- [ ] No crashes on startup or after 5 minutes of play
- [ ] Performance: hold for 60fps (enable Godot remote profiler via USB: **Debug → Deploy with Remote Debug**)

- [ ] **Step 7: Commit**

```bash
git add src/scenes/ui/touch_controls.tscn src/scenes/ui/touch_controls.gd src/scenes/world/
git commit -m "feat: add touch controls and validate Android export"
```

---

## What's next

This plan delivers the MVP: Godot 4 confirmed working, pseudo-3D depth system validated, ship flyable and landable on Android. The follow-on plans are:

- **Plan 2** — Universe generation, Economy, Factions, Missions (simulation layer)
- **Plan 3** — Persistence: local save/load system
- **Plan 4** — Chronicle system (emergent narrative)
