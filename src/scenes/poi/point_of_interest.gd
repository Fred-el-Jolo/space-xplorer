class_name PointOfInterest
extends WorldEntity

@export var data: POIData

signal landing_zone_entered(poi: PointOfInterest)
signal landing_zone_exited(poi: PointOfInterest)

var _player_in_range: bool = false

func check_landing_proximity(ship_z_depth: float) -> void:
	if data == null:
		return
	var in_range: bool = ship_z_depth <= z_depth + data.landing_threshold
	if in_range and not _player_in_range:
		_player_in_range = true
		landing_zone_entered.emit(self)
	elif not in_range and _player_in_range:
		_player_in_range = false
		landing_zone_exited.emit(self)
