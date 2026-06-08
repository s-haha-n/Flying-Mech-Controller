extends Node3D

@export var fly_through_radius := 2.0
@export var passed_color := Color(0.0, 1.0, 0.2)


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	for node in _get_all_children(self):
		if not node is MeshInstance3D:
			continue

		# duplicate material
		var mat = node.get_active_material(0)
		if mat:
			mat = mat.duplicate()
			node.set_surface_override_material(0, mat)

		# build Area3D as a CHILD of the mesh so it inherits its transform
		var area := Area3D.new()
		area.monitoring = true
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0xFFFFFFFF  # catch everything

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = fly_through_radius
		col.shape = shape
		area.add_child(col)

		# add as child of the mesh — no manual position needed, inherits it
		node.add_child(area)

		area.body_entered.connect(_on_entered.bind(node, mat))
		area.area_entered.connect(_on_area_entered.bind(node, mat))

		print("Area added to: ", node.name, " at global: ", node.global_position)


func _on_entered(body: Node3D, mesh: MeshInstance3D, mat: Material) -> void:
	print("body_entered: ", body.name, " groups: ", body.get_groups())
	if not body.is_in_group("player"):
		return
	_pass_through(mesh, mat)


func _on_area_entered(other: Area3D, mesh: MeshInstance3D, mat: Material) -> void:
	print("area_entered: ", other.name)
	# check if player is ancestor
	var p = other.get_parent()
	if p and p.is_in_group("player"):
		_pass_through(mesh, mat)


func _pass_through(mesh: MeshInstance3D, mat: Material) -> void:
	print("PASSED: ", mesh.name, " | mat: ", mat)
	mesh.queue_free()  # nuke it to confirm detection works
	if mat is BaseMaterial3D:
		mat.albedo_color = passed_color
	print("PASSED: ", mesh.name)


func _get_all_children(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children(child))
	return result
