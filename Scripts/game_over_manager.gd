extends Node

## Ends the round when life force hits zero; trigger to restart.

const LifeForceManagerScript := preload("res://Scripts/Player/life_force_manager.gd")

@export var game_over_text: String = "LIFE FORCE DEPLETED\nPull trigger to retry"
@export var label_distance: float = 1.8
@export var label_height: float = 1.5

var _manager: Node
var _is_game_over: bool = false
var _game_over_label: Label3D
var _player: Node3D

func _ready() -> void:
	await get_tree().process_frame
	_manager = get_tree().get_first_node_in_group("LifeForceManager")
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	if _manager == null or not (_manager is LifeForceManagerScript):
		push_warning("GameOverManager: LifeForceManager not found")
		_manager = null
		return
	_manager.life_force_depleted.connect(_on_life_force_depleted)
	_connect_restart_inputs()

func _connect_restart_inputs() -> void:
	if _player == null:
		return
	for controller_name in ["LeftHandController", "RightHandController"]:
		var controller := _player.get_node_or_null(controller_name) as XRController3D
		if controller and not controller.button_pressed.is_connected(_on_controller_button_pressed):
			controller.button_pressed.connect(_on_controller_button_pressed)

func _on_life_force_depleted() -> void:
	if _is_game_over:
		return
	_is_game_over = true
	_stop_spawning()
	_neutralize_phantoms()
	_show_game_over_label()

func _stop_spawning() -> void:
	var spawn_manager := get_tree().get_first_node_in_group("RiftSpawnManager")
	if spawn_manager == null:
		spawn_manager = get_node_or_null("/root/Main/RiftSpawnManager")
	if spawn_manager and spawn_manager.has_method("stop_spawning"):
		spawn_manager.stop_spawning()

	# Halt phantoms mid-stream from every active rift
	if spawn_manager:
		var rifts: Variant = spawn_manager.get("rift_instances")
		if rifts is Array:
			for rift in rifts:
				if is_instance_valid(rift) and rift.has_method("stop_spawning"):
					rift.stop_spawning()

func _neutralize_phantoms() -> void:
	for phantom in get_tree().get_nodes_in_group("phantom"):
		if not is_instance_valid(phantom):
			continue
		phantom.set_physics_process(false)
		phantom.set_process(false)
		if phantom is CollisionObject3D:
			phantom.collision_layer = 0
			phantom.collision_mask = 0
		var area := phantom.get_node_or_null("Area3D") as Area3D
		if area:
			area.collision_layer = 0
			area.collision_mask = 0
			area.monitoring = false

func _show_game_over_label() -> void:
	if _game_over_label and is_instance_valid(_game_over_label):
		_game_over_label.queue_free()

	_game_over_label = Label3D.new()
	_game_over_label.name = "GameOverLabel"
	_game_over_label.text = game_over_text
	_game_over_label.font_size = 64
	_game_over_label.pixel_size = 0.004
	_game_over_label.modulate = Color(1.0, 0.25, 0.3)
	_game_over_label.outline_size = 16
	_game_over_label.outline_modulate = Color(0.1, 0.0, 0.0)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_game_over_label.no_depth_test = true
	add_child(_game_over_label)

	var origin := Vector3.ZERO
	var forward := Vector3.FORWARD
	if _player:
		var camera := _player.get_node_or_null("XRCamera3D") as Node3D
		var look_from := camera if camera else _player
		origin = look_from.global_position
		forward = -look_from.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.001:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()

	_game_over_label.global_position = origin + forward * label_distance + Vector3.UP * 0.2
	_game_over_label.global_position.y = maxf(_game_over_label.global_position.y, label_height)

func _on_controller_button_pressed(button_name: String) -> void:
	if not _is_game_over:
		return
	if button_name == "trigger_click" or button_name == "ax_button" or button_name == "by_button":
		_restart_round()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_game_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_restart_round()

func _restart_round() -> void:
	get_tree().reload_current_scene()
