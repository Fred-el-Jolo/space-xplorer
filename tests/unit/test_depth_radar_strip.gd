extends GutTest

var strip: DepthRadarStrip

func before_each() -> void:
	strip = DepthRadarStrip.new()
	strip.custom_minimum_size = Vector2(14.0, 400.0)
	strip.size = Vector2(14.0, 400.0)
	add_child(strip)

func after_each() -> void:
	strip.queue_free()

func test_depth_to_y_min_depth_maps_to_zero() -> void:
	var y: float = strip.depth_to_y(DepthSystem.MIN_Z_DEPTH)
	assert_almost_eq(y, 0.0, 0.5)

func test_depth_to_y_max_depth_maps_to_height() -> void:
	var y: float = strip.depth_to_y(DepthSystem.MAX_Z_DEPTH)
	assert_almost_eq(y, 400.0, 0.5)

func test_depth_to_y_midpoint() -> void:
	var mid_depth: float = (DepthSystem.MIN_Z_DEPTH + DepthSystem.MAX_Z_DEPTH) / 2.0
	var y: float = strip.depth_to_y(mid_depth)
	assert_almost_eq(y, 200.0, 1.0)

func test_is_near_threshold_within_500() -> void:
	assert_true(DepthRadarStrip.is_near_depth(100.0, 400.0))

func test_is_near_threshold_beyond_500() -> void:
	assert_false(DepthRadarStrip.is_near_depth(100.0, 700.0))
