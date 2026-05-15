extends GutTest

func before_each() -> void:
	GameState.has_landed_once = false

func test_starts_false() -> void:
	assert_false(GameState.has_landed_once)

func test_can_be_set_true() -> void:
	GameState.has_landed_once = true
	assert_true(GameState.has_landed_once)
