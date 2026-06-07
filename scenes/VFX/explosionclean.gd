extends Node3D

@onready var _particles: GPUParticles3D = $GPUParticles3D
#@onready var _sound: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	_particles.emitting = true
	#_sound.play()
	# Wait for particles to finish then delete
	# GPUParticles3D lifetime * 2 gives it time to fully finish
	var wait_time := _particles.lifetime * 2.0
	get_tree().create_timer(wait_time).timeout.connect(queue_free)
