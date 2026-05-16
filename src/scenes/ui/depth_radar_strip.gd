class_name DepthRadarStrip
extends Control

const STRIP_WIDTH: float = 14.0
const GLOW_THRESHOLD: float = 500.0
const DEPTH_RANGE: float = DepthSystem.MAX_Z_DEPTH - DepthSystem.MIN_Z_DEPTH

var _ship: Ship = null
var _pois: Array[PointOfInterest] = []

func connect_to_world(ship: Ship, pois: Array[PointOfInterest]) -> void:
	_ship = ship
	_pois = pois

func depth_to_y(depth: float) -> float:
	return ((depth - DepthSystem.MIN_Z_DEPTH) / DEPTH_RANGE) * size.y

static func is_near_depth(ship_depth: float, poi_depth: float) -> bool:
	return absf(ship_depth - poi_depth) <= GLOW_THRESHOLD

func _process(_delta: float) -> void:
	if _ship:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, STRIP_WIDTH, size.y), Color(0.04, 0.07, 0.18, 0.82))
	draw_rect(Rect2(0.0, 0.0, STRIP_WIDTH, size.y), Color(0.3, 0.5, 0.9, 0.5), false, 1.0)
	if _ship == null:
		return
	var font := ThemeDB.fallback_font
	for poi: PointOfInterest in _pois:
		if poi.data == null:
			continue
		var col := _poi_color(poi.data.type)
		var y: float = depth_to_y(poi.z_depth)
		var band_px: float = (poi.data.landing_threshold / DEPTH_RANGE) * size.y
		var near: bool = is_near_depth(_ship.z_depth, poi.z_depth)
		col.a = 1.0 if near else 0.5
		draw_rect(Rect2(1.0, y - band_px * 0.5, STRIP_WIDTH - 2.0, maxf(band_px, 3.0)), col)
		if near:
			draw_string(font, Vector2(STRIP_WIDTH + 2.0, y + 4.0), poi.data.poi_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	var ship_y: float = depth_to_y(_ship.z_depth)
	draw_circle(Vector2(STRIP_WIDTH * 0.5, ship_y), 4.0, Color(0.1, 1.0, 0.8, 1.0))

func _poi_color(type: POIData.POIType) -> Color:
	match type:
		POIData.POIType.PLANET:   return Color(0.3, 0.9, 0.4)
		POIData.POIType.STATION:  return Color(0.3, 0.6, 1.0)
		POIData.POIType.ASTEROID: return Color(1.0, 0.6, 0.2)
		POIData.POIType.DERELICT: return Color(0.7, 0.7, 0.7)
	return Color.WHITE
