class_name PhaseBayEntry
extends CanvasLayer

signal phase_completed
signal phase_failed(damage: float)

const SPEED_LIMIT: float = 80.0
const THRUST_ACCEL: float = 220.0
const DRAG: float = 0.10
const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const PAD_W: float = 160.0
const PAD_H: float = 130.0
const PAD_GAP: float = 20.0
const SHIP_SIZE: float = 28.0
const WALL_MARGIN: float = 60.0

var _ctx: LandingContext = null
var _velocity: Vector2 = Vector2.ZERO
var _ship_pos: Vector2 = Vector2.ZERO
var _pads: Array[Rect2] = []
var _done: bool = false
var _ship_node: ColorRect
var _speed_bar: ProgressBar
var _warning_label: Label

static func pad_rects_for(type: POIData.POIType) -> Array[Rect2]:
	var grids: Dictionary = {
		POIData.POIType.PLANET:   Vector2i(2, 2),
		POIData.POIType.STATION:  Vector2i(3, 2),
		POIData.POIType.ASTEROID: Vector2i(2, 1),
		POIData.POIType.DERELICT: Vector2i(1, 1),
	}
	var grid: Vector2i = grids.get(type, Vector2i(1, 1))
	var total_w := grid.x * PAD_W + (grid.x - 1) * PAD_GAP
	var total_h := grid.y * PAD_H + (grid.y - 1) * PAD_GAP
	var origin := Vector2((SCREEN_W - total_w) * 0.5, (SCREEN_H - total_h) * 0.5 + 40.0)
	var result: Array[Rect2] = []
	for row in grid.y:
		for col in grid.x:
			var pos := origin + Vector2(col * (PAD_W + PAD_GAP), row * (PAD_H + PAD_GAP))
			result.append(Rect2(pos, Vector2(PAD_W, PAD_H)))
	return result

static func is_overspeed(velocity: Vector2) -> bool:
	return velocity.length() > SPEED_LIMIT

func begin(ctx: LandingContext) -> void:
	_ctx = ctx
	_pads = pad_rects_for(ctx.poi.data.type)
	_ship_pos = Vector2(SCREEN_W * 0.5, WALL_MARGIN + SHIP_SIZE)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var draw_node := _BayDrawer.new()
	draw_node.pads = _pads
	draw_node.assigned_pad = _ctx.assigned_pad
	draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(draw_node)

	_ship_node = ColorRect.new()
	_ship_node.color = Color(0.1, 1.0, 0.8)
	_ship_node.size = Vector2(SHIP_SIZE, SHIP_SIZE)
	add_child(_ship_node)

	var hud := HBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(hud)

	var lbl := Label.new()
	lbl.text = "BAY ENTRY — PAD %d" % _ctx.assigned_pad
	lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	hud.add_child(lbl)

	_warning_label = Label.new()
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_warning_label.visible = false
	hud.add_child(_warning_label)

	_speed_bar = ProgressBar.new()
	_speed_bar.max_value = SPEED_LIMIT * 1.5
	_speed_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_speed_bar.custom_minimum_size = Vector2(0.0, 18.0)
	add_child(_speed_bar)

func _process(delta: float) -> void:
	if _done:
		return
	var thrust := Vector2.ZERO
	if Input.is_action_pressed("ship_left"):  thrust.x = -1.0
	if Input.is_action_pressed("ship_right"): thrust.x = 1.0
	if Input.is_action_pressed("ship_up"):    thrust.y = -1.0
	if Input.is_action_pressed("ship_down"):  thrust.y = 1.0
	if thrust.length() > 0.0:
		thrust = thrust.normalized()
	_velocity += thrust * THRUST_ACCEL * delta
	_velocity = _velocity.lerp(Vector2.ZERO, DRAG)
	_ship_pos = (_ship_pos + _velocity * delta).clamp(
		Vector2(WALL_MARGIN, WALL_MARGIN),
		Vector2(SCREEN_W - WALL_MARGIN, SCREEN_H - WALL_MARGIN)
	)
	_ship_node.position = _ship_pos - Vector2(SHIP_SIZE * 0.5, SHIP_SIZE * 0.5)
	_speed_bar.value = _velocity.length()

	var overspeed := is_overspeed(_velocity)
	_warning_label.visible = overspeed
	if overspeed:
		_warning_label.text = "⚠ REDUCE SPEED"

	var ship_rect := Rect2(_ship_pos - Vector2(SHIP_SIZE * 0.5, SHIP_SIZE * 0.5), Vector2(SHIP_SIZE, SHIP_SIZE))
	for i in _pads.size():
		if ship_rect.intersects(_pads[i]):
			var pad_num := i + 1
			if pad_num != _ctx.assigned_pad:
				_done = true
				phase_failed.emit(5.0)
				return
			if overspeed:
				_done = true
				phase_failed.emit(15.0)
				return
			_done = true
			phase_completed.emit()
			return


class _BayDrawer extends Control:
	var pads: Array[Rect2] = []
	var assigned_pad: int = 1
	var _pulse_t: float = 0.0

	func _process(delta: float) -> void:
		_pulse_t += delta * 2.5
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for i in pads.size():
			var pad_num := i + 1
			var is_assigned := pad_num == assigned_pad
			var pulse := (sin(_pulse_t) * 0.5 + 0.5) if is_assigned else 0.0
			var col := Color(1.0, 0.75 + pulse * 0.25, 0.0, 1.0) if is_assigned else Color(0.3, 0.3, 0.4, 0.8)
			draw_rect(pads[i], col, false, 2.0 + pulse * 1.0)
			draw_string(font, pads[i].position + Vector2(6.0, 18.0), "PAD %d" % pad_num,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
