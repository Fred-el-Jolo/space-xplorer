extends GutTest

func test_gut_is_working() -> void:
	assert_true(true, "GUT is installed and running")

func test_basic_math() -> void:
	assert_eq(1 + 1, 2, "Basic arithmetic works")
