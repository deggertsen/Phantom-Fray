extends Node3D

## Minimal life-force presentation: wrist meter, camera tint, heartbeat.

const LifeForceManagerScript := preload("res://Scripts/Player/life_force_manager.gd")

@export var life_force_manager_path: NodePath = NodePath("../LifeForceManager")
@export var meter_offset: Vector3 = Vector3(0.0, 0.08, -0.05)
@export var tint_distance: float = 0.35

var _manager: Node
var _fill_mesh: MeshInstance3D
var _label: Label3D
var _tint_mesh: MeshInstance3D
var _heartbeat: AudioStreamPlayer
var _drain_blip: AudioStreamPlayer
var _fill_material: StandardMaterial3D
var _tint_material: StandardMaterial3D
var _base_fill_width: float = 0.12

const COLOR_HEALTHY := Color(0.25, 0.65, 1.0)
const COLOR_CAUTION := Color(0.55, 0.35, 0.95)
const COLOR_DANGER := Color(0.95, 0.35, 0.55)
const COLOR_CRITICAL := Color(0.95, 0.15, 0.15)

func _ready() -> void:
	_manager = get_node_or_null(life_force_manager_path)
	if _manager == null or not (_manager is LifeForceManagerScript):
		_manager = get_tree().get_first_node_in_group("LifeForceManager")
	if _manager == null:
		push_warning("LifeForceFeedback: LifeForceManager not found")
		return

	_build_meter()
	_build_camera_tint()
	_build_audio()

	_manager.life_force_changed.connect(_on_life_force_changed)
	_manager.life_force_state_changed.connect(_on_life_force_state_changed)
	_manager.damage_applied.connect(_on_damage_applied)

	_on_life_force_changed(_manager.current_life_force, _manager.max_life_force)
	_on_life_force_state_changed(_manager.get_state_name())

func _build_meter() -> void:
	position = meter_offset

	var background := MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(_base_fill_width + 0.01, 0.025, 0.008)
	background.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.05, 0.05, 0.08, 0.85)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	background.material_override = bg_mat
	add_child(background)

	_fill_mesh = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(_base_fill_width, 0.018, 0.01)
	_fill_mesh.mesh = fill_mesh
	_fill_material = StandardMaterial3D.new()
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_material.albedo_color = COLOR_HEALTHY
	_fill_material.emission_enabled = true
	_fill_material.emission = COLOR_HEALTHY
	_fill_material.emission_energy_multiplier = 1.5
	_fill_mesh.material_override = _fill_material
	add_child(_fill_mesh)

	_label = Label3D.new()
	_label.text = "LIFE 100"
	_label.font_size = 24
	_label.pixel_size = 0.0015
	_label.position = Vector3(0.0, 0.035, 0.0)
	_label.modulate = COLOR_HEALTHY
	_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_label.no_depth_test = true
	add_child(_label)

func _build_camera_tint() -> void:
	# Feedback lives under LeftHandController → XROrigin3D
	var origin := get_parent().get_parent() as Node3D
	var camera: XRCamera3D = null
	if origin:
		camera = origin.get_node_or_null("XRCamera3D") as XRCamera3D
	if camera == null:
		push_warning("LifeForceFeedback: XRCamera3D not found for tint")
		return

	_tint_mesh = MeshInstance3D.new()
	_tint_mesh.name = "LifeForceTint"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_tint_mesh.mesh = quad
	_tint_mesh.position = Vector3(0.0, 0.0, -tint_distance)
	_tint_material = StandardMaterial3D.new()
	_tint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint_material.albedo_color = Color(0.8, 0.0, 0.15, 0.0)
	_tint_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tint_material.render_priority = 10
	_tint_mesh.material_override = _tint_material
	_tint_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(_tint_mesh)

func _build_audio() -> void:
	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.name = "HeartbeatPlayer"
	_heartbeat.volume_db = -8.0
	_heartbeat.bus = &"Master"
	add_child(_heartbeat)

	var heartbeat_stream := _load_or_create_heartbeat_stream()
	if heartbeat_stream:
		_heartbeat.stream = heartbeat_stream

	_drain_blip = AudioStreamPlayer.new()
	_drain_blip.name = "DrainBlipPlayer"
	_drain_blip.volume_db = -12.0
	add_child(_drain_blip)
	_drain_blip.stream = _create_drain_blip_stream()

func _on_life_force_changed(current: float, maximum: float) -> void:
	var ratio := 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	if _fill_mesh:
		_fill_mesh.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
		_fill_mesh.position.x = -(_base_fill_width * (1.0 - ratio) * 0.5)
	if _label:
		_label.text = "LIFE %d" % int(round(current))

func _on_life_force_state_changed(state: StringName) -> void:
	var color := _color_for_state(state)
	if _fill_material:
		_fill_material.albedo_color = color
		_fill_material.emission = color
	if _label:
		_label.modulate = color
	_update_tint(state)
	_update_heartbeat(state)

func _on_damage_applied(_amount: float, _current: float) -> void:
	if _drain_blip:
		_drain_blip.play()

func _update_tint(state: StringName) -> void:
	if _tint_material == null:
		return
	var alpha := 0.0
	match state:
		&"healthy":
			alpha = 0.0
		&"caution":
			alpha = 0.05
		&"danger":
			alpha = 0.12
		&"critical", &"depleted":
			alpha = 0.22
	_tint_material.albedo_color.a = alpha

func _update_heartbeat(state: StringName) -> void:
	if _heartbeat == null or _heartbeat.stream == null:
		return

	match state:
		&"healthy":
			if _heartbeat.playing:
				_heartbeat.stop()
			return
		&"caution":
			_heartbeat.volume_db = -18.0
			_heartbeat.pitch_scale = 0.95
		&"danger":
			_heartbeat.volume_db = -10.0
			_heartbeat.pitch_scale = 1.05
		&"critical", &"depleted":
			_heartbeat.volume_db = -4.0
			_heartbeat.pitch_scale = 1.25

	if not _heartbeat.playing:
		_heartbeat.play()

func _color_for_state(state: StringName) -> Color:
	match state:
		&"caution":
			return COLOR_CAUTION
		&"danger":
			return COLOR_DANGER
		&"critical", &"depleted":
			return COLOR_CRITICAL
		_:
			return COLOR_HEALTHY

func _load_or_create_heartbeat_stream() -> AudioStream:
	const path := "res://Assets/Audio/SFX/heartbeat.wav"
	if ResourceLoader.exists(path):
		return load(path)
	return _create_heartbeat_stream()

func _create_heartbeat_stream() -> AudioStreamWAV:
	## Procedural double-thump loop so we ship without a binary asset dependency.
	var sample_rate := 22050
	var duration := 0.85
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var sample := 0.0
		sample += _thump(t, 0.05, 0.08, 55.0)
		sample += _thump(t, 0.22, 0.07, 45.0)
		sample = clampf(sample, -1.0, 1.0)
		var pcm := int(sample * 32767.0)
		data.encode_s16(i * 2, pcm)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func _create_drain_blip_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.12
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 28.0)
		var sample := sin(TAU * 180.0 * t) * env * 0.45
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _thump(t: float, start: float, length: float, freq: float) -> float:
	if t < start or t > start + length:
		return 0.0
	var local := t - start
	var env := exp(-local * 22.0)
	return sin(TAU * freq * local) * env * 0.7
