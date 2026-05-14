extends GutTest

func test_scale_at_base_depth() -> void:
	# BASE_SCALE is 100.0, so at z_depth=100 scale should be 1.0
	assert_almost_eq(DepthSystem.compute_scale(100.0), 1.0, 0.001)

func test_scale_nearer_is_larger() -> void:
	var near: float = DepthSystem.compute_scale(50.0)
	var far: float = DepthSystem.compute_scale(200.0)
	assert_gt(near, far)

func test_scale_does_not_divide_by_zero() -> void:
	var result: float = DepthSystem.compute_scale(0.0)
	assert_gt(result, 0.0)

func test_draw_order_farther_is_lower() -> void:
	var near: int = DepthSystem.compute_draw_order(100.0)
	var far: int = DepthSystem.compute_draw_order(500.0)
	assert_lt(far, near)

func test_visible_within_max_depth() -> void:
	assert_true(DepthSystem.is_visible(5000.0))

func test_invisible_beyond_max_depth() -> void:
	assert_false(DepthSystem.is_visible(15000.0))

func test_y_offset_deeper_is_higher_on_screen() -> void:
	var shallow: float = DepthSystem.compute_y_offset(0.0, 100.0)
	var deep: float = DepthSystem.compute_y_offset(0.0, 500.0)
	assert_lt(deep, shallow)
