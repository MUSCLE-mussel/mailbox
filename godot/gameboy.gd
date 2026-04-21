extends Item

@export var dpad_left_collider: CollisionShape3D
@export var dpad_right_collider: CollisionShape3D
@export var dpad_up_collider: CollisionShape3D
@export var dpad_down_collider: CollisionShape3D
@export var a_collider: CollisionShape3D
@export var b_collider: CollisionShape3D

var buttons_enabled: bool = false

func on_focus_gained():
	buttons_enabled = true
	
func on_focus_lost():
	buttons_enabled = false

func _process(delta: float) -> void:
	if !buttons_enabled: return
	
	
