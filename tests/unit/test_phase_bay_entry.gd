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
