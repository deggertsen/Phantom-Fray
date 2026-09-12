extends Node

@export var sample_interval: float = 1.0
@export var warning_fps: float = 68.0

var _remaining: float = 0.0

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0:
		return
	_remaining = sample_interval
	var fps := Engine.get_frames_per_second()
	if OS.is_debug_build() and fps < warning_fps:
		push_warning("Performance: %.1f FPS, %d phantoms, %d nodes" % [fps, get_tree().get_nodes_in_group("phantom").size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
