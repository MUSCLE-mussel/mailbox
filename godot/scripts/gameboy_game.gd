extends Node2D
class_name GameboyGame

@export var title: Node2D
@export var title_sound: AudioStream
@export var sound_position: Node3D
@export var background_off: CanvasItem

class GameboyInput:
	var a: bool
	var b: bool
	var dpad_left: bool
	var dpad_right: bool
	var dpad_up: bool
	var dpad_down: bool
	
enum State {
	OFF,
	TITLE,
	GAME,
}

var current_state : State
var title_start_position: Vector2
var timer: int

var previous_input: GameboyInput
var on: bool
var time_accumulator: float
const FRAME_TIME: = 1.0 / 59.727500569606 # actual gameboy framerate. may be a shitty idea though

func _ready():
	title_start_position = title.position
	background_off.visible = true

func set_state(state: State):
	if state == current_state: return
	
	match current_state:
		State.OFF:
			background_off.visible = false
		State.TITLE:
			title.visible = false
	
	current_state = state
	
	match current_state:
		State.OFF:
			background_off.visible = true
			time_accumulator = 0.0
		State.TITLE:
			title.visible = true
			title.position = title_start_position
			timer = 0

func turn_on():
	set_state(State.TITLE)
	
func turn_off():
	set_state(State.OFF)
	
func update(input: GameboyInput, dt: float):
	if current_state == State.OFF: return
	
	time_accumulator += dt
	while time_accumulator > FRAME_TIME:
		advance_frame(input)
		time_accumulator -= FRAME_TIME
	
	previous_input = input

func advance_frame(input: GameboyInput):
	match current_state:
		State.TITLE:
			
			const TITLE_END_HEIGHT: = 72
			
			if title.position.y < TITLE_END_HEIGHT:
				title.position.y += 1
			else:
				if timer == 0:
					AudioManager.play_3d_sound(title_sound, sound_position.global_position)
				timer += 1
				if timer >= 90:
					#set_state(State.GAME)
					pass
