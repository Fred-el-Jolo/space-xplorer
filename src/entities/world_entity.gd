class_name WorldEntity
extends Node2D

@export var z_depth: float = 1000.0

func _process(_delta: float) -> void:
	_apply_depth()

func _apply_depth() -> void:
	scale = Vector2.ONE * DepthSystem.compute_scale(z_depth)
	z_index = DepthSystem.compute_draw_order(z_depth)
	visible = DepthSystem.is_visible(z_depth)
