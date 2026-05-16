class_name PhaseTouchdown
extends CanvasLayer

signal phase_completed
signal phase_failed(damage: float)

const TILT_LIMIT: float = 0.2
const CUT_WINDOW_START: float = 0.75
const DESCENT_DURATION: float = 12.0
const SHIP_HALF: float = 14.0
const SCREEN_W: float = 1280.0
const SCREEN_H: float = 720.0
const THRUST_ACCEL: float = 160.0
const DRAG: float = 0.10
const SUCCESS_HOLD: float = 2.0
const MOUSE_TILT_SCALE: float = 1.0 / 200.0

var _ctx: LandingContext = null
var _pad_rect: Rect2
var _ship_pos: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _roll_tilt: float = 0.0
var _pitch_tilt: float = 0.0
var _descent_t: float = 0.0
var _thrust_cut: bool = false
var _success_hold_t: float = 0.0
var _failed: bool = false

var _draw_node: Control
var _roll_indicator: _TiltIndicator
var _pitch_indicator: _TiltIndicator
var _descent_bar: ProgressBar
var _cut_button: Button
var _status_label: Label

static func tilt_ok(tilt: float) -> bool:
	return absf(tilt) <= TILT_LIMIT

static func in_cut_window(t: float) -> bool:
	return t >= CUT_WINDOW_START

static func ship_centred(ship_pos: Vector2, pad: Rect2, half_size: float) -> bool:
	return pad.has_point(ship_pos - Vector2(half_size, half_size)) and \
		   pad.has_point(ship_pos + Vector2(half_size, half_size))

func begin(ctx: LandingContext) -> void:
	_ctx = ctx
	var pads := PhaseBayEntry.pad_rects_for(ctx.poi.data.type)
	_pad_rect = pads[ctx.assigned_pad - 1]
	_ship_pos = _pad_rect.get_center()
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_draw_node = _PadView.new()
	(_draw_node as _PadView).pad_rect = _pad_rect
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_draw_node)

	var top_label := Label.new()
	top_label.text = "TOUCHDOWN — PAD %d" % _ctx.assigned_pad
	top_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	top_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top_label)

	_status_label = Label.new()
	_status_label.text = "⚠ ALIGN SHIP BEFORE TOUCHDOWN"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
	_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_label.position.y = 30.0
	add_child(_status_label)

	_roll_indicator = _TiltIndicator.new()
	_roll_indicator.label = "ROLL"
	_roll_indicator.horizontal = true
	_roll_indicator.custom_minimum_size = Vector2(300.0, 32.0)
	_roll_indicator.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_roll_indicator.position = Vector2(40.0, -140.0)
	add_child(_roll_indicator)

	_pitch_indicator = _TiltIndicator.new()
	_pitch_indicator.label = "PITCH"
	_pitch_indicator.horizontal = false
	_pitch_indicator.custom_minimum_size = Vector2(32.0, 180.0)
	_pitch_indicator.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_pitch_indicator.position = Vector2(40.0, -90.0)
	add_child(_pitch_indicator)

	_descent_bar = ProgressBar.new()
	_descent_bar.max_value = 1.0
	_descent_bar.value = 0.0
	_descent_bar.custom_minimum_size = Vector2(0.0, 28.0)
	_descent_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_descent_bar.offset_top = -60.0
	add_child(_descent_bar)

	_cut_button = Button.new()
	_cut_button.text = "CUT THRUST"
	_cut_button.custom_minimum_size = Vector2(200.0, 48.0)
	_cut_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_cut_button.position = Vector2(-240.0, -80.0)
	_cut_button.pressed.connect(_on_cut_thrust)
	add_child(_cut_button)

func _process(delta: float) -> void:
	if _failed:
		return
	_update_tilt(delta)
	_update_ship_pos(delta)
	_update_descent(delta)
	_update_indicators()
	if _thrust_cut:
		_check_success(delta)

func _update_tilt(delta: float) -> void:
	var raw_roll: float
	var raw_pitch: float
	if OS.has_feature("mobile"):
		var accel := Input.get_accelerometer()
		raw_roll = clampf(accel.x / 9.8, -1.0, 1.0)
		raw_pitch = clampf(accel.y / 9.8, -1.0, 1.0)
	else:
		var mouse_delta := Input.get_last_mouse_velocity() * delta
		raw_roll = clampf(mouse_delta.x * MOUSE_TILT_SCALE, -1.0, 1.0)
		raw_pitch = clampf(mouse_delta.y * MOUSE_TILT_SCALE, -1.0, 1.0)
	_roll_tilt = lerpf(_roll_tilt, raw_roll, 0.15)
	_pitch_tilt = lerpf(_pitch_tilt, raw_pitch, 0.15)

