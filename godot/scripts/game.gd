extends Node3D
class_name Game

# UI
@export var notification_button: BaseButton;
@export var permissions_button: BaseButton;
@export var app_page_button: BaseButton;
@export var hello_world_button: BaseButton;
@export var reset_button: BaseButton;
@export var text: Label;
@export var delay_label: Label;
@export var delay_slider: HSlider;

@export var world: Node3D
@export var mailbox: Mailbox;
@export var gameboy: Item;
@export var box: Box;
@export var viewer: ObjectViewer
@export var viewing_parent: Node3D

@export var parcel_draw_sound: AudioStream

# Game state
enum GameState
{
	NONE,
	MAILBOX,
	PARCEL,
	OBJECT,
}
var current_state: GameState = GameState.NONE
var current_item: Item
var transition_tween: Tween = null

var mailbox_base_transform: Transform3D

# Android
const ANDROID_PLUGIN_NAME: = "MailboxAndroidPlugin"
var android_plugin: Object;

func _ready() -> void:
	Globals.game = self
	
	if Engine.has_singleton(ANDROID_PLUGIN_NAME):
		android_plugin = Engine.get_singleton(ANDROID_PLUGIN_NAME)
		android_plugin.connect("post_notifications_permission_result_received", on_post_notifications_permission_result_received)
	
	if android_plugin == null:
		notification_button.disabled = true;
		permissions_button.disabled = true;
		app_page_button.disabled = true;
		hello_world_button.disabled = true;
		delay_slider.editable = false;
	
	text.text = "uninitialized"
	notification_button.pressed.connect(on_notification_button_pressed)
	permissions_button.pressed.connect(on_permissions_button_pressed)
	app_page_button.pressed.connect(on_app_page_button_pressed)
	hello_world_button.pressed.connect(on_hello_world_button_pressed)
	reset_button.pressed.connect(on_reset_button_pressed)
	
	mailbox_base_transform = mailbox.transform
	
	# remove child of viewing_parent. They are useful to tune transforms in editor but they may fuck up raycasts and stuff runtime
	for n in viewing_parent.get_children():
		n.queue_free()
	
	update_delay_label()
	delay_slider.value_changed.connect(on_delay_value_changed)
	
	text.text = "initialiazing"
	
	mailbox.set_state(Mailbox.State.DISABLED)
	box.visible = false
	call_deferred("late_ready")
	
func late_ready():
	#set_state(GameState.OBJECT)
	#set_state(GameState.MAILBOX)
	set_state(GameState.PARCEL)
	
	#box.set_tape_unlocked()
	#box.set_all_flaps_opened()
	
func set_state(state: GameState):
	if state == current_state: return
	
	# Exit
	match current_state:
		GameState.MAILBOX:
			mailbox.set_state(Mailbox.State.DISABLED)
			
			box.clickable_collider.disabled = true
			box.visible = true
			if transition_tween != null:
				transition_tween.kill()
				transition_tween = null
			
		GameState.PARCEL:
			box.visible = false
			viewer.target = null
			viewer.play_sounds = false
			if transition_tween != null:
				transition_tween.kill()
				transition_tween = null
			gameboy.clickable_collider.disabled = true
			
		GameState.OBJECT:
			current_item.axis_lock_linear_x = false
			current_item.axis_lock_linear_y = false
			current_item.axis_lock_linear_z = false
			current_item.collision_mask = 0b0000_01110
			current_item.on_focus_lost()
			current_item = null
			viewer.target = null
	
	current_state = state
	
	# Enter
	match current_state:
		GameState.MAILBOX:
			mailbox.set_state(Mailbox.State.ENABLED)
			mailbox.can_open = true
			mailbox.set_closed()
			
			mailbox.transform = mailbox_base_transform
			
			# hack until objects are handled generically
			gameboy.reparent(box.content_parent, false)
			gameboy.transform = Transform3D.IDENTITY
			gameboy.freeze = true
			
			box.visible = true
			box.clickable_collider.disabled = false
			box.reparent(mailbox.content_parent, false)
			box.transform = Transform3D.IDENTITY
			box.reset()
			
		GameState.PARCEL:
			box.visible = true
			
			viewer.target = box
			viewer.play_sounds = true
			
			# hack until objects are handled generically
			gameboy.reparent(box.content_parent, false)
			gameboy.transform = Transform3D.IDENTITY
			gameboy.clickable_collider.disabled = false
			gameboy.freeze = true
			
			box.reparent(world, false)
			box.transform = viewing_parent.transform * box.get_base_viewing_transform()
			box.reset()
			box.can_unlock = true
			box.foam_spawner.spawn_foam()

			
		GameState.OBJECT:
			# hack for debug
			if current_item == null:
				current_item = gameboy
			assert(current_item != null)
			
			current_item.reparent(world, false)
			current_item.transform = viewing_parent.transform * current_item.get_base_viewing_transform()
			current_item.axis_lock_linear_x = true
			current_item.axis_lock_linear_y = true
			current_item.axis_lock_linear_z = true
			current_item.collision_mask = 0
			current_item.axis_lock_linear_z = true
			#current_item.angular_velocity = Vector3.ZERO
			
			viewer.target = current_item
			
			current_item.on_focus_gained()
	
