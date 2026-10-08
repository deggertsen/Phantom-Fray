extends Node3D

## Life-force presentation around the player: camera tint, frost and veins, damage
## distortion, heartbeat. The life readout itself is on the wrist display (round_hud.gd).

const LifeForceManagerScript := preload("res://Scripts/Player/life_force_manager.gd")

@export var life_force_manager_path: NodePath = NodePath("../LifeForceManager")
@export var tint_distance: float = 0.35
@export_range(0.0, 1.0, 0.05) var tint_strength: float = 1.0

var _manager: Node
var _tint_mesh: MeshInstance3D
var _distort_mesh: MeshInstance3D
var _distort_material: ShaderMaterial
var _distort_tween: Tween
var _impact_mesh: MeshInstance3D
var _impact_material: ShaderMaterial
var _impact_tween: Tween
var _heartbeat: AudioStreamPlayer
var _drain_blip: AudioStreamPlayer
var _depletion_stinger: AudioStreamPlayer
var _tint_material: StandardMaterial3D
var _veins_mesh: MeshInstance3D
var _veins_material: ShaderMaterial
var _veins_tween: Tween
var _veins_strength: float = 0.0

const VEIN_STRENGTH := {&"healthy": 0.0, &"caution": 0.3, &"danger": 0.6, &"critical": 0.9, &"depleted": 1.0}
const VEIN_BEAT := {&"healthy": 1.0, &"caution": 1.15, &"danger": 1.4, &"critical": 1.8, &"depleted": 0.0}

func _ready() -> void:
	_manager = get_node_or_null(life_force_manager_path)
	if _manager == null or not (_manager is LifeForceManagerScript):
		_manager = get_tree().get_first_node_in_group("LifeForceManager")
	if _manager == null:
		push_warning("LifeForceFeedback: LifeForceManager not found")
		return

	_build_camera_tint()
	_build_audio()

	_manager.life_force_state_changed.connect(_on_life_force_state_changed)
	_manager.damage_applied.connect(_on_damage_applied)
	_manager.life_force_depleted.connect(_on_life_force_depleted)

	_on_life_force_state_changed(_manager.get_state_name())

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
	_build_veins(camera)
	_build_damage_distort(camera)

## Frost and glowing veins at the edges of view, deeper as life force falls.
func _build_veins(camera: XRCamera3D) -> void:
	_veins_mesh = MeshInstance3D.new()
	_veins_mesh.name = "LifeForceVeins"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	_veins_mesh.mesh = quad
	_veins_mesh.position = Vector3(0.0, 0.0, -0.2)
	_veins_material = ShaderMaterial.new()
	_veins_material.shader = preload("res://Resources/Materials/life_veins.gdshader")
	_veins_material.set_shader_parameter("noise_tex", preload("res://Resources/Materials/breach_noise.tres"))
	_veins_material.set_shader_parameter("strength", 0.0)
	_veins_material.render_priority = 11
	_veins_mesh.material_override = _veins_material
	_veins_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_veins_mesh.visible = false
	camera.add_child(_veins_mesh)

func _update_veins(state: StringName) -> void:
	if _veins_material == null:
		return
	var target: float = VEIN_STRENGTH.get(state, 0.0)
	var settings := get_node_or_null("/root/GameSettings")
	if settings and settings.reduced_flashes:
		target *= 0.5
	_veins_material.set_shader_parameter("beat_rate", VEIN_BEAT.get(state, 1.0))
	if target > 0.0:
		_veins_mesh.visible = true
	if _veins_tween != null and _veins_tween.is_valid():
		_veins_tween.kill()
	_veins_tween = create_tween()
	_veins_tween.tween_method(_set_veins_strength, _veins_strength, target, 0.8).set_trans(Tween.TRANS_SINE)
	if target <= 0.0:
		_veins_tween.tween_callback(_veins_mesh.hide)

func _set_veins_strength(value: float) -> void:
	_veins_strength = value
	_veins_material.set_shader_parameter("strength", value)

func _build_damage_distort(camera: XRCamera3D) -> void:
	_distort_mesh = MeshInstance3D.new()
	_distort_mesh.name = "DamageDistort"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 2.6)
	_distort_mesh.mesh = quad
	_distort_mesh.position = Vector3(0.0, 0.0, -0.2)
	_distort_material = ShaderMaterial.new()
	_distort_material.shader = preload("res://Resources/Materials/damage_distort.gdshader")
	_distort_material.render_priority = 12
	_distort_material.set_shader_parameter("strength", 0.0)
	_distort_mesh.material_override = _distort_material
	_distort_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_distort_mesh.visible = false
	camera.add_child(_distort_mesh)
	_build_damage_impact(camera)

func _build_damage_impact(camera: XRCamera3D) -> void:
	_impact_mesh = MeshInstance3D.new()
	_impact_mesh.name = "DamageImpact"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.8, 2.8)
	_impact_mesh.mesh = quad
	_impact_mesh.position = Vector3(0.0, 0.0, -0.16)
	_impact_material = ShaderMaterial.new()
	_impact_material.shader = preload("res://Resources/Materials/damage_impact.gdshader")
	_impact_material.render_priority = 14
	_impact_material.set_shader_parameter("strength", 0.0)
	_impact_material.set_shader_parameter("hit_color", Color(1.0, 0.05, 0.1, 1.0))
	_impact_mesh.material_override = _impact_material
	_impact_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact_mesh.visible = false
	camera.add_child(_impact_mesh)

