extends Node3D

@export var round_controller_path: NodePath

var _score_label: Label3D
var _progress_label: Label3D
var _combo_label: Label3D
var _time_label: Label3D

func _ready() -> void:
	_create_hud()
	await get_tree().process_frame
	var controller := get_node_or_null(round_controller_path) as RoundController
	if controller == null:
		controller = get_tree().get_first_node_in_group("RoundController") as RoundController
	if controller:
		controller.score_changed.connect(_on_score_changed)
		controller.rift_progress_changed.connect(_on_progress_changed)
		controller.combo_changed.connect(_on_combo_changed)
		controller.time_changed.connect(_on_time_changed)

func _create_hud() -> void:
	_score_label = _make_label("SCORE 000000", Vector3(0.0, 0.055, 0.0), 28, Color(0.35, 0.9, 1.0))
	_progress_label = _make_label("RIFTS 0/3", Vector3(0.0, 0.025, 0.0), 24, Color(0.65, 0.95, 1.0))
	_combo_label = _make_label("x1.00", Vector3(0.0, -0.005, 0.0), 22, Color(1.0, 0.8, 0.2))
	_time_label = _make_label("04:00", Vector3(0.0, -0.032, 0.0), 22, Color.WHITE)

func _make_label(text: String, offset: Vector3, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = offset
	label.font_size = size
	label.pixel_size = 0.0015
	label.modulate = color
	label.outline_size = 6
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)
	return label

func _on_score_changed(total: int, _delta: int, _reason: StringName) -> void:
	_score_label.text = "SCORE %06d" % total

func _on_progress_changed(closed: int, total: int) -> void:
	_progress_label.text = "RIFTS %d/%d" % [closed, total]

func _on_combo_changed(_streak: int, multiplier: float) -> void:
	_combo_label.text = "x%.2f" % multiplier
	_combo_label.modulate = Color(1.0, 0.8, 0.2) if multiplier > 1.0 else Color(0.55, 0.7, 0.8)

func _on_time_changed(seconds: float) -> void:
	var whole := ceili(seconds)
	_time_label.text = "%02d:%02d" % [whole / 60, whole % 60]
	_time_label.modulate = Color(1.0, 0.3, 0.3) if seconds < 30.0 else Color.WHITE
