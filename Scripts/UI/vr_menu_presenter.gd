extends Node3D
class_name VRMenuPresenter

signal action_requested(action: StringName)

@export var panel_distance: float = 2.45
@export var panel_height_offset: float = -0.02
@export var screen_size: Vector2 = Vector2(3.35, 2.05)
@export var viewport_size: Vector2i = Vector2i(1280, 780)

var _player: Node3D
var _screen: XRToolsViewport2DIn3D
var _menu: VRMenuPanel
var _is_visible: bool = false
var _holo_nodes: Array[MeshInstance3D] = []
var _holo_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("VRMenuPresenter")
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	_build_holographic_frame()
	_build_screen()
	hide_menu()

func _process(delta: float) -> void:
	if not _is_visible:
		return
	_holo_time += delta
	for index in range(_holo_nodes.size()):
		var node := _holo_nodes[index]
		if not is_instance_valid(node):
			continue
		node.rotation.z += delta * (0.12 + index * 0.035) * (-1.0 if index % 2 else 1.0)
		var material := node.material_override as StandardMaterial3D
		if material:
			material.emission_energy_multiplier = 1.1 + sin(_holo_time * 1.8 + index) * 0.35

func show_main_menu(deploy_detail: String = "") -> void:
	_show()
	if deploy_detail == "":
		_menu.show_main_menu()
	else:
		_menu.show_main_menu(deploy_detail)

func show_operations(entries: Array[Dictionary]) -> void:
	_show()
	_menu.show_operations(entries)

func show_tutorial(page_index: int, pages: Array[Dictionary]) -> void:
	_show()
	_menu.show_tutorial(page_index, pages)

func show_settings(music: String, haptics: String, reduced_flashes: bool, from_pause: bool) -> void:
	_show()
	_menu.show_settings(music, haptics, reduced_flashes, from_pause)

func show_pause() -> void:
	_show()
	_menu.show_pause()

func show_abort_confirmation() -> void:
	_show()
	_menu.show_abort_confirmation()

func show_suspended() -> void:
	_show()
	_menu.show_suspended()

func show_results(outcome: StringName, score: int, debrief: String = "", next_title: String = "") -> void:
	_show()
	_menu.show_results(outcome, score, debrief, next_title)

func activate_at_viewport_point(point: Vector2) -> bool:
	if _menu == null or not _is_visible:
		return false
	return _menu.activate_at_viewport_point(point)

func hide_menu() -> void:
	_is_visible = false
	visible = false
	if _screen:
		_screen.enabled = false
		# https://docs.godotengine.org/en/stable/classes/class_subviewport.html#enum-subviewport-updatemode
		_screen.update_mode = XRToolsViewport2DIn3D.UpdateMode.UPDATE_ONCE

func recenter() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as Node3D
	if _player == null:
		return
	var camera := _player.get_node_or_null("XRCamera3D") as Node3D
	var anchor := camera if camera else _player
	var forward := -anchor.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	global_position = anchor.global_position + forward * panel_distance + Vector3.UP * panel_height_offset
	global_transform.basis = Basis.looking_at(forward, Vector3.UP)

func is_menu_visible() -> bool:
	return _is_visible

func _show() -> void:
	_is_visible = true
	visible = true
	_screen.enabled = true
	# A throttled viewport drops the frames where a trigger click has to land.
	_screen.update_mode = XRToolsViewport2DIn3D.UpdateMode.UPDATE_ALWAYS
	recenter()

func _build_holographic_frame() -> void:
	var cyan := _holo_material(Color("35e7ff"), 1.35)
	var magenta := _holo_material(Color("ff35c8"), 1.15)
	var rail_positions := [
		[Vector3(-1.83, 0.0, 0.035), Vector3(0.025, 2.28, 0.025), cyan],
		[Vector3(1.83, 0.0, 0.035), Vector3(0.025, 2.28, 0.025), magenta],
		[Vector3(0.0, 1.15, 0.035), Vector3(3.68, 0.025, 0.025), magenta],
		[Vector3(0.0, -1.15, 0.035), Vector3(3.68, 0.025, 0.025), cyan],
	]
	for entry in rail_positions:
		var rail := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = entry[1]
		rail.mesh = mesh
		rail.position = entry[0]
		rail.material_override = entry[2]
		add_child(rail)
	for index in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.22 + index * 0.09
		torus.outer_radius = 0.235 + index * 0.09
		torus.rings = 18
		torus.ring_segments = 32
		ring.mesh = torus
		ring.position = Vector3(1.48, 0.77, 0.06 + index * 0.008)
		ring.rotation.x = PI * 0.5
		ring.material_override = cyan if index % 2 == 0 else magenta
		add_child(ring)
		_holo_nodes.append(ring)

func _holo_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.72)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _build_screen() -> void:
	_screen = preload("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn").instantiate() as XRToolsViewport2DIn3D
	_screen.name = "MenuScreen"
	_screen.screen_size = screen_size
	_screen.viewport_size = Vector2(viewport_size)
	_screen.update_mode = XRToolsViewport2DIn3D.UpdateMode.UPDATE_THROTTLED
	_screen.throttle_fps = 30.0
	_screen.transparent = XRToolsViewport2DIn3D.TransparancyMode.OPAQUE
	_screen.unshaded = true
	_screen.filter = true
	add_child(_screen)
	_menu = preload("res://Scenes/UI/vr_menu_panel.tscn").instantiate() as VRMenuPanel
	_menu.action_requested.connect(_on_menu_action)
	_screen.scene_node = _menu
	_screen.get_node("Viewport").add_child(_menu)

func _on_menu_action(action: StringName) -> void:
	action_requested.emit(action)
