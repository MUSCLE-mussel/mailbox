extends Node3D
class_name Box

@export var animation_player: AnimationPlayer
@export var content_parent: Node3D
@export var unlock_path: Path3D
@export var animation_tree: AnimationTree
@export var interaction_radius: float = 0.15
@export var tape_smooth_time: float = 0.1
@export var flap_open_time: float = 1.0
@export var flap_close_time: float = 1.0

@export var viewing_base_rotation: Vector3
@export var viewing_base_scale: Vector3 = Vector3.ONE

@export var flap_l_area: CollisionObject3D
@export var flap_r_area: CollisionObject3D
@export var flap_f_area: CollisionObject3D
@export var flap_b_area: CollisionObject3D

@export var clickable_collider: CollisionShape3D

@export var foam_spawner: FoamSpawner

@export var flap_sounds: AudioStream
@export var tape_audio_player: AudioStreamPlayer3D

var can_unlock: bool = false
var is_unlocked: bool = false

var unlocking_touch_index: int = -1

var current_unlock_ratio: float = 0.0
var target_unlock_ratio: float = 0.0

var tape_open_animation_length: float

class FlapData:
	var open: bool
	var tween: Tween
	var property: String
	var sound: AudioStreamPlayer3D

var flap_l: FlapData
var flap_r: FlapData
var flap_f: FlapData
var flap_b: FlapData

var tape_disable_tween: Tween

func _ready():
	var tape_open_animation: = animation_player.get_animation(&"unlock")
	if tape_open_animation != null:
		tape_open_animation_length = tape_open_animation.length
	else:
		push_error("cant find box unlock animation")
	
	flap_l = FlapData.new()
	flap_l.property = "parameters/flap_l/blend_amount"
	flap_r = FlapData.new()
	flap_r.property = "parameters/flap_r/blend_amount"
	flap_f = FlapData.new()
	flap_f.property = "parameters/flap_f/blend_amount"
	flap_b = FlapData.new()
	flap_b.property = "parameters/flap_b/blend_amount"
	
	reset()
	
# HACK: scale is not applied to PhysicalBones, so we have to do it manually
func _physics_process(dt: float):
	flap_l_area.get_child(0).scale = global_basis.get_scale()
	flap_r_area.get_child(0).scale = global_basis.get_scale()
	flap_f_area.get_child(0).scale = global_basis.get_scale()
	flap_b_area.get_child(0).scale = global_basis.get_scale()

func _process(dt: float):
	
	update_tape_interaction()
	
	#Tools.draw_collision_shape_3d(flap_l_area.get_child(0) as CollisionShape3D)
	#Tools.draw_collision_shape_3d(flap_r_area.get_child(0) as CollisionShape3D)
	#Tools.draw_collision_shape_3d(flap_f_area.get_child(0) as CollisionShape3D)
	#Tools.draw_collision_shape_3d(flap_b_area.get_child(0) as CollisionShape3D)
			
	# update tape visual
	var target: = target_unlock_ratio
	if unlocking_touch_index >= 0:
		target = max(target, 0.05)
	var previous_unlock_ratio = current_unlock_ratio
	current_unlock_ratio = Tools.time_independent_lerp(current_unlock_ratio, target, tape_smooth_time, dt)
	animation_tree.set(&"parameters/tape_seek/seek_request", tape_open_animation_length * current_unlock_ratio)
	
	# Audio
	var unlock_speed = abs(current_unlock_ratio - previous_unlock_ratio) / dt
	tape_audio_player.volume_linear = clamp(remap(unlock_speed, 0.3, 3.0, 0.0, 1.0), 0.0, 1.0)
	#tape_audio_player.pitch_scale = remap(current_unlock_ratio, 0.0, 1.0, 0.9, 1.2)
	
	if is_unlocked:
		if GameInput.has_just_tapped:
			var area = Tools.get_collision_under_screen_position(GameInput.tap_position, 0b0000_0111)
			
			match area:
				flap_l_area:
					if !flap_l.open:
						open_flap(flap_l)
					else:
						close_flap(flap_l)
						
				flap_r_area:
					if !flap_r.open:
						open_flap(flap_r)
					else:
						close_flap(flap_r)
						
				flap_f_area:
					if !flap_f.open:
						open_flap(flap_f)
					else:
						close_flap(flap_f)
						
				flap_b_area:
					if !flap_b.open:
						open_flap(flap_b)
					else:
						close_flap(flap_b)

func reset():
	can_unlock = false
	is_unlocked = false
	current_unlock_ratio = 0.0
	target_unlock_ratio = 0.0
	unlocking_touch_index = -1
	animation_tree.set(&"parameters/tape_disable/add_amount", 0.0)
	animation_tree.set(&"parameters/tape_seek/seek_request", -1.0)
	
	if tape_disable_tween != null:
		tape_disable_tween.kill()
		tape_disable_tween = null
	
	reset_flap(flap_l)
	reset_flap(flap_r)
	reset_flap(flap_f)
	reset_flap(flap_b)
	
	foam_spawner.clear_spawned_foam()

