extends SceneTree

const SfxVariations := preload("res://Scripts/Audio/sfx_variations.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_resources()
	_validate_sfx_variations()
	await _validate_variant_rules()
	_validate_life_force()
	await _validate_attack_window()
	await _validate_mission_catalog()
	await _validate_difficulty_tiers()
	await _validate_rift_stragglers()
	await _validate_elapsed_timer()
	await _validate_menu_surface()
	await _validate_results_menu()
	await _validate_pink_dodge()
	_validate_squat_detector()
	_validate_push_up_detector()
	_validate_jump_detection()
	await _validate_low_sweep()
	_validate_maw_break_odds()
	await _validate_maw_boss()
	_validate_maw_cycle_variety()
	await _validate_maw_glimpse()
	await _validate_phantom_hold()
	await _validate_punch_power()
	await _validate_tutorial_flow()
	await _validate_resonance_sweep()
	_validate_hand_tracking_probe()
	_validate_tracked_hands()
	await process_frame
	if failures.is_empty():
		print("PHANTOM FURY VALIDATION PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _validate_resources() -> void:
	for path in [
		"res://main.tscn",
		"res://Scenes/Phantoms/base_phantom.tscn",
		"res://Scenes/Phantoms/yellow_phantom.tscn",
		"res://Scenes/Phantoms/blue_phantom.tscn",
		"res://Scenes/Phantoms/green_phantom.tscn",
		"res://Scenes/Phantoms/pink_phantom.tscn",
		"res://Scenes/Rifts/rift_manager.tscn",
		"res://Scenes/Hazards/resonance_sweep.tscn",
	]:
		if load(path) == null:
			failures.append("Failed to load %s" % path)
	var distort := load("res://Resources/Materials/damage_distort.gdshader") as Shader
	if distort == null:
		failures.append("Damage distort shader failed to load")
	else:
		var material := ShaderMaterial.new()
		material.shader = distort
		material.set_shader_parameter("strength", 1.0)
	var impact := load("res://Resources/Materials/damage_impact.gdshader") as Shader
	if impact == null:
		failures.append("Damage impact shader failed to load")
	else:
		var impact_material := ShaderMaterial.new()
		impact_material.shader = impact
		impact_material.set_shader_parameter("strength", 1.0)

func _validate_sfx_variations() -> void:
	var expected := {
		"phantom_death": 4,
		"bones_cracking": 8,
		"rift_close_sound": 3,
		"rift_open_sound": 1,
	}
	for stem in expected:
		if SfxVariations.variation_count(stem) != int(expected[stem]):
			failures.append("%s has %d takes, expected %d" % [stem, SfxVariations.variation_count(stem), int(expected[stem])])
	var first := SfxVariations.pick("bones_cracking")
	var varied := false
	for _i in 6:
		if SfxVariations.pick("bones_cracking") != first:
			varied = true
			break
	if first == null or not varied:
		failures.append("Hit takes did not vary")
	for stem in expected:
		var stream := SfxVariations.pick(stem)
		if stream == null:
			failures.append("%s pick returned no stream" % stem)

func _validate_variant_rules() -> void:
	var yellow_scene := load("res://Scenes/Phantoms/yellow_phantom.tscn") as PackedScene
	var yellow := yellow_scene.instantiate()
	root.add_child(yellow)
	await process_frame
	var wrong: Dictionary = yellow._evaluate_strike({"hand_id": &"right", "position": yellow.global_position})
	if wrong.get("valid", true):
		failures.append("Yellow accepts right-hand strike")
	var correct: Dictionary = yellow._evaluate_strike({"hand_id": &"left", "position": yellow.get_node("SweetSpotVisual").global_position})
	if not correct.get("valid", false) or not correct.get("sweet_spot", false):
		failures.append("Yellow sweet spot rejects left-hand strike")
	var faces: Dictionary = {}
	for face in 3:
		yellow.place_sweet_spot(face)
		var spot: Vector3 = yellow.get_node("SweetSpotVisual").position
		if face == 0 and spot.x > -0.2:
			failures.append("Yellow hook spot left the punching side")
		elif face == 1 and spot.y > -0.2:
			failures.append("Yellow uppercut spot is not on the underside")
		elif face == 2 and spot.z < 0.2:
			failures.append("Yellow jab spot is not on the front")
		var sweet: Dictionary = yellow._evaluate_strike({"hand_id": &"left", "position": yellow.get_node("SweetSpotVisual").global_position})
		if not sweet.get("sweet_spot", false):
			failures.append("Moved sweet spot rejected the strike")
		faces[face] = true
	for _roll in 24:
		yellow.place_sweet_spot()
		var rolled: Vector3 = yellow.get_node("SweetSpotVisual").position
		if rolled.y < -0.2:
			faces["belly"] = true
		elif rolled.z > 0.2:
			faces["front"] = true
		elif absf(rolled.x) > 0.2:
			faces["side"] = true
	if not faces.has("belly") or not faces.has("front") or not faces.has("side"):
		failures.append("Yellow sweet spot did not vary between hook, uppercut, and jab")
	var blue_scene := load("res://Scenes/Phantoms/blue_phantom.tscn") as PackedScene
	var blue := blue_scene.instantiate()
	root.add_child(blue)
	await process_frame
	blue.place_sweet_spot(0)
	if blue.get_node("SweetSpotVisual").position.x < 0.2:
		failures.append("Blue hook spot left the punching side")
	blue.queue_free()
	yellow.queue_free()
	await process_frame

	var green_scene := load("res://Scenes/Phantoms/green_phantom.tscn") as PackedScene
	var green := green_scene.instantiate()
	root.add_child(green)
	await process_frame
	var first: Dictionary = green._evaluate_strike({"hand_id": &"left"})
	var second: Dictionary = green._evaluate_strike({"hand_id": &"right"})
	if first.get("valid", true) or not second.get("valid", false):
		failures.append("Green two-hand block rule failed")
	green.queue_free()

func _validate_menu_surface() -> void:
	var menu_scene := load("res://Scenes/UI/vr_menu_panel.tscn") as PackedScene
	if menu_scene == null:
		failures.append("VR menu scene failed to load")
		return
	var menu := menu_scene.instantiate() as VRMenuPanel
	root.add_child(menu)
	await process_frame
	menu.show_main_menu()
	await process_frame
	var deploy := _find_button(menu, "DEPLOY MISSION")
	var training := _find_button(menu, "START TRAINING")
	var settings := _find_button(menu, "OPEN SETTINGS")
	if deploy == null or training == null or settings == null:
		failures.append("Main menu mission/training/settings actions are not all present")
	else:
		var activated := [false]
		menu.action_requested.connect(func(action: StringName) -> void:
			activated[0] = action == &"deploy"
		)
		if not menu.activate_at_viewport_point(deploy.get_global_rect().get_center()) or not activated[0]:
			failures.append("Pointing at a menu button did not activate it")
	# A new recruit: training is the highlighted button, and Deploy still works.
	menu.show_main_menu("NEXT", true)
	await process_frame
	var new_training := _find_button(menu, "START TRAINING")
	var new_deploy := _find_button(menu, "DEPLOY MISSION")
	if new_training == null or not bool(new_training.get_meta(&"primary", false)) or new_deploy == null or bool(new_deploy.get_meta(&"primary", false)) or new_deploy.disabled:
		failures.append("A new recruit's main menu does not lead with training")
	elif not "TRAINING RECOMMENDED FIRST" in new_deploy.text:
		failures.append("Deploy does not recommend training to a new recruit")
	menu.show_training_complete("NEXT")
	await process_frame
	var complete_actions := _button_actions(menu)
	if complete_actions != ["training_deploy", "training_replay", "training_menu"]:
		failures.append("Training Complete offers %s" % [complete_actions])
	menu.show_pause(true)
	await process_frame
	if _button_actions(menu) != ["resume", "pause_settings", "end_training"]:
		failures.append("The training pause menu offers %s" % [_button_actions(menu)])
	menu.show_results(&"defeat", 100, "", "", 0.0, 0.0, "", true)
	await process_frame
	if not "results_training" in _button_actions(menu):
		failures.append("Defeat results do not offer Review Training")
	menu.show_results(&"victory", 100, "", "NEXT", 60.0, 0.0, "", false)
	await process_frame
	if "results_training" in _button_actions(menu):
		failures.append("Victory results offer Review Training")
	menu.show_settings("75%", "50%", "100%", false, false)
	await process_frame
	var flashes_off := false
	var flashes_on := false
	var saw_reset := false
	for button in _buttons_under(menu):
		var action := String(button.get_meta(&"menu_action", &""))
		if action == "settings_flashes_off":
			flashes_off = button.text.begins_with("●")
		elif action == "settings_flashes_on":
			flashes_on = not button.text.begins_with("●")
		elif action == "reset_progress":
			saw_reset = true
	if not flashes_off or not flashes_on or not saw_reset:
		failures.append("Reduced flashes is not an off/on switch")
	menu.show_settings("OFF", "100%", "0%", true, false)
	await process_frame
	for button in _buttons_under(menu):
		var action := String(button.get_meta(&"menu_action", &""))
		if action == "settings_flashes_on" and not button.text.begins_with("●"):
			failures.append("Reduced flashes on-state is unmarked")
		if action == "settings_flashes_off" and button.text.begins_with("●"):
			failures.append("Reduced flashes off-state stayed marked")
	menu.show_settings("75%", "50%", "100%", false, false, true)
	await process_frame
	var own_music_marked := false
	for button in _buttons_under(menu):
		var action := String(button.get_meta(&"menu_action", &""))
		if action == "own_music_on":
			own_music_marked = button.text.begins_with("●")
		elif action == "music_down" or action == "music_up":
			failures.append("Soundtrack volume still shows while playing your own music")
	if not own_music_marked:
		failures.append("Play my own music on-state is unmarked")
	menu.show_reset_confirmation()
	await process_frame
	var keep := _find_button(menu, "KEEP PROGRESS")
	var wipe := _find_button(menu, "RESET PROGRESS")
	if keep == null or wipe == null:
		failures.append("Progress reset does not ask for confirmation")
	elif String(keep.get_meta(&"menu_action")) != "reset_cancel" or String(wipe.get_meta(&"menu_action")) != "reset_confirm":
		failures.append("Progress reset confirmation actions are wired wrong")
	var levels = load("res://Scripts/Core/game_settings.gd").new()
	if levels.volume_label(-80.0) != "OFF" or levels.volume_label(-20.0) != "25%" or levels.volume_label(-14.0) != "50%" or levels.volume_label(-8.0) != "75%" or levels.volume_label(-2.0) != "100%":
		failures.append("Volume steps are not shown as off through 100 percent")
	levels.cleared_missions = PackedStringArray(["first_light", "open_arc"])
	levels.pending_mission_id = "the_maw"
	levels.clear_mission_progress()
	if not levels.cleared_missions.is_empty() or levels.pending_mission_id != "":
		failures.append("Mission progress did not clear")
	levels.free()
	menu.queue_free()
	await process_frame

func _buttons_under(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button:
		found.append(node as Button)
	for child in node.get_children():
		found.append_array(_buttons_under(child))
	return found

func _button_actions(node: Node) -> Array[String]:
	var actions: Array[String] = []
	for button in _buttons_under(node):
		actions.append(String(button.get_meta(&"menu_action", &"")))
	return actions

func _find_button(node: Node, text_fragment: String) -> Button:
	if node is Button and text_fragment in node.text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text_fragment)
		if found:
			return found
	return null

func _validate_pink_dodge() -> void:
	var pink_scene := load("res://Scenes/Phantoms/pink_phantom.tscn") as PackedScene
	var pink := pink_scene.instantiate()
	root.add_child(pink)
	await process_frame
	pink._telegraph_remaining = 0.0
	pink._locked_target = pink.global_position + Vector3.FORWARD
	pink._previous_target_distance = 0.5
	pink.global_position = pink._locked_target + Vector3.BACK
	pink._physics_process(0.01)
	if not pink._terminal:
		failures.append("Pink dodge pass detection failed")
	pink.queue_free()
	var missed := pink_scene.instantiate()
	root.add_child(missed)
	await process_frame
	var aside := Node3D.new()
	root.add_child(aside)
	aside.global_position = Vector3(1.1, 1.6, 0.0)
	missed._player_camera = aside
	missed._locked_target = Vector3(0.0, 1.6, 0.0)
	missed.global_position = Vector3(0.0, 1.6, 1.2)
	missed._telegraph_remaining = 0.0
	missed._previous_target_distance = 1.2
	var dodged_hurt := [false]
	missed.player_contact.connect(func(_amount: float) -> void:
		dodged_hurt[0] = true
	)
	missed.set_physics_process(false)
	for _step in 120:
		if missed._terminal:
			break
		await _physics_step(missed)
	if dodged_hurt[0] or not missed._terminal:
		failures.append("Pink dodge still damaged the player")
	missed.queue_free()
	aside.queue_free()
	var caught := pink_scene.instantiate()
	root.add_child(caught)
	await process_frame
	var inline := Node3D.new()
	root.add_child(inline)
	inline.global_position = Vector3(0.0, 1.6, 0.0)
	caught._player_camera = inline
	caught._locked_target = inline.global_position
	caught.global_position = Vector3(0.0, 1.6, 1.2)
	caught._telegraph_remaining = 0.0
	caught._previous_target_distance = 1.2
	var lane_hurt := [false]
	caught.player_contact.connect(func(_amount: float) -> void:
		lane_hurt[0] = true
	)
	caught.set_physics_process(false)
	for _step in 120:
		if caught._terminal:
			break
		await _physics_step(caught)
	if not lane_hurt[0]:
		failures.append("Pink lane hit did not damage the player")
	caught.queue_free()
	inline.queue_free()
	await process_frame

func _validate_attack_window() -> void:
	var yellow_scene := load("res://Scenes/Phantoms/yellow_phantom.tscn") as PackedScene
	var yellow := yellow_scene.instantiate()
	root.add_child(yellow)
	await process_frame
	var sweet_position: Vector3 = yellow.get_node("SweetSpotVisual").global_position
	var early: Dictionary = yellow.receive_strike({"hand_id": &"left", "position": sweet_position, "direction": Vector3.FORWARD, "speed": 4.0})
	if early.get("valid", true) or early.get("resolution_kind", &"") != &"not_open" or yellow._terminal:
		failures.append("Yellow accepts a strike before the attack window opens")
	yellow._phase = Phantom.Phase.COMMIT
	var hit: Dictionary = yellow.receive_strike({"hand_id": &"left", "position": sweet_position, "direction": Vector3.FORWARD, "speed": 4.0})
	if not hit.get("valid", false) or not hit.get("sweet_spot", false) or not hit.get("on_beat", false):
		failures.append("Yellow commit window did not score an on-beat sweet spot")
	yellow.queue_free()
	await _validate_arc_motion(yellow_scene)
	await _validate_turn_back(yellow_scene)
	await _validate_green_arrival()
	await _validate_possession(yellow_scene)

## A player who steps out of the path is still the target. A phantom that flies past the head
## must come back for it at once, never float at the point where the head used to be.
func _validate_turn_back(yellow_scene: PackedScene) -> void:
	var yellow := yellow_scene.instantiate()
	root.add_child(yellow)
	await process_frame
	var head := Node3D.new()
	root.add_child(head)
	head.global_position = Vector3(0.0, 1.6, 0.0)
	yellow.global_position = Vector3(0.0, 1.4, 3.0)
	yellow._player_camera = head
	yellow.set_physics_process(false)
	yellow._build_curve()
	# Already past where the head was, at full lunge speed, the way a dodged phantom is.
	yellow.global_position = Vector3(0.0, 1.38, 0.1)
	yellow.velocity = Vector3(0.0, 0.0, -yellow.pattern_commit_speed)
	yellow._curve_progress = 1.0
	# The player stepped aside.
	head.global_position = Vector3(0.7, 1.6, 0.0)
	var closest := INF
	var idle_frames := 0
	var floated := false
	var frames_to_reach := -1
	for step in 240:
		if yellow._terminal:
			break
		await _physics_step(yellow)
		var distance: float = yellow.global_position.distance_to(head.global_position)
		closest = minf(closest, distance)
		if distance <= 0.34:
			frames_to_reach = step
			break
		if distance < 2.5 and yellow.velocity.length() < 0.35:
			idle_frames += 1
			if idle_frames >= 15:
				floated = true
				break
		else:
			idle_frames = 0
	if floated:
		failures.append("Dodged phantom floated beside the player")
	elif not yellow._terminal and closest > 0.34:
		failures.append("Dodged phantom did not come back for the head (closest %.2f m)" % closest)
	elif frames_to_reach > 120:
		failures.append("Dodged phantom took %d frames to turn back" % frames_to_reach)
	yellow.queue_free()
	head.queue_free()
	await process_frame

func _validate_arc_motion(yellow_scene: PackedScene) -> void:
	var yellow := yellow_scene.instantiate()
	root.add_child(yellow)
	await process_frame
	var head := Node3D.new()
	root.add_child(head)
	head.global_position = Vector3(0.0, 1.6, 0.0)
	yellow.global_position = Vector3(0.0, 1.3, 8.0)
	yellow._player_camera = head
	var start: Vector3 = yellow.global_position
	yellow.set_physics_process(false)
	# Judged while it is under way: a short arc can reach the head and possess inside two seconds.
	var under_way := false
	for _step in 120:
		await _physics_step(yellow)
		if yellow.global_position.distance_to(start) >= 1.0 and yellow.velocity.length() >= 0.3:
			under_way = true
			break
	if not under_way:
		failures.append("Yellow arc stalled during approach")
	if yellow.get_node_or_null("ApproachColumn") != null:
		failures.append("Approach column is still attached")
	yellow.queue_free()
	head.queue_free()
	await process_frame

func _validate_green_arrival() -> void:
	var green_scene := load("res://Scenes/Phantoms/green_phantom.tscn") as PackedScene
	var green := green_scene.instantiate()
	root.add_child(green)
	await process_frame
	var head := Node3D.new()
	root.add_child(head)
	head.global_position = Vector3(0.0, 1.6, 0.0)
	var green_body: Node3D = green
	green_body.global_position = Vector3(0.0, 1.2, 5.0)
	green._player_camera = head
	var stalled := false
	var slow_frames := 0
	var closest := INF
	green.set_physics_process(false)
	for _step in 400:
		if green._terminal:
			break
		var before: float = green_body.global_position.distance_to(head.global_position)
		await _physics_step(green)
		var after: float = green_body.global_position.distance_to(head.global_position)
		closest = minf(closest, after)
		var still_closing := after < before - 0.001 and before < 2.0
		if still_closing and green.velocity.length() < 0.35:
			slow_frames += 1
			if slow_frames >= 10:
				stalled = true
				break
		else:
			slow_frames = 0
	if stalled:
		failures.append("Green phantom stopped while closing")
	if not green._terminal and closest > 0.34:
		failures.append("Green phantom flew past the player")
	green.queue_free()
	head.queue_free()
	await process_frame

func _validate_results_menu() -> void:
	var player := Node3D.new()
	player.add_to_group("Player")
	var camera := Node3D.new()
	camera.name = "XRCamera3D"
	player.add_child(camera)
	root.add_child(player)
	camera.global_position = Vector3(0.0, 1.6, 0.0)
	var presenter := VRMenuPresenter.new()
	root.add_child(presenter)
	for _frame in 3:
		await process_frame
	presenter.show_results(
		&"victory",
		12840,
		"Chen: It knows your resonance now. This was the opening move. Not the end of the war.",
		"WIDEN THE RING"
	)
	for _frame in 4:
		await process_frame
	var panel_rect := Rect2(Vector2.ZERO, Vector2(1280, 780))
	for label in ["NEXT OPERATION", "RETRY MISSION", "MAIN MENU"]:
		var button := _find_button(presenter, label)
		if button == null:
			failures.append("Results action missing: %s" % label)
			continue
		var rect := button.get_global_rect()
		if rect.size.y < 20.0 or not panel_rect.encloses(rect):
			failures.append("Results button %s sits outside the panel %s" % [label, rect])
		elif rect.position.y + rect.size.y > 680.0:
			failures.append("Results button %s is pinned to the bottom edge %s" % [label, rect])
	var retry := _find_button(presenter, "RETRY MISSION")
	var body := presenter.get_node_or_null("MenuScreen/StaticBody3D")
	if retry == null or body == null or not body.has_method("global_to_viewport"):
		failures.append("Results pointer target is missing")
	else:
		var screen_size: Vector2 = body.get("screen_size")
		var viewport_size: Vector2 = body.get("viewport_size")
		var center: Vector2 = retry.get_global_rect().get_center()
		var local := Vector3(
			(center.x / viewport_size.x - 0.5) * screen_size.x,
			(0.5 - center.y / viewport_size.y) * screen_size.y,
			0.0
		)
		var shape := body.get_node("CollisionShape3D") as Node3D
		var world_point: Vector3 = shape.global_transform * local
		var mapped: Vector2 = body.call("global_to_viewport", world_point)
		if mapped.distance_to(center) > 24.0:
			failures.append("Results pointer map missed retry by %s px" % mapped.distance_to(center))
		var activated := [false]
		presenter.action_requested.connect(func(action: StringName) -> void:
			activated[0] = action == &"retry"
		)
		if not presenter.activate_at_viewport_point(mapped) or not activated[0]:
			failures.append("Pointing at retry did not activate it")
		activated[0] = false
		var aim_origin: Vector3 = world_point + shape.global_transform.basis.z * 1.2
		var aim_direction: Vector3 = world_point - aim_origin
		if not presenter.activate_from_aim(aim_origin, aim_direction) or not activated[0]:
			failures.append("Aiming at retry did not activate it")
		var screen_shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if screen_shape == null:
			failures.append("Results screen has no collision shape")
		else:
			screen_shape.disabled = true
			presenter.ensure_screen_collision()
			await process_frame
			if screen_shape.disabled:
				failures.append("Results screen collider stayed disabled")
	var profile = load("res://Scripts/Core/game_settings.gd").new()
	profile.cleared_missions = PackedStringArray(["first_light"])
	profile.best_times = {"first_light": 342.0}
	var entries := MissionCatalog.operation_entries(profile)
	profile.free()
	presenter.show_operations(entries)
	for _frame in 4:
		await process_frame
	for entry in entries:
		var card := _find_button(presenter, "%s  %s" % [entry.get("codename", ""), entry.get("title", "")])
		var expected := MissionCatalog.expected_minutes_text(entry)
		if card == null or expected == "" or expected not in card.text:
			failures.append("Operations card for %s does not show its expected time" % entry.get("id", ""))
		elif entry.get("id", "") == "first_light" and "%s  •  YOUR BEST 5:42" % expected not in card.text:
			failures.append("Operations card does not show the best time beside the range: %s" % card.text)
		elif entry.get("id", "") != "first_light" and "YOUR BEST" in card.text:
			failures.append("Operations card shows a best time it does not have: %s" % card.text)
	var operation_buttons := 0
	var operation_panel := Rect2(Vector2.ZERO, Vector2(1280, 780))
	var stack := presenter.get_node("MenuScreen/Viewport").get_child(0)
	for button in _buttons_under(stack):
		operation_buttons += 1
		var op_rect := button.get_global_rect()
		if op_rect.size.y < 20.0 or not operation_panel.encloses(op_rect):
			failures.append("Operations button sits outside the panel %s" % op_rect)
	if operation_buttons < 7:
		failures.append("Operations list is missing a contract or the back button")
	var operations_footer := _find_label(stack, "LOCKED CONTRACTS OPEN WHEN YOU SEAL THE ONE BEFORE THEM")
	if operations_footer == null or operations_footer.get_global_rect().end.y > 750.0:
		failures.append("Operations footer runs off the bottom of the panel")
	presenter.show_main_menu(MissionCatalog.deploy_detail(null))
	for _frame in 4:
		await process_frame
	var main_footer := _find_label(stack, "POINT AT A BUTTON  •  PULL TRIGGER TO SELECT  •  HOLD META BUTTON TO RECENTER")
	if main_footer == null or main_footer.get_global_rect().end.y > 750.0:
		failures.append("Main menu footer runs off the bottom of the panel")
	presenter.queue_free()
	player.queue_free()
	await process_frame

func _validate_possession(yellow_scene: PackedScene) -> void:
	var yellow := yellow_scene.instantiate()
	root.add_child(yellow)
	await process_frame
	var head := Node3D.new()
	root.add_child(head)
	head.global_position = yellow.global_position
	yellow._player_camera = head
	var contacted := [false]
	yellow.player_contact.connect(func(amount: float) -> void:
		contacted[0] = amount >= 20.0
	)
	var possessed: bool = yellow._try_possess_between(yellow.global_position, yellow.global_position)
	if not possessed or not yellow._terminal or not contacted[0]:
		failures.append("Phantom overlap did not possess the player")
	var graze := yellow_scene.instantiate()
	root.add_child(graze)
	await process_frame
	var far_head := Node3D.new()
	root.add_child(far_head)
	far_head.global_position = graze.global_position + Vector3(0.62, 0.0, 0.0)
	graze._player_camera = far_head
	if graze._try_possess_between(graze.global_position, graze.global_position) or graze._terminal:
		failures.append("Phantom edge graze possessed the player")
	graze.global_position = far_head.global_position + Vector3(0.0, -0.2, 6.0)
	var bows: Dictionary = {}
	for _i in 8:
		graze._build_curve()
		var drop: float = far_head.global_position.y - graze._locked_target.y
		var flat := Vector2(
			graze._locked_target.x - far_head.global_position.x,
			graze._locked_target.z - far_head.global_position.z
		)
		if drop < 0.14 or drop > 0.34 or flat.length() > 0.05:
			failures.append("Punchable phantom is not aimed below the head")
			break
		bows[snappedf(graze._curve_control.x, 0.15)] = true
		var nearest := INF
		for step in 48:
			var point: Vector3 = graze._bezier(float(step) / 47.0)
			nearest = minf(nearest, point.distance_to(graze._locked_target))
		if nearest > 0.2:
			failures.append("Approach arc misses the player")
			break
	if bows.size() < 2:
		failures.append("Approach arc did not vary")
	graze.queue_free()
	far_head.queue_free()
	yellow.queue_free()
	head.queue_free()
	await process_frame

func _validate_mission_catalog() -> void:
	if MissionCatalog.all_missions().size() != 6:
		failures.append("Mission catalog does not contain six operations")
	for mission in MissionCatalog.all_missions():
		var minutes: Variant = mission.get("expected_minutes")
		if not minutes is Array or minutes.size() != 2 or typeof(minutes[0]) != TYPE_INT or typeof(minutes[1]) != TYPE_INT:
			failures.append("%s has no expected_minutes pair" % mission.get("id", ""))
		elif minutes[0] < 1 or minutes[1] < minutes[0] or minutes[1] > 30:
			failures.append("%s has an invalid expected_minutes range %s" % [mission.get("id", ""), minutes])
		var rift_count: int = mission.get("rifts", []).size()
		if mission.get("pressure_labels", []).size() != rift_count or mission.get("open_barks", []).size() != rift_count or mission.get("seal_lines", []).size() != rift_count - 1:
			failures.append("%s labels, barks, or seal lines do not match its %d rifts" % [mission.get("id", ""), rift_count])
	if MissionCatalog.expected_minutes_text({"expected_minutes": [6, 8]}) != "6 TO 8 MIN":
		failures.append("Expected time range does not read as 6 TO 8 MIN")
	if MissionCatalog.deploy_detail(null) != "NEXT • OP-01 FIRST LIGHT • %s • STANDARD" % MissionCatalog.expected_minutes_text(MissionCatalog.get_mission("first_light")):
		failures.append("Deploy button does not show the next mission's expected time and tier: %s" % MissionCatalog.deploy_detail(null))
	var none := PackedStringArray()
	if not MissionCatalog.is_unlocked_with_clears("first_light", none):
		failures.append("First Light should be available immediately")
	if MissionCatalog.is_unlocked_with_clears("widen_the_ring", none):
		failures.append("Widen the Ring unlocked before First Light")
	var cleared := PackedStringArray(["first_light"])
	if not MissionCatalog.is_unlocked_with_clears("widen_the_ring", cleared):
		failures.append("Widen the Ring stayed locked after First Light")
	if MissionCatalog.is_unlocked_with_clears("chens_gambit", cleared):
		failures.append("Chen's Gambit unlocked before the civic ring")
	var through_ring := PackedStringArray(["first_light", "widen_the_ring"])
	if MissionCatalog.is_unlocked_with_clears("double_breach", through_ring):
		failures.append("Double Breach unlocked before Chen's Gambit")
	var through_gambit := PackedStringArray(["first_light", "widen_the_ring", "chens_gambit"])
	if not MissionCatalog.is_unlocked_with_clears("double_breach", through_gambit):
		failures.append("Double Breach stayed locked after Chen's Gambit")
	var paired := MissionCatalog.get_mission("double_breach")
	if int(paired.get("max_concurrent", 1)) != 2 or not bool(paired.get("cluster_rifts", false)):
		failures.append("Double Breach does not open a paired rift")
	var paired_waves: Array = paired.get("rifts", [])
	if paired_waves.size() != 16:
		failures.append("Double Breach is missing its sixteen rifts")
	else:
		_expect_staggered_pairs(paired_waves, "Double Breach")
	var ring := MissionCatalog.get_mission("widen_the_ring")
	if ring.get("rifts", []).size() != 12:
		failures.append("Widen the Ring does not run twelve rifts")
	var gambit := MissionCatalog.get_mission("chens_gambit")
	if gambit.get("rifts", []).size() != 12:
		failures.append("Chen's Gambit does not run twelve rifts")
	if MissionCatalog.is_unlocked_with_clears("open_arc", through_gambit):
		failures.append("Open Arc unlocked before Double Breach")
	var through_breach := PackedStringArray(["first_light", "widen_the_ring", "chens_gambit", "double_breach"])
	if not MissionCatalog.is_unlocked_with_clears("open_arc", through_breach):
		failures.append("Open Arc stayed locked after Double Breach")
	var fan := MissionCatalog.get_mission("open_arc")
	if int(fan.get("max_concurrent", 1)) != 2 or bool(fan.get("cluster_rifts", false)) or not bool(fan.get("arc_rifts", false)):
		failures.append("Open Arc is not a wide paired rift")
	if fan.get("rifts", []) != paired.get("rifts", []):
		failures.append("Open Arc does not use Double Breach's rift waves")
	if MissionCatalog.is_unlocked_with_clears("the_maw", through_breach):
		failures.append("The Maw unlocked before Open Arc")
	var through_arc := PackedStringArray(["first_light", "widen_the_ring", "chens_gambit", "double_breach", "open_arc"])
	if not MissionCatalog.is_unlocked_with_clears("the_maw", through_arc):
		failures.append("The Maw stayed locked after Open Arc")
	var maw := MissionCatalog.get_mission("the_maw")
	var maw_waves: Array = maw.get("rifts", [])
	if maw_waves.size() != 1 or int(maw.get("max_concurrent", 1)) != 1:
		failures.append("The Maw is not a single rift")
	elif int(maw_waves[0].get("health", 0)) != 1600 or not is_equal_approx(float(maw_waves[0].get("interval", 0.0)), 0.875) or int(maw_waves[0].get("max_live", 0)) != 8 or not is_equal_approx(float(maw_waves[0].get("scale", 1.0)), 2.0):
		failures.append("The Maw is not a doubled mouth pouring a steady flood")
	await _validate_maw_rift()
	var first := MissionCatalog.get_mission("first_light")
	if int(first.get("max_concurrent", 1)) != 1 or bool(first.get("cluster_rifts", false)) or first.get("rifts", []).size() != 4:
		failures.append("First Light opened more than one rift")
	for mission in MissionCatalog.all_missions():
		if mission.has("duration") or mission.has("timeout_line"):
			failures.append("%s still carries a countdown window" % mission.get("id", "?"))
	await _validate_paired_rift_placement()
	await _validate_arc_rift_placement()
	for variant_id in ["yellow", "blue", "green", "pink"]:
		if load(MissionCatalog.scene_path(variant_id)) == null:
			failures.append("Mission pool failed to load %s" % variant_id)

## The four difficulties: Standard is the catalog exactly; every tier's multipliers reach a
## spawned phantom, its rift, and the life force; Full Resonance adds no sweeps to ordinary rifts
## (bosses carry the movements); the choice and per-tier records persist; only Full Resonance
## reaches the boss turn.
func _validate_difficulty_tiers() -> void:
	# Standard reproduces today's numbers.
	for mission in MissionCatalog.all_missions() + MissionCatalog.debug_missions():
		var standard := DifficultyTier.apply_mission(mission, DifficultyTier.STANDARD)
		if standard.get("rifts", []) != mission.get("rifts", []) or standard.has("boss") or standard.get("expected_minutes") != mission.get("expected_minutes"):
			failures.append("Standard changed %s" % mission.get("id", ""))
	var first_wave: Dictionary = DifficultyTier.apply_mission(MissionCatalog.get_mission("first_light"), DifficultyTier.STANDARD)["rifts"][0]
	if int(first_wave["health"]) != 70 or float(first_wave["interval"]) != 4.2 or float(first_wave["speed_scale"]) != 0.85 or float(first_wave["telegraph_scale"]) != 1.28 or first_wave.has("contact_scale") or first_wave["pool"] != ["yellow", "yellow", "blue"]:
		failures.append("Standard First Light is not 70 health, 4.2 s, 0.85 speed, 1.28 tells: %s" % first_wave)
	var maw_standard := DifficultyTier.apply_mission(MissionCatalog.get_mission("the_maw"), DifficultyTier.STANDARD)
	if maw_standard.has("tier_boss") or not maw_standard.get("glimpse", false) or int(maw_standard["rifts"][0]["health"]) != 1600:
		failures.append("The Standard Maw is not the 1600-health tutorial Maw with its glimpse")
	if DifficultyTier.apply_mission(maw_standard, DifficultyTier.FULL_RESONANCE) != maw_standard:
		failures.append("A tiered mission took a second tier")
	# Below Full Resonance a sweep never asks for more than a duck; at it, always a squat.
	var deep := {"health": 100, "interval": 3.0, "max_live": 4, "speed_scale": 1.0, "telegraph_scale": 1.0, "pool": ["yellow", "sweep"], "squat_depth": 0.2}
	for tier in [DifficultyTier.ASSIST, DifficultyTier.STANDARD, DifficultyTier.OPERATOR]:
		if not is_equal_approx(float(DifficultyTier.apply_wave(deep, tier)["squat_depth"]), DifficultyTier.DUCK_DEPTH):
			failures.append("%s let a sweep ask for more than a duck" % tier)
		if DifficultyTier.allows_bosses(tier) or DifficultyTier.asks_for_movement(tier):
			failures.append("%s asks for movement or allows a boss" % tier)
	if not DifficultyTier.allows_bosses(DifficultyTier.FULL_RESONANCE) or not DifficultyTier.info(DifficultyTier.FULL_RESONANCE).get("jumps", false):
		failures.append("Full Resonance does not ask for jumps or allow bosses")
	var base_wave := {"health": 100, "interval": 3.0, "max_live": 4, "speed_scale": 1.0, "telegraph_scale": 1.0, "pool": ["yellow"]}
	var yellow_scene := load(MissionCatalog.scene_path("yellow")) as PackedScene
	var reference := yellow_scene.instantiate() as Phantom
	root.add_child(reference)
	await process_frame
	var base_speed := reference.move_speed
	var base_tell := reference.pattern_telegraph_seconds
	var base_contact := reference.contact_damage
	reference.queue_free()
	# Each tier on a real round: the rift, the phantom it sends, and a contact reaching life force.
	for tier in DifficultyTier.ORDER:
		var info := DifficultyTier.info(tier)
		var container := Node3D.new()
		container.add_to_group("PhantomContainer")
		root.add_child(container)
		var director := RiftDirector.new()
		director.rift_manager_scene = load("res://Scenes/Rifts/rift_manager.tscn")
		root.add_child(director)
		var life := LifeForceManager.new()
		root.add_child(life)
		var round_controller := RoundController.new()
		round_controller.countdown_seconds = 0
		root.add_child(round_controller)
		await process_frame
		await process_frame
		round_controller.set_process(false)
		round_controller.begin_round({"id": "tier_check", "rifts": [base_wave]}, tier)
		round_controller._process(0.0)
		var rift: RiftManager = director.rift_instances[0] if not director.rift_instances.is_empty() else null
		if round_controller.current_tier() != tier or rift == null:
			failures.append("%s did not reach the round" % tier)
		else:
			var expected_health := maxi(int(round(100.0 * float(info["health"]))), 1)
			if rift.maximum_health != expected_health or not is_equal_approx(rift.spawn_interval, 3.0 * float(info["interval"])):
				failures.append("%s rift has %d health every %.2f s, expected %d every %.2f s" % [tier, rift.maximum_health, rift.spawn_interval, expected_health, 3.0 * float(info["interval"])])
			var phantom: Phantom = null
			for _try in 24:
				var spawned := rift._spawn_phantom()
				if spawned is Phantom:
					phantom = spawned
					break
			if phantom == null:
				failures.append("%s rift sent no phantom" % tier)
			else:
				var expected_tell := maxf(base_tell * float(info["telegraph"]), 0.35)
				if not is_equal_approx(phantom.move_speed, base_speed * float(info["speed"])) or not is_equal_approx(phantom.pattern_telegraph_seconds, expected_tell) or not is_equal_approx(phantom.contact_damage, base_contact * float(info["contact"])):
					failures.append("%s phantom moves %.2f with %.2f s tells and %.1f contact" % [tier, phantom.move_speed, phantom.pattern_telegraph_seconds, phantom.contact_damage])
				var before := life.current_life_force
				phantom.player_contact.emit(phantom.contact_damage)
				if not is_equal_approx(before - life.current_life_force, base_contact * float(info["contact"])):
					failures.append("%s contact did not reach life force at its scale: %.1f" % [tier, before - life.current_life_force])
		round_controller.abandon_round()
		for node in [round_controller, life, director, container]:
			node.queue_free()
		await process_frame
	# Full Resonance leaves ordinary rifts' pools alone: bosses carry the movements. A wave that
	# already has a sweep (the Sweep Drill) asks for a real squat there.
	for mission in MissionCatalog.all_missions():
		for wave in DifficultyTier.apply_mission(mission, DifficultyTier.FULL_RESONANCE).get("rifts", []):
			if "sweep" in wave.get("pool", []) or wave.has("squat_depth"):
				failures.append("Full Resonance put a sweep in %s" % mission.get("id", ""))
				break
	var drill_wave := {"health": 100, "interval": 3.0, "max_live": 4, "speed_scale": 1.0, "telegraph_scale": 1.0, "pool": ["yellow", "sweep"], "squat_depth": DifficultyTier.DUCK_DEPTH}
	var resonant := DifficultyTier.apply_wave(drill_wave, DifficultyTier.FULL_RESONANCE)
	if resonant["pool"] != ["yellow", "sweep"] or not is_equal_approx(float(resonant["squat_depth"]), DifficultyTier.SQUAT_DEPTH):
		failures.append("Full Resonance did not deepen an existing sweep to a squat: %s" % resonant)
	if base_wave["pool"] != ["yellow"] or drill_wave["pool"] != ["yellow", "sweep"]:
		failures.append("Applying a tier changed the catalog's own wave")
	var sweep_box := Node3D.new()
	sweep_box.add_to_group("PhantomContainer")
	root.add_child(sweep_box)
	var sweep_rift := RiftManager.new()
	sweep_rift.phantom_scenes = [yellow_scene]
	root.add_child(sweep_rift)
	await process_frame
	sweep_rift.configure_wave(resonant)
	var sweep: ResonanceSweep = null
	for _i in 24:
		var spawned := sweep_rift._spawn_phantom()
		if spawned is ResonanceSweep:
			sweep = spawned
			break
	if sweep == null or not is_equal_approx(sweep.squat_depth, DifficultyTier.SQUAT_DEPTH):
		failures.append("A Full Resonance sweep did not ask for a squat")
	for _i in 12:
		if sweep_rift.spawn_escort() is ResonanceSweep:
			failures.append("A boss escort came out as a sweep")
			break
	sweep_rift.force_cleanup()
	sweep_box.queue_free()
	await process_frame
	# The choice persists, defaults to Standard, survives Reset Progress, and records are per tier.
	var path := "user://validation_tier_settings.cfg"
	var levels = load("res://Scripts/Core/game_settings.gd").new()
	levels.settings_path = path
	if levels.difficulty_tier != DifficultyTier.STANDARD or MissionCatalog.tier_from(levels) != DifficultyTier.STANDARD:
		failures.append("A fresh profile does not start at Standard")
	levels.set_difficulty_tier(DifficultyTier.FULL_RESONANCE)
	levels.set_difficulty_tier("nightmare")
	levels.record_time("first_light", 200.0, DifficultyTier.FULL_RESONANCE)
	levels.record_score("first_light", 9000, DifficultyTier.FULL_RESONANCE)
	levels.record_time("first_light", 150.0)
	var reloaded = load("res://Scripts/Core/game_settings.gd").new()
	reloaded.settings_path = path
	reloaded.load_settings()
	if reloaded.difficulty_tier != DifficultyTier.FULL_RESONANCE:
		failures.append("The difficulty choice did not persist: %s" % reloaded.difficulty_tier)
	if not is_equal_approx(reloaded.best_time("first_light", DifficultyTier.FULL_RESONANCE), 200.0) or not is_equal_approx(reloaded.best_time("first_light"), 150.0) or reloaded.best_score("first_light", DifficultyTier.FULL_RESONANCE) != 9000 or reloaded.best_score("first_light") != 0:
		failures.append("Best scores and times are not kept per tier")
	if reloaded.best_times.get("first_light", 0.0) != 150.0:
		failures.append("Standard records moved off the bare mission id")
	var entries := MissionCatalog.operation_entries(reloaded)
	if not is_equal_approx(float(entries[0].get("best_seconds", 0.0)), 200.0) or entries[0].get("tier", "") != DifficultyTier.FULL_RESONANCE:
		failures.append("Operations does not show the chosen tier's best time")
	if not MissionCatalog.deploy_detail(reloaded).ends_with("• FULL RESONANCE"):
		failures.append("Deploy does not show the chosen tier: %s" % MissionCatalog.deploy_detail(reloaded))
	var maw_entry: Dictionary = entries[entries.size() - 1]
	if maw_entry.get("expected_minutes", []) != [4, 7]:
		failures.append("The Full Resonance Maw card does not cover the boss: %s" % [maw_entry.get("expected_minutes", [])])
	reloaded.reset_mission_progress()
	if reloaded.difficulty_tier != DifficultyTier.FULL_RESONANCE or reloaded.best_time("first_light", DifficultyTier.FULL_RESONANCE) != 0.0:
		failures.append("Reset Progress dropped the difficulty or kept a tier's record")
	levels.free()
	reloaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# The Operations screen offers all four, marks the choice, and still fits; results name the tier.
	var menu := (load("res://Scenes/UI/vr_menu_panel.tscn") as PackedScene).instantiate() as VRMenuPanel
	root.add_child(menu)
	await process_frame
	menu.show_operations(MissionCatalog.operation_entries(null), DifficultyTier.OPERATOR)
	await process_frame
	await process_frame
	var tier_buttons := 0
	for button in _buttons_under(menu):
		var action := String(button.get_meta(&"menu_action", &""))
		if action.begins_with("tier_"):
			tier_buttons += 1
			var marked := button.text.begins_with("●")
			if marked != (action == "tier_operator"):
				failures.append("Operations marks the wrong difficulty: %s" % button.text)
			if not Rect2(Vector2.ZERO, Vector2(1280, 780)).encloses(button.get_global_rect()):
				failures.append("A difficulty button sits outside the panel")
	if tier_buttons != 4:
		failures.append("Operations offers %d difficulties, not four" % tier_buttons)
	var footer := _find_label(menu, "LOCKED CONTRACTS OPEN WHEN YOU SEAL THE ONE BEFORE THEM")
	if footer == null or footer.get_global_rect().end.y > 750.0:
		failures.append("The difficulty row pushed the Operations footer off the panel")
	if _find_label(menu, "OPERATOR  •  %s" % DifficultyTier.blurb(DifficultyTier.OPERATOR).to_upper()) == null:
		failures.append("Operations does not say what the chosen difficulty asks")
	menu.show_results(&"victory", 4000, "", "", 300.0, 0.0, DifficultyTier.label(DifficultyTier.FULL_RESONANCE))
	await process_frame
	if not _has_label(menu, "ALL RIFTS SEALED  •  FULL RESONANCE"):
		failures.append("Results do not name the difficulty")
	menu.queue_free()
	await process_frame
	await _validate_boss_only_at_full_resonance()

## The campaign Maw, forced to break, at every tier: only Full Resonance arms the rift and plays
## the turn at zero health; every other tier seals it, on the glimpse when it shows.
func _validate_boss_only_at_full_resonance() -> void:
	var saved := {}
	_borrow_settings(true, saved)
	var lines: Dictionary = (load("res://Assets/Audio/VO/chen/chen_lines.json") as JSON).data.get("events", {})
	if not lines.has(DifficultyTier.deploy_event(DifficultyTier.FULL_RESONANCE)) or not lines.has("sweep_bend"):
		failures.append("Chen has no Full Resonance deploy line or bend correction")
	for tier in DifficultyTier.ORDER:
		var container := Node3D.new()
		container.add_to_group("PhantomContainer")
		root.add_child(container)
		var director := RiftDirector.new()
		director.rift_manager_scene = load("res://Scenes/Rifts/rift_manager.tscn")
		root.add_child(director)
		var life := LifeForceManager.new()
		root.add_child(life)
		var round_controller := RoundController.new()
		round_controller.countdown_seconds = 0
		root.add_child(round_controller)
		await process_frame
		await process_frame
		round_controller.set_process(false)
		var boss := director.get_node("MawBoss") as MawBoss
		var countdown := [""]
		round_controller.countdown_started.connect(func(mission: Dictionary) -> void: countdown[0] = DifficultyTier.deploy_event(String(mission.get("tier", ""))))
		MawBoss.force_next_break = true
		round_controller.begin_round(MissionCatalog.get_mission("the_maw"), tier)
		round_controller._process(0.0)
		var resonant := tier == DifficultyTier.FULL_RESONANCE
		if (countdown[0] != "") != resonant:
			failures.append("%s countdown line is wrong: '%s'" % [tier, countdown[0]])
		var rift: RiftManager = director.rift_instances[0] if not director.rift_instances.is_empty() else null
		if rift == null:
			failures.append("%s Maw did not open" % tier)
		else:
			if boss.breaks != resonant or rift.hold_open != resonant:
				failures.append("%s Maw %s" % [tier, "did not break" if resonant else "let a boss through"])
			rift.apply_result({"rift_damage": 100000, "base_score": 10})
			var turned := boss.stage == MawBoss.Stage.TURN
			if turned != resonant:
				failures.append("%s Maw %s the boss turn" % [tier, "never reached" if resonant else "reached"])
		if MawBoss.force_next_break:
			failures.append("A forced break outlived the %s Maw" % tier)
		MawBoss.force_next_break = false
		round_controller.abandon_round()
		for node in [round_controller, life, director, container]:
			node.queue_free()
		await process_frame
	_borrow_settings(false, saved)

func _validate_paired_rift_placement() -> void:
	var director := RiftDirector.new()
	root.add_child(director)
	await process_frame
	var player := Node3D.new()
	root.add_child(player)
	var camera := Node3D.new()
	camera.name = "XRCamera3D"
	player.add_child(camera)
	camera.global_position = Vector3(0.0, 1.6, 0.0)
	camera.look_at(Vector3(0.0, 1.6, -5.0), Vector3.UP)
	director._player = player
	director._cluster_rifts = true
	var forward := Vector3(0.0, 0.0, -1.0)
	for _i in 6:
		director.rift_instances.clear()
		var first: Vector3 = director._find_valid_position()
		var to_first := first - player.global_position
		to_first.y = 0.0
		if to_first.length() < 9.0 or to_first.length() > 13.2 or to_first.normalized().dot(forward) < 0.7:
			failures.append("Paired rift did not open in front of the player")
			break
		var anchor := Node3D.new()
		root.add_child(anchor)
		anchor.global_position = first
		director.rift_instances.append(anchor)
		var second: Vector3 = director._find_valid_position()
		var gap := Vector2(second.x - first.x, second.z - first.z).length()
		var to_second := second - player.global_position
		to_second.y = 0.0
		if gap < 3.2 or gap > 5.0 or to_second.length_squared() < 0.001 or to_second.normalized().dot(forward) < 0.45:
			failures.append("Paired rift is not beside its partner")
		anchor.queue_free()
		if not failures.is_empty() and failures[failures.size() - 1] == "Paired rift is not beside its partner":
			break
	director.queue_free()
	player.queue_free()
	await process_frame

func _expect_staggered_pairs(waves: Array, label: String) -> void:
	for pair in range(0, waves.size(), 2):
		if pair + 1 >= waves.size():
			failures.append("%s has an unpaired rift" % label)
			return
		var gap := absf(float(waves[pair].get("interval", 0.0)) - float(waves[pair + 1].get("interval", 0.0)))
		if gap < 0.3:
			failures.append("%s spawns a pair on the same clock" % label)
			return

func _validate_arc_rift_placement() -> void:
	var director := RiftDirector.new()
	root.add_child(director)
	await process_frame
	var player := Node3D.new()
	root.add_child(player)
	var camera := Node3D.new()
	camera.name = "XRCamera3D"
	player.add_child(camera)
	camera.global_position = Vector3(0.0, 1.6, 0.0)
	camera.look_at(Vector3(0.0, 1.6, -5.0), Vector3.UP)
	director._player = player
	director._arc_rifts = true
	var forward := Vector3(0.0, 0.0, -1.0)
	for _i in 8:
		director.rift_instances.clear()
		var first: Vector3 = director._find_valid_position()
		var to_first := first - player.global_position
		to_first.y = 0.0
		if to_first.length() < 10.5 or to_first.length() > 14.5 or absf(forward.signed_angle_to(to_first.normalized(), Vector3.UP)) > deg_to_rad(50.0):
			failures.append("Open Arc rift did not open in front of the player")
			break
		var anchor := Node3D.new()
		root.add_child(anchor)
		anchor.global_position = first
		director.rift_instances.append(anchor)
		var second: Vector3 = director._find_valid_position()
		var to_second := second - player.global_position
		to_second.y = 0.0
		var between := to_first.normalized().angle_to(to_second.normalized())
		var second_turn := absf(forward.signed_angle_to(to_second.normalized(), Vector3.UP))
		var gap := Vector2(second.x - first.x, second.z - first.z).length()
		if to_second.length() < 10.5 or to_second.length() > 14.5 or second_turn > PI * 0.5 + 0.02:
			failures.append("Open Arc partner requires more than a 90 degree turn")
		elif between < deg_to_rad(38.0) or between > PI * 0.5 + 0.02 or gap < 6.0:
			failures.append("Open Arc pair is opposite or still clustered")
		anchor.queue_free()
		if not failures.is_empty() and (failures[failures.size() - 1] == "Open Arc partner requires more than a 90 degree turn" or failures[failures.size() - 1] == "Open Arc pair is opposite or still clustered"):
			break
	director.queue_free()
	player.queue_free()
	await process_frame

func _validate_rift_stragglers() -> void:
	var container := Node3D.new()
	container.add_to_group("PhantomContainer")
	root.add_child(container)
	var director := RiftDirector.new()
	director.rift_manager_scene = load("res://Scenes/Rifts/rift_manager.tscn")
	director.total_rifts = 1
	root.add_child(director)
	await process_frame
	var cleared := [false]
	var scored := [0]
	director.all_clear.connect(func() -> void: cleared[0] = true)
	director.phantom_resolved.connect(func(_result: Dictionary) -> void: scored[0] += 1)
	director.start_round()
	await process_frame
	var rift: RiftManager = director.rift_instances[0]
	var phantom: Phantom = rift._live_phantoms.values()[0]
	rift._close_rift()
	await process_frame
	if not is_instance_valid(phantom) or phantom._terminal:
		failures.append("Sealing a rift took its phantoms with it")
	elif cleared[0] or not director.has_stragglers():
		failures.append("Mission cleared with a phantom still out")
	else:
		phantom.resolve_without_strike({"base_score": 10, "rift_damage": 5})
		if scored[0] != 1:
			failures.append("Phantom from a sealed rift did not score")
		if not cleared[0]:
			failures.append("Clearing the last phantom did not end the mission")
	director.cleanup_round()
	director.queue_free()
	container.queue_free()
	await process_frame

func _validate_elapsed_timer() -> void:
	var container := Node3D.new()
	container.add_to_group("PhantomContainer")
	root.add_child(container)
	var director := RiftDirector.new()
	director.rift_manager_scene = load("res://Scenes/Rifts/rift_manager.tscn")
	director.total_rifts = 1
	root.add_child(director)
	var life := LifeForceManager.new()
	root.add_child(life)
	var round_controller := RoundController.new()
	round_controller.countdown_seconds = 0
	root.add_child(round_controller)
	await process_frame
	await process_frame
	round_controller.set_process(false)
	var ticks: Array[float] = []
	round_controller.time_changed.connect(func(seconds: float) -> void: ticks.append(seconds))
	var outcome := [&""]
	round_controller.round_finished.connect(func(result: StringName, _score: int) -> void: outcome[0] = result)
	var rift_row := [-1]
	round_controller.rift_progress_changed.connect(func(_closed: int, total: int) -> void: rift_row[0] = total)
	round_controller.begin_round(MissionCatalog.get_mission("first_light"))
	round_controller._process(0.0)
	if rift_row[0] != 4:
		failures.append("Going live did not lay out the mission's rift row: %d" % rift_row[0])
	for _step in 3:
		round_controller._process(1.0)
	if ticks.size() < 4 or not is_zero_approx(ticks[0]) or ticks[-1] <= ticks[0] or not is_equal_approx(round_controller.elapsed_seconds, 3.0):
		failures.append("Mission clock did not count up from zero: %s" % [ticks])
	round_controller.pause_round()
	round_controller._process(5.0)
	if not is_equal_approx(round_controller.elapsed_seconds, 3.0):
		failures.append("Mission clock kept running while paused")
	round_controller.resume_round()
	round_controller._process(3600.0)
	if outcome[0] != &"" or not round_controller.is_round_active():
		failures.append("Mission ended on the clock: %s" % outcome[0])
	round_controller._on_all_clear()
	if outcome[0] != &"victory":
		failures.append("Clearing the rifts did not end in victory")
	var levels = load("res://Scripts/Core/game_settings.gd").new()
	levels.settings_path = "user://validation_settings.cfg"
	levels.record_time("first_light", round_controller.elapsed_seconds)
	levels.record_time("first_light", round_controller.elapsed_seconds + 30.0)
	if not is_equal_approx(levels.best_time("first_light"), round_controller.elapsed_seconds):
		failures.append("Victory time did not record as the best time")
	levels.record_time("first_light", 200.0)
	if not is_equal_approx(levels.best_time("first_light"), 200.0):
		failures.append("A faster victory did not replace the best time")
	levels.clear_mission_progress()
	if levels.best_time("first_light") != 0.0:
		failures.append("Reset progress kept the best time")
	levels.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://validation_settings.cfg"))
	var menu := (load("res://Scenes/UI/vr_menu_panel.tscn") as PackedScene).instantiate() as VRMenuPanel
	root.add_child(menu)
	await process_frame
	menu.show_results(&"victory", 12840, "", "", 252.4, 280.0)
	await process_frame
	if not _has_label(menu, "SEALED IN 4:12  •  NEW BEST TIME"):
		failures.append("Victory results do not show the completion time")
	menu.queue_free()
	director.cleanup_round()
	for node in [round_controller, life, director, container]:
		node.queue_free()
	await process_frame

func _has_label(node: Node, text: String) -> bool:
	return _find_label(node, text) != null

func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child in node.get_children():
		var found := _find_label(child, text)
		if found:
			return found
	return null

func _validate_maw_rift() -> void:
	var rift := RiftManager.new()
	root.add_child(rift)
	await process_frame
	var wave: Dictionary = MissionCatalog.get_mission("the_maw").get("rifts", [])[0]
	rift.configure_wave(wave)
	var portal := rift.get_node_or_null("Portal") as MeshInstance3D
	var quad := portal.mesh as QuadMesh if portal else null
	if rift.maximum_health != 1600 or not is_equal_approx(rift.spawn_interval, 0.875) or rift.max_live_phantoms != 8:
		failures.append("The Maw rift did not take the doubled feed")
	elif quad == null or not quad.size.is_equal_approx(Vector2(8.0, 8.0)) or rift.spawn_radius < 4.9:
		failures.append("The Maw rift did not grow")
	rift.queue_free()
	await process_frame

func _validate_life_force() -> void:
	var life := LifeForceManager.new()
	root.add_child(life)
	life.apply_damage(25.0)
	if not is_equal_approx(life.current_life_force, 75.0):
		failures.append("Life force damage calculation failed")
	life.apply_damage(75.0)
	if not life.is_depleted():
		failures.append("Life force depletion failed")
	life.queue_free()

## Recorded-shape motions through the squat prototype: a squat counts; a duck, a waist bend,
## a side-step duck, and a hop do not; a shorter player squats against their own height.
func _validate_squat_detector() -> void:
	var squat := SquatDetector.new()
	var standing := Vector3(0.0, 1.62, 0.0)
	_drive_head(squat, standing, standing, 0.0, 0.0, 1.5)
	if squat.state != SquatDetector.State.STANDING or absf(squat.standing_height - 1.62) > 0.01:
		failures.append("Squat detector did not calibrate a still standing head")
	var bottom := Vector3(0.0, 1.62 * 0.72, 0.08)
	_drive_head(squat, standing, bottom, 0.0, -20.0, 0.6)
	_drive_head(squat, bottom, bottom, -20.0, -20.0, 0.3)
	_drive_head(squat, bottom, standing, -20.0, 0.0, 0.6)
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5)
	if squat.rep_count != 1:
		failures.append("Squat detector missed a clean squat")
	var duck := Vector3(0.0, 1.62 * 0.88, 0.0)
	_drive_head(squat, standing, duck, 0.0, 0.0, 0.3)
	_drive_head(squat, duck, standing, 0.0, 0.0, 0.3)
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5)
	var bend := Vector3(0.0, 1.2, 0.55)
	_drive_head(squat, standing, bend, 0.0, -70.0, 0.7)
	_drive_head(squat, bend, bend, -70.0, -70.0, 0.4)
	_drive_head(squat, bend, standing, -70.0, 0.0, 0.7)
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5)
	var side := Vector3(0.55, 1.62 * 0.76, 0.0)
	_drive_head(squat, standing, side, 0.0, 0.0, 0.4)
	_drive_head(squat, side, side, 0.0, 0.0, 0.3)
	_drive_head(squat, side, standing, 0.0, 0.0, 0.5)
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5)
	var hop := Vector3(0.0, 1.62 + 0.15, 0.0)
	_drive_head(squat, standing, hop, 0.0, 0.0, 0.15)
	_drive_head(squat, hop, standing, 0.0, 0.0, 0.15)
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5)
	if squat.rep_count != 1:
		failures.append("Squat detector counted a duck, a bend, a side-step, or a hop as a squat")
	# Shapes from the Quest 3 session on 2026-10-09 (Exercise_Mechanics_Exploration.md, test 2).
	# A waist bend to the floor: the head drops almost straight down with the eyes still level as it
	# crosses the squat line, and only then looks at the floor.
	var level := Vector3(0.0, 1.62 * 0.68, 0.12)
	var floor_reach := Vector3(0.0, 0.5, 0.2)
	_drive_head(squat, standing, level, 0.0, -5.0, 0.4)
	_drive_head(squat, level, floor_reach, -5.0, -82.0, 0.5)
	_drive_head(squat, floor_reach, floor_reach, -82.0, -82.0, 0.4)
	_drive_head(squat, floor_reach, standing, -82.0, 0.0, 0.7)
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5)
	# A side-step duck at the gentlest ratio seen (0.82 travel per metre dropped).
	var gentle_side := Vector3(0.41, 1.62 - 0.5, 0.0)
	_drive_head(squat, standing, gentle_side, 0.0, -3.0, 0.6)
	_drive_head(squat, gentle_side, gentle_side, -3.0, -3.0, 0.3)
	_drive_head(squat, gentle_side, standing, -3.0, 0.0, 0.6)
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5)
	if squat.rep_count != 1:
		failures.append("Squat detector counted a waist bend that looked down late, or a gentle side-step duck")
	# A deep squat as recorded: an 83 cm drop, 10 cm of travel, eyes slightly up.
	var deep := Vector3(0.0, 1.62 - 0.83, 0.1)
	_drive_head(squat, standing, deep, 0.0, 6.0, 0.55)
	_drive_head(squat, deep, standing, 6.0, 0.0, 0.55)
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5)
	if squat.rep_count != 2:
		failures.append("Squat detector missed a deep squat recorded on the headset")
	# A bow while looking up at the opponent (David's cheat, 2026-10-11): the torso pivots at the
	# hips, which shift back a little, and the eyes stay 10 degrees up. Pitch cannot see it; the
	# early arc can, since the head swings forward before it falls.
	var hip := 0.9
	var torso := 1.62 - hip
	var bow: Array[Vector3] = []
	for step in 11:
		var angle := deg_to_rad(80.0 * step / 10.0)
		bow.append(Vector3(0.0, hip + torso * cos(angle), (torso - 0.15) * sin(angle)))
	for i in range(bow.size() - 1):
		_drive_head(squat, bow[i], bow[i + 1], 10.0, 10.0, 0.06, Vector2(0.0, 1.0))
	_drive_head(squat, bow[bow.size() - 1], bow[bow.size() - 1], 10.0, 10.0, 0.3, Vector2(0.0, 1.0))
	_drive_head(squat, bow[bow.size() - 1], standing, 10.0, 0.0, 0.7, Vector2(0.0, 1.0))
	_drive_head(squat, standing, standing, 0.0, 0.0, 0.5, Vector2(0.0, 1.0))
	if squat.rep_count != 2 or squat.last_rejection != &"bowed":
		failures.append("Squat detector counted a bow made while looking up (%d reps, last %s)" % [squat.rep_count, squat.last_rejection])
	squat.free()
	var short := SquatDetector.new()
	var short_standing := Vector3(0.0, 1.30, 0.0)
	var short_bottom := Vector3(0.0, 1.30 * 0.70, 0.05)
	_drive_head(short, short_standing, short_standing, 0.0, 0.0, 1.5)
	_drive_head(short, short_standing, short_bottom, 0.0, -15.0, 0.5)
	_drive_head(short, short_bottom, short_bottom, -15.0, -15.0, 0.3)
	_drive_head(short, short_bottom, short_standing, -15.0, 0.0, 0.5)
	_drive_head(short, short_standing, short_standing, 0.0, 0.0, 0.3)
	if short.rep_count != 1:
		failures.append("Squat detector missed a shorter player's squat")
	short.free()

