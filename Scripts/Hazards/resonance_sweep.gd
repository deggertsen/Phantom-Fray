extends Node3D
class_name ResonanceSweep

## A horizontal blade of rift energy the player squats under. Two rails light at the blade's
## height on either side of the player, then the blade runs in from the rift side, over the
## space the head was in, and on past it. Under the blade: a dodge that scores like the pink
## Spearfin. Head above it as it crosses: a hit, like a possession.
##
## A standalone hazard, so The Maw's tentacle can drive the same code later. It enters missions
## through the wave pool ("sweep" in MissionCatalog.SCENE_BY_ID) and speaks the interface
## RiftManager._spawn_phantom expects: resolved, player_contact, apply_pressure, the "phantom"
## group, and set_interactions_enabled for pause.
## See development/Exercise_Mechanics_Exploration.md, "A. Resonance sweep" and Step 3.

signal resolved(result: Dictionary)
signal player_contact(damage: float)
## The blade reached the player: true if it passed over, false if it hit. Fires before resolved or player_contact.
signal crossed(cleared: bool)
## The rails start to light, after any wait for another sweep. Chen calls "Low!" on it.
signal telegraph_started

const SfxVariations := preload("res://Scripts/Audio/sfx_variations.gd")
const RIFT_VIOLET := Color(0.78, 0.32, 1.0)
const BLADE_WIDTH := 4.2
const RAIL_OFFSET := 1.05
## Used when there is no camera, or it reads lower than any standing player could.
const FALLBACK_STANDING := 1.6
const MIN_STANDING := 1.0
const BLADE_GLOW := 0.55
## The tell is pitched so it ends as the blade sets out, and the whoosh so its loudest moment,
## this far in, lands as the blade reaches the player. Takes in SfxVariations follow the same rule.
const WHOOSH_PEAK := 0.75
const TELL_SECONDS := 1.15
const WHOOSH_SECONDS := 1.1
const SAMPLE_RATE := 22050

@export var variant_id: StringName = &"sweep"
@export var telegraph_seconds: float = 1.15
## Share of standing eye height the blade sits below it. 0.12 is the pink duck; 0.20 a half squat.
@export var squat_depth: float = 0.12
@export var blade_speed: float = 6.0
## Where the blade appears, ahead of the player toward the rift, and how far past it runs.
@export var start_distance: float = 4.5
@export var overrun_distance: float = 1.6
@export var base_score: int = 150
@export var rift_damage: int = 14
@export var contact_damage: float = 20.0
## A hit is judged, and the blade put out, this far short of the eyes, so it never draws through the face.
@export var contact_lead: float = 0.12
## Quiet time after another sweep before this one lights, so squats never come back to back.
@export var rest_seconds: float = 1.5
## Set before add_child to aim the sweep instead of running it from the spawn point toward the player.
## side: +1 comes in from the player's right, -1 from the left. travel_direction: a world direction.
## side wins when both are set; with neither, it comes from where it spawned (the rift).
@export var side: float = 0.0
@export var travel_direction: Vector3 = Vector3.ZERO
## Off when something else carries the motion, such as a boss tentacle. Detection runs the same.
@export var blade_visible: bool = true
@export var rails_visible: bool = true

var standing_height: float = FALLBACK_STANDING
var sweep_height: float = FALLBACK_STANDING * (1.0 - 0.12)

var _camera: Node3D
var _player: Node3D
var _detector: SquatDetector
var _source: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.BACK
var _center: Vector3 = Vector3.ZERO
var _telegraph_remaining: float
## -1 until this sweep has looked for another one in flight, then the rest left, 0 once clear.
var _rest_remaining: float = -1.0
var _blade_travel: float = 0.0
var _previous_ahead: float = INF
## Resolved or made contact. Nothing more is reported after this.
var _judged: bool = false
## The blade has run its course, broken on the player, or been cleaned up. It fades out.
var _finished: bool = false
var _broken: bool = false
var _interactions_enabled: bool = true
var _fade: float = 1.0
var _alive_time: float = 0.0
var _bent_reason: StringName = &""
var _height_measured: bool = false
var _rails: Array[MeshInstance3D] = []
var _rail_material: StandardMaterial3D
var _blade: MeshInstance3D
var _blade_material: StandardMaterial3D
var _blade_glow_material: StandardMaterial3D
var _rail_time: float = 0.0
var _tell_player: AudioStreamPlayer3D
var _whoosh_player: AudioStreamPlayer3D
## Made once, and only when there are no recorded takes.
static var _generated_tell: AudioStreamWAV
static var _generated_whoosh: AudioStreamWAV

