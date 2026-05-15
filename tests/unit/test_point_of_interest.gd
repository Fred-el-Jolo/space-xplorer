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
