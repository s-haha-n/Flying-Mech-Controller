extends RigidBody3D

@export var speed := 18.0
@export var lifetime := 6.0
@export var damage := 10

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.0
	# Fire forward on spawn
	linear_velocity = -global_transform.basis.z * speed
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
