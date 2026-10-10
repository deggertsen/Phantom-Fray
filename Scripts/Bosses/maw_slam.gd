extends Node3D
class_name MawSlam

## The Maw's slam. An impact ring paints the floor around where the player stands, the way the
## pink Spearfin paints its lane, while the tentacle rises overhead; then it comes down. A head
## outside the ring at impact is a dodge that scores like the pink one. A head still inside it is
## a hit, like a possession. MawBoss reads `progress()` to pose the tentacle over the ring.
##
## Speaks the interface RiftManager.add_attacker expects: resolved, player_contact, the "phantom"
## group, set_interactions_enabled for pause, force_cleanup.
## See development/Exercise_Mechanics_Exploration.md, "The slam: dodge it, then work on it".

signal resolved(result: Dictionary)
signal player_contact(damage: float)
## The tentacle hit the floor. `hit` is true when the player was still in the ring.
signal impacted(hit: bool)

const RING_COLOR := Color(1.0, 0.2, 0.42)

@export var variant_id: StringName = &"slam"
## The tentacle rising overhead while the ring paints. This is the tell.
@export var raise_seconds: float = 1.7
## The fall itself, quick, after the tell.
@export var fall_seconds: float = 0.4
## The pink dodge's radius, a touch wider: one side-step clears it.
@export var ring_radius: float = 0.75
@export var base_score: int = 150
@export var rift_damage: int = 14
@export var contact_damage: float = 20.0

var center: Vector3 = Vector3.ZERO

var _camera: Node3D
var _elapsed: float = 0.0
var _judged: bool = false
var _finished: bool = false
var _interactions_enabled: bool = true
var _fade: float = 1.0
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _fill_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("phantom")
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if player:
		_camera = player.get_node_or_null("XRCamera3D") as Node3D
	# Locked where the player stands as the tell starts. The slam comes down there.
	var head := _head_position()
	var floor_y := player.global_position.y if player else 0.0
	center = Vector3(head.x, floor_y, head.z)
	global_position = center
	_build_ring()
	_update_ring()

## 0 at the start of the tell, 1 at impact.
func progress() -> float:
	return clampf(_elapsed / maxf(raise_seconds + fall_seconds, 0.01), 0.0, 1.0)

## 0 to 1 through the rise, then 0 to 1 through the fall.
func rise() -> float:
	return clampf(_elapsed / maxf(raise_seconds, 0.01), 0.0, 1.0)

func fall() -> float:
	return clampf((_elapsed - raise_seconds) / maxf(fall_seconds, 0.01), 0.0, 1.0)

func has_impacted() -> bool:
	return _elapsed >= raise_seconds + fall_seconds

func set_interactions_enabled(enabled: bool) -> void:
	_interactions_enabled = enabled

func shows_approach_cue() -> bool:
	return not _judged

func is_in_flight() -> bool:
	return not _finished

func force_cleanup() -> void:
	_judged = true
	_finished = true

func _physics_process(delta: float) -> void:
	advance(delta)

func _process(delta: float) -> void:
	if _finished:
		_fade = maxf(_fade - delta * 2.5, 0.0)
		if _fade <= 0.0:
			queue_free()
	_update_ring()

## One step of the slam. Split from _physics_process so the validation runner can drive it.
func advance(delta: float) -> void:
	if _judged or not _interactions_enabled or delta <= 0.0:
		return
	_elapsed += delta
	if has_impacted():
		_impact()

func _impact() -> void:
	_judged = true
	_finished = true
	var head := _head_position()
	var offset := Vector2(head.x - center.x, head.z - center.z)
	var hit := offset.length() < ring_radius
	impacted.emit(hit)
	if hit:
		player_contact.emit(contact_damage)
		return
	resolved.emit({
		"variant_id": variant_id,
		"valid": true,
		"sweet_spot": false,
		"resolution_kind": &"dodge",
		"base_score": base_score,
		"rift_damage": rift_damage,
		"hit_quality": 0.0,
		"world_position": head,
		"failure_reason": &"",
		"on_beat": true,
	})

func _head_position() -> Vector3:
	if _camera:
		return _camera.global_position
	return Vector3(0.0, 1.6, 0.0)

func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "ImpactRing"
	var torus := TorusMesh.new()
	torus.inner_radius = ring_radius - 0.06
	torus.outer_radius = ring_radius + 0.04
	torus.rings = 32
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, 0.15, 1.0)
	_ring.position = Vector3.UP * 0.03
	_ring_material = _energy_material()
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var fill := MeshInstance3D.new()
	fill.name = "ImpactFill"
	var disc := CylinderMesh.new()
	disc.top_radius = ring_radius - 0.06
	disc.bottom_radius = ring_radius - 0.06
	disc.height = 0.01
	disc.radial_segments = 32
	disc.rings = 1
	fill.mesh = disc
	fill.position = Vector3.UP * 0.02
	_fill_material = _energy_material()
	fill.material_override = _fill_material
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fill)

func _energy_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_fog = true
	material.albedo_color = Color(RING_COLOR, 0.0)
	return material

func _update_ring() -> void:
	if _ring_material == null:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var calm: bool = settings != null and bool(settings.get("reduced_flashes"))
	var told := rise()
	# The ring pulses faster as the fall nears. Reduced Flashes keeps it a steady ramp.
	var pulse := 1.0 if calm else 0.7 + 0.3 * sin(_elapsed * lerpf(8.0, 22.0, told))
	_ring_material.albedo_color.a = clampf(0.3 + told * 0.8, 0.0, 1.0) * pulse * _fade * (0.6 if calm else 1.0)
	_fill_material.albedo_color.a = told * told * 0.22 * _fade * (0.6 if calm else 1.0)
