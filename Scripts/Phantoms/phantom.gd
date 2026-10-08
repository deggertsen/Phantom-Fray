extends CharacterBody3D
class_name Phantom

const SfxVariations := preload("res://Scripts/Audio/sfx_variations.gd")
const CREATURE_MATERIAL := preload("res://Resources/Materials/creature.tres")
const GLOW_STRENGTH := 0.3

## One continuous arc into reach. Speed ramps by acceleration, never a stop-then-dash.
## A punch counts once the body is in reach, because that is when the fist can meet it.
## Movement uses CharacterBody3D.move_and_slide():
## https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html#class-characterbody3d-method-move-and-slide

signal resolved(result: Dictionary)
signal player_contact(damage: float)
signal feedback_requested(kind: StringName, position: Vector3, intensity: float)
signal strike_rejected(reason: StringName)

enum Phase { APPROACH, TELEGRAPH, COMMIT, RECOVER }

@export var variant_id: StringName = &"neutral"
@export var move_speed: float = 3.2
@export var acceleration: float = 2.6
@export var wobble_strength: float = 0.18
@export var wobble_speed: float = 2.0
@export var hover_height: float = 1.25
@export var base_score: int = 100
@export var rift_damage: int = 10
@export var contact_damage: float = 20.0
## Distance from the phantom origin to the head or body center. The mesh edge does not count.
@export var possession_radius: float = 0.30
@export var required_hand: StringName = &""
@export var phantom_color: Color = Color(0.55, 0.25, 1.0, 0.88)
@export var dissolve_speed: float = 1.4
@export var uses_attack_pattern: bool = true
@export var engage_distance: float = 2.4
@export var pattern_telegraph_seconds: float = 0.8
@export var pattern_commit_speed: float = 6.2
@export var pattern_commit_seconds: float = 0.5
@export var recover_seconds: float = 0.4
@export var lateral_bias: float = 0.0
@export var height_bias: float = 0.0
## How far off the preferred side a commit may aim. Yellow stays left, blue stays right.
@export var lateral_reach_min: float = 0.1
@export var lateral_reach_max: float = 0.28
@export var height_jitter: float = 0.16
@export var body_widen: float = 1.0
## How far the arc bows off the straight line. Yellow bows left, blue bows right.
@export var arc_scale: float = 2.4
## Punches land once the phantom is this close. The arrival itself is the timing.
@export var strike_reach: float = 1.7

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var contact_area: Area3D = $Area3D

var _player_camera: Node3D
var _time: float = 0.0
var _terminal: bool = false
var _dissolving: bool = false
var _dissolve_amount: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _audio_player: AudioStreamPlayer3D
var _possess_player: AudioStreamPlayer3D
## Shared so every phantom does not rebuild the siphon clip.
static var _shared_possess_stream: AudioStream
var _phase: Phase = Phase.APPROACH
var _phase_remaining: float = 0.0
var _locked_target: Vector3 = Vector3.ZERO
var _commit_closest: float = INF
var _alert: float = 0.0
var _mesh_basis_scale: Vector3 = Vector3.ONE
var _curve_ready: bool = false
var _curve_start: Vector3 = Vector3.ZERO
var _curve_control: Vector3 = Vector3.ZERO
var _curve_control_b: Vector3 = Vector3.ZERO
var _curve_end: Vector3 = Vector3.ZERO
var _curve_progress: float = 0.0
var _curve_length: float = 1.0
var _camera_closest: float = INF
var _coast_time: float = 0.0
var _stall_time: float = 0.0
var _stalls: int = 0
var _alive_time: float = 0.0
var _impact_drop: float = 0.22
var _glow: MeshInstance3D