func _ready() -> void:
	add_to_group("phantom")
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	if _player:
		_camera = _player.get_node_or_null("XRCamera3D") as Node3D
		_detector = _player.get_node_or_null("SquatDetector") as SquatDetector
	if _detector:
		_detector.squat_rejected.connect(_on_squat_rejected)
	_source = global_position
	_telegraph_remaining = telegraph_seconds
	_lock_geometry()
	_build_visuals()
	_build_audio()
	_update_visuals()

func apply_pressure(speed_scale: float, telegraph_scale: float) -> void:
	blade_speed *= speed_scale
	telegraph_seconds = maxf(telegraph_seconds * telegraph_scale, 0.45)
	_telegraph_remaining = telegraph_seconds

## Reads `squat_depth` from the wave, so a mission can ask for a duck or a real squat.
func apply_wave(wave: Dictionary) -> void:
	if wave.has("squat_depth"):
		squat_depth = clampf(float(wave["squat_depth"]), 0.05, 0.4)
		_lock_height()
		_place_visuals()

func set_interactions_enabled(enabled: bool) -> void:
	_interactions_enabled = enabled
	if _tell_player:
		_tell_player.stream_paused = not enabled
		_whoosh_player.stream_paused = not enabled

func shows_approach_cue() -> bool:
	return not _judged

func is_in_flight() -> bool:
	return not _finished

## How far the blade is through its run: 0 until it sets out (rest and telegraph), 1 at the end.
func progress() -> float:
	return clampf(_blade_travel / (start_distance + overrun_distance), 0.0, 1.0)

## 0 to 1 through the telegraph; 1 once the blade is out.
func telegraph_progress() -> float:
	if _rest_remaining != 0.0:
		return 0.0
	return 1.0 - clampf(_telegraph_remaining / maxf(telegraph_seconds, 0.01), 0.0, 1.0)

## The middle of the blade in world space, at the line's height, for a tentacle tip to follow.
func blade_position() -> Vector3:
	var along := _blade_travel - start_distance
	return Vector3(_center.x, sweep_height, _center.z) + _direction * along

func force_cleanup() -> void:
	_judged = true
	_finished = true
	if _tell_player:
		_tell_player.stop()
		_whoosh_player.stop()

func _physics_process(delta: float) -> void:
	advance(delta)

func _process(delta: float) -> void:
	if _finished:
		_fade = maxf(_fade - delta * 4.0, 0.0)
		_update_visuals()
		if _fade <= 0.0:
			queue_free()
		return
	_rail_time += delta
	_update_visuals()

## One step of the sweep. Split from _physics_process so the validation runner can drive it.
func advance(delta: float) -> void:
	if _finished or not _interactions_enabled or delta <= 0.0:
		return
	_alive_time += delta
	if _alive_time > 22.0:
		force_cleanup()
		return
	if _waiting_for_lane(delta):
		return
	if _telegraph_remaining > 0.0:
		_telegraph_remaining = maxf(_telegraph_remaining - delta, 0.0)
		return
	if _blade_travel == 0.0:
		_play_whoosh()
	_blade_travel += blade_speed * delta
	if _blade_travel >= start_distance + overrun_distance:
		_finished = true
		return
	if _judged:
		return
	var head := _head_position()
	# How far the blade still has to go to reach the head, along the sweep.
	var ahead := (start_distance - _blade_travel) + (head - _center).dot(_direction)
	var under_blade := absf((head - _center).dot(_right())) <= BLADE_WIDTH * 0.5
	if under_blade and head.y >= sweep_height and ahead <= contact_lead and _previous_ahead > 0.0:
		_hit()
		return
	if ahead <= 0.0 and _previous_ahead > 0.0:
		_clear(under_blade)
		return
	_previous_ahead = ahead

func _clear(under_blade: bool) -> void:
	_judged = true
	crossed.emit(true)
	var bend := _bend_fault()
	resolved.emit({
		"variant_id": variant_id,
		"valid": true,
		"sweet_spot": false,
		"resolution_kind": &"sweep",
		"base_score": base_score,
		"rift_damage": rift_damage,
		"hit_quality": 0.0,
		"world_position": _head_position(),
		"failure_reason": &"",
		# Decision 5: a bend still clears the blade, but loses the bonus. It never fails.
		"on_beat": bend == &"" and under_blade,
		"form_fault": bend,
	})

func _hit() -> void:
	_judged = true
	crossed.emit(false)
	_finished = true
	# The blade goes out where it met the player instead of drawing on through the face.
	_broken = true
	_whoosh_player.stop()
	player_contact.emit(contact_damage)

## Why this dip was not a clean squat, when the detector is calibrated: a lean, a bend, or "".
func _bend_fault() -> StringName:
	if _detector == null or _detector.standing_height <= 0.0:
		return &""
	if _bent_reason != &"":
		return _bent_reason
	return _detector.dip_fault()

func _on_squat_rejected(reason: StringName) -> void:
	if _judged or _rest_remaining != 0.0:
		return
	if reason == &"leaned_or_stepped" or reason == &"looking_at_floor":
		_bent_reason = reason

