extends Node3D
class_name VRMenuPresenter

signal action_requested(action: StringName)
## The world map's view reached where it was easing to: see zoom_world_to_city.
signal world_zoom_settled

@export var panel_distance: float = 2.45
@export var panel_height_offset: float = -0.02
@export var screen_size: Vector2 = Vector2(3.35, 2.05)
@export var viewport_size: Vector2i = Vector2i(1280, 780)
## The city map and results wrap around the player in three panels: the city on the left, the map
## in the middle, the site and Deploy on the right. The side panels turn this far in toward the
## player and stand this far off the middle one's edges.
@export var wrap_angle_degrees: float = 30.0
@export var wrap_gap: float = 0.06

## How far above the play space origin the camera must be to count as a tracked, standing head.
const MIN_HEAD_HEIGHT := 0.8

var _player: Node3D
var _single_root: Node3D
var _wrap_root: Node3D
var _screen: XRToolsViewport2DIn3D
var _menu: VRMenuPanel
## Left, center, right.
var _wrap_screens: Array[XRToolsViewport2DIn3D] = []
var _left_panel: VRWrapPanel
var _map_panel: VRWrapPanel
var _right_panel: VRWrapPanel
var _wrapped: bool = false
var _is_visible: bool = false
## The panels have been put in front of a tracked head. Until then each show places them.
var _placed: bool = false
var _holo_nodes: Array[MeshInstance3D] = []
var _holo_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("VRMenuPresenter")
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	_single_root = Node3D.new()
	_single_root.name = "Single"
	add_child(_single_root)
	_wrap_root = Node3D.new()
	_wrap_root.name = "Wrap"
	add_child(_wrap_root)
	_build_holographic_frame()
	_build_screen()
	_build_wrap()
	hide_menu()

func _process(delta: float) -> void:
	# Shown before the head was tracked: placed once, as soon as it is.
	if _is_visible and not _placed and _head_tracked():
		recenter()
	if not _is_visible or _wrapped:
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

## The main menu: the breach city. entries are MissionCatalog.operation_entries; selected_id is
## the site the right panel shows and Deploy starts.
func show_city_map(entries: Array[Dictionary], selected_id: String, tier_id: String = DifficultyTier.STANDARD, training_first: bool = false) -> void:
	_show(true)
	_left_panel.show_city_status(entries, training_first)
	_map_panel.show_city_map(entries, selected_id)
	var selected: Dictionary = {}
	for entry in entries:
		if entry.get("id", "") == selected_id:
			selected = entry
	_right_panel.show_site_detail(selected, tier_id, training_first)

## The world front. world: see VRWrapPanel.show_world_status; entries are WorldMap.city_entries.
func show_world_map(world: Dictionary, entries: Array[Dictionary], selected_id: String) -> void:
	_show(true)
	_left_panel.show_world_status(world)
	_map_panel.show_world_map(entries, selected_id, world)
	var selected: Dictionary = {}
	for entry in entries:
		if entry.get("id", "") == selected_id:
			selected = entry
	_right_panel.show_world_city(selected, world)

## Closes the world map in on a city before its section opens. False when the world map is not
## showing; otherwise world_zoom_settled fires once it is there.
func zoom_world_to_city(city_id: String) -> bool:
	return _is_visible and _wrapped and _map_panel.zoom_world_to_city(city_id)

## One section of a city. city: see VRWrapPanel.show_operations_status.
func show_city_operations(city: Dictionary) -> void:
	_show(true)
	_left_panel.show_operations_status(city)
	_map_panel.show_operations_map(city)
	_right_panel.show_district_detail(city)

## report: see VRWrapPanel's results section. A world mission's report carries "world".
func show_results(report: Dictionary) -> void:
	_show(true)
	if report.has("world"):
		_left_panel.show_world_report(report)
		_map_panel.show_world_results_map(report)
		_right_panel.show_world_results_actions(report)
		return
	_left_panel.show_city_report(report)
	_map_panel.show_results_map(report)
	_right_panel.show_results_actions(report)

func show_training_complete(deploy_detail: String) -> void:
	_show(false)
	_menu.show_training_complete(deploy_detail)

func show_settings(music: String, effects: String, haptics: String, reduced_flashes: bool, from_pause: bool, own_music: bool = false) -> void:
	_show(false)
	_menu.show_settings(music, effects, haptics, reduced_flashes, from_pause, own_music)

func show_reset_confirmation() -> void:
	_show(false)
	_menu.show_reset_confirmation()

