extends GutTest

func test_default_checkpoint_phase_is_one() -> void:
	var ctx := LandingContext.new()
	assert_eq(ctx.checkpoint_phase, 1)

func test_assigned_pad_settable() -> void:
	var ctx := LandingContext.new()
	ctx.assigned_pad = 3
	assert_eq(ctx.assigned_pad, 3)

func test_approach_rng_seed_settable() -> void:
	var ctx := LandingContext.new()
	ctx.approach_rng_seed = 42
	assert_eq(ctx.approach_rng_seed, 42)

func test_hull_at_sequence_start_settable() -> void:
	var ctx := LandingContext.new()
	ctx.hull_at_sequence_start = 75.0
	assert_almost_eq(ctx.hull_at_sequence_start, 75.0, 0.001)
