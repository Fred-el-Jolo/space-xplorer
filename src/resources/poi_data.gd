class_name POIData
extends Resource

enum POIType { PLANET, STATION, ASTEROID, DERELICT }

@export var type: POIType = POIType.PLANET
@export var poi_name: String = "Unknown"
@export var description: String = ""
@export var landing_threshold: float = 60.0
