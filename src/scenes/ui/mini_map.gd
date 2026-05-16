class_name MiniMap
extends Node2D

const MAP_SIZE   := Vector2(160.0, 100.0)
const WORLD_MIN  := Vector2(-200.0, -200.0)
const WORLD_RANGE := Vector2(1600.0, 1000.0)

var _ship: Ship = null
var _pois: Array[PointOfInterest] = []

func connect_to_world(ship: Ship, pois: Array[PointOfInterest]) -> void:
	_ship = ship
	_pois = pois

func _process(_delta: float) -> void:
	if _ship != null:
		queue_redraw()

func _world_to_map(world_pos: Vector2) -> Vector2:
	return (world_pos - WORLD_MIN) / WORLD_RANGE * MAP_SIZE

static func depth_dot_radius(depth_dist: float) -> float:
	return lerpf(6.0, 2.0, clampf(depth_dist / 2000.0, 0.0, 1.0))

static func depth_dot_alpha(depth_dist: float) -> float:
	return lerpf(1.0, 0.3, clampf(depth_dist / 2000.0, 0.0, 1.0))

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.04, 0.07, 0.18, 0.82))
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.3, 0.5, 0.9, 0.7), false, 1.5)
	draw_string(font, Vector2(4.0, 11.0), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.5, 0.7, 1.0, 0.9))
	for poi: PointOfInterest in _pois:
		if poi.data == null:
			continue
		var mp := _world_to_map(poi.position)
		var depth_dist := absf(_ship.z_depth - poi.z_depth) if _ship else 0.0
		var col := _poi_color(poi.data.type)
		col.a = depth_dot_alpha(depth_dist)
		draw_circle(mp, depth_dot_radius(depth_dist), col)
		draw_string(font, mp + Vector2(4.0, 3.0), poi.data.poi_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col)
	if _ship:
		var sp := _world_to_map(_ship.position).clamp(Vector2(2, 2), MAP_SIZE - Vector2(2, 2))
		draw_circle(sp, 4.0, Color(0.1, 1.0, 0.8, 1.0))

func _poi_color(type: POIData.POIType) -> Color:
	match type:
		POIData.POIType.PLANET:   return Color(0.3, 0.9, 0.4)
		POIData.POIType.STATION:  return Color(0.3, 0.6, 1.0)
		POIData.POIType.ASTEROID: return Color(1.0, 0.6, 0.2)
		POIData.POIType.DERELICT: return Color(0.7, 0.7, 0.7)
	return Color.WHITE