func _ready() -> void:
	# The body is punchable but does not physically block on the player's hurtbox.
	collision_layer = 4
	collision_mask = 0
	contact_area.collision_layer = 8
	contact_area.collision_mask = 1
	add_to_group("phantom")
	contact_area.body_entered.connect(_on_contact_body_entered)

	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if player:
		_player_camera = player.get_node_or_null("XRCamera3D") as Node3D
	if _player_camera == null:
		push_warning("Phantom: XRCamera3D not found; using origin as target")

	var material := CREATURE_MATERIAL.duplicate() as ShaderMaterial
	var creature := _creature_mesh()
	if creature:
		mesh_instance.mesh = creature
		mesh_instance.transform = Transform3D.IDENTITY
	mesh_instance.material_override = material
	material.set_shader_parameter("dissolve_amount", 0.0)
	material.set_shader_parameter("impact_point", global_position)
	material.set_shader_parameter("dissolve_direction", Vector3.UP)
	material.set_shader_parameter("base_color", phantom_color)
	material.set_shader_parameter("edge_color", phantom_color.lightened(0.35))
	material.set_shader_parameter("alert", 0.0)
	material.set_shader_parameter("phase_offset", randf() * 20.0)
	_tune_creature_material(material)
	_mesh_basis_scale = mesh_instance.scale
	_glow = GlowSprite.create(phantom_color, 1.7, GLOW_STRENGTH)
	_glow.name = "CreatureGlow"
	mesh_instance.add_child(_glow)

	# https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "DeathAudio"
	_audio_player.bus = &"SFX"
	_audio_player.volume_db = -7.0
	_audio_player.max_distance = 20.0
	add_child(_audio_player)

	_possess_player = AudioStreamPlayer3D.new()
	_possess_player.name = "PossessAudio"
	_possess_player.bus = &"SFX"
	_possess_player.volume_db = -4.0
	_possess_player.max_distance = 20.0
	add_child(_possess_player)

func _physics_process(delta: float) -> void:
	if _terminal:
		_knockback_velocity *= pow(0.08, delta)
		velocity = _knockback_velocity
		move_and_slide()
		return
	if not uses_attack_pattern or _player_camera == null:
		return

	_time += delta
	_alive_time += delta
	if _alive_time > 22.0:
		force_cleanup()
		return
	var origin := global_position
	if _phase == Phase.RECOVER:
		_tick_recover(delta)
	else:
		_tick_arc(delta)
	if not _terminal:
		_try_possess_between(origin, global_position)

func _process(delta: float) -> void:
	if _dissolving:
		_dissolve_amount = minf(_dissolve_amount + dissolve_speed * delta, 1.0)
		var material := mesh_instance.material_override as ShaderMaterial
		if material:
			material.set_shader_parameter("dissolve_amount", _dissolve_amount)
		if _glow:
			(_glow.material_override as StandardMaterial3D).albedo_color.a = GLOW_STRENGTH * (1.0 - _dissolve_amount)
		if _dissolve_amount >= 1.0:
			queue_free()
		return
	_update_pattern_visual()

func apply_pressure(speed_scale: float, telegraph_scale: float) -> void:
	move_speed *= speed_scale
	pattern_commit_speed *= speed_scale
	## A longer tell is a gentler acceleration, not a pause before a dash.
	acceleration = clampf(acceleration / clampf(telegraph_scale, 0.55, 1.5), 1.15, 5.5)
	pattern_telegraph_seconds = maxf(pattern_telegraph_seconds * telegraph_scale, 0.35)

func is_strike_window_open() -> bool:
	if not uses_attack_pattern:
		return true
	if _phase == Phase.COMMIT:
		return true
	if _player_camera == null:
		return false
	return global_position.distance_to(_player_camera.global_position) <= strike_reach

func shows_approach_cue() -> bool:
	return not _terminal and not _dissolving

func receive_strike(strike: Dictionary) -> Dictionary:
	if _terminal:
		return _make_result(false, false, &"already_resolved", 0, 0, strike)
	if uses_attack_pattern and not is_strike_window_open():
		feedback_requested.emit(&"rejected", strike.get("position", global_position), 0.15)
		return _make_result(false, false, &"not_open", 0, 0, strike)
	var result := _evaluate_strike(strike)
	if not result.get("valid", false):
		if result.get("resolution_kind", &"") == &"wrong_hand":
			strike_rejected.emit(&"wrong_hand")
		var feedback: StringName = &"guard" if result.get("resolution_kind", &"") == &"block_half" else &"rejected"
		feedback_requested.emit(feedback, strike.get("position", global_position), 0.35 if feedback == &"guard" else 0.25)
		return result
	if _phase == Phase.COMMIT:
		result["on_beat"] = true
		result["base_score"] = int(round(float(result.get("base_score", 0)) * 1.25))
		result["rift_damage"] = int(round(float(result.get("rift_damage", 0)) * 1.15))
	_resolve_from_strike(result, strike)
	return result