func _build_audio() -> void:
	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.name = "HeartbeatPlayer"
	_heartbeat.volume_db = -8.0
	_heartbeat.bus = &"Critical"
	add_child(_heartbeat)

	var heartbeat_stream := _load_or_create_heartbeat_stream()
	if heartbeat_stream:
		_heartbeat.stream = heartbeat_stream

	_drain_blip = AudioStreamPlayer.new()
	_drain_blip.name = "DrainBlipPlayer"
	_drain_blip.volume_db = -12.0
	_drain_blip.bus = &"Critical"
	add_child(_drain_blip)
	_drain_blip.stream = _create_drain_blip_stream()

	_depletion_stinger = AudioStreamPlayer.new()
	_depletion_stinger.name = "DepletionStinger"
	_depletion_stinger.volume_db = 8.0
	_depletion_stinger.bus = &"Master"
	_depletion_stinger.stream = _create_depletion_stinger()
	add_child(_depletion_stinger)

func _on_life_force_state_changed(state: StringName) -> void:
	_update_tint(state)
	_update_veins(state)
	_update_heartbeat(state)

func _on_damage_applied(_amount: float, _current: float) -> void:
	if _drain_blip:
		_drain_blip.play()
	_flash_possession()
	_distort_vision()
	_slam_impact()
	_rumble_possession()

func _flash_possession() -> void:
	if _tint_material == null:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var scale := 0.4 if settings and settings.reduced_flashes else 1.0
	var resting := _tint_material.albedo_color.a
	_tint_material.albedo_color = Color(0.95, 0.08, 0.1, 0.78 * scale)
	var tween := create_tween()
	tween.tween_property(_tint_material, "albedo_color:a", resting, 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _distort_vision() -> void:
	if _distort_material == null or _distort_mesh == null:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var reduced: bool = settings != null and bool(settings.reduced_flashes)
	var peak := 0.55 if reduced else 1.0
	var duration := 0.4 if reduced else 0.85
	_distort_mesh.visible = true
	_set_distort_strength(peak)
	if _distort_tween != null and _distort_tween.is_valid():
		_distort_tween.kill()
	_distort_tween = create_tween()
	_distort_tween.tween_method(_set_distort_strength, peak, 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_distort_tween.tween_callback(_hide_distort)

func _set_distort_strength(value: float) -> void:
	if _distort_material:
		_distort_material.set_shader_parameter("strength", value)

func _hide_distort() -> void:
	if _distort_mesh:
		_distort_mesh.visible = false

func _slam_impact() -> void:
	if _impact_material == null or _impact_mesh == null:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var reduced: bool = settings != null and bool(settings.reduced_flashes)
	var peak := 0.42 if reduced else 1.0
	var duration := 0.28 if reduced else 0.55
	_impact_mesh.visible = true
	_impact_mesh.scale = Vector3.ONE * 0.72
	_impact_material.set_shader_parameter("strength", peak)
	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	_impact_tween = create_tween()
	_impact_tween.tween_method(_set_impact_strength, peak, 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_impact_tween.parallel().tween_property(_impact_mesh, "scale", Vector3.ONE * 1.2, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_callback(_hide_impact)

func _set_impact_strength(value: float) -> void:
	if _impact_material:
		_impact_material.set_shader_parameter("strength", value)

func _hide_impact() -> void:
	if _impact_mesh:
		_impact_mesh.visible = false

func _rumble_possession() -> void:
	var rumble := XRToolsRumbleEvent.new()
	rumble.magnitude = 1.0
	rumble.duration_ms = 360
	rumble.active_during_pause = false
	rumble.indefinite = false
	XRToolsRumbleManager.add("possession_%s" % Time.get_ticks_usec(), rumble)

func _on_life_force_depleted() -> void:
	if _heartbeat and _heartbeat.playing:
		_heartbeat.stop()
	if _drain_blip and _drain_blip.playing:
		_drain_blip.stop()
	if _depletion_stinger:
		_depletion_stinger.play()
	if _tint_material:
		_tint_material.albedo_color = Color(0.45, 0.0, 0.08, 0.38)
		var tween := create_tween()
		tween.tween_property(_tint_material, "albedo_color:a", 0.08, 1.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

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
	var settings := get_node_or_null("/root/GameSettings")
	var accessibility_scale := 0.45 if settings and settings.reduced_flashes else 1.0
	_tint_material.albedo_color.a = alpha * tint_strength * accessibility_scale

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
		&"critical":
			_heartbeat.volume_db = -4.0
			_heartbeat.pitch_scale = 1.25
		&"depleted":
			if _heartbeat.playing:
				_heartbeat.stop()
			return

	if not _heartbeat.playing:
		_heartbeat.play()

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

func _create_depletion_stinger() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 1.25
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / sample_rate
		var env := exp(-t * 2.4)
		var low := sin(TAU * (62.0 - t * 18.0) * t) * env * 0.55
		var pulse := sin(TAU * 180.0 * t) * exp(-t * 10.0) * 0.22
		var noise := sin(TAU * 37.0 * t + sin(t * 41.0)) * exp(-t * 4.0) * 0.12
		data.encode_s16(i * 2, int(clampf(low + pulse + noise, -1.0, 1.0) * 32767.0))
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
