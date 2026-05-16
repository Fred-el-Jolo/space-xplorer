extends GutTest

func test_tilt_in_green_zone() -> void:
	assert_true(PhaseTouchdown.tilt_ok(0.0))
	assert_true(PhaseTouchdown.tilt_ok(0.19))

func test_tilt_outside_green_zone() -> void:
	assert_false(PhaseTouchdown.tilt_ok(0.21))
	assert_false(PhaseTouchdown.tilt_ok(-0.21))

func test_descent_bar_green_window_last_25_percent() -> void:
	assert_true(PhaseTouchdown.in_cut_window(0.76))
	assert_true(PhaseTouchdown.in_cut_window(1.0))

func test_descent_bar_outside_green_window() -> void:
	assert_false(PhaseTouchdown.in_cut_window(0.74))
	assert_false(PhaseTouchdown.in_cut_window(0.0))

func test_ship_centred_in_pad() -> void:
	var pad := Rect2(100.0, 100.0, 160.0, 130.0)
	var ship_pos := Vector2(180.0, 165.0)
	assert_true(PhaseTouchdown.ship_centred(ship_pos, pad, 14.0))

func test_ship_outside_pad() -> void:
	var pad := Rect2(100.0, 100.0, 160.0, 130.0)
	var ship_pos := Vector2(50.0, 165.0)
	assert_false(PhaseTouchdown.ship_centred(ship_pos, pad, 14.0))
