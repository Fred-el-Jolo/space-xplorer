extends GutTest

var sf: StarField

func before_each() -> void:
	sf = StarField.new()
	sf.star_count = 50
	sf.area = Vector2(1000.0, 500.0)
	sf.base_color = Color(1, 1, 1, 1)
	sf.min_size = 0.5
	sf.max_size = 2.0
	sf.seed_val = 42
	add_child(sf)

func after_each() -> void:
	sf.queue_free()

func test_generates_correct_star_count() -> void:
	assert_eq(sf._stars.size(), 50)

func test_all_stars_within_area() -> void:
	for star in sf._stars:
		assert_true(star["pos"].x >= 0.0 and star["pos"].x <= sf.area.x)
		assert_true(star["pos"].y >= 0.0 and star["pos"].y <= sf.area.y)

func test_different_seeds_produce_different_positions() -> void:
	var sf2 := StarField.new()
	sf2.star_count = 50
	sf2.area = Vector2(1000.0, 500.0)
	sf2.seed_val = 99
	add_child(sf2)
	assert_ne(sf._stars[0]["pos"], sf2._stars[0]["pos"])
	sf2.queue_free()