func _validate_resonance_sweep() -> void:
	var sweep_scene := load(MissionCatalog.scene_path("sweep")) as PackedScene
	if sweep_scene == null:
		failures.append("Mission pool failed to load sweep")
		return
	var drill := MissionCatalog.get_mission("sweep_drill")
	var in_campaign := false
	for mission in MissionCatalog.all_missions():
		in_campaign = in_campaign or mission.get("id", "") == "sweep_drill"
	if drill.is_empty() or in_campaign or not MissionCatalog.is_unlocked_with_clears("sweep_drill", PackedStringArray()):
		failures.append("Sweep drill is not a debug-only operation that starts from the command line")
	elif drill.get("rifts", [])[0].get("pool", []) != ["yellow", "blue", "sweep"]:
		failures.append("Sweep drill does not mix yellow, blue, and sweep")
	for entry in MissionCatalog.operation_entries(null):
		if entry.get("id", "") == "sweep_drill":
			failures.append("Sweep drill leaked into the Operations list")
	var player := Node3D.new()
	player.name = "SweepTestPlayer"
	player.add_to_group("Player")
	var camera := Node3D.new()
	camera.name = "XRCamera3D"
	player.add_child(camera)
	root.add_child(player)
	camera.position = Vector3(0.0, 1.62, 0.0)
	var ahead := Vector3(0.0, 1.5, -4.0)
	# A head below the line as the blade crosses resolves like the pink dodge.
	var low := _spawn_sweep(sweep_scene, ahead)
	if absf(low.sweep_height - 1.62 * 0.88) > 0.01:
		failures.append("Sweep did not sit at duck depth below the head at spawn: %.3f" % low.sweep_height)
	var low_log := _watch_sweep(low)
	camera.position = Vector3(0.0, 1.30, 0.0)
	# The tell rises as the rails light, and the whoosh rides the blade once it sets out. Both on SFX.
	low.advance(1.0 / 72.0)
	if low._tell_player.stream == null or low._tell_player.bus != &"SFX" or not low._tell_player.playing:
		failures.append("Sweep did not sound its tell as the rails lit")
	elif absf(low._tell_player.pitch_scale - 1.0) > 0.01 or low._whoosh_player.playing:
		failures.append("Sweep tell is off the telegraph, or the whoosh started early")
	_run_sweep(low, low.telegraph_seconds + 0.05)
	if low._whoosh_player.stream == null or low._whoosh_player.bus != &"SFX" or not low._whoosh_player.playing:
		failures.append("Sweep blade set out without its whoosh")
	elif low._whoosh_player.get_parent() != low._blade or absf(low._whoosh_player.pitch_scale - 1.0) > 0.01:
		failures.append("Sweep whoosh does not ride the blade or peak as it reaches the player")
	_run_sweep(low, 3.0)
	var cleared: Dictionary = low_log["resolved"]
	if cleared.is_empty() or low_log["hurt"] or not cleared.get("on_beat", false) or int(cleared.get("rift_damage", 0)) != 14 or int(cleared.get("base_score", 0)) != 150:
		failures.append("Sweep over a head below the line did not resolve as a dodge: %s" % cleared)
	if low.is_in_flight():
		failures.append("Cleared sweep did not run on past the player")
	low.free()
	# A head above the line takes the hit, and the blade goes out short of the face.
	camera.position = Vector3(0.0, 1.62, 0.0)
	var high := _spawn_sweep(sweep_scene, ahead)
	var high_log := _watch_sweep(high)
	_run_sweep(high, 3.0)
	if not high_log["hurt"] or not high_log["resolved"].is_empty():
		failures.append("Sweep over a standing head did not damage the player")
	elif high._blade_travel > high.start_distance - high.contact_lead + 0.1:
		failures.append("Sweep drew through the face before it hit")
	high.free()
	# Paused, it does not move and cannot hit; resumed, it carries on.
	var held := _spawn_sweep(sweep_scene, ahead)
	var held_log := _watch_sweep(held)
	# Paused once its tell is sounding, so the tell has to hold too. A 3D player starts on its next physics frame.
	held.advance(1.0 / 72.0)
	await physics_frame
	await physics_frame
	held.set_interactions_enabled(false)
	_run_sweep(held, 3.0)
	if held_log["hurt"] or not held_log["resolved"].is_empty() or held._blade_travel > 0.0:
		failures.append("Paused sweep still moved or judged the player")
	if not held._tell_player.stream_paused:
		failures.append("Paused sweep kept sounding")
	held.set_interactions_enabled(true)
	camera.position = Vector3(0.0, 1.30, 0.0)
	_run_sweep(held, 3.0)
	if held_log["resolved"].is_empty():
		failures.append("Sweep did not resume after pause")
	held.free()
	# Reduced Flashes dims the blade's glow.
	var settings := root.get_node_or_null("GameSettings")
	if settings == null:
		failures.append("GameSettings autoload missing; cannot check the sweep under Reduced Flashes")
	else:
		var was_reduced: bool = settings.reduced_flashes
		var glowing := _spawn_sweep(sweep_scene, ahead)
		settings.reduced_flashes = false
		glowing._update_visuals()
		var full_glow: float = glowing._blade_glow_material.albedo_color.a
		settings.reduced_flashes = true
		glowing._update_visuals()
		if glowing._blade_glow_material.albedo_color.a > full_glow * 0.5:
			failures.append("Sweep blade glow ignores Reduced Flashes")
		settings.reduced_flashes = was_reduced
		glowing.free()
	# A boss can aim it from one side and carry the motion with its own mesh.
	camera.position = Vector3(0.0, 1.62, 0.0)
	var flank := sweep_scene.instantiate() as ResonanceSweep
	flank.side = 1.0
	flank.blade_visible = false
	flank.position = ahead
	root.add_child(flank)
	flank.set_physics_process(false)
	flank.set_process(false)
	var crossings: Array[bool] = []
	flank.crossed.connect(func(cleared: bool) -> void: crossings.append(cleared))
	camera.position = Vector3(0.0, 1.30, 0.0)
	var halfway := false
	for _index in int(3.0 / (1.0 / 72.0)):
		flank.advance(1.0 / 72.0)
		flank._update_visuals()
		if flank._blade.visible:
			failures.append("Hidden sweep blade still drew")
			break
		halfway = halfway or (flank.progress() > 0.3 and flank.progress() < 0.7)
	if not flank._direction.is_equal_approx(Vector3.LEFT) or crossings != [true] or not halfway:
		failures.append("Sweep from the right did not cross right to left and report it: %s %s" % [flank._direction, crossings])
	flank.free()
	camera.position = Vector3(0.0, 1.62, 0.0)
	# Pressure shortens the tell, never below the floor.
	var rushed := _spawn_sweep(sweep_scene, ahead)
	rushed.apply_pressure(1.0, 0.1)
	if not is_equal_approx(rushed.telegraph_seconds, 0.45):
		failures.append("Sweep telegraph went under its 0.45 s floor")
	# A second sweep waits for the first to finish, then rests, before it lights.
	var queued := _spawn_sweep(sweep_scene, ahead)
	queued.advance(0.5)
	if not is_equal_approx(queued._telegraph_remaining, queued.telegraph_seconds):
		failures.append("A second sweep lit while the first was still in flight")
	rushed.free()
	queued.free()
	# With the detector calibrated, the line follows standing height, and a bend loses the bonus.
	var detector := SquatDetector.new()
	detector.name = "SquatDetector"
	player.add_child(detector)
	# It runs every physics frame now; the runner drives it by hand.
	detector.set_physics_process(false)
	var standing := Vector3(0.0, 1.70, 0.0)
	_drive_head(detector, standing, standing, 0.0, 0.0, 1.5)
	camera.position = standing
	# Chen calls each sweep as its rails light, and corrects a bend, but not every time.
	var chen := ChenComms.new()
	root.add_child(chen)
	await process_frame
	await process_frame
	var said: Array[String] = []
	chen.line_started.connect(func(_speaker: String, _text: String, _seconds: float) -> void: said.append(chen._playing_event))
	var clean := _spawn_sweep(sweep_scene, ahead)
	if absf(clean.sweep_height - 1.70 * 0.88) > 0.01:
		failures.append("Sweep did not read standing height from the squat detector")
	var clean_log := _watch_sweep(clean)
	_dip_under_sweep(clean, detector, camera, standing, Vector3(0.0, 1.32, 0.04), 0.0, -10.0, chen)
	if clean_log["resolved"].is_empty() or not clean_log["resolved"].get("on_beat", false):
		failures.append("Clean squat under the sweep lost its bonus: %s" % clean_log["resolved"])
	if said != ["sweep"]:
		failures.append("Chen did not call the sweep, or corrected a clean squat: %s" % [said])
	clean.free()
	# Four bent dips in a row: she corrects the first and the fourth, and every one still clears.
	var corrected: Array[bool] = []
	for attempt in 4:
		_drive_head(detector, camera.position, standing, -10.0, 0.0, 0.6)
		_drive_head(detector, standing, standing, 0.0, 0.0, 0.5)
		camera.position = standing
		_step_chen(chen, 4.0)
		said.clear()
		var bent := _spawn_sweep(sweep_scene, ahead)
		var bent_log := _watch_sweep(bent)
		_dip_under_sweep(bent, detector, camera, standing, Vector3(0.0, 1.40, -0.6), 0.0, -70.0, chen)
		var bent_result: Dictionary = bent_log["resolved"]
		if bent_result.is_empty() or bent_log["hurt"] or bent_result.get("on_beat", true) or bent_result.get("form_fault", &"") == &"":
			failures.append("A bend under the sweep kept the bonus or failed the dodge: %s" % bent_result)
		corrected.append(said.has("sweep_bend"))
		bent.free()
	if corrected != [true, false, false, true]:
		failures.append("Chen's bend correction is not once every three sweeps: %s" % [corrected])
	chen.free()
	# The rift hands the wave's squat depth to the sweep it spawns.
	var container := Node3D.new()
	container.add_to_group("PhantomContainer")
	root.add_child(container)
	var rift := RiftManager.new()
	rift.phantom_scenes.append(sweep_scene)
	root.add_child(rift)
	await process_frame
	rift.position = ahead
	var deep := (drill.get("rifts", [{}])[0] as Dictionary).duplicate(true)
	deep["pool"] = ["sweep"]
	deep["squat_depth"] = 0.2
	rift.configure_wave(deep)
	rift._spawn_phantom()
	var spawned: ResonanceSweep = null
	for child in container.get_children():
		if child is ResonanceSweep:
			spawned = child
	if spawned == null or not is_equal_approx(spawned.squat_depth, 0.2) or absf(spawned.sweep_height - 1.70 * 0.8) > 0.01:
		failures.append("Rift did not pass the wave's squat depth to the sweep")
	rift.force_cleanup()
	container.queue_free()
	player.queue_free()
	await process_frame

