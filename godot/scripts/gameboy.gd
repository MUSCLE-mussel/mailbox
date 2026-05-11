extends Item

@export var dpad_left_area: Area3D
@export var dpad_right_area: Area3D
@export var dpad_up_area: Area3D
@export var dpad_down_area: Area3D
@export var a_area: Area3D
@export var b_area: Area3D
@export var power_switch_area: Area3D

@export var button1_down_sound: AudioStream
@export var button1_up_sound: AudioStream
@export var button2_down_sound: AudioStream
@export var button2_up_sound: AudioStream
@export var power_on_sound: AudioStream
@export var power_off_sound: AudioStream

@export var animation_tree: AnimationTree
@export var gameboy_game: GameboyGame

@export var physics_impact_sound_min_impulse: float
@export var physics_impact_sound_max_impulse: float
@export var physics_impact_sound: AudioStream

var buttons_enabled: bool = false

var power_on: bool = false
var power_switch_tween: Tween
var power_switch_ratio: float # needs the proxy otherwise we can't play the animation backwards

class ButtonState:
	var touch_index: int = -1
	var ratio: float
	var property: StringName

var a_state: ButtonState
var b_state: ButtonState
var dpad_up_state: ButtonState
var dpad_down_state: ButtonState
var dpad_left_state: ButtonState
var dpad_right_state: ButtonState

var buttons: Array[ButtonState]

var previous_game_input: GameboyGame.GameboyInput

const BUTTON_PRESS_DURATION: = 0.07
const BUTTON_RELEASE_DURATION := 0.27

const POWER_ON_DURATION: = 0.1
const POWER_OFF_DURATION: = 0.4

func _ready():
	a_state = ButtonState.new()
	b_state = ButtonState.new()
	dpad_up_state = ButtonState.new()
	dpad_down_state = ButtonState.new()
	dpad_left_state = ButtonState.new()
	dpad_right_state = ButtonState.new()
	a_state.property = &"parameters/a/seek_request"
	b_state.property = &"parameters/b/seek_request"
	dpad_up_state.property = &"parameters/dpad_up/seek_request"
	dpad_down_state.property = &"parameters/dpad_down/seek_request"
	dpad_left_state.property = &"parameters/dpad_left/seek_request"
	dpad_right_state.property = &"parameters/dpad_right/seek_request"
	buttons.append(a_state)
	buttons.append(b_state)
	buttons.append(dpad_up_state)
	buttons.append(dpad_down_state)
	buttons.append(dpad_left_state)
	buttons.append(dpad_right_state)
	
	previous_game_input = GameboyGame.GameboyInput.new()

func on_focus_gained():
	buttons_enabled = true
	
func on_focus_lost():
	buttons_enabled = false
	reset()

func reset():
	power_switch_ratio = 0.0
	
	for button in buttons:
		button.touch_index = -1
		button.ratio = 0.0
		animation_tree.set(button.property, 0.0)
		
	animation_tree.set(&"parameters/power_switch/seek_request", 0.0)
	power_on = false
	if power_switch_tween != null:
		power_switch_tween.kill()
		power_switch_tween = null
		
	gameboy_game.set_state(GameboyGame.State.OFF)

