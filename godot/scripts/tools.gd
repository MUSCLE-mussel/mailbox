extends Node
class_name _Tools

func find_parent_by_type(node: Node, clss_name: String, recursive: bool = true) -> Node:
	var parent: = node.get_parent()
	if parent != null:
		if does_script_inherit_from(parent.get_script(), clss_name):
			return parent
		if parent.is_class(clss_name) || get_class_name(parent) == clss_name:
			return parent
		if recursive:
			return find_parent_by_type(parent, clss_name, true)
	return null

func does_script_inherit_from(script: Script, clss_name: String, check_self: bool = true) -> bool:
	if script == null:
		return false
	if check_self && script.get_global_name() == clss_name:
		return true
	return does_script_inherit_from(script.get_base_script(), clss_name)
	
func get_class_name(object: Object) -> String:
	if not object:
		return type_string(TYPE_NIL)
	var script: Script = object.get_script()
	var object_name := script.get_global_name() as String if script else object.get_class()
	if object_name.is_empty():
		var script_path := script.resource_path
		if script_path.is_empty():
			push_error("Cannot get class name from inner classes")
		return script_path
	return object_name
	
func get_collision_under_screen_position(pos: Vector2, collision_mask: int = 0xFFFFFFFF, camera: Camera3D = null, ray_length: float = 100.0) -> CollisionObject3D:
	if camera == null:
		camera = get_viewport().get_camera_3d()
	var ray_origin: = camera.project_ray_origin(pos)
	var ray_normal: = camera.project_ray_normal(pos)
	var query: = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_normal * ray_length, collision_mask)
	query.collide_with_areas = true
	var result: = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return result.get("collider") as CollisionObject3D

#   Calculate the line segment result_A > result_BtB that is the shortest route between
#   two lines A and B. Calculate also the values of ratio_A and ratio_B where
#	  result_A = A1 + ratio_A (A2 - A1)
#	  result_B = B1 + ratio_B (B2 - B1)
#   Return false if no solution exists.
class ShortestRouteResult:
	var success: bool
	var result_A: Vector3
	var result_B: Vector3
	var ratio_A: float
	var ratio_B: float

func line_line_shortest_route(A1: Vector3, A2: Vector3, B1: Vector3, B2: Vector3) -> ShortestRouteResult:
	var result: = ShortestRouteResult.new()
	result.success = false
	
	# NOTE(Remi|2020/01/10): Algorithm found here: http://paulbourke.net/geometry/pointlineplane/
	var p13: = A1 - B1
	var p43: = B2 - B1
	if p43.is_equal_approx(Vector3.ZERO):
		return result;
	var p21: = A2 - A1;
	if p21.is_equal_approx(Vector3.ZERO):
		return result;

	var d1343: = p13.x * p43.x + p13.y * p43.y + p13.z * p43.z;
	var d4321: = p43.x * p21.x + p43.y * p21.y + p43.z * p21.z;
	var d1321: = p13.x * p21.x + p13.y * p21.y + p13.z * p21.z;
	var d4343: = p43.x * p43.x + p43.y * p43.y + p43.z * p43.z;
	var d2121: = p21.x * p21.x + p21.y * p21.y + p21.z * p21.z;

	var denom: = d2121 * d4343 - d4321 * d4321;
	if is_equal_approx(denom, 0.0):
		return result;
		
	result.success = true;
	
	var numer: = d1343 * d4321 - d1321 * d4343;

	result.ratio_A = numer / denom;
	result.ratio_B = (d1343 + d4321 * (result.ratio_A)) / d4343;

	result.result_A = A1 + p21 * result.ratio_A;
	result.result_B = B1 + p43 * result.ratio_B;

	return result
	
# NOTE(Remi|2019/05/30): See http://www.rorydriscoll.com/2016/03/07/frame-rate-independent-damping-using-lerp/
func time_independent_lerp(base: float, target: float, time_to_90: float, dt: float) -> float:
	if time_to_90 <= 0: return target
	var lambda: = -log(1.0 - 0.9) / time_to_90
	return lerp(base, target, 1.0 - exp(-lambda * dt))
	
func time_independent_lerp_vec2(base: Vector2, target: Vector2, time_to_90: float, dt: float) -> Vector2:
	return Vector2(
		time_independent_lerp(base.x, target.x, time_to_90, dt),
		time_independent_lerp(base.y, target.y, time_to_90, dt)
	)
	
func time_independent_lerp_vec3(base: Vector3, target: Vector3, time_to_90: float, dt: float) -> Vector3:
	return Vector3(
		time_independent_lerp(base.x, target.x, time_to_90, dt),
		time_independent_lerp(base.y, target.y, time_to_90, dt),
		time_independent_lerp(base.z, target.z, time_to_90, dt)
	)

func draw_collision_shape_3d(collision_shape: CollisionShape3D, color: Color = Color.RED):
	if collision_shape.shape == null: return
	
	var position: = collision_shape.global_position
	var rotation: = collision_shape.global_basis.get_rotation_quaternion()
	var scale: = collision_shape.global_basis.get_scale()
	
	if collision_shape.shape is BoxShape3D:
		var box: = collision_shape.shape as BoxShape3D
		DebugDraw3D.draw_box(position, rotation, box.size * scale, color, true)
		
