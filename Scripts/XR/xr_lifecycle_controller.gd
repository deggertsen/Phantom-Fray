extends Node

@export var start_xr_path: NodePath = NodePath("../StartXR")

var _start_xr: Node
var _round: RoundController
var _flow: Node
var _suspended: bool = false
var _was_round_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_xr = get_node_or_null(start_xr_path)
	if _start_xr:
		if _start_xr.has_signal("xr_started"):
			_start_xr.xr_started.connect(_on_xr_started)
		if _start_xr.has_signal("xr_ended"):
			_start_xr.xr_ended.connect(_on_xr_ended)
		if _start_xr.has_signal("xr_failed_to_initialize"):
			_start_xr.xr_failed_to_initialize.connect(_on_xr_failed)
	await get_tree().process_frame
	_connect_recenter_signal()
	_round = get_tree().get_first_node_in_group("RoundController") as RoundController
	_flow = get_node_or_null("../GameFlowController")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_suspend_gameplay()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_resume_available()

func _connect_recenter_signal() -> void:
	if _start_xr == null:
		return
	var xr_interface: XRInterface = _start_xr.get("xr_interface")
	if xr_interface and xr_interface.has_signal("pose_recentered") and not xr_interface.pose_recentered.is_connected(_on_pose_recentered):
		xr_interface.pose_recentered.connect(_on_pose_recentered)

func _on_xr_started() -> void:
	_connect_recenter_signal()
	_resume_available()
	_on_pose_recentered()
	if _flow:
		if _was_round_active and _flow.has_method("show_suspended_pause"):
			_flow.show_suspended_pause()
		elif _flow.has_method("restore_current_menu"):
			_flow.restore_current_menu()

func _on_pose_recentered() -> void:
	if _flow and _flow.has_method("recenter_current_panel"):
		_flow.recenter_current_panel()

func _on_xr_ended() -> void:
	_suspend_gameplay()

func _on_xr_failed() -> void:
	if OS.has_feature("editor") or OS.is_debug_build():
		push_warning("XR runtime unavailable; desktop fallback remains active")
	else:
		push_error("XR initialization failed on release build")

func _suspend_gameplay() -> void:
	if _suspended:
		return
	_suspended = true
	_was_round_active = _round != null and _round.is_round_in_progress()
	if _was_round_active:
		_round.pause_round()
		if _flow and _flow.has_method("show_suspended_pause"):
			_flow.show_suspended_pause()
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	if sfx_index >= 0:
		AudioServer.set_bus_mute(sfx_index, true)

func _resume_available() -> void:
	if not _suspended:
		return
	_suspended = false
	var index := AudioServer.get_bus_index(&"SFX")
	if index >= 0:
		AudioServer.set_bus_mute(index, false)
	# Active combat resumes explicitly; non-combat menu state is restored on XR focus.
