extends Node3D
class_name RiftDirector

const SfxVariations := preload("res://Scripts/Audio/sfx_variations.gd")

signal rift_spawned(rift_id: int, rift: Node3D)
signal rift_closed(rift_id: int, closed_count: int, total_count: int)
signal phantom_resolved(result: Dictionary)
signal player_damaged(amount: float)
signal strike_rejected(reason: StringName)
signal all_rifts_closed

@export var rift_manager_scene: PackedScene
@export var total_rifts: int = 3
@export var max_concurrent_rifts: int = 1
@export var min_player_distance: float = 11.0
@export var max_player_distance: float = 16.0
@export var min_rift_distance: float = 8.0
@export var rift_height: float = 2.2

var spawning_enabled: bool = false
var spawned_rifts: int = 0
var closed_rifts: int = 0
var rift_instances: Array[Node3D] = []
var _next_rift_id: int = 1
var _player: Node3D
var _mission: Dictionary = {}
var _wave_cursor: int = 0

func _ready() -> void:
	add_to_group("RiftSpawnManager")
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	var compass := preload("res://Scripts/Presentation/rift_compass.gd").new()
	compass.name = "RiftCompass"
	add_child(compass)
	var bearings := preload("res://Scripts/Presentation/phantom_bearings.gd").new()
	bearings.name = "PhantomBearings"
	add_child(bearings)

func start_round(mission: Dictionary = {}) -> void:
	_mission = mission
	var waves: Array = mission.get("rifts", [])
	if not waves.is_empty():
		total_rifts = waves.size()
	_wave_cursor = spawned_rifts
	spawning_enabled = true
	_fill_rift_slots()

func stop_spawning() -> void:
	spawning_enabled = false
	for rift in rift_instances:
		if is_instance_valid(rift) and rift.has_method("stop_spawning"):
			rift.stop_spawning()

func resume_spawning() -> void:
	spawning_enabled = true
	for rift in rift_instances:
		if is_instance_valid(rift) and rift.has_method("start_spawning"):
			rift.start_spawning(false)
	_fill_rift_slots()

func cleanup_round() -> void:
	spawning_enabled = false
	for rift in rift_instances.duplicate():
		if is_instance_valid(rift) and rift.has_method("force_cleanup"):
			rift.force_cleanup()
	rift_instances.clear()
	spawned_rifts = 0
	closed_rifts = 0
	_next_rift_id = 1

func _fill_rift_slots() -> void:
	while spawning_enabled and rift_instances.size() < max_concurrent_rifts and spawned_rifts < total_rifts:
		_spawn_new_rift()

func _spawn_new_rift() -> void:
	if rift_manager_scene == null:
		push_error("RiftDirector: rift_manager_scene is missing")
		return
	var rift := rift_manager_scene.instantiate() as Node3D
	var id := _next_rift_id
	_next_rift_id += 1
	rift.rift_id = id
	add_child(rift)
	rift.global_position = _find_valid_position()
	if _player and not rift.global_position.is_equal_approx(_player.global_position):
		rift.look_at(_player.global_position + Vector3.UP * 1.4, Vector3.UP)
	var waves: Array = _mission.get("rifts", [])
	if _wave_cursor < waves.size() and rift.has_method("configure_wave"):
		rift.configure_wave(waves[_wave_cursor])
	_wave_cursor += 1
	rift.closed.connect(_on_rift_closed.bind(id, rift))
	rift.phantom_resolved.connect(_on_phantom_resolved)
	rift.player_damaged.connect(_on_player_damaged)
	if rift.has_signal("strike_rejected"):
		rift.strike_rejected.connect(_on_strike_rejected)
	rift_instances.append(rift)
	spawned_rifts += 1
	_play_open_sound(rift.global_position)
	rift_spawned.emit(id, rift)
	rift.start_spawning(true)

func _on_rift_closed(rift_id: int, rift: Node3D) -> void:
	rift_instances.erase(rift)
	closed_rifts += 1
	rift_closed.emit(rift_id, closed_rifts, total_rifts)
	if closed_rifts >= total_rifts:
		spawning_enabled = false
		all_rifts_closed.emit()
	else:
		var replacement_delay := get_tree().create_timer(1.35)
		replacement_delay.timeout.connect(_fill_rift_slots)

func _on_phantom_resolved(result: Dictionary) -> void:
	phantom_resolved.emit(result)

func _on_player_damaged(amount: float) -> void:
	player_damaged.emit(amount)

func _on_strike_rejected(reason: StringName) -> void:
	strike_rejected.emit(reason)

func _find_valid_position() -> Vector3:
	var player_position := _player.global_position if _player else Vector3.ZERO
	for _attempt in range(40):
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(min_player_distance, max_player_distance)
		var candidate := player_position + Vector3(sin(angle) * distance, rift_height, cos(angle) * distance)
		var valid := true
		for existing in rift_instances:
			if is_instance_valid(existing) and existing.global_position.distance_to(candidate) < min_rift_distance:
				valid = false
				break
		if valid:
			return candidate
	return player_position + Vector3(0.0, rift_height, -min_player_distance)

func _play_open_sound(position: Vector3) -> void:
	var stream := SfxVariations.pick("rift_open_sound")
	if stream == null:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.bus = &"SFX"
	audio.volume_db = -9.0
	audio.max_distance = 35.0
	audio.global_position = position
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