func _spawn_sweep(scene: PackedScene, at: Vector3) -> ResonanceSweep:
	var sweep := scene.instantiate() as ResonanceSweep
	sweep.position = at
	root.add_child(sweep)
	# The runner steps it by hand, so the tree's own physics frames must not.
	sweep.set_physics_process(false)
	sweep.set_process(false)
	return sweep

func _watch_sweep(sweep: ResonanceSweep) -> Dictionary:
	var seen := {"resolved": {}, "hurt": false}
	sweep.resolved.connect(func(result: Dictionary) -> void: seen["resolved"] = result)
	sweep.player_contact.connect(func(_amount: float) -> void: seen["hurt"] = true)
	return seen

func _run_sweep(sweep: ResonanceSweep, seconds: float) -> void:
	var step := 1.0 / 72.0
	for _index in int(seconds / step):
		sweep.advance(step)

## Dips the head from standing to the bottom while the telegraph runs, holds it there as the
## blade crosses, and feeds the same motion to the detector, as a headset would.
func _dip_under_sweep(sweep: ResonanceSweep, detector: SquatDetector, camera: Node3D, from: Vector3, to: Vector3, pitch_from: float, pitch_to: float, chen: ChenComms = null) -> void:
	var step := 1.0 / 72.0
	for index in int(3.0 / step):
		var t := clampf(float(index + 1) / (0.7 / step), 0.0, 1.0)
		var head := from.lerp(to, t)
		detector.sample(head, lerpf(pitch_from, pitch_to, t), step)
		camera.position = head
		sweep.advance(step)
		if chen:
			_step_chen(chen, step)