func _evaluate_strike(strike: Dictionary) -> Dictionary:
	var hand_id: StringName = strike.get("hand_id", &"")
	if required_hand != &"" and hand_id != required_hand:
		return _make_result(false, false, &"wrong_hand", 0, 0, strike)
	return _make_result(true, false, &"strike", base_score, rift_damage, strike)

func _make_result(
	valid: bool,
	sweet_spot: bool,
	resolution_kind: StringName,
	score_value: int,
	damage_value: int,
	strike: Dictionary = {}
) -> Dictionary:
	return {
		"variant_id": variant_id,
		"valid": valid,
		"sweet_spot": sweet_spot,
		"resolution_kind": resolution_kind,
		"base_score": score_value,
		"rift_damage": damage_value,
		"hit_quality": strike.get("quality", 0.0),
		"world_position": strike.get("position", global_position),
		"failure_reason": &"" if valid else resolution_kind,
		"on_beat": false,
	}

func _resolve_from_strike(result: Dictionary, strike: Dictionary) -> void:
	_terminal = true
	_disable_collisions()
	var direction: Vector3 = strike.get("direction", Vector3.ZERO)
	var speed: float = strike.get("speed", 0.0)
	_knockback_velocity = direction.normalized() * clampf(speed, 1.0, 10.0) * 1.8
	_begin_dissolve(strike.get("position", global_position), direction)
	feedback_requested.emit(
		&"sweet" if result.get("sweet_spot", false) else &"hit",
		result.get("world_position", global_position),
		result.get("hit_quality", 0.0)
	)
	resolved.emit(result)

func resolve_without_strike(result: Dictionary) -> void:
	if _terminal:
		return
	_terminal = true
	_disable_collisions()
	_begin_dissolve(global_position, Vector3.UP)
	resolved.emit(result)

func set_interactions_enabled(enabled: bool) -> void:
	if _terminal:
		return
	collision_layer = 4 if enabled else 0
	contact_area.collision_layer = 8 if enabled else 0
	contact_area.set_deferred("monitoring", enabled)

func force_cleanup() -> void:
	if _terminal:
		return
	_terminal = true
	_disable_collisions()
	_dissolving = true
	dissolve_speed = maxf(dissolve_speed, 3.0)

func _tick_arc(delta: float) -> void:
	if not _curve_ready:
		_build_curve()
	var ramp := smoothstep(0.1, 0.85, _curve_progress)
	var speed := lerpf(move_speed, pattern_commit_speed, ramp)
	# The parameter is a carrot. Reaching 1 must not freeze the body still on the way in.
	_curve_progress = minf(_curve_progress + speed * delta / _curve_length, 1.0)
	var steer := _steer_point()
	var to_steer := steer - global_position
	if to_steer.length_squared() < 0.05:
		to_steer = _curve_end - global_position
	var desired: Vector3
	if to_steer.length_squared() > 0.04:
		desired = to_steer.normalized() * speed
	else:
		var through := _curve_end - _curve_start
		if through.length_squared() < 0.0001:
			through = velocity if velocity.length_squared() > 0.01 else Vector3.FORWARD
		desired = through.normalized() * speed
	var to_player := _locked_target - global_position
	var camera_distance := global_position.distance_to(_player_camera.global_position)
	if camera_distance < 3.2 and camera_distance > 0.02:
		var homing := smoothstep(3.2, 0.55, camera_distance)
		desired = desired.lerp(to_player.normalized() * speed, homing)
	# https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html#class-characterbody3d-method-move-and-slide
	velocity = velocity.lerp(desired, clampf(acceleration * delta, 0.0, 1.0))
	_face_direction(desired)
	move_and_slide()
	camera_distance = global_position.distance_to(_player_camera.global_position)
	var closing_in := camera_distance < strike_reach * 1.4
	if velocity.length() < 0.2 and _curve_progress > 0.08 and not closing_in:
		_stall_time += delta
		if _stall_time > 0.5:
			_stalls += 1
			_stall_time = 0.0
			if _stalls >= 2:
				force_cleanup()
				return
			_curve_ready = false
			return
	else:
		_stall_time = maxf(_stall_time - delta, 0.0)
	var in_reach := camera_distance <= strike_reach
	_phase = Phase.COMMIT if in_reach else Phase.APPROACH
	_set_alert(lerpf(0.2, 1.0, maxf(ramp, 1.0 if in_reach else 0.0)))
	# Leave only after the body has passed through the player. A wide arc must not count as a miss.
	var passed_through := _camera_closest <= possession_radius and camera_distance > _camera_closest + 0.16
	_camera_closest = minf(_camera_closest, camera_distance)
	var arrived := _curve_progress > 0.92 and global_position.distance_to(_curve_end) < 0.35 and _camera_closest <= possession_radius
	_coast_time = _coast_time + delta if arrived else 0.0
	if passed_through or _coast_time > 0.12:
		_begin_recover()

