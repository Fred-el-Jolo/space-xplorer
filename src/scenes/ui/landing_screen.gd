class_name LandingScreen
extends CanvasLayer

@onready var type_badge: Label = $Panel/VBox/TypeBadge
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var refueled_label: Label = $Panel/VBox/RefueledLabel
@onready var depart_button: Button = $Panel/VBox/DepartButton

var _ship: Ship = null

const TYPE_LABELS: Dictionary = {
    POIData.POIType.PLANET:   "PLANET",
    POIData.POIType.STATION:  "SPACE STATION",
    POIData.POIType.ASTEROID: "ASTEROID OUTPOST",
    POIData.POIType.DERELICT: "DERELICT SHIP",
}

const TYPE_COLORS: Dictionary = {
    POIData.POIType.PLANET:   Color(0.2, 0.8, 0.3),
    POIData.POIType.STATION:  Color(0.3, 0.6, 1.0),
    POIData.POIType.ASTEROID: Color(1.0, 0.6, 0.1),
    POIData.POIType.DERELICT: Color(0.6, 0.6, 0.6),
}

func show_for(poi: PointOfInterest, ship: Ship) -> void:
    _ship = ship
    type_badge.text = TYPE_LABELS[poi.data.type]
    type_badge.add_theme_color_override("font_color", TYPE_COLORS[poi.data.type])
    name_label.text = poi.data.poi_name
    description_label.text = poi.data.description
    _refuel(ship)
    if not GameState.has_landed_once:
        GameState.has_landed_once = true
    BeaconSystem.deactivate()
    ship.set_landed(true)
    ShipInput.suspended = true
    visible = true

func _refuel(ship: Ship) -> void:
    ship.fuel = ship.data.max_fuel
    ship.fuel_changed.emit(ship.fuel)
    refueled_label.visible = true
    var tween := create_tween()
    tween.tween_interval(1.5)
    tween.tween_callback(func(): refueled_label.visible = false)

func _on_depart_pressed() -> void:
    if _ship:
        _ship.set_landed(false)
    ShipInput.suspended = false
    visible = false
