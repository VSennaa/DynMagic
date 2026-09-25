@tool
extends Node3D
## Replace every imported surface with the shared toon shader, keeping its flat palette.
## FP arm poses share an origin; show only the requested pose.

static var _materials: Dictionary[Color, ShaderMaterial] = {}

@export_enum("OpenPalm", "Fist", "PalmDown", "Cast") var pose: String = "OpenPalm":
	set(value):
		pose = value
		if is_inside_tree():
			_select_pose()


func _ready() -> void:
	_apply_toon(self)
	_select_pose()


func _apply_toon(node: Node) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		for index: int in instance.mesh.get_surface_count():
			var imported: BaseMaterial3D = instance.mesh.surface_get_material(index) as BaseMaterial3D
			var color: Color = imported.albedo_color if imported != null else Color.WHITE
			if not _materials.has(color):
				_materials[color] = Toon.material(color)
			instance.set_surface_override_material(index, _materials[color])
	for child: Node in node.get_children():
		_apply_toon(child)


func _select_pose() -> void:
	for pose_name: String in ["OpenPalm", "Fist", "PalmDown", "Cast"]:
		var mesh: Node3D = find_child(pose_name, true, false) as Node3D
		if mesh != null:
			mesh.visible = pose_name == pose