## Runs Chen's clock by hand. Each line ends when its time is up, as the voice player's finished would.
func _step_chen(chen: ChenComms, seconds: float) -> void:
	var step := 1.0 / 72.0
	for _index in maxi(int(round(seconds / step)), 1):
		chen._process(step)
		if chen._playing_event != "" and chen._clock >= chen._speaking_until:
			chen._on_line_finished()

## Steps a phantom by hand inside a physics frame. Outside one, move_and_slide moves by the process
## delta, which uncapped headless frames make arbitrarily small, so the body barely moves.
func _physics_step(body: Node) -> void:
	await physics_frame
	body._physics_process(body.get_physics_process_delta_time())

func _drive_head(squat: SquatDetector, from: Vector3, to: Vector3, pitch_from: float, pitch_to: float, seconds: float, facing: Vector2 = Vector2.ZERO) -> void:
	var step := 1.0 / 72.0
	var steps := maxi(int(round(seconds / step)), 1)
	for index in steps:
		var t := float(index + 1) / float(steps)
		squat.sample(from.lerp(to, t), lerpf(pitch_from, pitch_to, t), step, facing)

func _validate_maw_break_odds() -> void:
	if not MawBoss.decide_break(0, 0, 0.99):
		failures.append("The first Maw at the boss difficulty did not break")
	if MawBoss.decide_break(1, 0, 0.5) or not MawBoss.decide_break(1, 0, 0.2):
		failures.append("A later Maw does not break about one time in three")
	if not MawBoss.decide_break(5, 2, 0.99):
		failures.append("Two Maws in a row without a boss did not force a break")
	if not is_equal_approx(MawBoss.drain_rate(840, 210.0), 4.0):
		failures.append("The anchor does not run dry in its set time")
	var path := "user://validation_maw_odds.cfg"
	var levels = load("res://Scripts/Core/game_settings.gd").new()
	levels.settings_path = path
	# The unluckiest rolls possible still meet a boss every third Maw.
	var dry := 0
	var longest_dry := 0
	for index in 12:
		var broke := MawBoss.decide_break(levels.boss_maws_faced, levels.maws_without_boss, 0.999)
		if index == 0 and not broke:
			failures.append("The first boss Maw of a fresh profile did not break")
		levels.record_maw(broke)
		dry = 0 if broke else dry + 1
		longest_dry = maxi(longest_dry, dry)
	if longest_dry > 2:
		failures.append("Three Maws in a row sealed without a boss")
	var reloaded = load("res://Scripts/Core/game_settings.gd").new()
	reloaded.settings_path = path
	reloaded.load_settings()
	if reloaded.boss_maws_faced != 12 or reloaded.maws_without_boss != levels.maws_without_boss:
		failures.append("The Maw counters did not persist: %d faced, %d dry" % [reloaded.boss_maws_faced, reloaded.maws_without_boss])
	reloaded.clear_mission_progress()
	if reloaded.boss_maws_faced != 0 or reloaded.maws_without_boss != 0:
		failures.append("Reset progress kept the Maw counters")
	# With fair rolls the pity rule lifts one in three to 9 in 19 (about 0.47) over a long run.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var faced := 1
	var without := 0
	var breaks := 0
	for _i in 3000:
		var broke := MawBoss.decide_break(faced, without, rng.randf())
		faced += 1
		without = 0 if broke else without + 1
		breaks += 1 if broke else 0
	var share := float(breaks) / 3000.0
	if share < 0.42 or share > 0.52:
		failures.append("Boss Maws break at %.2f, not the 0.47 one in three plus the pity rule gives" % share)
	levels.free()
	reloaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Points the GameSettings autoload at a scratch file for a boss run, and back.
