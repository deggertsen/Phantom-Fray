extends Node

## Plays the boss Maw on desktop and saves stills of phase one, each beat of the turn, the fight,
## and the retreat. Shift+B starts it from the main menu as a tester would, forcing a break.
## Phase one is cut short by sealing the rift's health directly; everything after that plays
## as the game runs it. Life force is made bottomless, since nobody is punching.
## Run: Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/boss_capture.tscn
## Writes PNGs to res://reports/boss/<label>/ (label from --art-label=<name>, default "current").

var _out_dir: String
var _main: Node3D
var _camera: Node3D
var _boss: MawBoss
var _rift: RiftManager

func _ready() -> void:
	var label := "current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-label="):
			label = arg.trim_prefix("--art-label=")
	_out_dir = ProjectSettings.globalize_path("res://reports/boss/%s" % label)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# The break counters this run records stay out of the real profile.
	var settings := get_node_or_null("/root/GameSettings")
	if settings:
		settings.settings_path = "user://boss_capture_settings.cfg"
	_main =(load("res://main.tscn") as PackedScene).instantiate() as Node3D
	add_child(_main)
	# A desktop window losing focus would suspend the round as a headset does. Not here.
	var lifecycle := _main.get_node_or_null("XRLifecycleController")
	if lifecycle:
		lifecycle.queue_free()
	await _wait(1.0)
	_camera = _main.get_node("Player/XRCamera3D") as Node3D
	_camera.position = Vector3(0.0, 1.6, 0.0)
	var life := _main.get_node("Player/LifeForceManager") as LifeForceManager
	life.max_life_force = 1000000.0
	_press(KEY_B, true)
	await _wait(3.6)
	var director := _main.get_node("RiftSpawnManager") as RiftDirector
	_boss = director.get_node("MawBoss") as MawBoss
	if director.rift_instances.is_empty() or not _boss.breaks:
		push_error("BOSS CAPTURE: the boss Maw did not start or did not break")
		get_tree().quit(1)
		return
	_rift = director.rift_instances[0] as RiftManager
	_face(_rift.portal_center() + Vector3.DOWN * 1.5)
	await _wait(6.0)
	await _capture("01-phase-one-flood")
	_capture_bracer("01-bracer-phase-one")
	# Phase one ends on the last resolve, as every rift does.
	_rift.apply_result({"rift_damage": 100000, "base_score": 0, "resolution_kind": &"strike"})
	await _at_turn(0.3)
	await _capture("02-turn-false-seal")
	await _at_turn(0.9)
	await _capture("03-turn-silence")
	await _at_turn(2.2)
	await _capture("04-turn-escort-flees")
	await _at_turn(4.6)
	await _capture("05-turn-tear")
	await _at_turn(6.4)
	await _capture("06-turn-tentacle-slides")
	await _at_turn(8.4)
	_face(_boss._tentacle.tip() if _boss._tentacle else _rift.portal_center())
	await _capture("07-turn-tentacle-risen-look-up")
	_face(_rift.portal_center() + Vector3.DOWN * 1.5)
	await _at_turn(8.6)
	await _capture("07b-turn-tentacle-risen")
	await _at_turn(10.5)
	await _capture("08-turn-roar-shockwave")
	await _until(func() -> bool: return _boss.stage == MawBoss.Stage.FIGHT and _boss._clock > 1.6)
	await _capture("09-fight-anchor")
	_capture_bracer("09-bracer-anchor")
	await _until(func() -> bool: return _boss._step.get("do", "") == "sweep" and _boss._sweep != null and float(_boss._sweep.call("telegraph_progress")) > 0.6)
	await _capture("10-sweep-drawn-back")
	await _until(func() -> bool: return _boss._sweep != null and float(_boss._sweep.call("progress")) > 0.35)
	await _capture("11-sweep-crossing")
	await _until(func() -> bool: return _boss._step.get("do", "") == "volley" and _boss._step_time > 1.5)
	await _capture("12-escort-volley")
	await _until(func() -> bool: return _boss._step.get("do", "") == "slam" and _boss._slam != null and is_instance_valid(_boss._slam) and _boss._slam.rise() > 0.7)
	await _capture("13-slam-raised")
	# A side-step out of the ring before it lands, as the player would.
	_camera.position = Vector3(1.1, 1.6, 0.0)
	await _until(func() -> bool: return _boss.is_spent_window_open() and _boss._phase_time > 0.6)
	await _capture("14-spent-tentacle")
	for _i in 4:
		_press(KEY_P)
		await _wait(0.5)
	_capture_bracer("14-bracer-after-push-ups")
	_camera.position = Vector3(0.0, 1.6, 0.0)
	# Skip to the end of the anchor. The retreat plays as the game runs it.
	_rift.drain_health(_rift.rift_health)
	await _wait(0.6)
	await _capture("15-retreat")
	await _wait(1.2)
	await _capture("16-retreat-closing")
	_capture_bracer("16-bracer-sealed")
	await _wait(3.0)
	await _capture("17-results")
	print("BOSS CAPTURE COMPLETE: %s" % _out_dir)
	get_tree().quit()

func _at_turn(seconds: float) -> void:
	await _until(func() -> bool: return _boss.stage != MawBoss.Stage.TURN or _boss._clock >= seconds)

func _until(condition: Callable, timeout: float = 60.0) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if waited >= timeout:
		push_warning("BOSS CAPTURE: timed out waiting")

func _face(target: Vector3) -> void:
	if not _camera.global_position.is_equal_approx(target):
		_camera.look_at(target, Vector3.UP)

func _press(keycode: Key, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.shift_pressed = shift
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## The wrist panel sits out of the desktop camera's view, so save what its own display last drew.
func _capture_bracer(file_name: String) -> void:
	var display := _main.get_node_or_null("Player/LeftHandController/RoundHUD/Display") as SubViewport
	if display:
		display.get_texture().get_image().save_png("%s/%s.png" % [_out_dir, file_name])

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out_dir, file_name])
