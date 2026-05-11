extends Node
class_name _AudioManager

func play_3d_sound(stream: AudioStream, position: Vector3, destroy_when_finished: bool = true) -> AudioStreamPlayer3D:
	var player: = AudioStreamPlayer3D.new()
	add_child(player)
	player.stream = stream
	player.global_position = position
	
	player.play()
	
	if destroy_when_finished:
		var on_finished: = func():
			player.queue_free()
		player.finished.connect(on_finished)
	return player

func randomize_pitch(player: AudioStreamPlayer3D, min_pitch: float, max_pitch: float):
	player.pitch_scale = randf_range(min_pitch, max_pitch)
