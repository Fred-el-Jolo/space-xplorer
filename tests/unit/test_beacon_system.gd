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
