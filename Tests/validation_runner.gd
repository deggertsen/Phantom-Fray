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
	await _validate_possession(yellow_scene)

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
	var offsets: Dictionary = {}
	for _i in 8:
		graze._lock_target()
		offsets[snappedf(graze._locked_target.x, 0.02)] = true
	if offsets.size() < 2:
		failures.append("Yellow commit target did not vary")
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