func show_pause(training: bool = false) -> void:
	_show(false)
	_menu.show_pause(training)

func show_abort_confirmation() -> void:
	_show(false)
	_menu.show_abort_confirmation()

func show_suspended() -> void:
	_show(false)
	_menu.show_suspended()

## Presses the button under a ray, on whichever showing panel the ray meets first.
func activate_from_aim(origin: Vector3, direction: Vector3) -> bool:
	var best_panel: VRMenuPanel = null
	var best_point := Vector2.ZERO
	var best_distance := INF
	for screen in _active_screens():
		var hit: Variant = _aim_hit(screen, origin, direction)
		if hit == null or float(hit[0]) >= best_distance:
			continue
		best_distance = float(hit[0])
		best_point = hit[1]
		best_panel = screen.get_meta(&"panel") as VRMenuPanel
	if best_panel == null:
		return false
	return best_panel.activate_at_viewport_point(best_point)

## Presses the button at a pointer ray's hit on one of the screens' bodies.
func activate_on_body(body: Object, hit: Vector3) -> bool:
	if not _is_visible or body == null or not body.has_method("global_to_viewport"):
		return false
	for screen in _active_screens():
		if screen.get_node_or_null("StaticBody3D") == body:
			var panel := screen.get_meta(&"panel") as VRMenuPanel
			return panel.activate_at_viewport_point(body.global_to_viewport(hit))
	return false

## [distance along the ray, viewport point] where the ray meets the screen, or null.
func _aim_hit(target: XRToolsViewport2DIn3D, origin: Vector3, direction: Vector3) -> Variant:
	var screen := target.get_node_or_null("Screen") as Node3D
	if screen == null or direction.length_squared() < 0.0001:
		return null
	var normal := screen.global_transform.basis.z.normalized()
	var travel := direction.normalized()
	var denom := travel.dot(normal)
	if absf(denom) < 0.0001:
		return null
	var distance := (screen.global_position - origin).dot(normal) / denom
	if distance < 0.05 or distance > 12.0:
		return null
	var hit := origin + travel * distance
	var local: Vector3 = screen.global_transform.affine_inverse() * hit
	var size := target.screen_size
	if absf(local.x) > size.x * 0.55 or absf(local.y) > size.y * 0.55:
		return null
	var vp := target.viewport_size
	return [distance, Vector2((local.x / size.x + 0.5) * vp.x, (0.5 - local.y / size.y) * vp.y)]

func hide_menu() -> void:
	_is_visible = false
	visible = false
	for screen in _all_screens():
		_set_screen_active(screen, false)

## Puts the panels in front of the head, where the camera says it is: the first placement.
func recenter() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as Node3D
	if _player == null:
		return
	var camera := _player.get_node_or_null("XRCamera3D") as Node3D
	var anchor := camera if camera else _player
	_place(anchor.global_position, -anchor.global_transform.basis.z)

## Holding the Meta button, the only thing that moves placed panels. XRLifecycleController has just
## moved the play space so the head stands over its origin, facing its forward, at the same height.
## The camera node shows that only a few frames later, and panels aimed by it then landed off to
## the side, one press closer each time. So they go where the head now is, read off the origin.
func recenter_on_play_space() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as Node3D
	if _player == null:
		return
	var camera := _player.get_node_or_null("XRCamera3D") as Node3D
	var head := _player.global_position
	if camera:
		head.y = camera.global_position.y
	_place(head, -_player.global_transform.basis.z)

func _place(head: Vector3, facing: Vector3) -> void:
	var forward := Vector3(facing.x, 0.0, facing.z)
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	global_position = head + forward * panel_distance + Vector3.UP * panel_height_offset
	global_transform.basis = Basis.looking_at(forward, Vector3.UP)
	_placed = _head_tracked()

## A standing head: the camera well above the play space floor. Before tracking starts the camera
## sits at the origin, and panels placed then would sit on the floor.
func _head_tracked() -> bool:
	var camera := _player.get_node_or_null("XRCamera3D") as Node3D if _player else null
	return camera != null and camera.global_position.y - _player.global_position.y >= MIN_HEAD_HEIGHT

func is_menu_visible() -> bool:
	return _is_visible

