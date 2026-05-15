class_name HUD
extends CanvasLayer

@onready var depth_label: Label = $VBoxContainer/DepthLabel
@onready var fuel_bar: ProgressBar = $VBoxContainer/FuelBar
@onready var hull_bar: ProgressBar = $VBoxContainer/HullBar
@onready var speed_label: Label = $VBoxContainer/SpeedLabel
@onready var land_button: Button = $LandButton
@onready var nav_label: Label = $NavLabel
@onready var beacon_label: Label = $BeaconLabel
@onready var mini_map: MiniMap = $MiniMap

signal land_requested

var _ship: Ship = null
var _pois: Array[PointOfInterest] = []

func _ready() -> void:
	land_button.pressed.connect(func(): land_requested.emit())

func connect_to_ship(ship: Ship) -> void:
	assert(ship.data != null, "HUD.connect_to_ship: Ship must have ShipData assigned")
	_ship = ship
	fuel_bar.max_value = ship.data.max_fuel
	hull_bar.max_value = ship.data.max_hull
	fuel_bar.value = ship.fuel
	hull_bar.value = ship.hull
	depth_label.text = "Depth: %d" % int(ship.z_depth)
	ship.fuel_changed.connect(_on_fuel_changed)
	ship.hull_changed.connect(_on_hull_changed)
	ship.depth_changed.connect(_on_depth_changed)

func connect_to_world(ship: Ship, pois: Array[PointOfInterest]) -> void:
	_pois = pois
	mini_map.connect_to_world(ship, pois)
	nav_label.visible = not pois.is_empty()

func show_land_button(show: bool) -> void:
	land_button.visible = show

func show_beacon_active(active: bool) -> void:
	beacon_label.visible = active

func _process(_delta: float) -> void:
	if _ship == null:
		return
	speed_label.text = "SPD %d" % int(_ship.linear_velocity.length())
	if not _pois.is_empty():
		_update_nav()

func _update_nav() -> void:
	var nearest := _find_nearest_poi()
	if nearest == null or nearest.data == null:
		return
	var dir := nearest.position - _ship.position
	var dist := int(dir.length())
	var depth_diff := nearest.z_depth - _ship.z_depth
	var depth_hint: String
	var z_close := absf(depth_diff) <= nearest.data.landing_threshold
	var xy_close := dir.length() <= nearest.data.landing_xy_radius
	if z_close and xy_close:
		depth_hint = "LAND"
	elif depth_diff > 0:
		depth_hint = "▲Far"
	else:
		depth_hint = "▼Near"
	nav_label.text = "%s %s  %dm  %s" % [_dir_arrow(dir), nearest.data.poi_name, dist, depth_hint]

func _find_nearest_poi() -> PointOfInterest:
	var nearest: PointOfInterest = null
	var min_d := INF
	for poi: PointOfInterest in _pois:
		var d := Vector3(_ship.position.x, _ship.position.y, _ship.z_depth).distance_to(
			Vector3(poi.position.x, poi.position.y, poi.z_depth))
		if d < min_d:
			min_d = d
			nearest = poi
	return nearest

func _dir_arrow(dir: Vector2) -> String:
	if dir.length_squared() < 1.0:
		return "●"
	const ARROWS: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var idx := int(round(dir.angle() / (PI / 4.0))) % 8
	if idx < 0:
		idx += 8
	return ARROWS[idx]

func _on_fuel_changed(value: float) -> void:
	fuel_bar.value = value

func _on_hull_changed(value: float) -> void:
	hull_bar.value = value

func _on_depth_changed(value: float) -> void:
	depth_label.text = "Depth: %d" % int(value)
