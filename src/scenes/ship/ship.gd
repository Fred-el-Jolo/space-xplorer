class_name Ship
extends RigidBody2D

@export var data: ShipData

var z_depth: float = 1000.0
var fuel: float = 0.0
var hull: float = 0.0

var thrust_input: Vector2 = Vector2.ZERO
var depth_input: float = 0.0

signal fuel_changed(value: float)
signal hull_changed(value: float)  # emitted when damage system is implemented
signal depth_changed(value: float)

func _ready() -> void:
	if data:
		fuel = data.max_fuel
		hull = data.max_hull
		linear_damp = data.linear_damp_value

func _physics_process(delta: float) -> void:
	_handle_thrust(delta)
	_handle_depth(delta)
	_apply_depth_visual()

func _handle_thrust(delta: float) -> void:
	if thrust_input == Vector2.ZERO:
		return
	if fuel <= 0.0:
		return
	apply_central_force(thrust_input.normalized() * data.thrust_power)
	fuel = maxf(0.0, fuel - data.fuel_burn_rate * delta)
	fuel_changed.emit(fuel)

func _handle_depth(delta: float) -> void:
	if depth_input == 0.0:
		return
	z_depth = clampf(
		z_depth + depth_input * data.depth_speed * delta,
		DepthSystem.MIN_Z_DEPTH,
		DepthSystem.MAX_Z_DEPTH
	)
	depth_changed.emit(z_depth)

func set_landed(landed: bool) -> void:
	if landed:
		thrust_input = Vector2.ZERO
		depth_input = 0.0
		linear_velocity = Vector2.ZERO
		freeze = true
	else:
		freeze = false

func _apply_depth_visual() -> void:
	scale = Vector2.ONE * DepthSystem.compute_scale(z_depth)
	z_index = DepthSystem.compute_draw_order(z_depth)
	visible = DepthSystem.is_visible(z_depth)
