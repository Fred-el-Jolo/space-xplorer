class_name DepthSystem

const BASE_SCALE: float = 100.0
const PERSPECTIVE_FACTOR: float = 0.3
const MAX_Z_DEPTH: float = 10000.0
const MIN_Z_DEPTH: float = 1.0

static func compute_scale(z_depth: float) -> float:
	return BASE_SCALE / maxf(z_depth, MIN_Z_DEPTH)

static func compute_y_offset(world_y: float, z_depth: float) -> float:
	return world_y - (z_depth * PERSPECTIVE_FACTOR)

static func compute_draw_order(z_depth: float) -> int:
	return -int(z_depth)

static func is_visible(z_depth: float) -> bool:
	return z_depth <= MAX_Z_DEPTH