## Another sweep still in flight, or only just finished: wait for it, then rest, then light.
func _waiting_for_lane(delta: float) -> bool:
	if _rest_remaining == 0.0:
		return false
	for other in get_tree().get_nodes_in_group("phantom"):
		var sweep := other as ResonanceSweep
		if sweep and sweep != self and sweep.is_in_flight() and sweep.get_instance_id() < get_instance_id():
			_rest_remaining = rest_seconds
			return true
	if _rest_remaining > 0.0:
		_rest_remaining = maxf(_rest_remaining - delta, 0.0)
		if _rest_remaining > 0.0:
			return true
	_rest_remaining = 0.0
	# The player may have moved while this one waited. Aim at where they stand now.
	_lock_geometry()
	_place_visuals()
	_play_tell()
	telegraph_started.emit()
	return false

func _lock_geometry() -> void:
	var head := _head_position()
	_center = Vector3(head.x, _floor_height(), head.z)
	var toward := head - _source
	if absf(side) > 0.01 and _camera:
		var right := _camera.global_transform.basis.x
		toward = -right * signf(side)
	elif travel_direction.length_squared() > 0.0001:
		toward = travel_direction
	toward.y = 0.0
	if toward.length_squared() < 0.04 and _camera:
		toward = _camera.global_transform.basis.z
		toward.y = 0.0
	_direction = toward.normalized() if toward.length_squared() > 0.0001 else Vector3.BACK
	_lock_height()
	# The node stands on the player's feet with -Z the way the blade travels, so it comes in from +Z.
	global_transform = Transform3D(Basis.looking_at(_direction, Vector3.UP), _center)
	_previous_ahead = INF

## Standing height from the detector once it has calibrated; otherwise the head at spawn. Only the
## first lock reads the head, so a player already ducking when a later lock runs cannot drag the line down.
func _lock_height() -> void:
	var floor_y := _floor_height()
	if _detector and _detector.standing_height > 0.0:
		standing_height = _detector.standing_height
	elif not _height_measured:
		standing_height = _head_position().y - floor_y
		if standing_height < MIN_STANDING:
			standing_height = FALLBACK_STANDING
	_height_measured = true
	sweep_height = floor_y + standing_height * (1.0 - squat_depth)

func _head_position() -> Vector3:
	if _camera:
		return _camera.global_position
	return Vector3(0.0, FALLBACK_STANDING, 0.0)

func _floor_height() -> float:
	return _player.global_position.y if _player else 0.0

func _right() -> Vector3:
	return _direction.cross(Vector3.UP).normalized()

func _reduced_flashes() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("reduced_flashes"))

func _build_visuals() -> void:
	_rail_material = _energy_material()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.03, 0.03, start_distance + overrun_distance)
	for rail_side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = "RailLeft" if rail_side < 0.0 else "RailRight"
		rail.mesh = rail_mesh
		rail.material_override = _rail_material
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rail.set_meta("side", rail_side)
		add_child(rail)
		_rails.append(rail)
	_blade = MeshInstance3D.new()
	_blade.name = "Blade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(BLADE_WIDTH, 0.03, 0.03)
	_blade.mesh = blade_mesh
	_blade_material = _energy_material()
	_blade.material_override = _blade_material
	_blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blade)
	var glow := MeshInstance3D.new()
	glow.name = "BladeGlow"
	var quad := QuadMesh.new()
	quad.size = Vector2(BLADE_WIDTH * 1.15, 0.22)
	glow.mesh = quad
	_blade_glow_material = GlowSprite.material(RIFT_VIOLET, 0.0)
	_blade_glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_blade_glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.material_override = _blade_glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(glow)
	_place_visuals()

## The tell rises from where the blade will appear, so it says which side it comes from. The
## whoosh rides the blade, so it swells and pans as the blade passes overhead.
## https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html
func _build_audio() -> void:
	_tell_player = AudioStreamPlayer3D.new()
	_tell_player.name = "TellAudio"
	_tell_player.bus = &"SFX"
	_tell_player.volume_db = -5.0
	_tell_player.unit_size = 3.0
	_tell_player.max_distance = 20.0
	add_child(_tell_player)
	_whoosh_player = AudioStreamPlayer3D.new()
	_whoosh_player.name = "WhooshAudio"
	_whoosh_player.bus = &"SFX"
	_whoosh_player.volume_db = -2.0
	# Small, so the pass overhead is clearly louder than the blade 4.5 m out.
	_whoosh_player.unit_size = 1.5
	_whoosh_player.max_distance = 20.0
	_blade.add_child(_whoosh_player)
	_place_visuals()

