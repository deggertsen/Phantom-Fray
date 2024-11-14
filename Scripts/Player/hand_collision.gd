extends XRController3D

signal punch_hit(velocity: float)

@onready var punch_area: Area3D = $PunchArea

func _ready():
    # Create collision area if it doesn't exist
    if !punch_area:
        punch_area = Area3D.new()
        var collision_shape = CollisionShape3D.new()
        var sphere_shape = SphereShape3D.new()
        sphere_shape.radius = 0.05  # Small sphere for punch detection
        collision_shape.shape = sphere_shape
        punch_area.add_child(collision_shape)
        add_child(punch_area)
    
    # Set collision layer and mask
    punch_area.collision_layer = 2  # Layer 2 for hands
    punch_area.collision_mask = 4   # Layer 3 for phantoms
    
    # Connect area signals
    punch_area.body_entered.connect(_on_punch_area_body_entered)

func _physics_process(delta):
    if is_button_pressed("grip_click"):
        # Calculate punch velocity when gripping
        var velocity = linear_velocity.length()
        if velocity > 1.0:  # Minimum velocity threshold
            punch_area.set_meta("current_velocity", velocity)

func _on_punch_area_body_entered(body: Node3D):
    if body.is_in_group("phantom"):
        var velocity = punch_area.get_meta("current_velocity", 0.0)
        if velocity > 1.0:  # Only register as hit if moving fast enough
            emit_signal("punch_hit", velocity)
            body.handle_punch(velocity, global_position)