func _borrow_settings(scratch: bool, saved: Dictionary) -> void:
	var settings := root.get_node_or_null("GameSettings")
	if settings == null:
		return
	if scratch:
		saved["path"] = settings.settings_path
		saved["faced"] = settings.boss_maws_faced
		saved["dry"] = settings.maws_without_boss
		saved["cleared"] = settings.cleared_missions
		saved["tutorial"] = settings.tutorial_completed
		saved["scores"] = settings.best_scores.duplicate()
		saved["times"] = settings.best_times.duplicate()
		settings.settings_path = "user://validation_boss_settings.cfg"
		settings.cleared_missions = PackedStringArray()
		return
	settings.settings_path = saved["path"]
	settings.boss_maws_faced = saved["faced"]
	settings.maws_without_boss = saved["dry"]
	settings.cleared_missions = saved["cleared"]
	settings.tutorial_completed = saved["tutorial"]
	settings.best_scores = saved["scores"]
	settings.best_times = saved["times"]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://validation_boss_settings.cfg"))

func _validate_maw_boss() -> void:
	var saved := {}
	_borrow_settings(true, saved)
	var container := Node3D.new()
	container.add_to_group("PhantomContainer")
	root.add_child(container)
	var director := RiftDirector.new()
	director.rift_manager_scene = load("res://Scenes/Rifts/rift_manager.tscn")
	root.add_child(director)
	var life := LifeForceManager.new()
	root.add_child(life)
	var round_controller := RoundController.new()
	round_controller.countdown_seconds = 0
	root.add_child(round_controller)
	await process_frame
	await process_frame
	round_controller.set_process(false)
	var boss := director.get_node("MawBoss") as MawBoss
	var outcome := [&""]
	round_controller.round_finished.connect(func(result: StringName, _score: int) -> void: outcome[0] = result)
	var named := [""]
	boss.phase_two_started.connect(func(boss_name: String, _rift_id: int) -> void: named[0] = boss_name)
	MawBoss.force_next_break = true
	# The boss Maw is the campaign Maw at Full Resonance.
	round_controller.begin_round(MissionCatalog.get_mission("the_maw"), DifficultyTier.FULL_RESONANCE)
	round_controller._process(0.0)
	var rift: RiftManager = director.rift_instances[0] if not director.rift_instances.is_empty() else null
	if rift == null or not boss.breaks or not rift.hold_open:
		failures.append("The boss Maw did not arm its rift to break")
		await _end_boss_validation(round_controller, life, director, container, saved)
		return
	# 1600 at Standard, 1760 at Full Resonance, half of it on a Maw that breaks.
	if rift.maximum_health != 880:
		failures.append("A breaking Maw's phase one was not shortened: %d" % rift.maximum_health)
	var closed := [false]
	rift.closed.connect(func() -> void: closed[0] = true)
	await process_frame
	# Phase one ends the way every rift ends: the last resolve takes it to zero.
	rift.apply_result({"rift_damage": 5000, "base_score": 10})
	if closed[0] or not rift.is_held() or boss.stage != MawBoss.Stage.TURN:
		failures.append("Zero health on a breaking Maw sealed it instead of playing the turn")
	# Pause holds the turn where it is.
	boss._process(0.6)
	var held_clock := boss._clock
	round_controller.pause_round()
	if boss.is_processing():
		failures.append("Pause did not stop the turn")
	for _i in 4:
		await process_frame
	if not is_equal_approx(boss._clock, held_clock):
		failures.append("The turn ran on while paused")
	round_controller.resume_round()
	if not boss.is_processing():
		failures.append("Resume did not restart the turn")
	boss._process(0.6)
	for phantom in rift.live_phantoms():
		if phantom is Phantom and not (phantom as Phantom).is_escorting():
			failures.append("A phantom alive at the turn did not flee to the escort ring")
			break
	for _i in int(ceil(MawBoss.TURN_SECONDS)):
		boss._process(1.0)
	if boss.stage != MawBoss.Stage.FIGHT or named[0] != "THE MAW":
		failures.append("The turn did not open the fight under the boss's name")
	# The bar refills as the anchor.
	boss._process(MawBoss.REFILL_SECONDS)
	if rift.maximum_health != boss.anchor_maximum or rift.rift_health != boss.anchor_maximum:
		failures.append("The anchor did not refill the rift's bar: %d / %d" % [rift.rift_health, rift.maximum_health])
	var before := rift.rift_health
	boss._process(10.0)
	if before - rift.rift_health != 40:
		failures.append("The anchor did not drain 4 a second on its own: %d" % (before - rift.rift_health))
	before = rift.rift_health
	director.player_damaged.emit(5.0)
	if rift.rift_health - before != MawBoss.POSSESSION_FEED:
		failures.append("A possession did not feed the anchor")
	before = rift.rift_health
	rift.apply_result({"rift_damage": 14, "base_score": 150})
	if before - rift.rift_health != 14:
		failures.append("A resolve did not drain the anchor")
	# The slam, the spent tentacle, the escort holding still, and push-up pulses.
	boss._summon_escort()
	before = rift.rift_health
	boss.register_push_up()
	if rift.rift_health != before:
		failures.append("A push-up counted outside a spent tentacle")
	boss._steps = [{"do": "slam"}]
	boss._next_step()
	if boss._slam == null:
		failures.append("The slam did not start")
	else:
		boss._slam.advance(5.0)
		if not boss.is_spent_window_open():
			failures.append("A slam did not leave a spent tentacle")
		for escort in boss._escorts:
			if is_instance_valid(escort) and not is_zero_approx(escort._escort_orbit_speed):
				failures.append("The escort kept circling while the tentacle was spent")
				break
		before = rift.rift_health
		for _i in MawBoss.SPENT_PUSH_UPS + 2:
			boss.register_push_up()
		if before - rift.rift_health != MawBoss.SPENT_PUSH_UPS * MawBoss.PULSE_DRAIN:
			failures.append("Ten push-ups did not drain ten pulses: %d" % (before - rift.rift_health))
		boss._process(0.1)
		if boss._step_phase != &"recoil":
			failures.append("The tenth push-up did not tear the tentacle back")
	# At zero the boss retreats, the rift seals behind it, and the mission is won.
	rift.drain_health(rift.rift_health)
	if boss.stage != MawBoss.Stage.RETREAT:
		failures.append("An empty anchor did not make the boss retreat")
	for _i in 3:
		boss._process(1.0)
	await process_frame
	if not closed[0] or outcome[0] != &"victory":
		failures.append("The retreat did not seal the Maw and win the mission (%s)" % outcome[0])
	await _end_boss_validation(round_controller, life, director, container, saved)

