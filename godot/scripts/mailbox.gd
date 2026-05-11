extends Node3D
class_name Mailbox

@export var animation_player: AnimationPlayer
@export var content_parent: Node3D
@export var closed_collider: CollisionShape3D
@export var opened_collider: CollisionShape3D

@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var closed_sound: AudioStream

var playing_sound: AudioStreamPlayer3D

enum State {
	NONE,
	DISABLED,
	ENABLED,
}


var current_state: State = State.NONE

var can_open: bool = true
var opened: bool = false

func set_state(state: State):
	if current_state == state: return
	
	# exit state
	match current_state:
		State.DISABLED:
			visible = true
	
	current_state = state
	
	# enter state
	match current_state:
		State.DISABLED:
			visible = false
			closed_collider.disabled = true
			opened_collider.disabled = true
			
func _ready():
	animation_player.animation_finished.connect(on_animation_finished)

func _process(delta: float) -> void:
	
	match current_state:
		State.ENABLED:
			if can_open:
				if GameInput.has_just_tapped:
					var area = Tools.get_collision_under_screen_position(GameInput.tap_position, 0b0000_0001) # mailbox + box
					if area != null: 
						var hit_mailbox: = Tools.find_parent_by_type(area, "Mailbox") as Mailbox
						if hit_mailbox == self:
							if opened:
								close()
							else:
								open()
		

func set_closed():
	animation_player.play(&"closed")
	opened = false
	closed_collider.disabled = false
	opened_collider.disabled = true
	
func set_opened():
	animation_player.play(&"opened")
	opened = true
	closed_collider.disabled = true
	opened_collider.disabled = false
	
func open():
	animation_player.play(&"open", -1, 1.4)
	opened = true
	closed_collider.disabled = true
	opened_collider.disabled = false
	
	if playing_sound != null:
		playing_sound.queue_free()
	playing_sound = AudioManager.play_3d_sound(open_sound, global_position)
	AudioManager.randomize_pitch(playing_sound, 0.95, 1.0)
	
	
func close():
	animation_player.play(&"open", -1, -2.0, true)
	opened = false
	closed_collider.disabled = false
	opened_collider.disabled = true
	
	if playing_sound != null:
		playing_sound.queue_free()
	playing_sound = AudioManager.play_3d_sound(close_sound, global_position)
	AudioManager.randomize_pitch(playing_sound, 0.95, 1.0)

func on_animation_finished(anim_name: StringName):
	if anim_name == &"open" && animation_player.current_animation_position <= 0.0:
		var player : = AudioManager.play_3d_sound(closed_sound, global_position)
		AudioManager.randomize_pitch(player, 0.95, 1.0)
