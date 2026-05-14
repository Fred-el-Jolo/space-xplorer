class_name Planet
extends WorldEntity

@export var planet_name: String = "Unknown Planet"
@export var landing_threshold: float = 50.0

signal landing_zone_entered(planet: Planet)
signal landing_zone_exited(planet: Planet)

var _player_in_range: bool = false

func check_landing_proximity(ship_z_depth: float) -> void:
	var in_range: bool = ship_z_depth <= z_depth + landing_threshold
	if in_range and not _player_in_range:
		_player_in_range = true
		landing_zone_entered.emit(self)
	elif not in_range and _player_in_range:
		_player_in_range = false
		landing_zone_exited.emit(self)
