extends CharacterBody3D
class_name Phantom

signal resolved(result: Dictionary)
signal player_contact(damage: float)
signal feedback_requested(kind: StringName, position: Vector3, intensity: float)

@export var variant_id: StringName = &"neutral"
@export var move_speed: float = 3.2
@export var acceleration: float = 5.0
@export var wobble_strength: float = 0.18
@export var wobble_speed: float = 2.0
@export var hover_height: float = 1.25
@export var base_score: int = 100
@export var rift_damage: int = 10
@export var contact_damage: float = 5.0
@export var required_hand: StringName = &""
@export var phantom_color: Color = Color(0.55, 0.25, 1.0, 0.88)
@export var dissolve_speed: float = 1.4

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var contact_area: Area3D = $Area3D

var _player_camera: Node3D
var _time: float = 0.0
var _terminal: bool = false
var _dissolving: bool = false
var _dissolve_amount: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _audio_player: AudioStreamPlayer3D

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

	var base_material := preload("res://Resources/Materials/dissolve.tres") as ShaderMaterial
	var material := base_material.duplicate() as ShaderMaterial
	mesh_instance.material_override = material
	material.set_shader_parameter("dissolve_amount", 0.0)
	material.set_shader_parameter("impact_point", global_position)
	material.set_shader_parameter("dissolve_direction", Vector3.UP)
	material.set_shader_parameter("base_color", phantom_color)
	material.set_shader_parameter("edge_color", phantom_color.lightened(0.35))

	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "DeathAudio"
	_audio_player.stream = preload("res://Assets/Audio/SFX/phantom_death.mp3")
	_audio_player.bus = &"SFX"
	_audio_player.volume_db = -7.0
	_audio_player.max_distance = 20.0
	add_child(_audio_player)

func _physics_process(delta: float) -> void:
	if _terminal:
		_knockback_velocity *= pow(0.08, delta)
		velocity = _knockback_velocity
		move_and_slide()
		return
	if _player_camera == null:
		return

	_time += delta
	var direction := (_player_camera.global_position - global_position).normalized()
	var wobble := Vector3(
		sin(_time * wobble_speed) * wobble_strength,
		cos(_time * wobble_speed * 0.7) * wobble_strength,
		sin(_time * wobble_speed * 1.3) * wobble_strength
	)
	var target_velocity := (direction + wobble).normalized() * move_speed
	velocity = velocity.lerp(target_velocity, clampf(acceleration * delta, 0.0, 1.0))
	var horizontal := Vector3(direction.x, 0.0, direction.z).normalized()
	if horizontal.length_squared() > 0.001:
		global_transform.basis = Basis(Vector3.UP, atan2(horizontal.x, horizontal.z))
	move_and_slide()

func _process(delta: float) -> void:
	if not _dissolving:
		return
	_dissolve_amount = minf(_dissolve_amount + dissolve_speed * delta, 1.0)
	var material := mesh_instance.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("dissolve_amount", _dissolve_amount)
	if _dissolve_amount >= 1.0:
		queue_free()

func receive_strike(strike: Dictionary) -> Dictionary:
	if _terminal:
		return _make_result(false, false, &"already_resolved", 0, 0, strike)
	var result := _evaluate_strike(strike)
	if not result.get("valid", false):
		feedback_requested.emit(&"rejected", strike.get("position", global_position), 0.25)
		return result
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

func _begin_dissolve(impact_position: Vector3, direction: Vector3) -> void:
	_dissolving = true
	var material := mesh_instance.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("impact_point", impact_position)
		material.set_shader_parameter("dissolve_direction", direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP)
	if _audio_player and not _audio_player.playing:
		_audio_player.play()

func _on_contact_body_entered(body: Node3D) -> void:
	if _terminal or not body.is_in_group("PlayerBody"):
		return
	_terminal = true
	_disable_collisions()
	_begin_dissolve(global_position, Vector3.UP)
	player_contact.emit(contact_damage)

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
