extends Node3D

## Edge-of-view chevrons for phantoms outside the headset view.
## The colored column is the landmark once you turn. This is the order to turn.
## Label3D: https://docs.godotengine.org/en/stable/classes/class_label3d.html

const VIEW_EDGE := deg_to_rad(50.0)
const HIDE_ANGLE := deg_to_rad(18.0)
const MARKER_DISTANCE := 1.35

var _markers: Dictionary = {}
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	var camera := _find_camera()
	var live: Dictionary = {}
	if camera == null:
		_clear_markers()
		return
	for phantom in get_tree().get_nodes_in_group("phantom"):
		if not is_instance_valid(phantom):
			continue
		if phantom.has_method("shows_approach_cue") and not phantom.shows_approach_cue():
			continue
		var id := phantom.get_instance_id()
		live[id] = phantom
		_aim_marker(id, phantom, camera)
	var stale: Array = []
	for id in _markers.keys():
		if not live.has(id):
			stale.append(id)
	for id in stale:
		var marker: Node = _markers[id]
		if is_instance_valid(marker):
			marker.queue_free()
		_markers.erase(id)

func _aim_marker(id: int, phantom: Node3D, camera: Node3D) -> void:
	var marker := _marker_for(id, phantom)
	var to_phantom := phantom.global_position - camera.global_position
	var flat := Vector3(to_phantom.x, 0.0, to_phantom.z)
	if flat.length_squared() < 0.36:
		marker.visible = false
		return
	var direction := flat.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var yaw := forward.signed_angle_to(direction, Vector3.UP)
	if absf(yaw) <= HIDE_ANGLE:
		marker.visible = false
		return
	marker.visible = true
	var shown := clampf(yaw, -VIEW_EDGE, VIEW_EDGE)
	var shown_dir := forward.rotated(Vector3.UP, shown)
	marker.global_position = camera.global_position + shown_dir * MARKER_DISTANCE + Vector3(0.0, -0.05, 0.0)
	var aim_target := marker.global_position + direction
	if aim_target.distance_squared_to(marker.global_position) > 0.001:
		marker.look_at(aim_target, Vector3.UP)
	var closeness := clampf(1.0 - flat.length() / 14.0, 0.25, 1.0)
	var pulse := 0.65 + sin(_time * lerpf(3.0, 9.0, closeness)) * 0.35
	var arrow := marker.get_node("Arrow") as MeshInstance3D
	if arrow:
		var material := arrow.material_override as StandardMaterial3D
		if material:
			material.emission_energy_multiplier = lerpf(1.5, 5.0, closeness) * pulse
	var label := marker.get_node("Label") as Label3D
	if label:
		label.text = "%s  %dm" % [_variant_name(phantom), int(round(flat.length()))]

func _marker_for(id: int, phantom: Node3D) -> Node3D:
	if _markers.has(id) and is_instance_valid(_markers[id]):
		return _markers[id]
	var color := Color(0.8, 0.9, 1.0)
	var raw = phantom.get("phantom_color")
	if raw is Color:
		color = raw
	var marker := Node3D.new()
	marker.name = "PhantomBearing"
	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.07, 0.52)
	arrow.mesh = mesh
	arrow.position = Vector3(0.0, 0.0, -0.2)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.95)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.2
	arrow.material_override = material
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(arrow)
	var label := Label3D.new()
	label.name = "Label"
	label.text = _variant_name(phantom)
	label.font_size = 64
	label.pixel_size = 0.0022
	label.position = Vector3(0.0, 0.16, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.25)
	label.outline_size = 12
	label.outline_modulate = Color(0.02, 0.02, 0.04)
	label.no_depth_test = true
	marker.add_child(label)
	add_child(marker)
	_markers[id] = marker
	return marker

func _variant_name(phantom: Node) -> String:
	match String(phantom.get("variant_id")):
		"yellow":
			return "YELLOW"
		"blue":
			return "BLUE"
		"green":
			return "GREEN"
		"pink":
			return "PINK"
		_:
			return "PHANTOM"

func _clear_markers() -> void:
	for id in _markers.keys():
		var marker: Node = _markers[id]
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()

func _find_camera() -> Node3D:
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if player == null:
		return null
	return player.get_node_or_null("XRCamera3D") as Node3D
