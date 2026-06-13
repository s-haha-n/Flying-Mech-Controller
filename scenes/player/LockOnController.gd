extends Node3D

var lock_target: Node3D = null
var lock_on_active: bool = false

@export var max_distance: float = 60.0
@export var max_angle: float = 45.0
@export var rotation_smoothing: float = 30.0

@onready var cam: Camera3D = get_viewport().get_camera_3d()
@onready var player: CharacterBody3D = get_parent()

# Cached references set from player _ready()
var hex_frame: Node3D = null
var camera_pivot: Node3D = null

func set_target_highlight(active: bool) -> void:
	if lock_target == null:
		return
	var mesh := lock_target.get_node_or_null("MeshInstance3D")
	if mesh == null:
		return
	var mat: Material = mesh.get_active_material(0)
	if mat == null:
		return
	if mat.resource_path != "":
		mat = mat.duplicate()
		mesh.set_surface_override_material(0, mat)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color.RED if active else Color.WHITE

func toggle_lock_on() -> void:
	if lock_on_active:
		set_target_highlight(false)
		lock_on_active = false
		lock_target = null
	else:
		lock_target = find_lock_target()
		lock_on_active = lock_target != null
		set_target_highlight(lock_on_active)

func find_lock_target() -> Node3D:
	var best: Node3D = null
	var best_score: float = INF
	for enemy in get_tree().get_nodes_in_group("target"):
		if not is_instance_valid(enemy):  # skip freed instances
			continue
		var to_enemy: Vector3 = enemy.global_position - cam.global_position
		var dist: float = to_enemy.length()
		if dist > max_distance:
			continue
		var angle: float = rad_to_deg(-cam.global_transform.basis.z.angle_to(to_enemy.normalized()))
		if angle > max_angle:
			continue
		var score: float = dist + angle * 0.5
		if score < best_score:
			best_score = score
			best = enemy
	return best

func update(delta: float) -> void:
	# Handle target being destroyed
	# This catches destruction mid-lock
	if lock_on_active and not is_instance_valid(lock_target):
		lock_on_active = false
		lock_target = null
		return
		

	if not lock_on_active or lock_target == null:
		return

	if player.global_position.distance_to(lock_target.global_position) > max_distance * 1.5:
		toggle_lock_on()
		return

	var to_target := lock_target.global_position - camera_pivot.global_position

	# --- Yaw: atan2 in world XZ plane ---
	var desired_yaw := atan2(to_target.x, to_target.z)
	
	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, desired_yaw, rotation_smoothing * delta)
	#camera_pivot.rotation.y = desired_yaw
	
	# --- Pitch: elevation angle from world space, not local basis ---
	var flat_dist := Vector2(to_target.x, to_target.z).length()
	var desired_pitch := -atan2(to_target.y, flat_dist)  # negative = Godot pitch convention
	
	camera_pivot.rotation.x = lerp_angle(camera_pivot.rotation.x, desired_pitch, rotation_smoothing * delta)
	#camera_pivot.rotation.x = desired_pitch
	
	# --- Hex frame faces target on flat plane ---
	var flat_target := Vector3(lock_target.global_position.x, hex_frame.global_position.y, lock_target.global_position.z)
	var desired_dir := (flat_target - hex_frame.global_position).normalized()
	var desired_angle := Vector3.BACK.signed_angle_to(desired_dir, Vector3.UP)
	hex_frame.global_rotation.y = lerp_angle(hex_frame.global_rotation.y, desired_angle, 10.0 * delta)
