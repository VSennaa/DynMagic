extends Node
## Runtime import contract and collision regression check. Run tools/verify_assets.tscn.

const ASSETS: Array[String] = ["mage", "fp_arms", "cover_low", "cover_high", "cover_bar", "pillar", "banner", "brazier", "spawn_arch", "arcane_core", "training_dummy"]
var _failures: int = 0


func check(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error(message)


func _ready() -> void:
	for asset: String in ASSETS:
		var packed: PackedScene = load("res://scenes/assets/%s.tscn" % asset) as PackedScene
		check(packed != null, "%s loads" % asset)
		if packed == null:
			continue
		var model: Node3D = packed.instantiate() as Node3D
		add_child(model)
		var count: int = 0
		var bounds: AABB
		var first: bool = true
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			count += mesh.mesh.get_faces().size() / 3
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			for surface: int in mesh.mesh.get_surface_count():
				var mat: ShaderMaterial = mesh.get_surface_override_material(surface) as ShaderMaterial
				check(mat != null and mat.shader == Toon.TOON_SHADER, "%s surface uses toon" % asset)
				if mat != null:
					var texture: Texture2D = mat.get_shader_parameter(&"albedo_texture") as Texture2D
					check(texture != null, "%s has baked albedo" % asset)
					if texture != null:
						check(texture.get_width() <= 1024 and texture.get_height() <= 1024, "texture budget")
				check(not mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV].is_empty(), "UV unwrap exists")
		if asset == "mage":
			var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
			check(skeleton != null and skeleton.get_bone_count() >= 7, "mage deform rig")
			var animation_player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			check(animation_player != null, "mage AnimationPlayer imported")
			if animation_player != null:
				for clip: String in ["idle", "walk", "cast", "dash", "death"]:
					check(animation_player.has_animation(clip), "mage clip " + clip)
					if animation_player.has_animation(clip):
						check(animation_player.get_animation(clip).get_track_count() > 0, "clip has bone tracks")
				if skeleton != null:
					animation_player.play("walk")
					animation_player.seek(.25, true)
					var pose_a: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone("leg_L"))
					animation_player.seek(.75, true)
					check(not pose_a.is_equal_approx(skeleton.get_bone_pose_rotation(skeleton.find_bone("leg_L"))), "walk deforms skeleton")
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/%s.json" % asset))
		check(count == int(report["triangles"]), "%s exported triangle count: %d" % [asset, count])
		var expected: Array = report["size_xyz_m"]
		check(bounds.size.distance_to(Vector3(expected[0], expected[1], expected[2])) < .001, "%s dimensions" % asset)
		check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s has no mesh collision" % asset)
		if asset != "fp_arms":
			check(absf(bounds.position.y) < .001, "%s sits on ground" % asset)
		if asset == "fp_arms":
			for pose: String in ["OpenPalm", "Fist", "PalmDown", "Cast"]:
				model.set("pose", pose)
				var visible_count: int = 0
				for node: Node in model.find_children("*", "MeshInstance3D", true, false):
					var mesh: MeshInstance3D = node as MeshInstance3D
					if mesh.visible:
						visible_count += 1
						check(mesh.name == pose, "selected pose matches")
				check(visible_count == 1, "one arm pose visible")
		print("ASSET_OK %s %d tris bounds=%s" % [asset, count, bounds.size])
		model.free()
	for variant: StringName in ArenaBuilder.VARIANTS:
		var arena: ArenaBuilder = ArenaBuilder.new()
		arena.variant = variant
		add_child(arena)
		# CSG builds physics shapes asynchronously.
		for frame: int in 5:
			await get_tree().physics_frame
		var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
		for entry: Array in ArenaBuilder.mirrored_layout(variant):
			var top: Vector3 = Vector3(entry[0], float(entry[3]) + .25, entry[1])
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * .5)
			var hit: Dictionary = space.intersect_ray(query)
			check(not hit.is_empty(), "%s cover collision at %s" % [variant, top])
			if not hit.is_empty():
				check(absf((hit["position"] as Vector3).y - float(entry[3])) < .001, "cover top unchanged")
		var sight: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0, 1.6, -22.5), Vector3(0, 1.6, 22.5))
		check(not space.intersect_ray(sight).is_empty(), "%s spawn sightline blocked" % variant)
		print("COLLISION_OK ", variant)
		arena.free()
	var core: ArcaneCore = ArcaneCore.create()
	add_child(core)
	var pedestal: Node3D = core.find_child("Pedestal", true, false) as Node3D
	var crystal: Node3D = core.find_child("Crystal", true, false) as Node3D
	check(pedestal != null and crystal != null, "core has crystal and pedestal")
	var initial: Transform3D = pedestal.transform
	core._process(.1)
	check(pedestal.transform == initial, "pedestal remains stationary")
	check(not crystal.basis.is_equal_approx(Basis.IDENTITY), "crystal rotates")
	core.free()
	var player: Player = preload("res://scenes/player/player.tscn").instantiate() as Player
	player.is_local = false
	add_child(player)
	check(player.has_node("ThirdPersonModel/Model"), "remote player uses mage wrapper")
	var controller: Node = player.get_node("MageAnimation")
	controller.set_process(false)
	player.velocity = Vector3(3, 0, 0)
	controller._process(.016)
	check(controller.current == &"walk", "moving remote walks")
	player.velocity = Vector3(20, 0, 0)
	controller._process(.016)
	check(controller.current == &"dash", "fast remote dashes")
	player.velocity = Vector3.ZERO
	player.composer.press_slot(0)
	controller._process(.016)
	check(controller.current == &"cast", "remote prepares cast")
	player.composer.clear()
	controller._process(.016)
	check(controller.current == &"idle", "cancel returns to idle")
	player.stats.take_damage(1000)
	check(controller.current == &"death", "Stats.died plays death")
	player.stats.reset()
	controller._process(.016)
	check(controller.current == &"idle", "new round exits death")
	var sync: NetSync = NetSync.new()
	sync.name = "NetSync"
	player.add_child(sync)
	sync.set_process(false)
	sync.set_physics_process(false)
	sync.role = NetSync.Role.CLIENT_REMOTE
	sync.remote_composer_bits = NetCodec.pack_composer(SpellComposer.State.AIMING, 0, 1)
	controller._process(.016)
	check(controller.current == &"cast", "synced composer drives remote animation")
	sync.remote_composer_bits = 0
	player.position.x += .05
	controller._process(.016)
	check(controller.current == &"walk", "interpolated displacement drives client walk")
	player.position.x += 10.0
	controller._process(.016)
	check(controller.current == &"idle", "teleport is not a dash")
	player.free()
	var local_player: Player = preload("res://scenes/player/player.tscn").instantiate() as Player
	add_child(local_player)
	var arms: Node = local_player.get_node("Head/Camera3D/FirstPersonArms")
	arms.set_process(false)
	check(arms.view.own_world_3d and arms.view.transparent_bg, "arms isolated from world depth")
	check(arms.camera.cull_mask == 1 << 19, "arms camera uses separate layer")
	for slot: int in 3:
		local_player.composer.clear()
		local_player.composer.press_slot(slot)
		arms._process(0.0)
		check(arms.arms.get("pose") == ["OpenPalm", "Fist", "PalmDown"][slot], "form selects arm pose")
	local_player.composer.clear()
	local_player.composer.press_slot(0)
	local_player.composer.press_slot(1)
	arms._process(0.0)
	check(local_player.composer.state == SpellComposer.State.AIMING and arms.arms.position.y > 0.02, "aim raises arms")
	local_player.composer.press_cast()
	arms._process(0.0)
	check(arms.arms.get("pose") == "Cast", "cast flash pose")
	arms._process(.13)
	check(arms.arms.get("pose") == "OpenPalm", "cast flash ends after 0.12s")
	local_player.stats.take_damage(1000)
	arms._process(0.0)
	check(not arms.overlay.visible, "dead player arms hidden")
	local_player.stats.reset()
	arms._process(0.0)
	check(arms.overlay.visible, "respawn restores arms")
	local_player.free()
	print("ASSET_CHECKS: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
