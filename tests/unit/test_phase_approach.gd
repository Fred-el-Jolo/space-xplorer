extends GutTest

func test_corridor_boundary_at_start_is_300() -> void:
	var gap := PhaseApproach.corridor_gap(0.0)
	assert_almost_eq(gap, 300.0, 0.1)

func test_corridor_boundary_at_end_is_120() -> void:
	var gap := PhaseApproach.corridor_gap(1.0)
	assert_almost_eq(gap, 120.0, 0.1)

func test_corridor_boundary_midpoint() -> void:
	var gap := PhaseApproach.corridor_gap(0.5)
	assert_almost_eq(gap, 210.0, 0.5)

func test_ship_rect_from_position() -> void:
	var r := PhaseApproach.ship_rect(Vector2(100.0, 200.0))
	assert_almost_eq(r.position.x, 84.0, 0.1)
	assert_almost_eq(r.position.y, 184.0, 0.1)
	assert_almost_eq(r.size.x, 32.0, 0.1)
	assert_almost_eq(r.size.y, 32.0, 0.1)

func test_outside_corridor_above() -> void:
	# corridor centre_y=360, gap=300 → upper=210, lower=510
	assert_true(PhaseApproach.outside_corridor(200.0, 360.0, 300.0))

func test_inside_corridor() -> void:
	assert_false(PhaseApproach.outside_corridor(360.0, 360.0, 300.0))
