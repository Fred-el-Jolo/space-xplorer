extends Node2D

@onready var ship: Ship = $Ship
@onready var planet: Planet = $Planet
@onready var hud: HUD = $HUD

func _ready() -> void:
	ShipInput.ship = ship
	hud.connect_to_ship(ship)
	planet.landing_zone_entered.connect(_on_landing_zone_entered)
	planet.landing_zone_exited.connect(_on_landing_zone_exited)

func _process(_delta: float) -> void:
	planet.check_landing_proximity(ship.z_depth)

func _on_landing_zone_entered(p: Planet) -> void:
	hud.show_landing_prompt(true)
	print("Entering landing zone: ", p.planet_name)

func _on_landing_zone_exited(p: Planet) -> void:
	hud.show_landing_prompt(false)
	print("Exiting landing zone: ", p.planet_name)
