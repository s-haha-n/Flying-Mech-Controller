extends CharacterBody3D
@onready var _state_label: Label3D = $Label3D
@export_group("Detection")
@export var aggro_range := 30.0
@export var attack_range := 20.0
@export var lose_range := 40.0
@export var aim_height_offset := 2.75

@export_group("Movement")
@export var move_speed := 4.0
@export var rotation_speed := 2.5
@export var hover_amplitude := 0.3      # bobbing height
@export var hover_frequency := 1.2      # bobbing speed

@export_group("Combat")
@export var projectile_scene: PackedScene
@export var shots_per_burst := 3
@export var burst_interval := 0.18      # seconds between shots in a burst
@export var shoot_cooldown := 4.0       # seconds between bursts
@export var projectile_damage := 10
@export var projectile_speed := 18.0

@export_group("Health")
@export var max_health := 60

@onready var _shoot_timer: Timer = $ShootTimer

enum State { IDLE, APPROACH, COMBAT, DEAD }
var _state := State.IDLE
var _player: Node3D = null
var _health: int
var _origin_y: float   # for hover bob

func _ready() -> void:
	add_to_group("target")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	#gravity_scale = 0.0 if has_method("gravity_scale") else 0
	_health = max_health
	_origin_y = global_position.y
	_player = get_tree().get_first_node_in_group("player")
	_shoot_timer.wait_time = shoot_cooldown
	_shoot_timer.one_shot = false
	_shoot_timer.timeout.connect(_on_shoot_timer)
	_shoot_timer.start()

func take_damage(amount: int) -> void:
	_health -= amount
	if _health <= 0:
		_enter_dead()

func _enter_dead() -> void:
	_state = State.DEAD
	_shoot_timer.stop()
	# Highlight off if locked on
	var mesh := get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.set_surface_override_material(0, null)
	queue_free()

func _on_shoot_timer() -> void:
	if _state == State.COMBAT:
		_fire_burst()

func _fire_burst() -> void:
	for i in shots_per_burst:
		await get_tree().create_timer(burst_interval * i).timeout
		if not is_instance_valid(self):
			return
		_spawn_projectile()

func _spawn_projectile() -> void:
	if projectile_scene == null or _player == null:
		return
	var p = projectile_scene.instantiate()
	get_tree().root.add_child(p)
	p.global_position = global_position
	var aim_pos := _player.global_position + Vector3(0, aim_height_offset, 0)
	var dir := (aim_pos - global_position).normalized()
	#p.linear_velocity = dir * projectile_speed
	# look_at points +Z at target, so we flip with basis.z negated
	#var dir := (_player.global_position - global_position).normalized()
	p.linear_velocity = dir * projectile_speed
	if p.has_method("set") :
		p.set("damage", projectile_damage)
		p.set("speed", projectile_speed)

func _physics_process(delta: float) -> void:
	if _state == State.DEAD or _player == null:
		return
	
	var dist := global_position.distance_to(_player.global_position)

	_state_label.text = State.keys()[_state]  # converts enum index to name string
	# --- State transitions ---
	match _state:
		State.IDLE:
			if dist < aggro_range:
				_state = State.APPROACH
		State.APPROACH:
			if dist < attack_range:
				_state = State.COMBAT
			elif dist > lose_range:
				_state = State.IDLE
		State.COMBAT:
			if dist > attack_range * 1.3:
				_state = State.APPROACH

	# --- Smooth look at player (Y axis only so it doesn't tilt) ---
	var flat_target := Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var desired_dir := (flat_target - global_position).normalized()
	if desired_dir.length() > 0.01:
		var desired_angle := Vector3.BACK.signed_angle_to(desired_dir, Vector3.UP)
		global_rotation.y = lerp_angle(global_rotation.y, desired_angle, rotation_speed * delta)

	# --- Movement ---
	match _state:
		State.IDLE:
			velocity = velocity.lerp(Vector3.ZERO, 6.0 * delta)
		State.APPROACH, State.COMBAT:
			var to_player := (_player.global_position - global_position).normalized()
			# In combat, maintain distance rather than closing in
			var move_dir := Vector3.ZERO
			if _state == State.APPROACH:
				move_dir = to_player
			else:
				# Strafe sideways in combat — ZoE orbital movement
				move_dir = to_player.cross(Vector3.UP).normalized()
			velocity = velocity.lerp(move_dir * move_speed, 8.0 * delta)

	# --- Hover bob ---
	var t := Time.get_ticks_msec() / 1000.0
	global_position.y = _origin_y + sin(t * hover_frequency) * hover_amplitude

	move_and_slide()