func update_tape_interaction():
	if is_unlocked || !can_unlock:
		unlocking_touch_index = -1
		return
	
	if unlocking_touch_index < 0 && current_unlock_ratio > 0.95:
		tape_disable_tween = get_tree().create_tween()
		tape_disable_tween.tween_property(animation_tree, "parameters/tape_disable/add_amount", 1.0, 0.2)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
		target_unlock_ratio = 1.0
		is_unlocked = true
		return
	
	if GameInput.touch_stack.size() == 0:
		unlocking_touch_index = -1
		return

	var touch: = GameInput.touch_stack[0]
	
	# temp wonky solution to prevent untaping from behind
	var tape_normal: = unlock_path.global_transform * unlock_path.curve.sample_baked_up_vector(0.0)
	var camera_normal: = get_viewport().get_camera_3d().project_ray_normal(touch.position)
	var is_tape_facing_away: bool = camera_normal.dot(tape_normal) >= 0
	if is_tape_facing_away:
		unlocking_touch_index = -1
		return
	
	var l: = unlock_path.curve.get_baked_length()
	var path_begin: = unlock_path.global_transform * unlock_path.curve.get_point_position(0);
	var path_end: = unlock_path.global_transform * unlock_path.curve.get_point_position(unlock_path.curve.point_count-1);
		
	var camera: Camera3D = get_viewport().get_camera_3d()
	var ray_origin: = camera.project_ray_origin(touch.position)
	var ray_normal: = camera.project_ray_normal(touch.position) * 100
	
	#DebugDraw3D.draw_line(path_begin, path_end)
	
	var result: = Tools.line_line_shortest_route(ray_origin, ray_origin + ray_normal, path_begin, path_end)
	if !result.success:
		unlocking_touch_index = -1
		return
		
	#DebugDraw3D.draw_sphere(result.result_B, 0.1)
	#DebugDraw3D.draw_sphere(result.result_A, 0.1)
	
	if unlocking_touch_index < 0:
		var offset = max(current_unlock_ratio * l, interaction_radius * unlock_path.global_transform.basis.get_scale().x) # small UX tweak for initial interaction that is off visual at 0
		var current_unlock_point: = unlock_path.global_transform * unlock_path.curve.sample_baked(offset)
		if touch.just_pressed && result.result_A.distance_to(current_unlock_point) <= interaction_radius:
			unlocking_touch_index = touch.index
	else:
		if touch.index != unlocking_touch_index || touch.just_released || touch.just_canceled:
			unlocking_touch_index = -1
			
	if unlocking_touch_index >= 0:
		var path_offset: = unlock_path.curve.get_closest_offset(unlock_path.global_transform.affine_inverse() * result.result_B)
		#DebugDraw3D.draw_sphere(unlock_path.global_transform * unlock_path.curve.sample_baked(path_offset), 0.1, Color.BISQUE)
		target_unlock_ratio = path_offset / l

func get_base_viewing_transform() -> Transform3D:
	return Transform3D(Basis(Quaternion.from_euler(viewing_base_rotation)).scaled(viewing_base_scale))
	
func reset_flap(flap: FlapData):
	flap.open = false
	if flap.tween != null:
		flap.tween.kill()
		flap.tween = null
	if flap.sound != null:
		flap.sound.queue_free()
	animation_tree.set(flap.property, 0.0)
		
func open_flap(flap: FlapData):
	if flap.tween != null: flap.tween.kill()
	flap.tween = get_tree().create_tween()
	flap.tween.tween_property(animation_tree, flap.property, 1.0, flap_open_time)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)
	if flap.sound != null:
		flap.sound.queue_free()
	flap.sound = AudioManager.play_3d_sound(flap_sounds, global_position)
	flap.open = true
	
func close_flap(flap: FlapData):
	if flap.tween != null: flap.tween.kill()
	flap.tween = get_tree().create_tween()
	flap.tween.tween_property(animation_tree, flap.property, 0.0, flap_close_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	if flap.sound != null:
		flap.sound.queue_free()
	flap.sound = AudioManager.play_3d_sound(flap_sounds, global_position)
	flap.open = false
	
func set_flap_opened(flap: FlapData):
	if flap.tween != null: flap.tween.kill()
	flap.tween = null
	if flap.sound != null:
		flap.sound.queue_free()
	animation_tree.set(flap.property, 1.0)
	flap.open = true
	
func set_all_flaps_opened():
	set_flap_opened(flap_l)
	set_flap_opened(flap_r)
	set_flap_opened(flap_f)
	set_flap_opened(flap_b)
	
func are_all_flaps_opened():
	return flap_l.open && flap_r.open && flap_f.open && flap_b.open
	
func is_any_flap_opened():
	return flap_l.open || flap_r.open || flap_f.open || flap_b.open
	
func set_tape_unlocked():
	is_unlocked = true
	current_unlock_ratio = 1.0
	target_unlock_ratio = 1.0
	unlocking_touch_index = -1
	animation_tree.set(&"parameters/tape_disable/add_amount", 1.0)
	animation_tree.set(&"parameters/tape_seek/seek_request", 1.0)