func _steer_point() -> Vector3:
	var sample := _curve_progress
	for _step in 8:
		var point := _bezier(sample)
		if point.distance_to(global_position) >= 1.2:
			return point
		sample = minf(sample + 0.08, 1.0)
	return _curve_end

func _build_curve() -> void:
	_lock_target()
	_curve_start = global_position
	# The approach ends on the player. The bow is only the middle of the path.
	_curve_end = _locked_target
	var side := lateral_bias
	if absf(side) < 0.01:
		side = -1.0 if randf() < 0.5 else 1.0
	else:
		side = signf(side)
	var right := _flat_right()
	var along := randf_range(0.22, 0.68)
	var bow := randf_range(arc_scale * 0.35, arc_scale * 1.2)
	var early := _curve_start.lerp(_curve_end, along)
	_curve_control = early + right * side * bow + Vector3.UP * randf_range(-0.45, 0.7)
	var late := _curve_start.lerp(_locked_target, randf_range(0.74, 0.88))
	_curve_control_b = late + right * side * bow * randf_range(0.04, 0.18)
	_curve_length = maxf(
		_curve_start.distance_to(_curve_control)
		+ _curve_control.distance_to(_curve_control_b)
		+ _curve_control_b.distance_to(_curve_end),
		0.5
	)
	_curve_progress = 0.0
	_camera_closest = INF
	_coast_time = 0.0
	_curve_ready = true

func _bezier(t: float) -> Vector3:
	var u := 1.0 - t
	return (
		u * u * u * _curve_start
		+ 3.0 * u * u * t * _curve_control
		+ 3.0 * u * t * t * _curve_control_b
		+ t * t * t * _curve_end
	)

func _begin_recover() -> void:
	_phase = Phase.RECOVER
	_phase_remaining = recover_seconds
	_set_alert(0.12)

func _tick_recover(delta: float) -> void:
	_phase_remaining -= delta
	var away := global_position - _player_camera.global_position
	away.y = 0.0
	if away.length_squared() > 0.001:
		var retreat := away.normalized() * move_speed * 0.75
		velocity = velocity.lerp(retreat, clampf(acceleration * delta, 0.0, 1.0))
	_face_direction(-away)
	move_and_slide()
	if _phase_remaining <= 0.0:
		_phase = Phase.APPROACH
		_curve_ready = false
		_set_alert(0.0)

func _lock_target() -> void:
	# Just under the eyes. High enough to punch, low enough to not be a bird.
	_impact_drop = randf_range(0.18, 0.30)
	_locked_target = _player_camera.global_position + Vector3.DOWN * _impact_drop

func _flat_right() -> Vector3:
	var right := _player_camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.001:
		return Vector3.RIGHT
	return right.normalized()

func _face_direction(direction: Vector3) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.length_squared() < 0.001:
		return
	global_transform.basis = Basis(Vector3.UP, atan2(horizontal.x, horizontal.z))

func _set_alert(amount: float) -> void:
	_alert = clampf(amount, 0.0, 1.0)
	var material := mesh_instance.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("alert", _alert)

func _update_pattern_visual() -> void:
	if mesh_instance == null:
		return
	var opening := _phase == Phase.TELEGRAPH or _phase == Phase.COMMIT
	var widen := body_widen if opening else 1.0
	var pulse := 1.0 + sin(_time * 16.0) * 0.05 * _alert
	mesh_instance.scale = Vector3(
		_mesh_basis_scale.x * widen * pulse,
		_mesh_basis_scale.y * pulse,
		_mesh_basis_scale.z * pulse
	)