func _end_boss_validation(round_controller: Node, life: Node, director: RiftDirector, container: Node, saved: Dictionary) -> void:
	director.cleanup_round()
	for node in [round_controller, life, director, container]:
		node.queue_free()
	await process_frame
	_borrow_settings(false, saved)

func _validate_maw_glimpse() -> void:
	var saved := {}
	_borrow_settings(true, saved)
	var container := Node3D.new()
	container.add_to_group("PhantomContainer")
	root.add_child(container)
	var director := RiftDirector.new()
	director.rift_manager_scene = load("res://Scenes/Rifts/rift_manager.tscn")
	root.add_child(director)
	await process_frame
	var boss := director.get_node("MawBoss") as MawBoss
	director.start_round(MissionCatalog.get_mission("first_light"))
	if boss.stage != MawBoss.Stage.IDLE:
		failures.append("An ordinary mission woke the boss")
	director.cleanup_round()
	director.start_round(MissionCatalog.get_mission("the_maw"))
	var rift: RiftManager = director.rift_instances[0]
	if boss.breaks or rift.hold_open or not boss.glimpse:
		failures.append("The tutorial Maw is not phase one with a first-seal glimpse")
	rift.apply_result({"rift_damage": 5000, "base_score": 10})
	if boss.stage != MawBoss.Stage.GLIMPSE or rift.dissolve_rate >= 0.75:
		failures.append("The tutorial Maw sealed without the tentacle glimpse")
	boss._process(MawBoss.GLIMPSE_SECONDS + 0.1)
	if boss.stage != MawBoss.Stage.DONE or is_instance_valid(boss._tentacle):
		failures.append("The glimpse did not end with the tentacle dragged back")
	director.cleanup_round()
	director.queue_free()
	container.queue_free()
	await process_frame
	_borrow_settings(false, saved)
	if not MissionCatalog.get_mission("the_maw_boss").is_empty() or MissionCatalog.all_missions().any(func(mission: Dictionary) -> bool: return mission.has("boss")):
		failures.append("A catalog mission carries a boss outside Full Resonance, or the old debug boss Maw is back")
	var lines: Dictionary = (load("res://Assets/Audio/VO/chen/chen_lines.json") as JSON).data.get("events", {})
	for event in ["boss_false_seal", "boss_holding_open", "boss_not_a_phantom", "boss_get_ready", "boss_sweep", "boss_slam", "boss_spent", "boss_waking", "boss_volley", "boss_retreat", "maw_glimpse"]:
		if not lines.has(event):
			failures.append("Chen has no %s line" % event)

