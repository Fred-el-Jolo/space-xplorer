class_name LandingOrchestrator
extends Node

signal landing_succeeded
signal ship_destroyed

const PAD_COUNTS: Dictionary = {
	POIData.POIType.PLANET: 4,
	POIData.POIType.STATION: 6,
	POIData.POIType.ASTEROID: 2,
	POIData.POIType.DERELICT: 1,
}

signal _phase_done(result: Dictionary)

var _ctx: LandingContext = null
var _landing_screen: LandingScreen = null

func init(landing_screen: LandingScreen) -> void:
	_landing_screen = landing_screen

func begin_landing(poi: PointOfInterest, ship: Ship) -> void:
	_ctx = LandingContext.new()
	_ctx.poi = poi
	_ctx.ship = ship
	_ctx.assigned_pad = pick_pad(poi.data.type)
	_ctx.approach_rng_seed = randi()
	_ctx.checkpoint_phase = 1
	_ctx.hull_at_sequence_start = ship.hull
	ShipInput.suspended = true
	_run_from_phase(1)

func pick_pad(type: POIData.POIType) -> int:
	return randi_range(1, PAD_COUNTS.get(type, 1))

static func is_ship_destroyed(ship: Ship) -> bool:
	return ship.hull <= 0.0

func apply_damage(ship: Ship, damage: float) -> void:
	ship.hull = maxf(0.0, ship.hull - damage)
	ship.hull_changed.emit(ship.hull)

func _run_from_phase(phase_num: int) -> void:
	_ctx.checkpoint_phase = phase_num
	var phase := _instantiate_phase(phase_num)
	add_child(phase)
	phase.phase_completed.connect(func(): _phase_done.emit({"ok": true, "damage": 0.0}), CONNECT_ONE_SHOT)
	phase.phase_failed.connect(func(dmg: float): _phase_done.emit({"ok": false, "damage": dmg}), CONNECT_ONE_SHOT)
	phase.begin(_ctx)
	var result: Dictionary = await _phase_done
	phase.queue_free()
	if result.ok:
		if phase_num == 4:
			_finish()
		else:
			_run_from_phase(phase_num + 1)
	else:
		apply_damage(_ctx.ship, result.damage)
		if is_ship_destroyed(_ctx.ship):
			ShipInput.suspended = false
			ship_destroyed.emit()
		else:
			_run_from_phase(phase_num)

const _PHASE_PATHS: Array[String] = [
	"",
	"res://src/scenes/landing/phase_atc.gd",
	"res://src/scenes/landing/phase_approach.gd",
	"res://src/scenes/landing/phase_bay_entry.gd",
	"res://src/scenes/landing/phase_touchdown.gd",
]

func _instantiate_phase(phase_num: int) -> Node:
	if phase_num < 1 or phase_num >= _PHASE_PATHS.size():
		push_error("LandingOrchestrator: unknown phase %d" % phase_num)
		return Node.new()
	var script: GDScript = load(_PHASE_PATHS[phase_num])
	return script.new()

func _finish() -> void:
	ShipInput.suspended = false
	_landing_screen.show_for(_ctx.poi, _ctx.ship)
	landing_succeeded.emit()
