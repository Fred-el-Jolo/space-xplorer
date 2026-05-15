extends Node

const BEACON_SPEED: float = 400.0
const BEACON_DEPTH_SPEED: float = 300.0

var _ship: Ship = null
var _pois: Array = []
var active: bool = false
var _target: PointOfInterest = null

signal beacon_activated
signal beacon_deactivated

func register(ship: Ship, pois: Array) -> void:
	if _ship and _ship.fuel_changed.is_connected(_on_fuel_changed):
		_ship.fuel_changed.disconnect(_on_fuel_changed)
	_ship = ship
	_pois = pois
	ship.fuel_changed.connect(_on_fuel_changed)

func _process(delta: float) -> void:
	if not active or _target == null or _ship == null:
		return
	var dir: Vector2 = _target.position - _ship.position
	if dir.length() > 10.0:
		_ship.linear_velocity = dir.normalized() * BEACON_SPEED
	else:
		_ship.linear_velocity = Vector2.ZERO
	_ship.z_depth = move_toward(_ship.z_depth, _target.z_depth, BEACON_DEPTH_SPEED * delta)
	_ship.depth_changed.emit(_ship.z_depth)
	_target.check_landing_proximity(_ship.position, _ship.z_depth)

func _on_fuel_changed(value: float) -> void:
	if value <= 0.0 and not active:
		_activate()

func _activate() -> void:
	_target = find_nearest(_ship.position, _ship.z_depth, _pois)
	if _target == null:
		return
	active = true
	ShipInput.suspended = true
	beacon_activated.emit()

func deactivate() -> void:
	active = false
	_target = null
	beacon_deactivated.emit()

static func find_nearest(ship_pos: Vector2, ship_z: float, pois: Array) -> PointOfInterest:
	var nearest: PointOfInterest = null
	var min_dist: float = INF
	for poi in pois:
		var d: float = Vector3(ship_pos.x, ship_pos.y, ship_z).distance_to(
			Vector3(poi.position.x, poi.position.y, poi.z_depth))
		if d < min_dist:
			min_dist = d
			nearest = poi
	return nearest
