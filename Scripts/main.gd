extends Node3D

var xr_interface: XRInterface

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")

		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
		print("Viewport use_xr set to: ", get_viewport().use_xr)
	else:
		print("OpenXR not initialized, please check if your headset is connected")

	# Add a delay before checking the viewport status
	await get_tree().create_timer(1.0).timeout
	print("Viewport use_xr status after delay: ", get_viewport().use_xr)

func _process(_delta):
	if xr_interface and xr_interface.is_initialized():
		print("Left hand position: ", $XROrigin3D/LeftHand.global_transform.origin)
		print("Right hand position: ", $XROrigin3D/RightHand.global_transform.origin)
