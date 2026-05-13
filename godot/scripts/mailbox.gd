extends Item
class_name Mailbox

@export_group("nodes")
@export var rigidbody: RigidBody3D
@export var door_collider: Node3D
@export var door_collider_anchor: Node3D
@export var animation_player: AnimationPlayer
@export var content_parent: Node3D

@export_group("sound")
@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var closed_sound: AudioStream

var playing_sound: AudioStreamPlayer3D
var can_open: bool = true
var opened: bool = false

func _ready():
	animation_player.animation_finished.connect(on_animation_finished)

func _process(delta: float) -> void:
	
	# sync door collider
	door_collider.global_transform = door_collider_anchor.global_transform
	
	# check open input
	if can_open && is_focused && GameInput.has_just_tapped:
		var collision = Tools.get_collision_under_screen_position(GameInput.tap_position, 0b0000_0111)
		if collision == self: 
			if opened:
				close()
			else:
				open()
		

func set_closed():
	animation_player.play(&"closed")
	opened = false
	
func set_opened():
	animation_player.play(&"opened")
	opened = true
	
func open():
	animation_player.play(&"open", -1, 1.4)
	opened = true
	
	if playing_sound != null:
		playing_sound.queue_free()
	playing_sound = AudioManager.play_3d_sound(open_sound, global_position)
	AudioManager.randomize_pitch(playing_sound, 0.95, 1.0)
	
	
func close():
	animation_player.play(&"open", -1, -2.0, true)
	opened = false
	
	if playing_sound != null:
		playing_sound.queue_free()
	playing_sound = AudioManager.play_3d_sound(close_sound, global_position)
	AudioManager.randomize_pitch(playing_sound, 0.95, 1.0)

func on_animation_finished(anim_name: StringName):
	if anim_name == &"open" && animation_player.current_animation_position <= 0.0:
		var player : = AudioManager.play_3d_sound(closed_sound, global_position)
		AudioManager.randomize_pitch(player, 0.95, 1.0)