## The hand tracking probe on synthetic palm paths: a clean punch counts once with its peak;
## a punch that loses tracking counts as dropped; a teleport is a jump, not a speed;
## a straight finger reads open and a curled one reads as a fist.
func _validate_hand_tracking_probe() -> void:
	var probe := HandTrackingProbe.new()
	if probe.is_enabled():
		failures.append("Hand tracking probe is on without debug_enabled or its project setting")
	var hand := HandTrackingProbe.Hand.new(&"right")
	var clock := [0.0]
	var rest := Vector3(0.2, 1.2, -0.2)
	var reach := Vector3(0.2, 1.3, -0.65)
	_drive_palm(probe, hand, clock, rest, rest, 0.3, true)
	_drive_palm(probe, hand, clock, rest, reach, 0.08, true)
	_drive_palm(probe, hand, clock, reach, reach, 0.2, true)
	_drive_palm(probe, hand, clock, reach, rest, 0.4, true)
	_drive_palm(probe, hand, clock, rest, rest, 1.1, true)
	if hand.punches != 1 or hand.dropped_punches != 0 or hand.drops != 0:
		failures.append("Hand tracking probe miscounted a clean punch: %d punches, %d dropped" % [hand.punches, hand.dropped_punches])
	if hand.peak_computed > 0.01:
		failures.append("Hand tracking probe kept a peak speed older than its window")
	_drive_palm(probe, hand, clock, rest, reach.lerp(rest, 0.5), 0.05, true)
	_drive_palm(probe, hand, clock, reach, reach, 0.4, false)
	_drive_palm(probe, hand, clock, reach, reach, 0.2, true)
	_drive_palm(probe, hand, clock, reach, rest, 0.4, true)
	_drive_palm(probe, hand, clock, rest, rest, 0.3, true)
	if hand.punches != 2 or hand.dropped_punches != 1 or hand.drops != 1:
		failures.append("Hand tracking probe did not count a punch that lost tracking as dropped")
	_drive_palm(probe, hand, clock, rest, rest + Vector3(0.0, 0.0, -1.0), 1.0 / 72.0, true)
	_drive_palm(probe, hand, clock, rest + Vector3(0.0, 0.0, -1.0), rest + Vector3(0.0, 0.0, -1.0), 0.3, true)
	if hand.jumps != 1 or hand.punches != 2:
		failures.append("Hand tracking probe counted a pose jump as hand speed")
	var held := rest + Vector3(0.0, 0.0, -1.0)
	clock[0] += 1.0 / 72.0
	probe.sample_hand(hand, clock[0], 1.0 / 72.0, true, held, Vector3(0.0, 0.0, -110.0), true)
	_drive_palm(probe, hand, clock, held, held, 0.3, true)
	if hand.jumps != 2 or hand.punches != 2:
		failures.append("Hand tracking probe counted a reported velocity spike as a punch")
	var straight := PackedVector3Array()
	var curled := PackedVector3Array()
	for index in 5:
		straight.append(Vector3(0.0, 0.0, -0.03 * index))
	curled.append(Vector3.ZERO)
	curled.append(Vector3(0.0, 0.0, -0.05))
	curled.append(Vector3(0.0, -0.035, -0.06))
	curled.append(Vector3(0.0, -0.045, -0.035))
	curled.append(Vector3(0.0, -0.035, -0.015))
	probe.set_curl(hand, PackedFloat32Array([probe.finger_curl(straight)]))
	if hand.fist or hand.curl > 0.05:
		failures.append("Hand tracking probe read a straight finger as curled")
	probe.set_curl(hand, PackedFloat32Array([probe.finger_curl(curled)]))
	if not hand.fist:
		failures.append("Hand tracking probe missed a curled finger: %.2f" % hand.curl)
	probe.free()

func _drive_palm(probe: HandTrackingProbe, hand: HandTrackingProbe.Hand, clock: Array, from: Vector3, to: Vector3, seconds: float, tracked: bool) -> void:
	var step := 1.0 / 72.0
	var steps := maxi(int(round(seconds / step)), 1)
	for index in steps:
		clock[0] += step
		var palm := from.lerp(to, float(index + 1) / float(steps))
		probe.sample_hand(hand, clock[0], step, tracked, palm, Vector3.ZERO, false)

## Push-ups from head height alone: three reps in a plank count three; a deep squat with the eyes
## level is not a plank; the head held still in a plank counts nothing.
func _validate_push_up_detector() -> void:
	var push := PushUpDetector.new()
	push.log_reps = false
	var count := [0]
	push.push_up_completed.connect(func() -> void: count[0] += 1)
	for _i in 30:
		push.sample(1.62, 0.0)
	# Down into a plank, face to the floor, then three push-ups between 45 and 22 cm.
	for step in 20:
		push.sample(lerpf(1.62, 0.45, step / 19.0), lerpf(0.0, -70.0, step / 19.0))
	for _rep in 3:
		for step in 15:
			push.sample(lerpf(0.45, 0.22, step / 14.0), -70.0)
		for step in 15:
			push.sample(lerpf(0.22, 0.45, step / 14.0), -70.0)
	if count[0] != 3 or not push.in_plank:
		failures.append("Push-up detector counted %d of 3 push-ups (in plank: %s)" % [count[0], push.in_plank])
	# Looking forward, as David does push-ups: the face only 10 degrees down. Two more count.
	for _rep in 2:
		for step in 15:
			push.sample(lerpf(0.5, 0.2, step / 14.0), -10.0)
		for step in 15:
			push.sample(lerpf(0.2, 0.5, step / 14.0), -10.0)
	if count[0] != 5:
		failures.append("Push-up detector missed push-ups done looking forward (%d of 5)" % count[0])
	for _i in 40:
		push.sample(0.50, -70.0)
	if count[0] != 5:
		failures.append("Push-up detector counted a head held still in a plank")
	for step in 20:
		push.sample(lerpf(0.5, 1.62, step / 19.0), 0.0)
	for step in 20:
		push.sample(lerpf(1.62, 0.72, step / 19.0), 5.0)
	for step in 20:
		push.sample(lerpf(0.72, 1.62, step / 19.0), 5.0)
	if count[0] != 5 or push.in_plank:
		failures.append("Push-up detector took a deep squat for a plank")
	# Controllers hanging, both hands tracked: a low head with the palms off the floor is no plank;
	# palms flat on the floor let it in, and a hand lost mid-set does not throw it out.
	for step in 20:
		push.sample(lerpf(1.62, 0.45, step / 19.0), -70.0, PushUpDetector.Palms.OFF_FLOOR)
	if push.in_plank:
		failures.append("Push-up detector entered a plank with the palms off the floor")
	push.sample(0.45, -70.0, PushUpDetector.Palms.ON_FLOOR)
	for step in 15:
		push.sample(lerpf(0.45, 0.22, step / 14.0), -70.0, PushUpDetector.Palms.OFF_FLOOR)
	for step in 15:
		push.sample(lerpf(0.22, 0.45, step / 14.0), -70.0, PushUpDetector.Palms.UNKNOWN)
	if count[0] != 6 or not push.in_plank:
		failures.append("Push-up detector lost a push-up with the palms on the floor (%d of 6)" % count[0])
	push.free()

## Simultaneous hands and controllers (decision 39): a hand is free only once the cameras have
## held it briefly, stays free through a short loss, and is held again the moment it grips; a free
## hand's visuals move onto the palm, where a held controller would put them, and it cannot strike.
func _validate_tracked_hands() -> void:
	var hands := TrackedHands.new()
	var changes := []
	hands.hand_freed.connect(func(side: StringName, free: bool) -> void: changes.append([side, free]))
	var step := 1.0 / 72.0
	for _i in 4:
		hands.step(&"left", step, true, false)
	if hands.is_free(&"left"):
		failures.append("Tracked hands freed a hand the cameras had seen for only %.2f s" % (4 * step))
	for _i in 6:
		hands.step(&"left", step, true, false)
	if not hands.is_free(&"left") or changes.size() != 1:
		failures.append("Tracked hands did not free a hand the cameras held")
	for _i in 30:
		hands.step(&"left", step, false, false)
	if not hands.is_free(&"left"):
		failures.append("Tracked hands dropped a free hand on a 0.4 s tracking loss")
	for _i in 20:
		hands.step(&"left", step, false, false)
	if hands.is_free(&"left"):
		failures.append("Tracked hands kept a hand free after the cameras lost it for 0.7 s")
	for _i in 10:
		hands.step(&"left", step, true, false)
	hands.step(&"left", step, false, true)
	if hands.is_free(&"left") or hands.is_free(&"right"):
		failures.append("Tracked hands kept a hand free after it gripped its controller")
	# A right hand held out as if shaking hands: fingers ahead, thumb side up, back of the hand right.
	var frame := TrackedHands.frame_from_points(Vector3(0.0, 0.0, 0.1), Vector3.ZERO, Vector3(0.0, 0.02, 0.0),
		Vector3(0.0, -0.04, 0.0), Vector3(0.0, 0.0, 0.04))
	if not frame.basis.is_equal_approx(Basis.IDENTITY) or not frame.origin.is_equal_approx(Vector3(0.0, 0.0, 0.04)):
		failures.append("Tracked hands built the hand frame wrong: %s" % frame)
	if TrackedHands.palm_is_flat(Transform3D.IDENTITY, 35.0) \
			or not TrackedHands.palm_is_flat(Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO), 35.0) \
			or not TrackedHands.palm_is_flat(Transform3D(Basis(Vector3.BACK, -PI / 2.0), Vector3.ZERO), 35.0):
		failures.append("Tracked hands misjudged a flat palm")
	hands.free()
	# Loaded here, not named: hand_collision.gd uses the XRToolsUserSettings autoload, which a
	# script compiled before the autoloads exist (this runner) cannot see.
	var combat_script := load("res://Scripts/Player/hand_collision.gd") as GDScript
	for side in [&"left", &"right"]:
		var controller = combat_script.new()
		controller.hand_id = side
		controller.tracker = StringName("%s_hand" % side)
		var glove := Node3D.new()
		glove.position = Vector3(0.0, 0.0, 0.05)
		controller.add_child(glove)
		root.add_child(controller)
		controller.set_hand_free(true)
		var grip: Transform3D = combat_script.get_script_constant_map()["GRIP_IN_PALM_%s" % String(side).to_upper()]
		var on_palm := grip.orthonormalized() * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.05))
		if controller.tracker != StringName("%s_hand" % side) or not glove.top_level \
				or not glove.global_transform.is_equal_approx(on_palm):
			failures.append("The %s hand's glove did not move onto the palm, where a held controller would be" % side)
		if controller.is_menu_trigger_down() or controller.free_hand_curl() != -1.0:
			failures.append("The %s free hand pinched or curled with no hand tracker" % side)
		controller.set_hand_free(false)
		if glove.top_level or not glove.position.is_equal_approx(Vector3(0.0, 0.0, 0.05)):
			failures.append("The %s hand did not go back to its controller" % side)
		controller.queue_free()

## Jumps from head height, shaped like the Quest 3 jump test (2026-10-09): a jump takes off near
## 2 m/s and lifts the head well over standing; a calf raise and a fast stand-up out of a squat do not.
func _validate_jump_detection() -> void:
	var detector := SquatDetector.new()
	var standing := Vector3(0.0, 1.62, 0.0)
	_drive_head(detector, standing, standing, 0.0, 0.0, 1.5)
	var jumps := [0]
	detector.jumped.connect(func(_speed: float) -> void: jumps[0] += 1)
	_drive_head(detector, standing, Vector3(0.0, 1.70, 0.0), 0.0, 0.0, 0.25)
	_drive_head(detector, Vector3(0.0, 1.70, 0.0), standing, 0.0, 0.0, 0.25)
	_drive_head(detector, standing, standing, 0.0, 0.0, 0.5)
	if jumps[0] != 0:
		failures.append("Jump detection took a calf raise for a jump")
	var bottom := Vector3(0.0, 1.0, 0.0)
	_drive_head(detector, standing, bottom, 0.0, 0.0, 0.6)
	_drive_head(detector, bottom, Vector3(0.0, 1.66, 0.0), 0.0, 0.0, 0.4)
	_drive_head(detector, Vector3(0.0, 1.66, 0.0), standing, 0.0, 0.0, 0.2)
	_drive_head(detector, standing, standing, 0.0, 0.0, 0.5)
	if jumps[0] != 0:
		failures.append("Jump detection took a fast stand-up out of a squat for a jump")
	var dip := Vector3(0.0, 1.50, 0.0)
	var top := Vector3(0.0, 1.88, 0.0)
	_drive_head(detector, standing, dip, 0.0, 0.0, 0.15)
	_drive_head(detector, dip, top, 0.0, 0.0, 0.2)
	if jumps[0] != 1 or not detector.is_airborne():
		failures.append("Jump detection missed a jump (%d, airborne %s)" % [jumps[0], detector.is_airborne()])
	_drive_head(detector, top, standing, 0.0, 0.0, 0.25)
	_drive_head(detector, standing, standing, 0.0, 0.0, 0.1)
	if detector.is_airborne() or detector.seconds_since_landing() > 0.2:
		failures.append("Jump detection did not land the jump")
	detector.free()

## A low sweep along the floor: standing still takes the hit; a jump timed to the pass clears it.
## The first cycle is the authored one; after that the blocks shuffle, the summon still comes
## before the volley, the jump pair still closes, and no two cycles in a row share an order.
func _validate_maw_cycle_variety() -> void:
	var boss := MawBoss.new()
	var first: Array = boss._build_cycle()
	if first != MawBoss.CYCLE:
		failures.append("The boss's first cycle is not the authored one")
	boss._cycles = 1
	var orders: Dictionary = {}
	var previous: Array = []
	for _i in 16:
		var steps: Array = boss._build_cycle()
		var does: Array = []
		for step in steps:
			does.append(String(step.get("do", "")))
		if does.count("slam") != 1 or does.count("summon") != 1 or does.count("volley") != 1 or does.count("sweep") != 2:
			failures.append("A shuffled boss cycle lost or doubled an attack: %s" % [does])
			break
		if does.find("summon") > does.find("volley"):
			failures.append("A shuffled boss cycle throws its volley before summoning an escort")
			break
		if does.slice(-4) != ["low_sweep", "rest", "low_sweep", "rest"]:
			failures.append("A shuffled boss cycle does not end on the jump pair: %s" % [does])
			break
		var order: Array = boss._last_order.duplicate()
		if order == previous:
			failures.append("Two boss cycles in a row used the same order")
			break
		previous = order
		orders[str(order)] = true
	if orders.size() < 2:
		failures.append("Boss cycles did not vary")
	boss.free()

func _validate_low_sweep() -> void:
	var sweep_scene := load(MissionCatalog.scene_path("sweep")) as PackedScene
	var player := Node3D.new()
	player.name = "LowSweepTestPlayer"
	player.add_to_group("Player")
	var camera := Node3D.new()
	camera.name = "XRCamera3D"
	player.add_child(camera)
	root.add_child(player)
	camera.position = Vector3(0.0, 1.62, 0.0)
	var detector := SquatDetector.new()
	detector.name = "SquatDetector"
	player.add_child(detector)
	detector.set_physics_process(false)
	_drive_head(detector, camera.position, camera.position, 0.0, 0.0, 1.5)
	var ahead := Vector3(0.0, 1.5, -4.0)
	for jump in [false, true]:
		var sweep := sweep_scene.instantiate() as ResonanceSweep
		sweep.low = true
		sweep.position = ahead
		root.add_child(sweep)
		sweep.set_physics_process(false)
		sweep.set_process(false)
		# Earlier tests may leave another Player in the group; judge by this one's detector and head.
		sweep._detector = detector
		sweep._camera = camera
		sweep._player = player
		if absf(sweep.sweep_height - sweep.jump_line) > 0.01:
			failures.append("Low sweep did not run at its jump line: %.3f" % sweep.sweep_height)
		var seen := _watch_sweep(sweep)
		var step := 1.0 / 72.0
		var reach := sweep.telegraph_seconds + sweep.start_distance / sweep.blade_speed
		var t := 0.0
		while t < reach + 1.0:
			var y := 1.62
			if jump:
				# Takes off 0.2 s before the blade arrives: 0.38 m up in 0.2 s, down in 0.25 s.
				var into := t - (reach - 0.2)
				if into > 0.0 and into < 0.2:
					y = 1.62 + 0.26 * into / 0.2
				elif into >= 0.2 and into < 0.45:
					y = 1.88 - 0.26 * (into - 0.2) / 0.25
			camera.position = Vector3(0.0, y, 0.0)
			detector.sample(camera.position, 0.0, step)
			sweep.advance(step)
			t += step
		if jump and (seen["hurt"] or seen["resolved"].is_empty() or seen["resolved"].get("resolution_kind", &"") != &"jump"):
			failures.append("A jump timed to the low sweep did not clear it: %s" % seen["resolved"])
		if not jump and not seen["hurt"]:
			failures.append("A low sweep under a standing player did not hit")
		sweep.free()
	player.free()
	await process_frame

