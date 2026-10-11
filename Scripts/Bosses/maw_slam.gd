extends Node3D
class_name MawSlam

## The Maw's slam. The tentacle rises overhead, a translucent curtain hangs down from it to the
## floor, and the floor paints the strip where it will land with the pink Spearfin's chevron lane;
## then it comes down along that strip, its tip where the player stood. A head out of the strip at
## impact is a dodge that scores like the pink one. A head still in it is a hit, like a possession.
## MawBoss reads `progress()` to pose the tentacle over the strip.
##
## On Quest 3 (2026-10-11) the first version's impact ring on the floor, and then a ring-shaped
## wall of light, did not read: David asked for a wide wall projected down from the tentacle and
## the pink lane's floor pattern, so the answer (step out of that strip) is obvious.
##
## Speaks the interface RiftManager.add_attacker expects: resolved, player_contact, the "phantom"
## group, set_interactions_enabled for pause, force_cleanup.
## See development/Exercise_Mechanics_Exploration.md, "The slam: dodge it, then work on it".

signal resolved(result: Dictionary)
signal player_contact(damage: float)
## The tentacle hit the floor. `hit` is true when the player was still in the strip.
signal impacted(hit: bool)

const RING_COLOR := Color(1.0, 0.2, 0.42)
const LANE_SHADER := preload("res://Resources/Materials/dodge_lane.gdshader")

@export var variant_id: StringName = &"slam"
## The tentacle rising overhead while the strip paints. This is the tell.
@export var raise_seconds: float = 1.7
## The fall itself, quick, after the tell.
@export var fall_seconds: float = 0.4
## Half the strip's width. The pink dodge's radius, a touch wider: one side-step clears it.
@export var half_width: float = 0.7
## How far the strip runs from the player toward the rift, along the fallen tentacle.
@export var reach_toward_rift: float = 5.0
## And how far past the player, so stepping straight back is not a free dodge.
@export var reach_behind: float = 1.2
## The curtain's height above the floor, up toward the raised tentacle.
@export var curtain_height: float = 4.5
@export var base_score: int = 150
@export var rift_damage: int = 14
@export var contact_damage: float = 20.0

## Flat direction from the player toward the rift. MawBoss sets it before add_child.
var toward_rift: Vector3 = Vector3.FORWARD
var center: Vector3 = Vector3.ZERO

var _camera: Node3D
var _elapsed: float = 0.0
var _judged: bool = false
var _finished: bool = false
var _interactions_enabled: bool = true
var _fade: float = 1.0
var _lane_material: ShaderMaterial
var _curtain_material: StandardMaterial3D
var _buzz_clock: float = 0.0

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
	toward_rift.y = 0.0
	toward_rift = toward_rift.normalized() if toward_rift.length_squared() > 0.001 else Vector3.FORWARD
	_build_strip()
	_update_strip()

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
	_update_strip()
	_buzz_while_inside(delta)

## Ticks both controllers while the head is still inside the strip through the tell, quickening
## and strengthening toward the fall, so a player looking anywhere feels that they are the target.
func _buzz_while_inside(delta: float) -> void:
	if _judged or not _interactions_enabled or rise() < 0.25:
		return
	if not is_in_strip(_head_position()):
		return
	_buzz_clock -= delta
	if _buzz_clock > 0.0:
		return
	_buzz_clock = lerpf(0.3, 0.12, rise())
	var interface := XRServer.primary_interface
	if interface == null:
		return
	var settings := get_node_or_null("/root/XRToolsUserSettings")
	var scale_by: float = float(settings.get("haptics_scale")) if settings else 1.0
	var amplitude := clampf(lerpf(0.25, 0.7, rise()) * scale_by, 0.0, 1.0)
	for hand in [&"left_hand", &"right_hand"]:
		interface.trigger_haptic_pulse(&"haptic", hand, 0.0, amplitude, 0.05, 0.0)

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
	var hit := is_in_strip(head)
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

## Whether a point is over the strip the tentacle will land on: within half_width of its line,
## from reach_behind past the player to reach_toward_rift toward the rift.
func is_in_strip(point: Vector3) -> bool:
	var offset := Vector3(point.x - center.x, 0.0, point.z - center.z)
	var along := offset.dot(toward_rift)
	var across := (offset - toward_rift * along).length()
	return across < half_width and along > -reach_behind and along < reach_toward_rift

func _build_strip() -> void:
	var length := reach_toward_rift + reach_behind
	# The midpoint of the strip, in this node's space (it sits at `center`, unrotated).
	var middle := toward_rift * (reach_toward_rift - reach_behind) * 0.5
	var facing := Basis.looking_at(-toward_rift, Vector3.UP)
	var lane := MeshInstance3D.new()
	lane.name = "SlamLane"
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(half_width * 2.0, 1.0)
	lane.mesh = quad
	_lane_material = ShaderMaterial.new()
	_lane_material.shader = LANE_SHADER
	_lane_material.set_shader_parameter("lane_color", Color(RING_COLOR, 1.0))
	_lane_material.set_shader_parameter("lane_length", length)
	_lane_material.set_shader_parameter("strength", 0.0)
	lane.material_override = _lane_material
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lane.transform = Transform3D(facing * Basis.from_scale(Vector3(1.0, 1.0, length)), middle + Vector3.UP * 0.025)
	add_child(lane)
	# Two sheets hanging down the strip's edges. One sheet down its middle was invisible on the
	# desktop capture: the player stands on that line and sees it edge-on. With one at each edge the
	# player stands in a lit corridor under the tentacle, and the way out is to the side.
	_curtain_material = curtain_material()
	var side := toward_rift.cross(Vector3.UP).normalized()
	for edge in [-1.0, 1.0]:
		var curtain := MeshInstance3D.new()
		curtain.name = "SlamCurtain"
		var sheet := QuadMesh.new()
		sheet.size = Vector2(length, curtain_height)
		curtain.mesh = sheet
		curtain.material_override = _curtain_material
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		curtain.transform = Transform3D(Basis(toward_rift, Vector3.UP, side), middle + side * half_width * edge + Vector3.UP * curtain_height * 0.5)
		add_child(curtain)

## Additive and double-sided: strongest up under the raised tentacle and still clear where it
## meets the floor. Static so ShaderWarmup compiles the same variant during the menu.
static func curtain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_fog = true
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.45))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 64
	material.albedo_texture = texture
	material.albedo_color = Color(RING_COLOR, 0.0)
	return material

func _update_strip() -> void:
	if _lane_material == null:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var calm: bool = settings != null and bool(settings.get("reduced_flashes"))
	var told := rise()
	# Both pulse faster as the fall nears. Reduced Flashes keeps them a steady ramp.
	var pulse := 1.0 if calm else 0.75 + 0.25 * sin(_elapsed * lerpf(8.0, 22.0, told))
	var dim := 0.6 if calm else 1.0
	_lane_material.set_shader_parameter("strength", clampf(0.35 + told * 0.9, 0.0, 1.0) * _fade * dim)
	_curtain_material.albedo_color.a = clampf(0.08 + told * 0.32, 0.0, 0.4) * pulse * _fade * dim
