extends CharacterBody3D

@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@onready var _muzzle: Marker3D = $HexFrame/Armature/Skeleton3D/BoneAttachment3D/Muzzle # Adjust path as needed
@onready var _muzzle_flash: GPUParticles3D = $HexFrame/Armature/Skeleton3D/BoneAttachment3D/Muzzle/MuzzleFlash # Adjust path as needed
@onready var _shoot_timer: Timer = $ShootTimer
@onready var arm_modifier: LookAtModifier3D = $HexFrame/Armature/Skeleton3D/UpperArmAim
@onready var arm_modifier2: LookAtModifier3D = $HexFrame/Armature/Skeleton3D/LowerArmAim
@onready var head_modifier: LookAtModifier3D = $HexFrame/Armature/Skeleton3D/HeadAim

@onready var _shoot_sound: AudioStreamPlayer3D = $HexFrame/Armature/Skeleton3D/BoneAttachment3D/Muzzle/ShootSound

@export_group("Movement")
@export var walk_speed := 8.0
@export var move_speed := 7.0  
@export var dash_speed := 30.0
@export var acceleration := 14.0
@export var deceleration := 10.0
@export var rotation_speed := 10.0
@export var vertical_speed := 8.0

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var tilt_upper_limit := PI * 0.45
@export var tilt_lower_limit := -PI * 0.45

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _hex_frame: Node3D = $HexFrame
@onready var _anim_tree: AnimationTree = $HexFrame/AnimationTree
const AIM_THRESHOLD := 0.85  # fire when arm is 85% raised

