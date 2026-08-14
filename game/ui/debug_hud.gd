extends VBoxContainer

@onready var fps_value: Label = $FPSValue


func _process(_delta: float) -> void:
    fps_value.text = "FPS: %d" % Engine.get_frames_per_second()

