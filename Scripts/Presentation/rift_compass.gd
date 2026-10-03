extends Node3D
class_name RiftCompass

## Edge-of-view marker for open rifts. The world beacon is the landmark;
## this chevron stays inside the headset view until you are looking at it.
## Label3D: https://docs.godotengine.org/en/stable/classes/class_label3d.html

const VIEW_EDGE := deg_to_rad(46.0)
const HIDE_ANGLE := deg_to_rad(16.0)
const MARKER_DISTANCE := 1.55

var _markers: Dictionary = {}

func _process(_delta: float) -> void:
	var camera := _find_camera()
	var live: Dictionary = {}
	if camera == null:
		_clear_markers()
		return
	for rift in get_tree().get_nodes_in_group("active_rift"):
		if not is_instance_valid(rift):
			continue
		if rift.has_method("is_marked") and not rift.is_marked():
			continue
		var id := rift.get_instance_id()
		live[id] = rift
		_aim_marker(id, rift, camera)
	var stale: Array = []
	for id in _markers.keys():
		if not live.has(id):
			stale.append(id)
	for id in stale:
		var marker: Node = _markers[id]
		if is_instance_valid(marker):
			marker.queue_free()
		_markers.erase(id)

func _aim_marker(id: int, rift: Node3D, camera: Node3D) -> void:
	var marker := _marker_for(id)
	var to_rift := rift.global_position - camera.global_position
	to_rift.y = 0.0
	if to_rift.length_squared() < 0.25:
		marker.visible = false
		return
	var direction := to_rift.normalized()
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
	marker.global_position = camera.global_position + shown_dir * MARKER_DISTANCE + Vector3(0.0, -0.18, 0.0)
	var aim_target := marker.global_position + direction
	if aim_target.distance_squared_to(marker.global_position) > 0.001:
		marker.look_at(aim_target, Vector3.UP)
	var label := marker.get_node("Label") as Label3D
	if label:
		label.text = "RIFT  %dm" % int(round(to_rift.length()))

func _marker_for(id: int) -> Node3D:
	if _markers.has(id) and is_instance_valid(_markers[id]):
		return _markers[id]
	var marker := Node3D.new()
	marker.name = "RiftMarker"
	var arrow := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.07, 0.28)
	arrow.mesh = mesh
	arrow.position = Vector3(0.0, 0.0, -0.12)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.45, 0.95, 1.0, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.9, 1.0)
	material.emission_energy_multiplier = 2.6
	arrow.material_override = material
	marker.add_child(arrow)
	var label := Label3D.new()
	label.name = "Label"
	label.text = "RIFT"
	label.font_size = 42
	label.pixel_size = 0.0018
	label.position = Vector3(0.0, 0.1, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.8, 0.96, 1.0)
	label.outline_size = 10
	label.outline_modulate = Color(0.02, 0.04, 0.08)
	label.no_depth_test = true
	marker.add_child(label)
	add_child(marker)
	_markers[id] = marker
	return marker

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
