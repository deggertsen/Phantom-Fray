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
	# A desktop window losing focus would suspend the run as a headset does. Not here.
	var lifecycle := _main.get_node_or_null("XRLifecycleController")
	if lifecycle:
		lifecycle.queue_free()
	await _wait(1.0)
	# Stand the desktop camera at head height, as a player would be.
	var camera := _main.get_node("Player/XRCamera3D") as Node3D
	camera.position = Vector3(0.0, 1.6, 0.0)
	# --mission=sweep_drill: GameFlowController has already deployed it, so skip the menus.
	for arg in OS.get_cmdline_user_args():
		if arg == "--mission=sweep_drill":
			await _capture_sweep(camera)
			return
		if arg == "--tutorial":
			await _capture_tutorial(camera)
			return
	await _capture("01-menu")
	# Training is its own capture (-- --tutorial): T would start the whole chamber here.
	_press(KEY_S)
	await _wait(0.8)
	await _capture("01c-settings")
	_press(KEY_ESCAPE)
	await _wait(0.5)
	await _capture_city_tiers()
	_press(KEY_ENTER)
	await _wait(0.8)
	await _capture("02c-deploy")
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
	await _capture_results()
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

## Chen's training chamber, start to finish at real speed, with a stand-in recruit doing the
## right thing at each paused hologram once she has finished explaining it.
## Run: Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/play_capture.tscn -- --tutorial --art-label=tutorial
func _capture_tutorial(camera: Node3D) -> void:
	var tutorial := get_tree().get_first_node_in_group("TutorialDirector") as TutorialDirector
	var chen := get_tree().get_first_node_in_group("ChenComms") as ChenComms
	var life := get_tree().get_first_node_in_group("LifeForceManager") as LifeForceManager
	var done := [false]
	tutorial.finished.connect(func() -> void: done[0] = true)
	# A new recruit, saved to a scratch profile so the run leaves the real one alone.
	var settings := get_node_or_null("/root/GameSettings")
	if settings:
		settings.settings_path = "user://play_capture_settings.cfg"
		settings.tutorial_completed = false
	_main.get_node("GameFlowController").restore_current_menu()
	await _wait(0.5)
	await _capture("t00-menu-new-recruit")
	_press(KEY_T)
	_watch_beats.call_deferred(tutorial)
	await _wait(2.0)
	await _capture("t01-intro")
	_capture_bracer("t01a-intro-caption")
	# The introduction is one long line; the wrist pages through it.
	await _wait(12.0)
	_capture_bracer("t01b-intro-caption-later")
	await _until_beat(tutorial, &"play_space")
	await _wait(1.5)
	await _capture("t02-play-space")
	while tutorial.beat == &"play_space":
		_press(KEY_ENTER)
		await _wait(0.5)
	await _wait(1.2)
	await _capture("t03-rift")
	var shots := {
		&"yellow": "t04-yellow-paused", &"blue": "t05-blue-paused", &"green": "t07-green-paused",
		&"pink": "t08-pink-lane-locked", &"possession": "t09a-possession-paused",
	}
	var taken := {}
	var tapped := false
	var stepped := false
	while not done[0]:
		await get_tree().physics_frame
		var beat := tutorial.beat
		var phantom := tutorial.current_phantom()
		var held := phantom != null and phantom.is_held()
		if held and shots.has(beat) and not taken.has(beat):
			taken[beat] = true
			await _wait(0.6)
			await _capture(shots[beat])
			_capture_bracer(shots[beat] + "-bracer")
		match beat:
			&"yellow", &"blue", &"green", &"power":
				if held and not chen.is_busy():
					if beat == &"power":
						_hit(phantom, &"left", 7.0 if tapped else 1.5)
						var hard := tapped
						tapped = true
						if hard:
							await _wait(0.35)
							await _capture("t11-power-readout")
					elif beat == &"green":
						_hit(phantom, &"left", 4.0)
						_hit(phantom, &"right", 4.0)
					else:
						_hit(phantom, &"left" if beat == &"yellow" else &"right", 4.0, true)
			&"pink":
				if held and not chen.is_busy() and not stepped:
					stepped = true
					camera.position.x = 0.6
			&"possession":
				camera.position.x = 0.0
				# Desktop cannot raise a glove into view: Enter stands in for the look.
				if not taken.has(&"glove") and "tutorial_glove_check" in tutorial.spoken and not chen.is_busy():
					taken[&"glove"] = true
					await _capture("t09c-glove-check")
					_press(KEY_ENTER)
				if not taken.has(&"frost") and life.current_life_force < life.max_life_force - 10.0:
					taken[&"frost"] = true
					await _wait(0.35)
					await _capture("t09b-possession-frost")
					_capture_bracer("t09b-possession-bracer")
			&"rift_health":
				if not taken.has(beat):
					taken[beat] = true
					await _wait(1.5)
					await _capture("t10-rift-health")
					_capture_bracer("t10-rift-health-bracer")
			&"chain", &"live_wave":
				_strike_in_reach(beat)
				if beat == &"chain" and not taken.has(beat):
					taken[beat] = true
					await _wait(3.5)
					await _capture("t06-chain")
					_capture_bracer("t06-chain-bracer")
				if beat == &"live_wave" and not taken.has(beat):
					taken[beat] = true
					await _wait(4.0)
					await _capture("t12-live-wave")
				if beat == &"live_wave" and not taken.has(&"seal") and "tutorial_last_one" in tutorial.spoken:
					taken[&"seal"] = true
					while tutorial.beat == &"live_wave" and not "tutorial_straggler" in tutorial.spoken and not "tutorial_sealed_clean" in tutorial.spoken:
						_strike_in_reach(beat)
						await get_tree().physics_frame
					await _wait(0.4)
					await _capture("t13-after-seal")
	await _wait(1.0)
	await _capture("t14-training-complete")
	print("PLAY CAPTURE COMPLETE: %s" % _out_dir)
	get_tree().quit()

