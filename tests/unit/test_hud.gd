extends GutTest

var hud: HUD

func before_each() -> void:
	hud = preload("res://src/scenes/ui/hud.tscn").instantiate()
	add_child(hud)

func after_each() -> void:
	hud.queue_free()

func test_land_button_emits_land_requested_when_pressed() -> void:
	watch_signals(hud)
	hud.land_button.emit_signal("pressed")
	assert_signal_emitted(hud, "land_requested")

func test_show_land_button_true_makes_button_visible() -> void:
	hud.show_land_button(true)
	assert_true(hud.land_button.visible)

func test_show_land_button_false_hides_button() -> void:
	hud.show_land_button(true)
	hud.show_land_button(false)
	assert_false(hud.land_button.visible)
