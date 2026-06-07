extends Area3D
@export var explosion_scene: PackedScene
@export var speed := 250.0
@export var lifetime := 2.0

func _ready():
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	var move_vec := -global_transform.basis.z * speed * delta
	
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + move_vec
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		_spawn_explosion(result.position)
		if result.collider.is_in_group("target"):
			result.collider.queue_free()
		queue_free()
		return
	
	global_position += move_vec

func _spawn_explosion(pos: Vector3) -> void:
	if not explosion_scene:
		return
	var explosion = explosion_scene.instantiate()
	# Add to root so it stays in world when bullet deletes itself
	get_tree().root.add_child(explosion)
	explosion.global_position = pos
