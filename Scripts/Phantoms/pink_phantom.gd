extends Phantom

@export var telegraph_seconds: float = 1.15
@export var charge_speed: float = 7.0
@export var dodge_radius: float = 0.65

var _telegraph_remaining: float
var _charging: bool = false
var _previous_target_distance: float = INF
var _pink_bow: float = 1.2
var _lane: MeshInstance3D
var _lane_material: ShaderMaterial

const LANE_SHADER := preload("res://Resources/Materials/dodge_lane.gdshader")
const LANE_OVERRUN := 1.5

func _ready() -> void:
	uses_attack_pattern = false
	variant_id = &"pink"
	phantom_color = Color(1.0, 0.15, 0.65, 0.9)
	base_score = 200
	rift_damage = 18
	super()
	_telegraph_remaining = telegraph_seconds
	_pink_bow = randf_range(0.45, 2.6) * (-1.0 if randf() < 0.5 else 1.0)
	_lock_pink_target()
	_build_lane()

## The Spearfin: a needle-billed fish built to charge.
func _creature_mesh() -> Mesh:
	return CreatureMesh.spearfin(_form)

func _tune_creature_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("sway_speed", 5.0)
	material.set_shader_parameter("flap_speed", 6.0)

## Chevrons on the floor from the Spearfin to where it will strike, so the dodge is readable.
func _build_lane() -> void:
	_lane = MeshInstance3D.new()
	_lane.name = "DodgeLane"
	_lane.top_level = true
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(0.9, 1.0)
	_lane.mesh = quad
	_lane_material = ShaderMaterial.new()
	_lane_material.shader = LANE_SHADER
	_lane_material.set_shader_parameter("lane_color", Color(phantom_color, 1.0))
	_lane.material_override = _lane_material
	_lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lane)
	_update_lane(0.0)

func _update_lane(strength: float) -> void:
	if _lane == null:
		return
	var from := Vector3(global_position.x, 0.02, global_position.z)
	var to := Vector3(_locked_target.x, 0.02, _locked_target.z)
	var span := to - from
	if span.length_squared() < 0.04:
		strength = 0.0
	_lane.visible = strength > 0.01
	if not _lane.visible:
		return
	# Run the lane a little past the player, so it reads as "through you".
	var length := span.length() + LANE_OVERRUN
	var direction := span.normalized()
	_lane.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), from + direction * length * 0.5)
	_lane.scale = Vector3(1.0, 1.0, length)
	_lane_material.set_shader_parameter("strength", strength)
	_lane_material.set_shader_parameter("lane_length", length)

func apply_pressure(speed_scale: float, telegraph_scale: float) -> void:
	super.apply_pressure(speed_scale, telegraph_scale)
	charge_speed *= speed_scale
	telegraph_seconds = maxf(telegraph_seconds * telegraph_scale, 0.45)
	_telegraph_remaining *= telegraph_scale

func _physics_process(delta: float) -> void:
	if _terminal:
		_update_lane(0.0)
		super(delta)
		return
	if _try_possess_between(global_position, global_position):
		return
	var told := 1.0
	if _telegraph_remaining > 0.0:
		_telegraph_remaining = maxf(_telegraph_remaining - delta, 0.0)
		told = 1.0 - clampf(_telegraph_remaining / maxf(telegraph_seconds, 0.01), 0.0, 1.0)
	var blend := told * told
	var aim := _locked_target
	if _player_camera:
		aim += _flat_right() * _pink_bow * (1.0 - blend)
	var direction := aim - global_position
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var speed := lerpf(1.7, charge_speed, blend)
	velocity = velocity.lerp(direction * speed, clampf(acceleration * delta, 0.0, 1.0))
	_face_direction(velocity)
	var origin := global_position
	move_and_slide()
	_set_alert(lerpf(0.35, 1.0, blend))
	_update_lane(clampf(0.35 + told * 0.9, 0.0, 1.0))
	_charging = blend > 0.8
	if _try_possess_between(origin, global_position):
		return
	if blend < 0.8:
		_previous_target_distance = global_position.distance_to(_locked_target)
		return
	var distance := global_position.distance_to(_locked_target)
	var passed_target := distance > _previous_target_distance and _previous_target_distance < dodge_radius * 1.8
	_previous_target_distance = distance
	if passed_target:
		var result := _make_result(true, false, &"dodge", base_score, rift_damage)
		result["on_beat"] = true
		resolve_without_strike(result)

func _evaluate_strike(strike: Dictionary) -> Dictionary:
	return _make_result(false, false, &"dodge_only", 0, 0, strike)

func _lock_pink_target() -> void:
	if _player_camera:
		_locked_target = _player_camera.global_position
	else:
		_locked_target = Vector3(0.0, 1.5, 0.0)
	_previous_target_distance = global_position.distance_to(_locked_target)
