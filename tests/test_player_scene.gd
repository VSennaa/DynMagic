@tool
extends McpTestSuite
## Player scene structure (docs/specs/05-player-controller.md section 1).


func suite_name() -> String:
	return "player_scene"


func test_player_script_compiles() -> void:
	# can_instantiate() is always false in the editor for non-@tool scripts,
	# so check that compilation produced the expected methods instead.
	var script: GDScript = load("res://scenes/player/player.gd") as GDScript
	assert_true(script != null, "player.gd must load")
	var methods: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		methods.append(str(method["name"]))
	assert_contains(methods, "simulate", "player.gd must compile and define simulate()")


func test_player_scene_nodes() -> void:
	var packed: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	assert_true(packed != null, "player.tscn must load")
	var state: SceneState = packed.get_state()
	var paths: Array[String] = []
	for i: int in state.get_node_count():
		paths.append(str(state.get_node_path(i)).trim_prefix("./"))
	for expected: String in ["CollisionShape3D", "Head", "Head/Camera3D", "Head/Camera3D/CastOrigin"]:
		assert_contains(paths, expected, "missing node %s in %s" % [expected, paths])
