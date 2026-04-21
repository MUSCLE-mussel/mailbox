extends Node
class_name _GameInput

const TAP_TIME_THRESHOLD = 0.1
const DEBUG = false

# public
class Touch:
	var index: int
	var position: Vector2
	var duration: float
	var drag_delta: Vector2
	var just_pressed: bool
	var just_released: bool
	var just_canceled: bool
	
	func is_down() -> bool:
		return !just_released && !just_canceled
	
var touch_stack: Array[Touch]

var has_just_tapped: bool
var tap_position: Vector2

var is_dragging: bool
var drag_delta: Vector2

# private
var frame_events: Array[InputEvent]

func get_first_touch() -> Touch:
	if touch_stack.size() == 0: return null
	return touch_stack[0]
	
func get_touch_by_index(index: int) -> Touch:
	for touch in touch_stack:
		if touch.index == index: return touch
	return null

func _input(event):
	if event is InputEventScreenTouch:
		frame_events.append(event)
	if event is InputEventScreenDrag:
		frame_events.append(event)
	pass

func _process(delta: float) -> void:
	# clear released events from last frame
	touch_stack = touch_stack.filter(is_touch_valid)
	
	# clear/update one frame values
	for i in touch_stack.size():
		touch_stack[i].just_pressed = false
		touch_stack[i].drag_delta = Vector2.ZERO
		touch_stack[i].duration += delta
	
	# unpile current frame events
	for event in frame_events:
		if event is InputEventScreenTouch:
			# Touch press
			if event.pressed:
				var touch: = Touch.new()
				touch.index = event.index
				touch.position = event.position
				touch.just_pressed = true
				touch_stack.append(touch)
				if DEBUG:
					print("pressed:", touch.index, touch.position)
				continue
				
			# Touch release / cancel
			for touch in touch_stack:
				if touch.index == event.index:
					touch.position = event.position
					if not event.pressed:
						touch.just_released = true
						if DEBUG:
							print("released:", touch.index, touch.position)
					elif event.canceled:
						touch.just_canceled = true
						if DEBUG:
							print("canceled:", touch.index, touch.position)
			continue
		elif event is InputEventScreenDrag:
			for touch in touch_stack:
				if touch.index == event.index:
					touch.drag_delta = event.position - touch.position
					touch.position = event.position
	frame_events.clear()
	
	# Process touch stack into convenient data
	has_just_tapped = false
	for i in touch_stack.size():
		var touch = touch_stack[i]
		if touch.just_released && touch.duration <= TAP_TIME_THRESHOLD && touch.drag_delta == Vector2.ZERO:
			has_just_tapped = true
			tap_position = touch.position
			if DEBUG:
				print("tap:", touch.index, tap_position)
				
	is_dragging = false
	if touch_stack.size() > 0:
		is_dragging = true
		drag_delta = touch_stack[0].drag_delta
	
func is_touch_valid(touch: Touch):
	return !touch.just_released && !touch.just_canceled
