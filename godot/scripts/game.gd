extends Node3D
class_name Game

# === STARTING STATE ===
func reset():
	clear_world()
	
	# Mailbox start
	var mailbox: = mailbox_scene.instantiate() as Mailbox
	var content: = gameboy_package_scene.instantiate() as Item
	mailbox.content_parent.add_child(content, true)
	set_focused_item(mailbox)
	content.align_with_origin(mailbox.content_parent)
	
	# Package start
	#set_focused_item(gameboy_package_scene.instantiate())
	
	# Package start
	#set_focused_item(gameboy_scene.instantiate())
# ======================

# UI
@export_group("ui")
@export var notification_button: BaseButton
@export var permissions_button: BaseButton
@export var app_page_button: BaseButton
@export var hello_world_button: BaseButton
@export var reset_button: BaseButton
@export var text: Label
@export var delay_label: Label
@export var delay_slider: HSlider

@export_group("nodes")
@export var world: Node3D
@export var viewer: ObjectViewer
@export var viewing_parent: Node3D

@export_group("sound")
@export var item_focus_sound: AudioStream

@export_group("")
@export var mailbox_scene: PackedScene
@export var gameboy_package_scene: PackedScene
@export var gameboy_scene: PackedScene

var focused_item: Item
var focus_in_rotation_tween: Tween

# Android
const ANDROID_PLUGIN_NAME: = "MailboxAndroidPlugin"
var android_plugin: Object;

func _ready() -> void:
	
	# Globals
	Globals.game = self
	
	# Android stuff
	if Engine.has_singleton(ANDROID_PLUGIN_NAME):
		android_plugin = Engine.get_singleton(ANDROID_PLUGIN_NAME)
		android_plugin.connect("post_notifications_permission_result_received", on_post_notifications_permission_result_received)
	if android_plugin == null:
		notification_button.disabled = true;
		permissions_button.disabled = true;
		app_page_button.disabled = true;
		hello_world_button.disabled = true;
		delay_slider.editable = false;
	
	# UI buttons
	text.text = "uninitialized"
	notification_button.pressed.connect(on_notification_button_pressed)
	permissions_button.pressed.connect(on_permissions_button_pressed)
	app_page_button.pressed.connect(on_app_page_button_pressed)
	hello_world_button.pressed.connect(on_hello_world_button_pressed)
	reset_button.pressed.connect(on_reset_button_pressed)
	update_delay_label()
	delay_slider.value_changed.connect(on_delay_value_changed)
	text.text = "initialiazing"
	
	# Scene setup
	for n in viewing_parent.get_children(): # remove child of viewing_parent. They are useful to tune transforms in editor but they may fuck up raycasts and stuff runtime
		n.queue_free()
	
	call_deferred("late_ready")
	
func late_ready():
	reset()
	
func clear_world():
	for n in world.get_children():
		n.queue_free()
	
func set_focused_item(item: Item):
	if focused_item != null:
		internal_unfocus_item(focused_item)
		focused_item.queue_free()
	
	focused_item = item
	
	if focused_item != null:
		internal_focus_item(focused_item)
		focused_item.transform = viewing_parent.transform * focused_item.get_base_viewing_transform()

func focus_item(item: Item):
	if item == focused_item: return
	
	var out_item = focused_item
	focused_item = item
	
	# out animation
	if out_item != null:
		internal_unfocus_item(out_item)
		var target_transform: Transform3D = out_item.transform\
			.translated(Vector3(0,0,-200))\
			.scaled(Vector3(0.02,0.02,0.02))
			
		var tween = get_tree().create_tween()
		tween.tween_property(out_item, "transform", target_transform, 0.4)\
			.set_ease(Tween.EASE_IN)\
			.set_trans(Tween.TRANS_BACK)
		tween.tween_callback(func():
			out_item.queue_free()
		)
	
	# in animation
	if focused_item != null:
		
		internal_focus_item(item)
		focused_item.is_focused = true
		
		const TWEEN_DELAY: = 0.3
		const TWEEN_TIME: = 1.0
		const TWEEN_EASE: = Tween.EASE_OUT
		const TWEEN_TRANS: = Tween.TRANS_ELASTIC
		
		var tween = get_tree().create_tween()
		tween.set_process_mode(Tween.TweenProcessMode.TWEEN_PROCESS_PHYSICS)
		
		var target_transform = viewing_parent.global_transform * focused_item.get_base_viewing_transform()
		tween.tween_property(focused_item, "position", target_transform * Vector3.ZERO, TWEEN_TIME)\
			.from_current()\
			.set_ease(TWEEN_EASE)\
			.set_trans(TWEEN_TRANS)\
			.set_delay(TWEEN_DELAY)
			
		tween.parallel().tween_property(focused_item, "scale", target_transform.basis.get_scale(), TWEEN_TIME)\
			.from_current()\
			.set_ease(TWEEN_EASE)\
			.set_trans(TWEEN_TRANS)\
			.set_delay(TWEEN_DELAY)
		
		# rotation tween is separate so that we can cancel it by interacting
		focus_in_rotation_tween = get_tree().create_tween()
		tween.set_process_mode(Tween.TweenProcessMode.TWEEN_PROCESS_PHYSICS)
		focus_in_rotation_tween.tween_property(focused_item, "rotation", target_transform.basis.get_euler(), TWEEN_TIME)\
			.from_current()\
			.set_ease(TWEEN_EASE)\
			.set_trans(TWEEN_TRANS)\
			.set_delay(TWEEN_DELAY)
		
		AudioManager.play_3d_sound(item_focus_sound, focused_item.global_position)
		
	

func internal_focus_item(item: Item):
	assert(item != null)
	if item.get_parent_node_3d() != null:
		item.reparent(world, true)
	else:
		world.add_child(item)
	item.is_focused = true
	viewer.target = item
	item.on_focus_gained()
	
	var rb: = (item as Node3D) as RigidBody3D # fu gdscript
	if rb != null:
		#rb.freeze = true
		#rb.angular_velocity = Vector3.ZERO
		#rb.linear_velocity = Vector3.ZERO
		rb.axis_lock_linear_x = true
		rb.axis_lock_linear_y = true
		rb.axis_lock_linear_z = true
	

func internal_unfocus_item(item: Item):
	assert(item != null)
	item.is_focused = false
	item.on_focus_lost()


func _process(delta: float) -> void:
	if GameInput.has_just_tapped:
		var collision: Node = Tools.get_collision_under_screen_position(GameInput.tap_position, 0b0000_0111)
		if collision != null:
			var item: = collision as Item
			if item == null: return	
			focus_item(item)


func _physics_process(delta):
	if focused_item != null && !focused_item.is_consuming_input && focused_item.can_rotate:
		viewer.update(delta, GameInput.is_dragging, GameInput.drag_delta)
		
		if viewer.smoothed_drag_input.length() > 1.0:
			if focus_in_rotation_tween != null:
				focus_in_rotation_tween.kill()
				focus_in_rotation_tween = null
	

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
	reset()
	
func on_post_notifications_permission_result_received(result: bool):
	print("Permission: %s" % result)
	pass
