extends CollisionShape3D
class_name FoamSpawner

@export var foam_count: int = 10
@export var foam_scene: PackedScene

var spawned_foam: Array[Node3D]

func spawn_foam():
	var box: = shape as BoxShape3D
	if box == null: return
	var aabb: = AABB(Vector3.ZERO, box.size)
	var world: = Globals.game.world
	
	var rng: = RandomNumberGenerator.new() # may move to globals
	
	for i in foam_count:
		var foam: = foam_scene.instantiate() as Node3D
		world.add_child(foam)
		foam.global_position = global_transform * (Vector3(
			rng.randf_range(-box.size.x, box.size.x),
			rng.randf_range(-box.size.y, box.size.y),
			rng.randf_range(-box.size.z, box.size.z)
		) * 0.5)
		
		foam.rotation_degrees = Vector3(
			rng.randf_range(0.0, 360.0),
			rng.randf_range(0.0, 360.0),
			rng.randf_range(0.0, 360.0)
		)
		
		spawned_foam.append(foam)

func clear_spawned_foam():
	for foam in spawned_foam:
		foam.queue_free()
	spawned_foam.clear()