func _show(wrapped: bool) -> void:
	_is_visible = true
	visible = true
	_wrapped = wrapped
	_single_root.visible = not wrapped
	_wrap_root.visible = wrapped
	for screen in _all_screens():
		_set_screen_active(screen, (screen != _screen) == wrapped)
	if not _placed:
		recenter()
	# Victory opens the panels from the rift-close physics callback. A collision
	# shape changed in that callback does not come back until the idle frame.
	# https://docs.godotengine.org/en/stable/classes/class_collisionshape3d.html#class-collisionshape3d-property-disabled
	_arm_screen_collision.call_deferred()

func _set_screen_active(screen: XRToolsViewport2DIn3D, active: bool) -> void:
	screen.enabled = active
	# A throttled viewport drops the frames where a trigger click has to land.
	# https://docs.godotengine.org/en/stable/classes/class_subviewport.html#enum-subviewport-updatemode
	screen.update_mode = XRToolsViewport2DIn3D.UpdateMode.UPDATE_ALWAYS if active else XRToolsViewport2DIn3D.UpdateMode.UPDATE_ONCE

func _all_screens() -> Array[XRToolsViewport2DIn3D]:
	var screens: Array[XRToolsViewport2DIn3D] = [_screen]
	screens.append_array(_wrap_screens)
	return screens

func _active_screens() -> Array[XRToolsViewport2DIn3D]:
	if not _is_visible:
		return [] as Array[XRToolsViewport2DIn3D]
	if _wrapped:
		return _wrap_screens
	return [_screen] as Array[XRToolsViewport2DIn3D]

func ensure_screen_collision() -> void:
	_arm_screen_collision()

func _arm_screen_collision() -> void:
	if not _is_visible:
		return
	for screen in _active_screens():
		screen.enabled = true
		var shape := screen.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
		if shape:
			shape.set_deferred("disabled", false)

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
		_single_root.add_child(rail)
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
		_single_root.add_child(ring)
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
	_menu = preload("res://Scenes/UI/vr_menu_panel.tscn").instantiate() as VRMenuPanel
	_screen = _add_screen(_single_root, "MenuScreen", _menu, viewport_size, screen_size)

## The middle panel faces the player; each side panel stands off its edge, turned inward. They
## keep the single panel's pixels per meter, so text reads at the same size on both.
func _build_wrap() -> void:
	var pixels_per_meter := float(viewport_size.x) / screen_size.x
	var center_size := Vector2(VRWrapPanel.CENTER_PIXELS) / pixels_per_meter
	var side_size := Vector2(VRWrapPanel.SIDE_PIXELS) / pixels_per_meter
	var angle := deg_to_rad(wrap_angle_degrees)
	var half := side_size.x * 0.5
	var side_x := center_size.x * 0.5 + wrap_gap + half * cos(angle)
	var side_z := half * sin(angle)
	_left_panel = VRWrapPanel.new()
	_map_panel = VRWrapPanel.new()
	_right_panel = VRWrapPanel.new()
	_map_panel.world_zoom_settled.connect(func() -> void: world_zoom_settled.emit())
	var left := _add_screen(_wrap_root, "WrapLeft", _left_panel, VRWrapPanel.SIDE_PIXELS, side_size)
	left.position = Vector3(-side_x, 0.0, side_z)
	left.rotation.y = angle
	var center := _add_screen(_wrap_root, "WrapCenter", _map_panel, VRWrapPanel.CENTER_PIXELS, center_size)
	var right := _add_screen(_wrap_root, "WrapRight", _right_panel, VRWrapPanel.SIDE_PIXELS, side_size)
	right.position = Vector3(side_x, 0.0, side_z)
	right.rotation.y = -angle
	_wrap_screens = [left, center, right]

func _add_screen(parent: Node3D, screen_name: String, panel: VRMenuPanel, pixels: Vector2i, meters: Vector2) -> XRToolsViewport2DIn3D:
	var screen := preload("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn").instantiate() as XRToolsViewport2DIn3D
	screen.name = screen_name
	screen.screen_size = meters
	screen.viewport_size = Vector2(pixels)
	screen.update_mode = XRToolsViewport2DIn3D.UpdateMode.UPDATE_THROTTLED
	screen.throttle_fps = 30.0
	screen.transparent = XRToolsViewport2DIn3D.TransparancyMode.OPAQUE
	screen.unshaded = true
	screen.filter = true
	parent.add_child(screen)
	panel.action_requested.connect(_on_menu_action)
	screen.scene_node = panel
	screen.get_node("Viewport").add_child(panel)
	screen.set_meta(&"panel", panel)
	return screen

func _on_menu_action(action: StringName) -> void:
	action_requested.emit(action)
