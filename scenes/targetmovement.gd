extends RigidBody3D

enum Mode { WANDER, HOME }

@export var mode := Mode.WANDER
@export var move_speed := 4.0
@export var noise_frequency := 0.5   # how fast direction changes
@export var home_force := 12.0

var _noise_offset: float  # unique per instance so they don't all move in sync
var _player: Node3D

func _ready() -> void:
	add_to_group("target")
	# Random offset so each dummy samples noise at a different phase
	_noise_offset = randf() * 1000.0
	_player = get_tree().get_first_node_in_group("player")
	# Let RigidBody handle movement, disable gravity so they float
	gravity_scale = 0.0
	linear_damp = 2.0

func _physics_process(delta: float) -> void:
	match mode:
		Mode.WANDER:
			_wander(delta)
		Mode.HOME:
			_home(delta)

func _wander(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * noise_frequency + _noise_offset
	# Sample 3 offset time values to get independent x/y/z directions
	var dir := Vector3(
		sin(t * 1.0) * cos(t * 0.7),
		sin(t * 1.3 + 1.0),
		cos(t * 0.9 + 2.0)
	).normalized()
	apply_central_force(dir * move_speed)

func _home(delta: float) -> void:
	if not _player:
		return
	var to_player := (_player.global_position - global_position).normalized()
	apply_central_force(to_player * home_force)
