extends StaticBody3D

## Physical stand-in for a viewport button. The controller laser already
## collides with layer 23, so a trigger can select the action without the
## SubViewport turning the hit into a mouse click.
## https://docs.godotengine.org/en/stable/classes/class_staticbody3d.html

signal selected(action: StringName)

var action: StringName = &""
var _consumed: bool = false


func pointer_event(event: XRToolsPointerEvent) -> void:
	if event.event_type == XRToolsPointerEvent.Type.PRESSED:
		activate()


func activate() -> void:
	if _consumed or action == &"":
		return
	_consumed = true
	selected.emit(action)
