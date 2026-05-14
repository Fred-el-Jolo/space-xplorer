extends GutTest

var entity: WorldEntity

func before_each() -> void:
	entity = WorldEntity.new()
	entity.z_depth = 100.0
	add_child(entity)

func after_each() -> void:
	entity.queue_free()

func test_apply_depth_scale_at_100() -> void:
	entity.z_depth = 100.0
	entity._apply_depth()
	assert_almost_eq(entity.scale.x, 1.0, 0.001)

func test_apply_depth_scale_at_200() -> void:
	entity.z_depth = 200.0
	entity._apply_depth()
	assert_almost_eq(entity.scale.x, 0.5, 0.001)

func test_apply_depth_sets_z_index() -> void:
	entity.z_depth = 250.0
	entity._apply_depth()
	assert_eq(entity.z_index, -102)

func test_entity_hidden_beyond_max_depth() -> void:
	entity.z_depth = 15000.0
	entity._apply_depth()
	assert_false(entity.visible)

func test_entity_visible_within_max_depth() -> void:
	entity.z_depth = 500.0
	entity._apply_depth()
	assert_true(entity.visible)