func _process(delta: float) -> void:
	
	# Update state
	match current_state:
		GameState.MAILBOX:
			if transition_tween != null: return
			
			if GameInput.has_just_tapped:
				var area = Tools.get_collision_under_screen_position(GameInput.tap_position, 0b0000_0001)
				if area != null: 
					var hit_box: = Tools.find_parent_by_type(area, "Box") as Box
					if hit_box != null:
						
						# Mailbox to parcel transition
						var mailbox_target_transform: = mailbox.transform\
							.translated(Vector3(0,0,-200))\
							.scaled(Vector3(0.0001,0.0001,0.0001))
							
						transition_tween = get_tree().create_tween()
						transition_tween.tween_property(mailbox, "transform", mailbox_target_transform, 0.4)\
							.set_ease(Tween.EASE_IN)\
							.set_trans(Tween.TRANS_BACK)
						
						box.reparent(world)
						
						transition_tween.parallel().tween_property(box, "transform", viewing_parent.transform * box.get_base_viewing_transform(), 0.7)\
							.set_ease(Tween.EASE_OUT)\
							.set_trans(Tween.TRANS_ELASTIC)\
							.set_delay(0.4)
							
						transition_tween.tween_callback(on_transition_over)
						mailbox.can_open = false
						
						AudioManager.play_3d_sound(parcel_draw_sound, box.global_position)
						
						return
						
							
		GameState.PARCEL:
			if transition_tween != null: return
			
			if box.is_any_flap_opened() && gameboy.get_parent_node_3d() != Globals.game.world:
				gameboy.freeze = false
				gameboy.reparent(Globals.game.world)
			
			if GameInput.has_just_tapped:
				if true:
					var item_area = Tools.get_collision_under_screen_position(GameInput.tap_position, 0b0000_0111)
					if item_area != null:
						var item = Tools.find_parent_by_type(item_area, "Item") as Item
						if item == null: return
						current_item = item
						
						# Parcel to object transition
						var parcel_target_transform: = box.transform\
							.translated(mailbox.position - Vector3(0,0,-200))\
							.scaled(Vector3(0.0001,0.0001,0.0001))
							
						transition_tween = get_tree().create_tween()
						transition_tween.tween_property(box, "transform", parcel_target_transform, 0.4)\
							.set_ease(Tween.EASE_IN)\
							.set_trans(Tween.TRANS_BACK)
						
						current_item.reparent(world)
						transition_tween.parallel().tween_property(current_item, "transform", viewing_parent.transform * current_item.get_base_viewing_transform(), 1)\
							.set_ease(Tween.EASE_OUT)\
							.set_trans(Tween.TRANS_ELASTIC)\
							.set_delay(0.3)
							
						transition_tween.tween_callback(on_transition_over)
						
						AudioManager.play_3d_sound(parcel_draw_sound, current_item.global_position)
						
						return
			
func _physics_process(delta):
	# Update state
	match current_state:
		GameState.PARCEL:
			if box.unlocking_touch_index < 0:
				viewer.update(delta, GameInput.is_dragging, GameInput.drag_delta)
		
		GameState.OBJECT:
			if !current_item.is_consuming_input:
				viewer.update(delta, GameInput.is_dragging, GameInput.drag_delta)

func on_notification_button_pressed() -> void:
	android_plugin.test_notifications()
	pass

func on_permissions_button_pressed() -> void:
	var result: bool = android_plugin.request_notifications_permission()
	print(result)
	pass

func on_app_page_button_pressed() -> void:
	android_plugin.open_app_info_settings()
	pass
	
func on_delay_value_changed(value: float):
	update_delay_label()
	pass
	
func update_delay_label():
	delay_label.text = "Delay: %d" % delay_slider.value
	
func on_hello_world_button_pressed():
	android_plugin.hello_world()
	pass
	
func on_reset_button_pressed():
	set_state(GameState.NONE)
	set_state(GameState.MAILBOX)
	
func on_post_notifications_permission_result_received(result: bool):
	print("Permission: %s" % result)
	pass

func on_transition_over():
	match current_state:
		GameState.MAILBOX:
			set_state(GameState.PARCEL)
		
		GameState.PARCEL:
			set_state(GameState.OBJECT)
	