func _process(dt: float) -> void:
	
	process_input()
		
	# Update animations
	for button in buttons:
		button.ratio = Tools.time_independent_lerp(button.ratio, 1.0 if button.touch_index >= 0 else 0.0, BUTTON_PRESS_DURATION if button.touch_index >= 0 else BUTTON_RELEASE_DURATION, dt)
		animation_tree.set(button.property, button.ratio)
	
	animation_tree.set(&"parameters/power_switch/seek_request", power_switch_ratio)
	
	# Update game
	var game_input: = GameboyGame.GameboyInput.new()
	game_input.a = a_state.touch_index >= 0
	game_input.b = b_state.touch_index >= 0
	game_input.dpad_up = dpad_up_state.touch_index >= 0
	game_input.dpad_down = dpad_down_state.touch_index >= 0
	game_input.dpad_left = dpad_left_state.touch_index >= 0
	game_input.dpad_right = dpad_right_state.touch_index >= 0
	gameboy_game.update(game_input, dt)
	
	# Sound
	var button_01_down = func(): AudioManager.play_3d_sound(button1_down_sound, global_position)
	var button_01_up = func(): AudioManager.play_3d_sound(button1_up_sound, global_position)
	var button_02_down = func(): AudioManager.play_3d_sound(button2_down_sound, global_position)
	var button_02_up = func(): AudioManager.play_3d_sound(button2_up_sound, global_position)
	
	if !previous_game_input.a && game_input.a: button_01_down.call()
	if !previous_game_input.b && game_input.b: button_01_down.call()
	if !previous_game_input.dpad_up && game_input.dpad_up: button_02_down.call()
	if !previous_game_input.dpad_down && game_input.dpad_down: button_02_down.call()
	if !previous_game_input.dpad_left && game_input.dpad_left: button_02_down.call()
	if !previous_game_input.dpad_right && game_input.dpad_right: button_02_down.call()
	
	if previous_game_input.a && !game_input.a: button_01_up.call()
	if previous_game_input.b && !game_input.b: button_01_up.call()
	if previous_game_input.dpad_up && !game_input.dpad_up: button_02_up.call()
	if previous_game_input.dpad_down && !game_input.dpad_down: button_02_up.call()
	if previous_game_input.dpad_left && !game_input.dpad_left: button_02_up.call()
	if previous_game_input.dpad_right && !game_input.dpad_right: button_02_up.call()

	# End frame
	previous_game_input = game_input

func process_input():
	
	# reset state
	is_consuming_input = false
	
	if !buttons_enabled: return
	
	if GameInput.has_just_tapped:
		var tap_area: = Tools.get_collision_under_screen_position(GameInput.tap_position, 0b0000_0011)
		if tap_area == power_switch_area:
			toggle_power()
			
	for button in buttons:
		var touch: = GameInput.get_touch_by_index(button.touch_index)
		if touch == null:
			button.touch_index = -1
		else:
			is_consuming_input = true
	
	for touch in GameInput.touch_stack:
		if touch.just_pressed:
			var touch_area: = Tools.get_collision_under_screen_position(touch.position, 0b0000_0011)
			match touch_area:
				a_area:
					a_state.touch_index = touch.index
					is_consuming_input = true
				b_area:
					b_state.touch_index = touch.index
					is_consuming_input = true
				dpad_up_area:
					dpad_up_state.touch_index = touch.index
					is_consuming_input = true
				dpad_down_area:
					dpad_down_state.touch_index = touch.index
					is_consuming_input = true
				dpad_left_area:
					dpad_left_state.touch_index = touch.index
					is_consuming_input = true
				dpad_right_area:
					dpad_right_state.touch_index = touch.index
					is_consuming_input = true

func toggle_power():
	if power_on:
		turn_power_off()
	else:
		turn_power_on()

func turn_power_on():
	if power_switch_tween != null:
		power_switch_tween.kill()
	power_switch_tween = get_tree().create_tween()
	power_switch_tween.tween_property(self, "power_switch_ratio", 1.0, POWER_ON_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	power_switch_tween.finished.connect(on_power_on)
	AudioManager.play_3d_sound(power_on_sound, global_position)
	power_on = true
	

func turn_power_off():
	if power_switch_tween != null:
		power_switch_tween.kill()
	power_switch_tween = get_tree().create_tween()
	power_switch_tween.tween_property(self, "power_switch_ratio", 0.0, POWER_OFF_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)\
		.from_current()
	
	gameboy_game.set_state(GameboyGame.State.OFF)
	AudioManager.play_3d_sound(power_off_sound, global_position)
	power_on = false	
	
func on_power_on():
	gameboy_game.set_state(GameboyGame.State.TITLE)
	
func _integrate_forces(state: PhysicsDirectBodyState3D):
	
	# Play sound on impact
	for i in state.get_contact_count():
		var impulse_length: = state.get_contact_impulse(i).length()
		var t: = clampf((impulse_length - physics_impact_sound_min_impulse) / (physics_impact_sound_max_impulse - physics_impact_sound_min_impulse), 0.0, 1.0)
		
		if t > 0:
			#print(impulse_length)
			var contact_position: = global_transform * state.get_contact_local_position(0)
			var player: = AudioManager.play_3d_sound(physics_impact_sound, contact_position)
			player.volume_linear = remap(t, 0.0, 1.0, 0.5, 1.0)
