extends RefCounted
class_name MawTurnFX

## Placeholder sound and effects for The Maw's turn until real recordings and art exist:
## the low rumble under the silence, the roar, and the shockwave ring that rolls out across the
## arena. All procedural. Replace the streams by dropping takes into the SFX folder later.
## https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html

const RATE := 22050

## A looping sub-bass rumble, felt more than heard. Built once per boss Maw, in the countdown,
## because generating it mid-turn would hitch.
static func rumble_stream() -> AudioStreamWAV:
	var seconds := 2.0
	var data := PackedByteArray()
	var count := int(RATE * seconds)
	data.resize(count * 2)
	var noise := 0.0
	for i in count:
		var t := float(i) / RATE
		noise = lerpf(noise, randf_range(-1.0, 1.0), 0.02)
		# Whole cycles of each tone over the loop, so it loops without a click.
		var tone := sin(TAU * 38.0 * t) * 0.35 + sin(TAU * 51.0 * t + 0.7) * 0.25
		var swell := 0.75 + 0.25 * sin(TAU * t / seconds)
		data.encode_s16(i * 2, int(clampf((tone + noise * 0.9) * swell, -1.0, 1.0) * 30000.0))
	var stream := _wav(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream

## The roar from the rift: a falling growl with a rough edge.
static func roar_stream() -> AudioStreamWAV:
	var seconds := 2.6
	var data := PackedByteArray()
	var count := int(RATE * seconds)
	data.resize(count * 2)
	var noise := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(1.6, seconds, t))
		var freq := lerpf(95.0, 42.0, t / seconds)
		phase += TAU * freq / RATE
		noise = lerpf(noise, randf_range(-1.0, 1.0), 0.12)
		var growl := sin(phase) * 0.5 + sin(phase * 2.03) * 0.25 + sin(phase * 0.5) * 0.3
		var rasp := noise * (0.35 + 0.25 * sin(TAU * 23.0 * t))
		data.encode_s16(i * 2, int(clampf((growl + rasp) * env, -1.0, 1.0) * 31000.0))
	return _wav(data)

static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

## Plays a stream at a point, on a bus the turn's duck leaves alone, and frees itself.
static func play_at(parent: Node, stream: AudioStream, position: Vector3, volume_db: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.bus = &"Critical"
	audio.volume_db = volume_db
	audio.max_distance = 60.0
	audio.unit_size = 12.0
	parent.add_child(audio)
	audio.global_position = position
	if stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		audio.finished.connect(audio.queue_free)
	audio.play()
	return audio

## A ground ring rolling out from the rift across the arena, below eye level. Harmless:
## it passes under and through the player's legs and touches nothing.
static func shockwave(parent: Node, origin: Vector3, calm: bool) -> Node3D:
	var wave := MeshInstance3D.new()
	wave.name = "Shockwave"
	wave.top_level = true
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	wave.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_fog = true
	material.albedo_color = Color(1.0, 0.35, 0.55, 0.5 if calm else 0.85)
	wave.material_override = material
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(wave)
	wave.global_position = Vector3(origin.x, 0.18, origin.z)
	wave.scale = Vector3(1.0, 0.6, 1.0)
	wave.set_meta("age", 0.0)
	wave.set_meta("peak_alpha", material.albedo_color.a)
	return wave

## Grows and fades a shockwave. Returns false once it has rolled out and freed itself.
static func advance_shockwave(wave: Node3D, delta: float) -> bool:
	if not is_instance_valid(wave):
		return false
	var age: float = float(wave.get_meta("age")) + delta
	wave.set_meta("age", age)
	var radius := 1.0 + age * 14.0
	# Thicker as it rolls, but never taller than the shins.
	wave.scale = Vector3(radius, minf(0.6 + age * 0.4, 1.5), radius)
	var material := (wave as MeshInstance3D).material_override as StandardMaterial3D
	material.albedo_color.a = float(wave.get_meta("peak_alpha")) * (1.0 - smoothstep(0.6, 2.2, age))
	if age >= 2.2:
		wave.queue_free()
		return false
	return true
