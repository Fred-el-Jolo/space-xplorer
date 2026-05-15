extends Node2D

@onready var ship: Ship = $Ship
@onready var hud: HUD = $HUD
@onready var landing_screen: LandingScreen = $LandingScreen

var _pois: Array[PointOfInterest] = []
var _poi_in_range: PointOfInterest = null

func _ready() -> void:
	for child in $POIs.get_children():
		var poi := child as PointOfInterest
		if poi == null:
			continue
		_pois.append(poi)
		poi.landing_zone_entered.connect(_on_landing_zone_entered)
		poi.landing_zone_exited.connect(_on_landing_zone_exited)
	ShipInput.ship = ship
	hud.connect_to_ship(ship)
	hud.connect_to_world(ship, _pois)
	hud.land_requested.connect(_on_land_requested)
	BeaconSystem.register(ship, _pois)
	BeaconSystem.beacon_activated.connect(func(): hud.show_beacon_active(true))
	BeaconSystem.beacon_deactivated.connect(func(): hud.show_beacon_active(false))

func _process(_delta: float) -> void:
	for poi in _pois:
		poi.check_landing_proximity(ship.position, ship.z_depth)

func _on_landing_zone_entered(poi: PointOfInterest) -> void:
	_poi_in_range = poi
	if BeaconSystem.active:
		landing_screen.show_for(poi, ship)
	else:
		hud.show_land_button(true)

func _on_landing_zone_exited(_poi: PointOfInterest) -> void:
	_poi_in_range = null
	hud.show_land_button(false)

func _on_land_requested() -> void:
	if _poi_in_range == null:
		return
	landing_screen.show_for(_poi_in_range, ship)
	hud.show_land_button(false)
