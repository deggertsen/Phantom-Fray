extends CharacterBody3D

@export var hurtbox_radius: float = 0.28
@export var minimum_height: float = 0.9
@export var maximum_height: float = 2.1

@onready var camera: XRCamera3D = get_parent().get_node("XRCamera3D")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _capsule: CapsuleShape3D
var _last_height: float = -1.0

func _ready() -> void:
	add_to_group("PlayerBody")
	collision_layer = 1
	collision_mask = 4
	_capsule = collision_shape.shape as CapsuleShape3D
	if _capsule:
		_capsule.radius = hurtbox_radius

func _physics_process(_delta: float) -> void:
	if camera == null:
		return
	var tracked_height := clampf(camera.position.y, minimum_height, maximum_height)
	position.x = camera.position.x
	position.z = camera.position.z
	position.y = tracked_height * 0.5
	if _capsule and absf(tracked_height - _last_height) > 0.01:
		_last_height = tracked_height
		_capsule.height = tracked_height