func _update_ship_pos(delta: float) -> void:
	var thrust := Vector2.ZERO
	if Input.is_action_pressed("ship_left"):  thrust.x = -1.0
	if Input.is_action_pressed("ship_right"): thrust.x = 1.0
	if Input.is_action_pressed("ship_up"):    thrust.y = -1.0
	if Input.is_action_pressed("ship_down"):  thrust.y = 1.0
	if thrust.length() > 0.0:
		thrust = thrust.normalized()
	var wind := sin(Time.get_ticks_msec() * 0.001 + _ctx.assigned_pad) * 25.0
	_velocity += (thrust * THRUST_ACCEL + Vector2(wind, 0.0)) * delta
	_velocity = _velocity.lerp(Vector2.ZERO, DRAG)
	_ship_pos += _velocity * delta
	_ship_pos = _ship_pos.clamp(Vector2(SHIP_HALF, SHIP_HALF), Vector2(SCREEN_W - SHIP_HALF, SCREEN_H - SHIP_HALF))
	(_draw_node as _PadView).ship_pos = _ship_pos
	(_draw_node as _PadView).queue_redraw()

func _update_descent(delta: float) -> void:
	if _thrust_cut:
		return
	_descent_t = minf(_descent_t + delta / DESCENT_DURATION, 1.0)
	_descent_bar.value = _descent_t
	if _descent_t >= 1.0:
		_fail(20.0)

func _update_indicators() -> void:
	_roll_indicator.tilt = _roll_tilt
	_roll_indicator.queue_redraw()
	_pitch_indicator.tilt = _pitch_tilt
	_pitch_indicator.queue_redraw()

func _on_cut_thrust() -> void:
	if not in_cut_window(_descent_t):
		return
	_thrust_cut = true
	_cut_button.disabled = true

func _check_success(delta: float) -> void:
	var centred := ship_centred(_ship_pos, _pad_rect, SHIP_HALF)
	var roll_ok := tilt_ok(_roll_tilt)
	var pitch_ok := tilt_ok(_pitch_tilt)
	if centred and roll_ok and pitch_ok:
		_success_hold_t += delta
		_status_label.text = "HOLD STEADY... %.1f" % (SUCCESS_HOLD - _success_hold_t)
		if _success_hold_t >= SUCCESS_HOLD:
			phase_completed.emit()
	else:
		_success_hold_t = 0.0
		_status_label.text = "⚠ ALIGN SHIP BEFORE TOUCHDOWN"

func _fail(damage: float) -> void:
	if _failed:
		return
	_failed = true
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	tween.tween_callback(func(): phase_failed.emit(damage))


class _PadView extends Control:
	var pad_rect: Rect2 = Rect2()
	var ship_pos: Vector2 = Vector2.ZERO
	var _pulse_t: float = 0.0

	func _process(delta: float) -> void:
		_pulse_t += delta * 2.0
		queue_redraw()

	func _draw() -> void:
		var pulse := sin(_pulse_t) * 0.5 + 0.5
		draw_rect(pad_rect, Color(1.0, 0.75 + pulse * 0.25, 0.0, 0.6))
		draw_rect(pad_rect, Color(1.0, 0.9, 0.0, 0.9), false, 2.0)
		var ship_rect := Rect2(ship_pos - Vector2(14.0, 14.0), Vector2(28.0, 28.0))
		draw_rect(ship_rect, Color(0.1, 1.0, 0.8, 0.9))


class _TiltIndicator extends Control:
	var tilt: float = 0.0
	var label: String = ""
	var horizontal: bool = true
	const GREEN_ZONE: float = 0.2

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(2.0, 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.8))
		var track_start := Vector2(0.0, 20.0) if horizontal else Vector2(0.0, 16.0)
		var track_end := Vector2(size.x, 20.0) if horizontal else Vector2(0.0, size.y)
		draw_line(track_start, track_end, Color(0.3, 0.3, 0.4), 2.0)
		if horizontal:
			var centre_x := size.x * 0.5
			var hw := size.x * GREEN_ZONE * 0.5
			draw_rect(Rect2(centre_x - hw, 14.0, hw * 2.0, 12.0), Color(0.0, 0.8, 0.2, 0.4))
			var bx := centre_x + tilt * size.x * 0.5
			draw_circle(Vector2(bx, 20.0), 7.0, Color.WHITE if absf(tilt) <= GREEN_ZONE else Color(1.0, 0.3, 0.2))
		else:
			var centre_y := size.y * 0.5
			var hh := size.y * GREEN_ZONE * 0.5
			draw_rect(Rect2(2.0, centre_y - hh, 10.0, hh * 2.0), Color(0.0, 0.8, 0.2, 0.4))
			var by := centre_y + tilt * size.y * 0.5
			draw_circle(Vector2(7.0, by), 7.0, Color.WHITE if absf(tilt) <= GREEN_ZONE else Color(1.0, 0.3, 0.2))
