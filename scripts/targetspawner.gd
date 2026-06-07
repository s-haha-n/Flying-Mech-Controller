extends Node3D

@export var target_scene: PackedScene
@export var count := 8
@export var radius := 15.0
@export var mode: int = 0  # 0 = WANDER, 1 = HOME

func _ready() -> void:
	spawn()

func spawn() -> void:
	for i in count:
		var t = target_scene.instantiate()
		add_child(t)
		# Random point on a sphere surface
		t.global_position = global_position + Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized() * radius
		t.mode = mode