func _play_tell() -> void:
	var stream := SfxVariations.pick("sweep_tell")
	if stream == null:
		if _generated_tell == null:
			_generated_tell = _make_tell()
		stream = _generated_tell
	# A shorter telegraph plays the tell faster and higher, so it still ends as the blade sets out.
	_tell_player.stream = stream
	_tell_player.pitch_scale = clampf(stream.get_length() / maxf(telegraph_seconds, 0.01), 0.8, 2.0)
	_tell_player.play()

func _play_whoosh() -> void:
	var stream := SfxVariations.pick("sweep_whoosh")
	if stream == null:
		if _generated_whoosh == null:
			_generated_whoosh = _make_whoosh()
		stream = _generated_whoosh
	var reach_seconds := start_distance / maxf(blade_speed, 0.01)
	_whoosh_player.stream = stream
	_whoosh_player.pitch_scale = clampf(WHOOSH_PEAK / reach_seconds, 0.6, 2.0)
	_whoosh_player.play()

## Used only when there is no sweep_tell take: a tone climbing two octaves, its tremolo
## quickening like the rails' flicker, cut short at the top where the blade fires.
## https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html
static func _make_tell() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * TELL_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		var progress := t / TELL_SECONDS
		var freq := 160.0 * pow(4.0, progress)
		phase += TAU * freq / float(SAMPLE_RATE)
		var tremolo := 0.7 + 0.3 * sin(TAU * lerpf(4.0, 14.0, progress) * t)
		var env := pow(progress, 1.4) * clampf(t / 0.02, 0.0, 1.0) * clampf((TELL_SECONDS - t) / 0.03, 0.0, 1.0)
		var tone := sin(phase) * 0.6 + sin(phase * 1.5 + 0.7) * 0.22 + sin(phase * 3.0) * 0.1
		samples[i] = tone * tremolo * env
	return _to_wav(samples)

## Used only when there is no sweep_whoosh take: noise that brightens and swells to WHOOSH_PEAK,
## with a low blade hum under it, then falls away behind the player.
static func _make_whoosh() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * WHOOSH_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var noise := 0.0
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		var env := pow(t / WHOOSH_PEAK, 2.2) if t < WHOOSH_PEAK else exp(-(t - WHOOSH_PEAK) * 7.0)
		env *= clampf((WHOOSH_SECONDS - t) / 0.04, 0.0, 1.0)
		noise = lerpf(noise, randf_range(-1.0, 1.0), lerpf(0.04, 0.45, env))
		var hum := sin(TAU * 95.0 * t) * 0.3 + sin(TAU * 190.0 * t + 0.3) * 0.1
		samples[i] = (noise * 1.6 + hum) * env
	return _to_wav(samples)

static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var loudest := 0.001
	for sample in samples:
		loudest = maxf(loudest, absf(sample))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest * 0.85, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _energy_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_receive_shadows = true
	material.disable_fog = true
	material.albedo_color = Color(RIFT_VIOLET.lightened(0.35), 0.0)
	return material

func _place_visuals() -> void:
	if _blade == null:
		return
	var height := sweep_height - _center.y
	var length := start_distance + overrun_distance
	for rail in _rails:
		var rail_side: float = rail.get_meta("side")
		rail.position = Vector3(rail_side * RAIL_OFFSET, height, start_distance - length * 0.5)
	_blade.position = Vector3(0.0, height, start_distance - _blade_travel)
	if _tell_player:
		_tell_player.position = Vector3(0.0, height, start_distance)

func _update_visuals() -> void:
	if _blade == null:
		return
	var calm := _reduced_flashes()
	var lit := 0.0
	if _rest_remaining == 0.0:
		lit = 1.0 - clampf(_telegraph_remaining / maxf(telegraph_seconds, 0.01), 0.0, 1.0)
	# The rails flicker as they light. Reduced Flashes keeps them a steady, dimmer ramp.
	var flicker := 1.0 if calm else 0.75 + sin(_rail_time * 18.0) * 0.25
	for rail in _rails:
		rail.visible = rails_visible
	_rail_material.albedo_color.a = lit * lit * flicker * (0.55 if calm else 0.9) * _fade
	_blade.visible = blade_visible and not _broken and _rest_remaining == 0.0 and _telegraph_remaining <= 0.0 and _blade_travel > 0.0 and _fade > 0.0
	_blade.position.z = start_distance - _blade_travel
	# Close to the eyes the glow would fill the view as it passes overhead, so it fades out there.
	var gap := absf((start_distance - _blade_travel) + (_head_position() - _center).dot(_direction))
	var near := smoothstep(0.25, 1.6, gap)
	_blade_material.albedo_color.a = (0.7 if calm else 1.0) * lerpf(0.35, 1.0, near) * _fade
	_blade_glow_material.albedo_color.a = BLADE_GLOW * (0.45 if calm else 1.0) * near * _fade
