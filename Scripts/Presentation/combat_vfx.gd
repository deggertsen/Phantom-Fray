extends Node3D
class_name CombatVFX

## What a hit looks like in the world: sparks, a shockwave ring, and a flash at the point
## of impact. Phantoms send their feedback_requested signal here. Everything is pooled, so
## a hit never allocates, and each burst stays under the 40-particle budget.

const POOL_SIZE := 6
const SPARKS := 28

var _bursts: Array[CPUParticles3D] = []
var _rings: Array[MeshInstance3D] = []
var _flashes: Array[MeshInstance3D] = []
var _next_burst: int = 0
var _next_ring: int = 0
var _next_flash: int = 0

func _ready() -> void:
	add_to_group("CombatVFX")
	for i in POOL_SIZE:
		_bursts.append(_make_burst())
		_rings.append(_make_ring())
		_flashes.append(_make_flash())

## Connected with the phantom's color bound on: (kind, position, intensity, color).
func play(kind: StringName, at: Vector3, intensity: float, color: Color) -> void:
	var calm := _reduced_flashes()
	match kind:
		&"hit":
			_burst(at, color, lerpf(1.8, 2.8, intensity))
			_ring(at, color, 0.55, 0.38, calm)
			_flash(at, color, 0.9, calm)
		&"sweet":
			_burst(at, color.lerp(Color.WHITE, 0.4), 3.4)
			_burst(at, color, 2.2)
			_ring(at, Color.WHITE, 0.95, 0.45, calm)
			_ring(at, color, 0.6, 0.3, calm)
			_flash(at, Color.WHITE, 1.5, calm)
		&"guard":
			_burst(at, color, 1.1)
			_flash(at, color, 0.45, calm)
		&"rejected":
			_burst(at, Color(1.0, 0.3, 0.35), 0.8)

func _burst(at: Vector3, color: Color, speed: float) -> void:
	var burst := _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % POOL_SIZE
	burst.global_position = at
	burst.color = color
	burst.initial_velocity_min = speed * 0.4
	burst.initial_velocity_max = speed
	burst.restart()
	burst.emitting = true

func _ring(at: Vector3, color: Color, reach: float, seconds: float, calm: bool) -> void:
	var ring := _rings[_next_ring]
	_next_ring = (_next_ring + 1) % POOL_SIZE
	var material := ring.material_override as StandardMaterial3D
	material.albedo_color = Color(color, 0.5 if calm else 1.0)
	ring.global_position = at
	ring.scale = Vector3.ONE * 0.08
	ring.visible = true
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * reach, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(ring.hide)

func _flash(at: Vector3, color: Color, strength: float, calm: bool) -> void:
	var flash := _flashes[_next_flash]
	_next_flash = (_next_flash + 1) % POOL_SIZE
	var material := flash.material_override as StandardMaterial3D
	material.albedo_color = Color(color, strength * (0.45 if calm else 1.0))
	flash.global_position = at
	flash.scale = Vector3.ONE * 0.5
	flash.visible = true
	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.3, 0.18)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.18)
	tween.chain().tween_callback(flash.hide)

func _make_burst() -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = SPARKS
	burst.lifetime = 0.55
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.gravity = Vector3(0.0, -1.5, 0.0)
	burst.damping_min = 2.0
	burst.damping_max = 3.0
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	burst.scale_amount_curve = shrink
	var spark := QuadMesh.new()
	spark.size = Vector2(0.09, 0.09)
	var material := GlowSprite.material(Color.WHITE, 1.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	spark.material = material
	burst.mesh = spark
	add_child(burst)
	return burst

func _make_ring() -> MeshInstance3D:
	var ring := GlowSprite.create(Color.WHITE, 1.0, 1.0)
	(ring.material_override as StandardMaterial3D).albedo_texture = GlowSprite.ring_texture()
	ring.visible = false
	add_child(ring)
	return ring

func _make_flash() -> MeshInstance3D:
	var flash := GlowSprite.create(Color.WHITE, 1.0, 1.0)
	flash.visible = false
	add_child(flash)
	return flash

func _reduced_flashes() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("reduced_flashes"))