var _one_shot_node: AnimationNodeOneShot

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_one_shot_node = _anim_tree.tree_root.get_node("OneShot")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event.is_action_pressed("right_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# --- PLAY SLASH ANIMATION ---
		_anim_tree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_camera_input_direction = event.screen_relative * mouse_sensitivity

# Not working
func _update_head_influence(delta: float) -> void:
	var player_forward := -_hex_frame.global_transform.basis.z
	var cam_forward := -_camera.global_transform.basis.z
	
	# Dot product: 1.0 = same dir, 0.0 = 90deg, -1.0 = opposite
	var dot := player_forward.dot(cam_forward)
	
	# Remap: full influence when camera is in front, zero when behind
	# smoothstep gives a natural ease instead of a hard cutoff
	var target_inf := smoothstep(-0.2, 0.4, dot)
	
	head_modifier.influence = lerp(head_modifier.influence, target_inf, 6.0 * delta)

func shoot() -> void:
	var bullet = bullet_scene.instantiate()
	# 1 Add bullet to the root scene (not the player) so it doesn't move with the player
	get_tree().root.add_child(bullet)
	
	# 2 Set the bullet position to the muzzle
	bullet.global_transform = _muzzle.global_transform
	# Add the player's current velocity so the bullet doesn't lag behind
	bullet.global_position += velocity * get_physics_process_delta_time()
	
	# Targeting: Aim the bullet toward the center of the screen
	var cam = get_viewport().get_camera_3d()
	var screen_center = get_viewport().size / 2
	
	var origin = cam.project_ray_origin(screen_center)
	var end = origin + cam.project_ray_normal(screen_center) * 1000.0
	
	# Use a RayCast to see what the reticle is pointing at
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	
	# FIX 1: Only hit Layer 1 (Environment). This ignores Layer 2 (Player).
	query.collision_mask = 1 
	# FIX 2: Explicitly tell the ray to ignore the player's physics body
	query.exclude = [self.get_rid()] 
	
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	
	var target_pos = end
	if not result.is_empty():
		target_pos = result.position # Aim at the wall/enemy we hit
	
	# Make the bullet face that target point
	bullet.look_at(target_pos)
	
	var spread_angle := 0.005  # radians, tune this (~2 degrees)
	bullet.rotate_object_local(Vector3.UP, randf_range(-spread_angle, spread_angle))
	bullet.rotate_object_local(Vector3.RIGHT, randf_range(-spread_angle, spread_angle))
	
	_shoot_sound.pitch_scale = randf_range(0.95, 1.05)
	_shoot_sound.play()
	
func _process(delta: float) -> void:	
	# FOV Stretching
	var target_fov = 80.0
	if Input.is_action_pressed("dash"):
		target_fov = 105.0 # High speed stretch
	
	_camera.fov = lerp(_camera.fov, target_fov, 4.0 * delta)
	
func _physics_process(delta: float) -> void:
	# --- Camera Rotation ---
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO
	_one_shot_node.filter_enabled = Input.is_action_pressed("dash")
	# --- Input ---
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	var move_direction := (forward * raw_input.y + right * raw_input.x)
	move_direction.y += Input.get_axis("move_descend", "move_ascend")

	move_direction = move_direction.normalized() if move_direction.length() > 0.01 else Vector3.ZERO
	
	
	# --- 2. Aiming Logic (New) ---
	var is_shooting := Input.is_action_pressed("left_click")
	
	# Transition the arm influence (0.0 = lowered, 1.0 = aiming)
	var target_influence := 1.0 if is_shooting else 0.0
	arm_modifier.influence = lerp(arm_modifier.influence, target_influence, 20.0 * delta)
	arm_modifier2.influence = lerp(arm_modifier.influence, target_influence, 20.0 * delta)

	if is_shooting:
		var arm_ready := arm_modifier.influence >= AIM_THRESHOLD
		if arm_ready and _shoot_timer.is_stopped():
			shoot()
			_muzzle_flash.restart()
			_shoot_timer.start()
		
	# --- Speed Logic ---
	var is_dashing := Input.is_action_pressed("dash")
	var is_running := Input.is_action_pressed("run")
	_anim_tree.set("parameters/OneShot/filter_enabled", is_running)
	
	var current_max_speed: float = walk_speed
	if is_dashing:
		current_max_speed = dash_speed
	elif is_running or move_direction.length() > 0: # Using sforward when moving
		current_max_speed = move_speed

	var target_velocity := move_direction * current_max_speed
	var blend_factor := acceleration * delta if move_direction.length() > 0.1 else deceleration * delta
	velocity = velocity.lerp(target_velocity, blend_factor)

	move_and_slide()

	# --- Rotation ---
	var flat_dir := Vector3(velocity.x, 0.0, velocity.z)
	if flat_dir.length() > 0.2:
		_last_movement_direction = flat_dir.normalized()
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_hex_frame.global_rotation.y = lerp_angle(_hex_frame.global_rotation.y, target_angle, rotation_speed * delta)
	
	 # ZoE Camera Lean: Shift camera left/right based on horizontal input
	#var target_h_offset = -raw_input.x * 0.5 # Lean the opposite way of movement
	#_camera.h_offset = lerp(_camera.h_offset, target_h_offset, 5.0 * delta)
	# Lean up/down based on vertical movement
	#var target_v_offset = (raw_input.y * 0.3) + 0.5 # Default 0.5 to keep mech low
	#_camera.v_offset = lerp(_camera.v_offset, target_v_offset, 5.0 * delta)
	
	#_update_head_influence(delta)
	_update_animation(delta)
	
func _update_animation(delta: float) -> void:
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	
	# We use a value 0.0 (Idle), 1.0 (Run/sforward), 2.0 (Dash)
	var target_state: float = 0.0
	if horizontal_speed > 0.5:
		if Input.is_action_pressed("dash"):
			target_state = 2.0 # Dash
		else:
			target_state = 1.0 # Run (sforward)
	
	# Lerp the movement blend value for smooth transitions
	var current_blend = _anim_tree.get("parameters/MoveType/blend_position")
	var new_blend = lerp(current_blend if current_blend != null else 0.0, target_state, 10.0 * delta)
	_anim_tree.set("parameters/MoveType/blend_position", new_blend)
