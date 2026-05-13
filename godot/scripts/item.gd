extends Node3D
class_name Item

@export var viewing_base_rotation: Vector3
@export var viewing_base_scale: Vector3 = Vector3.ONE
@export var can_rotate: bool

var is_focused: bool
var is_consuming_input: bool

func on_focus_gained():
	pass
	
func on_focus_lost():
	pass

func get_base_viewing_transform() -> Transform3D:
	return Transform3D(Basis(Quaternion.from_euler(viewing_base_rotation)).scaled(viewing_base_scale))
