class_name PhaseApproach
extends CanvasLayer

signal phase_completed
signal phase_failed(damage: float)

const SCROLL_SPEED: float = 180.0
const THRUST_ACCEL: float = 260.0
const DRAG: float = 0.12
const APPROACH_LENGTH: float = 2400.0
const SHIP_SIZE: float = 32.0
const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const SHIP_X: float = 200.0
const CENTRE_Y: float = 360.0

var _ctx: LandingContext = null
var _progress: float = 0.0
var _ship_y: float = CENTRE_Y
var _ship_vy: float = 0.0
var _scroll_x: float = 0.0
var _rng := RandomNumberGenerator.new()
var _hazards: Array[Rect2] = []
var _done: bool = false

var _bg: ColorRect
var _ship_rect_node: ColorRect
var _upper_line: Line2D
var _lower_line: Line2D
var _progress_bar: ProgressBar
var _speed_label: Label

static func corridor_gap(t: float) -> float:
	return lerpf(300.0, 120.0, t)

static func ship_rect(pos: Vector2) -> Rect2:
	return Rect2(pos - Vector2(SHIP_SIZE * 0.5, SHIP_SIZE * 0.5), Vector2(SHIP_SIZE, SHIP_SIZE))

static func outside_corridor(ship_y: float, centre_y: float, gap: float) -> bool:
	return ship_y < centre_y - gap * 0.5 or ship_y > centre_y + gap * 0.5

func begin(ctx: LandingContext) -> void:
	_ctx = ctx
	_rng.seed = ctx.approach_rng_seed
	_build_ui()
	_spawn_hazards()

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.02, 0.08)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_upper_line = Line2D.new()
	_upper_line.width = 2.0
	_upper_line.default_color = Color(0.3, 0.6, 1.0, 0.8)
	add_child(_upper_line)

	_lower_line = Line2D.new()
	_lower_line.width = 2.0
	_lower_line.default_color = Color(0.3, 0.6, 1.0, 0.8)
	add_child(_lower_line)

	_ship_rect_node = ColorRect.new()
	_ship_rect_node.color = Color(0.1, 1.0, 0.8)
	_ship_rect_node.size = Vector2(SHIP_SIZE, SHIP_SIZE)
	add_child(_ship_rect_node)

	var hud_bar := HBoxContainer.new()
	hud_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_bar.add_theme_constant_override("separation", 16)
	add_child(hud_bar)

	var approach_label := Label.new()
	approach_label.text = "APPROACH — PAD %d" % _ctx.assigned_pad
	approach_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	hud_bar.add_child(approach_label)

	_speed_label = Label.new()
	hud_bar.add_child(_speed_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.max_value = APPROACH_LENGTH
	_progress_bar.value = 0.0
	_progress_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_progress_bar.custom_minimum_size = Vector2(0.0, 18.0)
	add_child(_progress_bar)

func _spawn_hazards() -> void:
	_hazards.clear()
	var count := _rng.randi_range(2, 4)
	for i in count:
		var hx := APPROACH_LENGTH * (float(i + 1) / float(count + 1))
		var hy := CENTRE_Y + _rng.randf_range(-80.0, 80.0)
		var hw := _rng.randf_range(60.0, 100.0)
		var hh := _rng.randf_range(40.0, 70.0)
		_hazards.append(Rect2(hx - hw * 0.5, hy - hh * 0.5, hw, hh))

func _process(delta: float) -> void:
	if _done:
		return

	_scroll_x += SCROLL_SPEED * delta
	_progress = clampf(_scroll_x / APPROACH_LENGTH, 0.0, 1.0)
	_progress_bar.value = _scroll_x

	var thrust := 0.0
	if Input.is_action_pressed("ship_up"):
		thrust = -1.0
	elif Input.is_action_pressed("ship_down"):
		thrust = 1.0
	_ship_vy += thrust * THRUST_ACCEL * delta
	_ship_vy = lerpf(_ship_vy, 0.0, DRAG)
	_ship_y = clampf(_ship_y + _ship_vy * delta, 20.0, SCREEN_H - 20.0)

	_speed_label.text = "SPD %.0f" % absf(_ship_vy)

	var t := _progress
	var gap := corridor_gap(t)
	_update_corridor_lines(gap)

	var ship_pos := Vector2(SHIP_X, _ship_y)
	var sr := ship_rect(ship_pos)
	_ship_rect_node.position = sr.position

	if outside_corridor(_ship_y, CENTRE_Y, gap):
		_done = true
		phase_failed.emit(20.0)
		return

	for hz in _hazards:
		var world_hz := Rect2(hz.position.x - _scroll_x + SCREEN_W, hz.position.y, hz.size.x, hz.size.y)
		if sr.intersects(world_hz):
			_done = true
			phase_failed.emit(20.0)
			return

	if _progress >= 1.0:
		_done = true
		phase_completed.emit()

func _update_corridor_lines(gap: float) -> void:
	var upper_y := CENTRE_Y - gap * 0.5
	var lower_y := CENTRE_Y + gap * 0.5
	_upper_line.clear_points()
	_lower_line.clear_points()
	for i in 6:
		var px := float(i) / 5.0 * SCREEN_W
		_upper_line.add_point(Vector2(px, upper_y))
		_lower_line.add_point(Vector2(px, lower_y))
