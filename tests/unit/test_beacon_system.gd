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
