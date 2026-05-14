class_name HUD
extends CanvasLayer

@onready var depth_label: Label = $VBoxContainer/DepthLabel
@onready var fuel_bar: ProgressBar = $VBoxContainer/FuelBar
@onready var hull_bar: ProgressBar = $VBoxContainer/HullBar
@onready var landing_label: Label = $LandingLabel

func connect_to_ship(ship: Ship) -> void:
	fuel_bar.max_value = ship.data.max_fuel
	hull_bar.max_value = ship.data.max_hull
	fuel_bar.value = ship.fuel
	hull_bar.value = ship.hull
	depth_label.text = "Depth: %d" % int(ship.z_depth)
	ship.fuel_changed.connect(_on_fuel_changed)
	ship.hull_changed.connect(_on_hull_changed)
	ship.depth_changed.connect(_on_depth_changed)

func show_landing_prompt(show: bool) -> void:
	landing_label.visible = show

func _on_fuel_changed(value: float) -> void:
	fuel_bar.value = value

func _on_hull_changed(value: float) -> void:
	hull_bar.value = value

func _on_depth_changed(value: float) -> void:
	depth_label.text = "Depth: %d" % int(value)
