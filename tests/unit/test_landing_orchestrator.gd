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
