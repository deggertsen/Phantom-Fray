extends Node

## Plays the real game on desktop with the same keys a tester would press, and saves frames.
## Run: Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/play_capture.tscn
## Writes PNGs to res://reports/play/<label>/ (label from --art-label=<name>, default "current").

var _out_dir: String
var _main: Node3D

func _ready() -> void:
	var label := "current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-label="):
			label = arg.trim_prefix("--art-label=")
	_out_dir = ProjectSettings.globalize_path("res://reports/play/%s" % label)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	add_child(_main)
	await _wait(1.0)
	# Stand the desktop camera at head height, as a player would be.
	var camera := _main.get_node("Player/XRCamera3D") as Node3D
	camera.position = Vector3(0.0, 1.6, 0.0)
	# --mission=sweep_drill: GameFlowController has already deployed it, so skip the menus.
	for arg in OS.get_cmdline_user_args():
		if arg == "--mission=sweep_drill":
			await _capture_sweep(camera)
			return
	await _capture("01-menu")
	_press(KEY_T)
	await _wait(0.8)
	await _capture("01b-tutorial")
	_press(KEY_ESCAPE)
	await _wait(0.5)
	_press(KEY_S)
	await _wait(0.8)
	await _capture("01c-settings")
	_press(KEY_ESCAPE)
	await _wait(0.5)
	_press(KEY_ENTER)
	await _wait(0.8)
	await _capture("02-operations")
	_press(KEY_ENTER)
	await _wait(2.0)
	await _capture("03-countdown")
	await _wait(7.0)
	await _capture("04-combat")
	_capture_bracer("04-bracer")
	await _wait(5.0)
	await _capture("05-combat")
	_capture_bracer("05-bracer")
	_press(KEY_ESCAPE)
	await _wait(0.8)
	await _capture("06-pause")
	print("PLAY CAPTURE COMPLETE: %s" % _out_dir)
	get_tree().quit()

## The resonance sweep: the rails lighting, the blade coming in, and the blade over a ducked head.
## Run: Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/play_capture.tscn -- --mission=sweep_drill --art-label=sweep
func _capture_sweep(camera: Node3D) -> void:
	await _wait(4.0)
	# Keep the frames about the sweep: no lunges hitting the desktop camera mid-shot.
	for rift in get_tree().get_nodes_in_group("active_rift"):
		rift.stop_spawning()
	for phantom in get_tree().get_nodes_in_group("phantom"):
		phantom.force_cleanup()
	await _wait(0.6)
	var container := _main.get_tree().get_first_node_in_group("PhantomContainer") as Node3D
	# One sweep straight ahead, rather than waiting on the pool to roll one.
	var sweep := (load(MissionCatalog.scene_path("sweep")) as PackedScene).instantiate() as ResonanceSweep
	container.add_child(sweep)
	sweep.global_position = camera.global_position + Vector3(0.0, -0.1, -5.0)
	sweep._source = sweep.global_position
	sweep._lock_geometry()
	sweep._place_visuals()
	var shots := ["07-sweep-telegraph", "08-sweep-blade", "09-sweep-overhead"]
	while is_instance_valid(sweep) and not shots.is_empty():
		await get_tree().physics_frame
		if shots[0] == "07-sweep-telegraph" and sweep._rest_remaining == 0.0 and sweep._telegraph_remaining < 0.25:
			await _capture(shots.pop_front())
		elif shots[0] == "08-sweep-blade" and sweep._blade_travel > 2.2:
			await _capture(shots.pop_front())
			camera.position = Vector3(0.0, 1.28, 0.0)
		elif shots[0] == "09-sweep-overhead" and sweep._blade_travel > 4.1:
			await _capture(shots.pop_front())
	print("PLAY CAPTURE COMPLETE: %s" % _out_dir)
	get_tree().quit()

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
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
