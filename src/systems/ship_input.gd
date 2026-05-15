extends Node

var ship: Ship = null
var suspended: bool = false

func _process(_delta: float) -> void:
	if not ship or suspended:
		return
	ship.thrust_input = _read_thrust()
	ship.depth_input = _read_depth()

func _read_thrust() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ship_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("ship_right"):
		dir.x += 1.0
	if Input.is_action_pressed("ship_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("ship_down"):
		dir.y += 1.0
	return dir.normalized()

func _read_depth() -> float:
	var d := 0.0
	if Input.is_action_pressed("ship_depth_in"):
		d -= 1.0
	if Input.is_action_pressed("ship_depth_out"):
		d += 1.0
	return d
