class_name StarField
extends Node2D

@export var star_count: int = 100
@export var area: Vector2 = Vector2(2560, 1440)
@export var base_color: Color = Color(1, 1, 1, 1)
@export var min_size: float = 0.5
@export var max_size: float = 1.5
@export var seed_val: int = 0

var _stars: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	_stars.clear()
	for i in star_count:
		_stars.append({
			"pos": Vector2(rng.randf_range(0.0, area.x), rng.randf_range(0.0, area.y)),
			"size": rng.randf_range(min_size, max_size),
			"brightness": rng.randf_range(0.4, 1.0),
		})
	queue_redraw()

func _draw() -> void:
	for star in _stars:
		var c := Color(base_color.r, base_color.g, base_color.b,
			base_color.a * star["brightness"])
		draw_circle(star["pos"], star["size"], c)
