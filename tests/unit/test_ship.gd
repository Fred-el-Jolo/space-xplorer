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
