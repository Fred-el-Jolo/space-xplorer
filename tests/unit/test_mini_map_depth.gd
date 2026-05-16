extends GutTest

func test_radius_at_zero_depth_dist_is_max() -> void:
	var r := MiniMap.depth_dot_radius(0.0)
	assert_almost_eq(r, 6.0, 0.01)

func test_radius_at_2000_depth_dist_is_min() -> void:
	var r := MiniMap.depth_dot_radius(2000.0)
	assert_almost_eq(r, 2.0, 0.01)

func test_radius_at_1000_depth_dist_is_midpoint() -> void:
	var r := MiniMap.depth_dot_radius(1000.0)
	assert_almost_eq(r, 4.0, 0.01)

func test_alpha_at_zero_depth_dist_is_one() -> void:
	var a := MiniMap.depth_dot_alpha(0.0)
	assert_almost_eq(a, 1.0, 0.01)

func test_alpha_at_2000_depth_dist_is_min() -> void:
	var a := MiniMap.depth_dot_alpha(2000.0)
	assert_almost_eq(a, 0.3, 0.01)

func test_radius_clamped_beyond_2000() -> void:
	var r := MiniMap.depth_dot_radius(5000.0)
	assert_almost_eq(r, 2.0, 0.01)
