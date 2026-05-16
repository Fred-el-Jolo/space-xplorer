# src/scenes/landing/phase_atc.gd
class_name PhaseATC
extends CanvasLayer

signal phase_completed
signal phase_failed(damage: float)

const ATC_LINES: Array[String] = [
	"Clearance request received...",
	"Checking pad availability...",
	"PAD %d ASSIGNED. Approach vector set.",
	"Reduce speed below 80 u/s on entry.",
]
const LINE_DELAY: float = 0.5

var _ctx: LandingContext = null
var _panel: PanelContainer
var _vbox: VBoxContainer
var _comms_label: RichTextLabel
var _schematic: Control
var _ack_button: Button

func begin(ctx: LandingContext) -> void:
	_ctx = ctx
	_build_ui()
	_start_typewriter()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560.0, 420.0)
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(_vbox)

	var title := Label.new()
	title.text = "ATC COMMS — %s" % _ctx.poi.data.poi_name.to_upper()
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	_vbox.add_child(title)

	var sep := HSeparator.new()
	_vbox.add_child(sep)

	_comms_label = RichTextLabel.new()
	_comms_label.bbcode_enabled = true
	_comms_label.custom_minimum_size = Vector2(0.0, 120.0)
	_comms_label.fit_content = true
	_vbox.add_child(_comms_label)

	_schematic = _build_schematic()
	_schematic.visible = false
	_vbox.add_child(_schematic)

	_ack_button = Button.new()
	_ack_button.text = "ACKNOWLEDGED"
	_ack_button.visible = false
	_ack_button.pressed.connect(_on_acknowledged)
	_vbox.add_child(_ack_button)

func _build_schematic() -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(0.0, 160.0)
	var draw_node := _PadSchematic.new()
	draw_node.assigned_pad = _ctx.assigned_pad
	draw_node.poi_type = _ctx.poi.data.type
	draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(draw_node)
	return container

func _start_typewriter() -> void:
	var tween := create_tween()
	tween.set_sequential(true)
	for i in ATC_LINES.size():
		var line: String = ATC_LINES[i]
		if line.contains("%d"):
			line = line % _ctx.assigned_pad
		tween.tween_callback(_append_line.bind(line))
		tween.tween_interval(LINE_DELAY)
	tween.tween_callback(_reveal_schematic)

func _append_line(line: String) -> void:
	_comms_label.append_text("[color=#88ccff]> %s[/color]\n" % line)

func _reveal_schematic() -> void:
	_schematic.visible = true
	_ack_button.visible = true

func _on_acknowledged() -> void:
	phase_completed.emit()


# Inner class for pad drawing — keeps PhaseATC self-contained
class _PadSchematic extends Control:
	var assigned_pad: int = 1
	var poi_type: POIData.POIType = POIData.POIType.PLANET

	const PAD_GRIDS: Dictionary = {
		POIData.POIType.PLANET:   Vector2i(2, 2),
		POIData.POIType.STATION:  Vector2i(3, 2),
		POIData.POIType.ASTEROID: Vector2i(2, 1),
		POIData.POIType.DERELICT: Vector2i(1, 1),
	}
	const PAD_SIZE := Vector2(60.0, 50.0)
	const PAD_GAP := Vector2(12.0, 10.0)

	var _pulse_t: float = 0.0

	func _process(delta: float) -> void:
		_pulse_t += delta * 3.0
		queue_redraw()

	func _draw() -> void:
		var grid: Vector2i = PAD_GRIDS.get(poi_type, Vector2i(1, 1))
		var total_w := grid.x * PAD_SIZE.x + (grid.x - 1) * PAD_GAP.x
		var total_h := grid.y * PAD_SIZE.y + (grid.y - 1) * PAD_GAP.y
		var origin := (size - Vector2(total_w, total_h)) * 0.5
		var pad_idx := 1
		for row in grid.y:
			for col in grid.x:
				var pos := origin + Vector2(col * (PAD_SIZE.x + PAD_GAP.x), row * (PAD_SIZE.y + PAD_GAP.y))
				var is_assigned := pad_idx == assigned_pad
				var pulse := (sin(_pulse_t) * 0.5 + 0.5) if is_assigned else 0.0
				var col_color := Color(1.0, 0.8 + pulse * 0.2, 0.0) if is_assigned else Color(0.4, 0.4, 0.4)
				draw_rect(Rect2(pos, PAD_SIZE), col_color, not is_assigned)
				if is_assigned:
					draw_rect(Rect2(pos, PAD_SIZE), col_color.lightened(0.3), false, 2.0)
				var font := ThemeDB.fallback_font
				draw_string(font, pos + Vector2(4.0, 14.0), str(pad_idx),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
				pad_idx += 1
