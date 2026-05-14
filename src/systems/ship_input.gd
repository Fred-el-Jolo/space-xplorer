extends Node

var ship: Ship = null

func _process(_delta: float) -> void:
	if not ship:
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
	return dir

func _read_depth() -> float:
	if Input.is_action_pressed("ship_depth_in"):
		return -1.0
	if Input.is_action_pressed("ship_depth_out"):
		return 1.0
	return 0.0
