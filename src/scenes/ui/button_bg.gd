extends Node2D

func _draw() -> void:
	var bg := Color(0.08, 0.12, 0.3, 0.55)
	var border := Color(0.45, 0.7, 1.0, 0.85)
	_btn(Rect2(120, 480, 100, 100), bg, border)  # Up
	_btn(Rect2(10,  580, 100, 100), bg, border)  # Left
	_btn(Rect2(230, 580, 100, 100), bg, border)  # Right
	_btn(Rect2(120, 610, 100, 100), bg, border)  # Down
	_btn(Rect2(1100, 540, 130, 60), bg, border)  # Near (depth_in)
	_btn(Rect2(1100, 620, 130, 60), bg, border)  # Far (depth_out)

func _btn(r: Rect2, bg: Color, border: Color) -> void:
	draw_rect(r, bg)
	draw_rect(r, border, false, 2.0)