## The creature body each variant wears. The unaligned phantom is a Drifter.
func _creature_mesh() -> Mesh:
	return CreatureMesh.drifter()

## Variants tune how their body moves (sway speed, flapping, snapping claws).
func _tune_creature_material(_material: ShaderMaterial) -> void:
	pass

func _begin_dissolve(impact_position: Vector3, direction: Vector3, play_death_sound: bool = true) -> void:
	_dissolving = true
	_on_dissolve_started()
	var material := mesh_instance.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("impact_point", impact_position)
		material.set_shader_parameter("dissolve_direction", direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP)
	if play_death_sound:
		_play_death_sound()

func _on_dissolve_started() -> void:
	pass

func _try_possess_between(from_position: Vector3, to_position: Vector3) -> bool:
	if _terminal:
		return false
	if not _core_reaches_player(from_position, to_position):
		return false
	_possess()
	return true

func _possess() -> void:
	if _terminal:
		return
	_terminal = true
	_disable_collisions()
	_begin_dissolve(global_position, Vector3.UP, false)
	_play_possession_sound()
	player_contact.emit(contact_damage)

func _core_reaches_player(from_position: Vector3, to_position: Vector3) -> bool:
	var points: Array[Vector3] = []
	if _player_camera:
		points.append(_player_camera.global_position)
		# Punchable phantoms finish under the eyes. Pink's lane is not a body part:
		# leaving that line is the dodge.
		if uses_attack_pattern:
			points.append(_player_camera.global_position + Vector3.DOWN * _impact_drop)
	var body := get_tree().get_first_node_in_group("PlayerBody") as Node3D
	if body:
		points.append(body.global_position)
	for point in points:
		if _closest_distance(from_position, to_position, point) <= possession_radius:
			return true
	return false

func _play_death_sound() -> void:
	if _audio_player == null or _audio_player.playing:
		return
	var stream := SfxVariations.pick("phantom_death")
	if stream == null:
		return
	_audio_player.stream = stream
	_audio_player.play()

func _play_possession_sound() -> void:
	if _possess_player == null:
		return
	var stream := SfxVariations.pick("phantom_possess")
	if stream == null:
		if _shared_possess_stream == null:
			_shared_possess_stream = _make_possession_tone()
		stream = _shared_possess_stream
	_possess_player.stream = stream
	_possess_player.play()

func _make_possession_tone() -> AudioStreamWAV:
	## Used only when no phantom_possess take is in the SFX folder.
	## https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html
	var sample_rate := 22050
	var duration := 0.72
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise := 0.0
	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var attack := sin(PI * clampf(t / 0.06, 0.0, 1.0))
		var env := attack * exp(-t * 2.6)
		var freq := lerpf(520.0, 70.0, pow(t / duration, 0.85))
		var tone := sin(TAU * freq * t) * 0.46
		var glass := sin(TAU * freq * 2.01 * t + 0.4) * 0.16
		noise = lerpf(noise, randf_range(-1.0, 1.0), 0.18)
		var breath := noise * 0.14 * exp(-t * 1.8)
		var sample := clampf((tone + glass + breath) * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _closest_distance(from_position: Vector3, to_position: Vector3, point: Vector3) -> float:
	var segment := to_position - from_position
	var length_sq := segment.length_squared()
	if length_sq <= 0.0001:
		return from_position.distance_to(point)
	var t := clampf((point - from_position).dot(segment) / length_sq, 0.0, 1.0)
	return from_position.lerp(to_position, t).distance_to(point)

func _on_contact_body_entered(body: Node3D) -> void:
	if _terminal or not body.is_in_group("PlayerBody"):
		return
	# The contact capsule's skin used to count as a bite. Only the origin does.
	if not _core_reaches_player(global_position, global_position):
		return
	_possess()

func _disable_collisions() -> void:
	collision_layer = 0
	collision_mask = 0
	contact_area.collision_layer = 0
	contact_area.collision_mask = 0
	contact_area.set_deferred("monitoring", false)
	var body_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_shape:
		body_shape.set_deferred("disabled", true)
	var area_shape := contact_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if area_shape:
		area_shape.set_deferred("disabled", true)
