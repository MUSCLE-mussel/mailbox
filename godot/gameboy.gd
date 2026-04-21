extends Item

@export var dpad_left_area: Area3D
@export var dpad_right_area: Area3D
@export var dpad_up_area: Area3D
@export var dpad_down_area: Area3D
@export var a_area: Area3D
@export var b_area: Area3D
@export var power_switch_area: Area3D

@export var animation_tree: AnimationTree

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
	pass

func _process(dt: float) -> void:
	
	process_input()
		
	# Update animations
	for button in buttons:
		button.ratio = Tools.time_independent_lerp(button.ratio, 1.0 if button.touch_index >= 0 else 0.0, BUTTON_PRESS_DURATION if button.touch_index >= 0 else BUTTON_RELEASE_DURATION, dt)
		animation_tree.set(button.property, button.ratio)
	
	animation_tree.set(&"parameters/power_switch/seek_request", power_switch_ratio)
	

func process_input():
	
	# reset state
	is_consuming_input = false
	
	if !buttons_enabled: return
	
	if GameInput.has_just_tapped:
		var tap_area: = Tools.get_area_under_screen_position(GameInput.tap_position, 0b0000_1000)
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
			var touch_area: = Tools.get_area_under_screen_position(touch.position, 0b0000_1000)
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
	
	power_on = true
	

func turn_power_off():
	if power_switch_tween != null:
		power_switch_tween.kill()
	power_switch_tween = get_tree().create_tween()
	power_switch_tween.tween_property(self, "power_switch_ratio", 0.0, POWER_OFF_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)\
		.from_current()
	
	power_on = false	
	
