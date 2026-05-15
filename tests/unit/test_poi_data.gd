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
