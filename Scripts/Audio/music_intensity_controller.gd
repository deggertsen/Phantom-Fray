extends Node

@export var low_life_volume_db: float = 2.0
@export var normal_volume_db: float = 0.0
@export var climax_pitch: float = 1.08

var _music_manager: Node
var _life_force: LifeForceManager
var _round: RoundController
var _life_state: StringName = &"healthy"
var _closed_rifts: int = 0
var _total_rifts: int = 3
var _pressure: float = 0.0

func _ready() -> void:
	await get_tree().process_frame
	_music_manager = get_node_or_null("../MusicManager")
	_life_force = get_tree().get_first_node_in_group("LifeForceManager") as LifeForceManager
	_round = get_tree().get_first_node_in_group("RoundController") as RoundController
	if _life_force:
		_life_force.life_force_state_changed.connect(_on_life_state_changed)
	if _round:
		_round.rift_progress_changed.connect(_on_rift_progress_changed)
		_round.pressure_changed.connect(_on_pressure_changed)

func _on_life_state_changed(state: StringName) -> void:
	_life_state = state
	_apply_music_state()

func _on_rift_progress_changed(closed: int, total: int) -> void:
	_closed_rifts = closed
	_total_rifts = total
	_apply_music_state()

func _on_pressure_changed(ratio: float) -> void:
	_pressure = clampf(ratio, 0.0, 1.0)
	_apply_music_state()

func _apply_music_state() -> void:
	var player := _get_music_player()
	if player == null:
		return
	var pressured := normal_volume_db + _pressure * 1.6
	player.volume_db = low_life_volume_db if _life_state in [&"danger", &"critical"] else pressured
	var pitch := lerpf(1.0, climax_pitch, _pressure)
	if _total_rifts > 0 and _closed_rifts >= _total_rifts - 1 and _closed_rifts > 0:
		pitch = climax_pitch
	elif _life_state == &"critical":
		pitch = maxf(pitch, 1.04)
	player.pitch_scale = pitch

func _get_music_player() -> AudioStreamPlayer:
	if _music_manager == null:
		return null
	return _music_manager.get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
