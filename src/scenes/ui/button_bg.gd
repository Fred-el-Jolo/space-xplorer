extends Node2D

const _RECTS := [
	Rect2(120, 480, 100, 100),
	Rect2(10,  580, 100, 100),
	Rect2(230, 580, 100, 100),
	Rect2(120, 610, 100, 100),
	Rect2(1100, 540, 130, 60),
	Rect2(1100, 620, 130, 60),
]
const _ACTIONS := [
	"ship_up", "ship_left", "ship_right", "ship_down",
	"ship_depth_in", "ship_depth_out",
]

var _pressed: Dictionary = {}

func _ready() -> void:
	for child in get_parent().get_children():
		if not child is TouchScreenButton:
			continue
		var btn := child as TouchScreenButton
		_pressed[btn.action] = false
		btn.pressed.connect(func(): _on_btn(btn.action, true))
		btn.released.connect(func(): _on_btn(btn.action, false))

func _on_btn(action: String, is_pressed: bool) -> void:
	_pressed[action] = is_pressed
	queue_redraw()

func _draw() -> void:
	for i in _RECTS.size():
		var p: bool = _pressed.get(_ACTIONS[i], false)
		_btn(_RECTS[i],
			Color(0.35, 0.55, 1.0, 0.85) if p else Color(0.08, 0.12, 0.3, 0.55),
			Color(1.0, 1.0, 1.0, 1.0)    if p else Color(0.45, 0.7, 1.0, 0.85))

func _btn(r: Rect2, bg: Color, border: Color) -> void:
	draw_rect(r, bg)
	draw_rect(r, border, false, 2.0)
