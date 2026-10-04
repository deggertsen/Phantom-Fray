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
	_validate_mission_catalog()
	await _validate_menu_surface()
	await _validate_results_menu()
	await _validate_pink_dodge()
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
	menu.queue_free()
	await process_frame

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
	if MissionCatalog.all_missions().size() != 3:
		failures.append("Mission catalog does not contain three operations")
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
	for variant_id in ["yellow", "blue", "green", "pink"]:
		if load(MissionCatalog.scene_path(variant_id)) == null:
			failures.append("Mission pool failed to load %s" % variant_id)

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
