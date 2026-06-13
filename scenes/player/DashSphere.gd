extends MeshInstance3D

@export var max_scale        : float = 1.8
@export var scale_start      : float = 3.8  # spawns large, shrinks to max_scale during fade-in
@export var sharpness_start  : float = 1.8
@export var sharpness_target : float = 5.0
@export var fade_in_time     : float = 0.15
@export var fade_out_time    : float = 0.22

@onready var dash_trails : GPUParticles3D = $DashTrails

var _mat   : ShaderMaterial
var _phase : int   = 0
var _t     : float = 0.0
var _dir   : Vector3 = Vector3.FORWARD


func _ready() -> void:
	_mat = material_override as ShaderMaterial
	visible = false


func trigger(world_direction: Vector3) -> void:
	_dir = world_direction.normalized()
	_phase = 1
	_t = 0.0
	scale = Vector3.ONE * scale_start
	visible = true
	_mat.set_shader_parameter("band_sharpness", sharpness_start)
	_update_tail()
	dash_trails.emitting = true


func end_dash() -> void:
	if _phase == 1 or _phase == 2:
		_phase = 1 # supposed to do phase 3
		_t = 0.0
		dash_trails.emitting = false


func update_direction(world_velocity: Vector3) -> void:
	if world_velocity.length() > 0.1:
		_dir = world_velocity.normalized()
	if _phase == 2:
		_update_tail()


func _process(delta: float) -> void:
	if _phase == 0:
		return
	_t += delta

	match _phase:
		1:
			var p : float = clamp(_t / fade_in_time, 0.0, 1.0)
			_mat.set_shader_parameter("band_sharpness", lerp(sharpness_start, sharpness_target, p))
			scale = Vector3.ONE * lerp(scale_start, max_scale, p)
			if p >= 1.0:
				_phase = 2
				_t = 0.0
		2:
			_update_tail()
		3:
			var p : float = clamp(_t / fade_out_time, 0.0, 1.0)
			_mat.set_shader_parameter("band_sharpness", lerp(sharpness_target, sharpness_start, p))
			scale = Vector3.ONE * lerp(max_scale, scale_start, p)
			if p >= 1.0:
				_phase = 0
				visible = false


func _update_tail() -> void:
	var local_dir : Vector3 = get_parent().global_transform.basis.inverse() * (-_dir)
	_mat.set_shader_parameter("tail_direction", local_dir.normalized())