## If a beat runs past 60 s, print what is in play, once per beat, so a stalled run says why.
func _watch_beats(tutorial: TutorialDirector) -> void:
	var beat := &""
	var since := 0.0
	var reported := false
	# Started from the T press, which the game reads a frame or two later.
	while not tutorial.is_running():
		await get_tree().process_frame
	while tutorial.is_running():
		await get_tree().process_frame
		if tutorial.beat != beat:
			beat = tutorial.beat
			since = 0.0
			reported = false
		since += get_process_delta_time()
		if since < 60.0 or reported:
			continue
		reported = true
		var chen := get_tree().get_first_node_in_group("ChenComms") as ChenComms
		var round := get_tree().get_first_node_in_group("RoundController") as RoundController
		print("BEAT STALL %s chen=%s queue=%d voice_playing=%s round_active=%s spoken_last=%s" % [beat, chen._playing_event, chen._queue.size(), chen._player.playing, round.is_round_active(), tutorial.spoken.slice(-3)])
		for rift in get_tree().get_nodes_in_group("active_rift"):
			print("  rift health=%d feed=%s spawning=%s live=%d" % [rift.rift_health, rift.feed_enabled, rift.spawning_enabled, rift.live_phantoms().size()])
		for node in get_tree().get_nodes_in_group("phantom"):
			var p := node as Phantom
			if p:
				print("  %s held=%s phase=%d dist=%.2f alive=%.1f physics=%s terminal=%s" % [p.variant_id, p.is_held(), p._phase, p.global_position.distance_to(_main.get_node("Player/XRCamera3D").global_position), p._alive_time, p.is_physics_processing(), p._terminal])

func _until_beat(tutorial: TutorialDirector, beat: StringName) -> void:
	while tutorial.beat != beat:
		await get_tree().process_frame

## The stand-in recruit in a live beat: the matching hand on anything in reach.
func _strike_in_reach(_beat: StringName) -> void:
	for node in get_tree().get_nodes_in_group("phantom"):
		var phantom := node as Phantom
		if phantom == null or not phantom.shows_approach_cue() or not phantom.is_strike_window_open():
			continue
		match phantom.variant_id:
			&"yellow":
				_hit(phantom, &"left", 4.5)
			&"blue":
				_hit(phantom, &"right", 4.5)
			&"green":
				_hit(phantom, &"left", 4.5)
				_hit(phantom, &"right", 4.5)

func _hit(phantom: Phantom, hand: StringName, speed: float, on_lure: bool = false) -> void:
	if not is_instance_valid(phantom) or not phantom.shows_approach_cue():
		return
	var at := phantom.global_position
	var lure := phantom.get_node_or_null("SweetSpotVisual") as Node3D
	if lure and on_lure:
		at = lure.global_position
	elif lure:
		at += Vector3(0.0, -0.5, 0.0)
	phantom.receive_strike({"hand_id": hand, "position": at, "direction": Vector3.FORWARD, "speed": speed})
## The city map at Full Resonance, then back at the profile's difficulty. The tier is switched in
## memory only, so the real profile keeps its choice.
func _capture_city_tiers() -> void:
	var flow := _main.get_node("GameFlowController")
	var settings := get_node_or_null("/root/GameSettings")
	if settings:
		var chosen := String(settings.difficulty_tier)
		settings.difficulty_tier = DifficultyTier.FULL_RESONANCE
		flow._show_main_menu()
		await _wait(0.6)
		await _capture("02-city-full-resonance")
		settings.difficulty_tier = chosen
	flow._show_main_menu()
	await _wait(0.6)

## Results after sealing the junction, from a scratch profile so the real one records nothing.
func _capture_results() -> void:
	var presenter := _main.get_node("VRMenuPresenter") as VRMenuPresenter
	var profile: Node = load("res://Scripts/Core/game_settings.gd").new()
	profile.cleared_missions = PackedStringArray(["first_light", "widen_the_ring", "chens_gambit"])
	var entries := MissionCatalog.operation_entries(profile)
	presenter.show_results({
		"outcome": &"victory",
		"score": 12840,
		"debrief": "Chen: It knows your resonance now. This was the opening move. Not the end of the war.",
		"seconds": 252.0,
		"previous_best": 280.0,
		"best_seconds": 252.0,
		"tier": DifficultyTier.STANDARD,
		"mission": entries[2],
		"next": entries[3],
		"sealed_before": 2,
		"entries": entries,
		"offer_training": false,
	})
	await _wait(0.6)
	await _capture("07-results")
	profile.free()

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
