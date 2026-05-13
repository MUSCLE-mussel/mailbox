extends Node
class_name ObjectViewer

@export var target: Node3D
@export var camera: Camera3D
@export var drag_speed: Vector2 = Vector2(1,1);
@export var physics_drag_speed: Vector2 = Vector2(1,1);
@export var drag_smooth_time: float = 0.05;
@export var sample_count: int = 10;
@export var max_input: float = 3.0
@export var foley_input_threshold: float = 1.0

@export var foley_sounds: AudioStream

var play_sounds: bool = false
var current_foley: AudioStreamPlayer3D

class InputSample:
	var input: Vector2
	var dt: float

var samples: Array[InputSample]

var smoothed_drag_input: Vector2
var previous_smoothed_drag_input: Vector2
var previous_is_dragging: bool

func update(delta: float, is_dragging: bool, input: Vector2):
	if target == null: return
	if camera == null: return
	
	previous_smoothed_drag_input = smoothed_drag_input
	
	if is_dragging:
		# we average samples cause zero inputs are inserted before release in the input on some devices and it kills momentum
		var sample: = InputSample.new()
		sample.input = input
		sample.dt = delta
		samples.append(sample)
		while samples.size() > sample_count:
			samples.pop_front()
			
		var total_time: float = 0.0
		var average_input: Vector2 = Vector2.ZERO
		for s in samples:
			total_time += s.dt
			
		for s in samples:
			average_input += (s.dt / total_time) * s.input
		
		var input_length: = average_input.length()
		if  input_length > max_input:
			average_input = average_input / input_length * max_input
		
		smoothed_drag_input = average_input
	else:
		samples.clear()
		smoothed_drag_input = Tools.time_independent_lerp_vec2(smoothed_drag_input, Vector2.ZERO, drag_smooth_time, delta)
		
	
	#print("%.2f, %s %v"%[delta, is_dragging, input])
	
	var target_rigidbody: = target as RigidBody3D
	
	var x_axis = camera.get_camera_transform().basis.y
	var y_axis = camera.get_camera_transform().basis.x
	
	if target_rigidbody == null:
		target.rotate(x_axis, smoothed_drag_input.x * drag_speed.x)
		target.rotate(y_axis, smoothed_drag_input.y * drag_speed.y)
	else:
		var torque: Vector3 = x_axis * smoothed_drag_input.x * physics_drag_speed.x + y_axis * smoothed_drag_input.y * physics_drag_speed.y
		#print(torque)
		target_rigidbody.apply_torque(torque)
		#target_rigidbody.angular_velocity = clamp(target_rigidbody.angular_velocity, Vector3(-max_angular_velocity, -max_angular_velocity, -max_angular_velocity), Vector3(max_angular_velocity, max_angular_velocity, max_angular_velocity))
		
	# Sound
	if play_sounds:
		var should_play_foley: = false
		should_play_foley = should_play_foley || (smoothed_drag_input.length() >= foley_input_threshold && current_foley == null)
		if should_play_foley:
			current_foley = AudioManager.play_3d_sound(foley_sounds, target.global_position)
		if current_foley != null:
			var t: float = (smoothed_drag_input.length() - foley_input_threshold) / (max_input - foley_input_threshold)
			#print(t)
			current_foley.volume_linear = max(current_foley.volume_linear, clampf(t, 0.1, 1.0))
	
	previous_is_dragging = is_dragging

func reset():
	smoothed_drag_input = Vector2.ZERO
