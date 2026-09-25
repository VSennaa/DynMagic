@tool
extends McpTestSuite
## Sanity checks for project setup (ROADMAP M0).


func suite_name() -> String:
	return "smoke"


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "DynMagic")


func test_physics_tick_rate() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60)


func test_autoload_scripts_exist() -> void:
	for autoload_name: String in ["settings", "net", "lobby", "match_state", "spell_db", "audio_bus", "scene_router"]:
		var path: String = "res://autoload/%s.gd" % autoload_name
		assert_true(ResourceLoader.exists(path), "missing %s" % path)


func test_input_actions_exist() -> void:
	var actions: Array[StringName] = [
		&"move_forward", &"move_back", &"move_left", &"move_right",
		&"jump", &"crouch", &"sprint",
		&"slot_1", &"slot_2", &"slot_3", &"compose_cancel",
		&"cast", &"recast", &"scoreboard", &"pause", &"net_overlay",
	]
	# The editor's InputMap holds editor actions, so read the project settings instead.
	for action: StringName in actions:
		assert_true(ProjectSettings.has_setting("input/%s" % action), "missing input action %s" % action)
