extends CanvasLayer

func _ready() -> void:
	visible = OS.has_feature("mobile") or OS.has_feature("web")