## Training's paused hologram: a yellow told to hold stops in reach and stays there without
## possessing, even with the head leaning into it; a wrong hand leaves it held, the right hand
## resolves it, and a released one lunges and possesses. A pink holds at lane lock, shrugs off
## a punch, and once the head is out of its lane and it is released, resolves as a dodge.
func _validate_phantom_hold() -> void:
	var head := Node3D.new()
	root.add_child(head)
	head.global_position = Vector3(0.0, 1.6, 0.0)
	var yellow := await _held_yellow(head)
	if yellow == null:
		failures.append("A yellow told to hold never paused in reach")
		head.queue_free()
		return
	var distance := yellow.global_position.distance_to(head.global_position)
	if distance > 1.1 or distance < 0.8:
		failures.append("A held yellow paused %.2f m from the head, not in punching reach" % distance)
	var spot := yellow.global_position
	for _step in 90:
		await _physics_step(yellow)
	head.global_position = spot + Vector3(0.0, 0.0, 0.2)
	for _step in 30:
		await _physics_step(yellow)
	if yellow._terminal or yellow.global_position.distance_to(spot) > 0.01 or not yellow.is_held():
		failures.append("A held yellow moved, ended, or possessed while paused")
	head.global_position = Vector3(0.0, 1.6, 0.0)
	var lure: Vector3 = yellow.sweet_spot_visual.global_position
	var wrong: Dictionary = yellow.receive_strike({"hand_id": &"right", "position": lure, "direction": Vector3.FORWARD, "speed": 4.0})
	if wrong.get("resolution_kind", &"") != &"wrong_hand" or not yellow.is_held():
		failures.append("A wrong hand released a held yellow")
	var right: Dictionary = yellow.receive_strike({"hand_id": &"left", "position": lure, "direction": Vector3.FORWARD, "speed": 4.0})
	if not right.get("valid", false) or yellow.is_held():
		failures.append("The right hand did not resolve a held yellow")
	yellow.queue_free()
	var lunger := await _held_yellow(head)
	if lunger:
		var bitten := [false]
		lunger.player_contact.connect(func(_damage: float) -> void: bitten[0] = true)
		lunger.release_hold()
		for _step in 120:
			if bitten[0]:
				break
			await _physics_step(lunger)
		if not bitten[0]:
			failures.append("A released yellow did not lunge in and possess")
		lunger.queue_free()
	var pink := (load("res://Scenes/Phantoms/pink_phantom.tscn") as PackedScene).instantiate() as SpearfinPhantom
	root.add_child(pink)
	await process_frame
	pink.global_position = Vector3(0.0, 1.6, -9.0)
	pink._player_camera = head
	pink._lock_pink_target()
	pink.set_physics_process(false)
	pink.hold_at_lane_lock()
	for _step in 240:
		await _physics_step(pink)
		if pink.is_held() or pink._terminal:
			break
	if not pink.is_held():
		failures.append("A pink told to hold did not pause at lane lock")
	else:
		var punch: Dictionary = pink.receive_strike({"hand_id": &"left", "position": pink.global_position, "direction": Vector3.FORWARD, "speed": 4.0})
		if punch.get("valid", true) or not pink.is_held():
			failures.append("A punch moved a held pink")
		head.global_position += Vector3(0.6, 0.0, 0.0)
		var line := pink.charge_line()
		if Geometry3D.get_closest_point_to_segment(head.global_position, line[0], line[1]).distance_to(head.global_position) <= TutorialDirector.LANE_CLEARANCE:
			failures.append("A side-step did not leave the pink's lane")
		var outcome := [&""]
		pink.resolved.connect(func(result: Dictionary) -> void: outcome[0] = result.get("resolution_kind", &""))
		pink.player_contact.connect(func(_damage: float) -> void: outcome[0] = &"possessed")
		pink.release_hold()
		for _step in 240:
			if outcome[0] != &"":
				break
			await _physics_step(pink)
		if outcome[0] != &"dodge":
			failures.append("A released pink past an empty lane did not resolve as a dodge (%s)" % outcome[0])
	pink.queue_free()
	head.queue_free()
	await process_frame

func _held_yellow(head: Node3D) -> ResonancePhantom:
	var yellow := (load("res://Scenes/Phantoms/yellow_phantom.tscn") as PackedScene).instantiate() as ResonancePhantom
	root.add_child(yellow)
	await process_frame
	yellow.global_position = head.global_position + Vector3(0.0, -0.1, -3.0)
	yellow._player_camera = head
	yellow.set_physics_process(false)
	yellow.place_sweet_spot(TutorialDirector.LURE_JAB)
	yellow.hold_in_reach(TutorialDirector.HOLD_ANGLER)
	var entered := [false]
	yellow.held.connect(func() -> void: entered[0] = true)
	for _step in 400:
		await _physics_step(yellow)
		if entered[0] or yellow._terminal:
			break
	if not entered[0] or not yellow.is_held():
		yellow.queue_free()
		return null
	return yellow

## Punch power: rift damage rises from 0.85x for a 2 m/s punch to 1.3x for a 6 m/s one, the score
## does not move, and a soft lure hit still beats the hardest plain hit.
func _validate_punch_power() -> void:
	var soft := await _committed_strike(2.0, false)
	var hard := await _committed_strike(6.0, false)
	var harder := await _committed_strike(9.0, false)
	var soft_crit := await _committed_strike(2.0, true)
	if int(soft.get("rift_damage", 0)) != 10 or int(hard.get("rift_damage", 0)) != 15 or int(harder.get("rift_damage", 0)) != 15:
		failures.append("Punch power is not 0.85x to 1.3x rift damage: %d, %d, %d" % [soft.get("rift_damage", 0), hard.get("rift_damage", 0), harder.get("rift_damage", 0)])
	if int(soft.get("base_score", 0)) != int(hard.get("base_score", 0)):
		failures.append("Punch power changed the score")
	if int(soft_crit.get("rift_damage", 0)) <= int(hard.get("rift_damage", 0)):
		failures.append("A soft lure hit no longer beats the hardest plain hit")
	if not is_equal_approx(float(soft.get("power", -1.0)), 0.0) or not is_equal_approx(float(hard.get("power", -1.0)), 1.0):
		failures.append("Punch power is not carried on the result")

func _committed_strike(speed: float, on_lure: bool) -> Dictionary:
	var yellow := (load("res://Scenes/Phantoms/yellow_phantom.tscn") as PackedScene).instantiate() as ResonancePhantom
	root.add_child(yellow)
	await process_frame
	yellow.place_sweet_spot(TutorialDirector.LURE_JAB)
	yellow._phase = Phantom.Phase.COMMIT
	var at: Vector3 = yellow.sweet_spot_visual.global_position if on_lure else yellow.global_position + Vector3(0.0, -0.5, -0.4)
	var result: Dictionary = yellow.receive_strike({"hand_id": &"left", "position": at, "direction": Vector3.FORWARD, "speed": speed})
	yellow.queue_free()
	return result

## The training run, beat by beat, on the real round, rift, and life force, with the tutorial
## director's fast mode. The recruit is played by hand: a wrong hand first on the Anglers, one
## hand first on the green, a punch and then a side-step on the pink, hands down on the
## possession, a tap then a hard hit for power, and every phantom of the live wave.
func _validate_tutorial_flow() -> void:
	var saved := {}
	_borrow_settings(true, saved)
	var settings := root.get_node_or_null("GameSettings")
	if settings:
		settings.tutorial_completed = false
		settings.best_scores = {}
		settings.best_times = {}
	var player := Node3D.new()
	player.add_to_group("Player")
	root.add_child(player)
	var camera := Node3D.new()
	camera.name = "XRCamera3D"
	player.add_child(camera)
	camera.position = Vector3(0.0, 1.6, 0.0)
	var container := Node3D.new()
	container.add_to_group("PhantomContainer")
	root.add_child(container)
	var director := RiftDirector.new()
	director.rift_manager_scene = load("res://Scenes/Rifts/rift_manager.tscn")
	root.add_child(director)
	var life := LifeForceManager.new()
	root.add_child(life)
	var round_controller := RoundController.new()
	root.add_child(round_controller)
	var tutorial := TutorialDirector.new()
	tutorial.fast = true
	root.add_child(tutorial)
	await process_frame
	await process_frame
	await process_frame
	var beats: Array[StringName] = []
	tutorial.beat_started.connect(func(beat: StringName) -> void: beats.append(beat))
	var done := [false]
	tutorial.finished.connect(func() -> void: done[0] = true)
	tutorial.start()
	# What the stand-in recruit has done in each beat.
	var acted := {}
	var drains: Array[float] = []
	life.damage_applied.connect(func(amount: float, _current: float) -> void:
		if tutorial.beat == &"possession":
			drains.append(amount))
	var wrong_held := {}
	for _frame_index in 6000:
		if done[0]:
			break
		await process_frame
		var phantom := tutorial.current_phantom()
		match tutorial.beat:
			&"yellow", &"blue":
				if phantom and phantom.is_held():
					var right_hand: StringName = &"left" if tutorial.beat == &"yellow" else &"right"
					var wrong_hand: StringName = &"right" if right_hand == &"left" else &"left"
					if not acted.has(tutorial.beat):
						acted[tutorial.beat] = true
						_hit(phantom, wrong_hand, 4.0, true)
						wrong_held[tutorial.beat] = phantom.is_held() and tutorial.beat in [&"yellow", &"blue"]
					elif tutorial.spoken.count("tutorial_wrong_hand") >= (1 if tutorial.beat == &"yellow" else 2):
						_hit(phantom, right_hand, 4.0, true)
			&"chain":
				for node in container.get_children():
					var live := node as Phantom
					if live and live.shows_approach_cue() and live.is_strike_window_open():
						_hit(live, &"left" if live.variant_id == &"yellow" else &"right", 4.0, false)
			&"green":
				if phantom and phantom.is_held():
					if not acted.has(&"green"):
						acted[&"green"] = true
						_hit(phantom, &"left", 4.0, false)
						if not phantom.is_held():
							failures.append("One hand broke a held green")
					elif "tutorial_green_one" in tutorial.spoken:
						_hit(phantom, &"left", 4.0, false)
						_hit(phantom, &"right", 4.0, false)
			&"pink":
				if phantom and phantom.is_held():
					if not acted.has(&"pink"):
						acted[&"pink"] = true
						_hit(phantom, &"left", 4.0, false)
						if not phantom.is_held():
							failures.append("A punch released a held pink")
					elif not acted.has(&"pink_step") and "tutorial_pink_punch" in tutorial.spoken:
						acted[&"pink_step"] = true
						camera.position = Vector3(0.6, 1.6, 0.0)
			&"possession":
				camera.position = Vector3(0.0, 1.6, 0.0)
			&"power":
				if phantom and phantom.is_held() and phantom.shows_approach_cue():
					var first := not acted.has(&"tap")
					acted[&"tap"] = true
					_hit(phantom, &"left", 1.5 if first else 7.0, false)
			&"live_wave":
				if not acted.has(&"floor"):
					acted[&"floor"] = true
					life.apply_damage(500.0)
					if life.is_depleted() or not is_equal_approx(life.current_life_force, 20.0):
						failures.append("Training's life floor did not hold the recruit at 20: %.0f" % life.current_life_force)
				for node in container.get_children():
					var live := node as Phantom
					if live == null or not live.shows_approach_cue() or not live.is_strike_window_open():
						continue
					match live.variant_id:
						&"yellow":
							_hit(live, &"left", 4.0, false)
						&"blue":
							_hit(live, &"right", 4.0, false)
						&"green":
							_hit(live, &"left", 4.0, false)
							_hit(live, &"right", 4.0, false)
	if not done[0]:
		failures.append("Training did not finish; it stopped in beat %s" % tutorial.beat)
	if beats != TutorialDirector.BEATS:
		failures.append("Training beats ran out of order: %s" % [beats])
	for beat in [&"yellow", &"blue"]:
		if not wrong_held.get(beat, false):
			failures.append("A wrong hand moved training past the %s beat" % beat)
	if drains != [20.0]:
		failures.append("The possession beat did not drain exactly 20 once: %s" % [drains])
	for event in ["tutorial_wrong_hand", "tutorial_green_one", "tutorial_pink_punch", "tutorial_pink_done", "tutorial_possessed", "tutorial_glove_seen", "tutorial_power_seen", "tutorial_last_one", "tutorial_straggler", "tutorial_signoff_comms"]:
		if not event in tutorial.spoken:
			failures.append("Training never said %s" % event)
	if not tutorial.spoken.has("tutorial_chain_done") and not tutorial.spoken.has("tutorial_chain_enough"):
		failures.append("The chain beat never finished")
	var lines: Dictionary = (load("res://Assets/Audio/VO/chen/chen_lines.json") as JSON).data.get("events", {})
	for event in tutorial.spoken:
		if not lines.has(event):
			failures.append("Training says %s, which chen_lines.json does not have" % event)
	if settings:
		if not settings.tutorial_completed:
			failures.append("Finishing training did not mark it complete")
		if not settings.cleared_missions.is_empty() or not settings.best_scores.is_empty() or not settings.best_times.is_empty():
			failures.append("Training recorded a clear, a score, or a time")
	# End Training from the pause menu stops it anywhere and still counts it as done.
	var flow = load("res://Scripts/Core/game_flow_controller.gd").new()
	flow._tutorial = tutorial
	flow._round = round_controller
	flow._settings = settings
	if settings:
		settings.tutorial_completed = false
	round_controller.abandon_round()
	tutorial.start()
	for _i in 3:
		await process_frame
	flow._end_training()
	if tutorial.is_running():
		failures.append("End Training left the simulation running")
	if settings and not settings.tutorial_completed:
		failures.append("End Training did not count training as done")
	flow.free()
	tutorial.stop()
	round_controller.abandon_round()
	for node in [tutorial, round_controller, life, director, container, player]:
		node.queue_free()
	await process_frame
	_borrow_settings(false, saved)

func _hit(phantom: Phantom, hand: StringName, speed: float, on_lure: bool) -> void:
	if not is_instance_valid(phantom) or not phantom.shows_approach_cue():
		return
	var at := phantom.global_position
	var lure := phantom.get_node_or_null("SweetSpotVisual") as Node3D
	if lure and on_lure:
		at = lure.global_position
	elif lure:
		at += Vector3(0.0, -0.5, 0.0)
	phantom.receive_strike({"hand_id": hand, "position": at, "direction": Vector3.FORWARD, "speed": speed})
