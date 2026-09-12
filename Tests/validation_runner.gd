extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_resources()
	await _validate_variant_rules()
	_validate_life_force()
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
	var deploy := _find_button(menu, "DEPLOY MISSION")
	var training := _find_button(menu, "START TRAINING")
	var settings := _find_button(menu, "OPEN SETTINGS")
	if deploy == null or training == null or settings == null:
		failures.append("Main menu mission/training/settings actions are not all present")
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
