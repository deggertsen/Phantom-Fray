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
	await _validate_rift_stragglers()
	await _validate_elapsed_timer()
	await _validate_menu_surface()
	await _validate_results_menu()
	await _validate_pink_dodge()
	_validate_squat_detector()
	_validate_maw_break_odds()
	await _validate_maw_boss()
	await _validate_maw_glimpse()
	await process_frame
	if failures.is_empty():
		print("PHANTOM FRAY VALIDATION PASSED")
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
		"phantom_possess": 2,
		"rift_close_sound": 3,
		"rift_open_sound": 1,
	}
	for stem in expected:
		if SfxVariations.variation_count(stem) != int(expected[stem]):
			failures.append("%s has %d takes, expected %d" % [stem, SfxVariations.variation_count(stem), int(expected[stem])])
	var first := SfxVariations.pick("phantom_possess")
	var varied := false
	for _i in 6:
		if SfxVariations.pick("phantom_possess") != first:
			varied = true
			break
	if first == null or not varied:
		failures.append("Possession takes did not vary")
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
	var tutorial_pages: Array[Dictionary] = [{
		"eyebrow": "TEST",
		"title": "WAIT FOR CONTINUE",
		"body": "Tutorial content remains visible until Continue is selected.",
		"callout": "CONTINUE",
		"color": Color.CYAN,
	}]
	menu.show_tutorial(0, tutorial_pages)
	if _find_button(menu, "COMPLETE TRAINING") == null:
		failures.append("Tutorial continue action is missing")
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
	for _step in 40:
		if missed._terminal:
			break
		missed._physics_process(0.05)
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
	for _step in 40:
		if caught._terminal:
			break
		caught._physics_process(0.05)
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
	await _validate_green_arrival()
	await _validate_possession(yellow_scene)

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
	for _step in 120:
		yellow._physics_process(0.016)
	if yellow.global_position.distance_to(start) < 1.0 or yellow.velocity.length() < 0.3:
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
	for _step in 420:
		if green._terminal:
			break
		var before: float = green_body.global_position.distance_to(head.global_position)
		green._physics_process(0.016)
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
	if MissionCatalog.deploy_detail(null) != "NEXT • OP-01 FIRST LIGHT • %s" % MissionCatalog.expected_minutes_text(MissionCatalog.get_mission("first_light")):
		failures.append("Deploy button does not show the next mission's expected time: %s" % MissionCatalog.deploy_detail(null))
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
	squat.free()
	var short := SquatDetector.new()
	var short_standing := Vector3(0.0, 1.30, 0.0)
	var short_bottom := Vector3(0.0, 1.30 * 0.75, 0.05)
	_drive_head(short, short_standing, short_standing, 0.0, 0.0, 1.5)
	_drive_head(short, short_standing, short_bottom, 0.0, -15.0, 0.5)
	_drive_head(short, short_bottom, short_bottom, -15.0, -15.0, 0.3)
	_drive_head(short, short_bottom, short_standing, -15.0, 0.0, 0.5)
	_drive_head(short, short_standing, short_standing, 0.0, 0.0, 0.3)
	if short.rep_count != 1:
		failures.append("Squat detector missed a shorter player's squat")
	short.free()

func _drive_head(squat: SquatDetector, from: Vector3, to: Vector3, pitch_from: float, pitch_to: float, seconds: float) -> void:
	var step := 1.0 / 72.0
	var steps := maxi(int(round(seconds / step)), 1)
	for index in steps:
		var t := float(index + 1) / float(steps)
		squat.sample(from.lerp(to, t), lerpf(pitch_from, pitch_to, t), step)

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
	# With fair rolls a boss comes through a bit more than one Maw in three; the pity rule adds some.
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
	if share < 0.33 or share > 0.5:
		failures.append("Boss Maws break at %.2f, not about one in three" % share)
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
		settings.settings_path = "user://validation_boss_settings.cfg"
		settings.cleared_missions = PackedStringArray()
		return
	settings.settings_path = saved["path"]
	settings.boss_maws_faced = saved["faced"]
	settings.maws_without_boss = saved["dry"]
	settings.cleared_missions = saved["cleared"]
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
	round_controller.begin_round(MissionCatalog.get_mission("the_maw_boss"))
	round_controller._process(0.0)
	var rift: RiftManager = director.rift_instances[0] if not director.rift_instances.is_empty() else null
	if rift == null or not boss.breaks or not rift.hold_open:
		failures.append("The boss Maw did not arm its rift to break")
		await _end_boss_validation(round_controller, life, director, container, saved)
		return
	if rift.maximum_health != 800:
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
	for _i in 12:
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
	if not MissionCatalog.get_mission("the_maw_boss").has("boss") or MissionCatalog.all_missions().any(func(mission: Dictionary) -> bool: return mission.has("boss")):
		failures.append("The boss Maw is not a debug-only mission")
	var lines: Dictionary = (load("res://Assets/Audio/VO/chen/chen_lines.json") as JSON).data.get("events", {})
	for event in ["boss_false_seal", "boss_holding_open", "boss_not_a_phantom", "boss_get_ready", "boss_sweep", "boss_slam", "boss_spent", "boss_waking", "boss_volley", "boss_retreat", "maw_glimpse"]:
		if not lines.has(event):
			failures.append("Chen has no %s line" % event)
