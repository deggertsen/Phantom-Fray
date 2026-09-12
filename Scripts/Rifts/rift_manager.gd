extends Node3D
class_name RiftManager

signal health_changed(current: int, maximum: int)
signal phantom_resolved(result: Dictionary)
signal player_damaged(amount: float)
signal closed

@export var phantom_scenes: Array[PackedScene] = []
@export var spawn_interval: float = 3.5
@export var max_live_phantoms: int = 4
@export var maximum_health: int = 100
@export var spawn_radius: float = 2.5

var rift_id: int = 0
var rift_health: int
var spawning_enabled: bool = false
var _closing: bool = false
var _dissolve_amount: float = 0.0
var _damage_flash: float = 0.0
var _spawn_timer: Timer
var _phantom_container: Node3D
var _live_phantoms: Dictionary = {}
var _portal_material: ShaderMaterial

func _ready() -> void:
	rift_health = maximum_health
	_initialize_rift_visuals()
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	_phantom_container = get_tree().get_first_node_in_group("PhantomContainer") as Node3D
	if _phantom_container == null:
		_phantom_container = self

func start_spawning() -> void:
	if _closing:
		return
	spawning_enabled = true
	_spawn_timer.start()

func stop_spawning() -> void:
	spawning_enabled = false
	if _spawn_timer:
		_spawn_timer.stop()

func force_cleanup() -> void:
	stop_spawning()
	for phantom in _live_phantoms.values():
		if is_instance_valid(phantom) and phantom.has_method("force_cleanup"):
			phantom.force_cleanup()
	_live_phantoms.clear()
	queue_free()

func _process(delta: float) -> void:
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	if _portal_material:
		_portal_material.set_shader_parameter("damage_flash", _damage_flash)
	if not _closing:
		return
	_dissolve_amount = minf(_dissolve_amount + delta * 0.75, 1.0)
	if _portal_material:
		_portal_material.set_shader_parameter("dissolve_amount", _dissolve_amount)
	if _dissolve_amount >= 1.0:
		queue_free()

func _on_spawn_timer_timeout() -> void:
	_prune_phantoms()
	if not spawning_enabled or _closing or _live_phantoms.size() >= max_live_phantoms:
		return
	_spawn_phantom()

func _spawn_phantom() -> void:
	if phantom_scenes.is_empty():
		push_warning("RiftManager: no phantom scenes configured")
		return
	var scene := phantom_scenes[randi() % phantom_scenes.size()]
	if scene == null:
		return
	var phantom := scene.instantiate() as Node3D
	if phantom == null:
		return
	var angle := randf_range(-0.65, 0.65)
	var offset := Vector3(sin(angle), randf_range(-0.35, 0.35), cos(angle)) * randf_range(0.8, spawn_radius)
	phantom.position = _phantom_container.to_local(global_position + offset)
	_phantom_container.add_child(phantom)
	_live_phantoms[phantom.get_instance_id()] = phantom
	phantom.resolved.connect(_on_phantom_resolved.bind(phantom))
	phantom.player_contact.connect(_on_phantom_player_contact.bind(phantom))
	phantom.tree_exiting.connect(_on_phantom_tree_exiting.bind(phantom.get_instance_id()))

func _on_phantom_resolved(result: Dictionary, phantom: Node3D) -> void:
	_unregister_phantom(phantom)
	if _closing:
		return
	var damage: int = result.get("rift_damage", 0)
	rift_health = maxi(rift_health - damage, 0)
	_damage_flash = 1.0
	_update_health_shader()
	health_changed.emit(rift_health, maximum_health)
	phantom_resolved.emit(result)
	if rift_health <= 0:
		_close_rift()

func _on_phantom_player_contact(amount: float, phantom: Node3D) -> void:
	_unregister_phantom(phantom)
	player_damaged.emit(amount)

func _on_phantom_tree_exiting(instance_id: int) -> void:
	_live_phantoms.erase(instance_id)

func _unregister_phantom(phantom: Node3D) -> void:
	if is_instance_valid(phantom):
		_live_phantoms.erase(phantom.get_instance_id())

func _prune_phantoms() -> void:
	for instance_id in _live_phantoms.keys():
		if not is_instance_valid(_live_phantoms[instance_id]):
			_live_phantoms.erase(instance_id)

func _close_rift() -> void:
	if _closing:
		return
	_closing = true
	stop_spawning()
	closed.emit()
	for phantom in _live_phantoms.values():
		if is_instance_valid(phantom) and phantom.has_method("force_cleanup"):
			phantom.force_cleanup()
	_live_phantoms.clear()
	var audio := AudioStreamPlayer3D.new()
	audio.stream = preload("res://Assets/Audio/SFX/rift_close_sound.mp3")
	audio.bus = &"SFX"
	audio.volume_db = -5.0
	add_child(audio)
	audio.play()

func _initialize_rift_visuals() -> void:
	var portal := MeshInstance3D.new()
	portal.name = "Portal"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.0, 4.0)
	portal.mesh = mesh
	_portal_material = preload("res://Resources/Materials/rift_video.tres").duplicate() as ShaderMaterial
	portal.material_override = _portal_material
	add_child(portal)
	_update_health_shader()

func _update_health_shader() -> void:
	if _portal_material == null:
		return
	var ratio := float(rift_health) / maxf(float(maximum_health), 1.0)
	_portal_material.set_shader_parameter("health_ratio", ratio)
	_portal_material.set_shader_parameter("intensity", lerpf(0.75, 1.2, ratio))
