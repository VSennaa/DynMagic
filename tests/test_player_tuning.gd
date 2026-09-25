@tool
extends McpTestSuite
## PlayerTuning values must match docs/specs/05-player-controller.md section 2.


func suite_name() -> String:
	return "player_tuning"


func test_tuning_matches_spec() -> void:
	var tuning: PlayerTuning = load("res://data/player_tuning.tres") as PlayerTuning
	assert_true(tuning != null, "player_tuning.tres must load as PlayerTuning")
	assert_eq(tuning.walk_speed, 5.5)
	assert_eq(tuning.sprint_speed, 7.5)
	assert_eq(tuning.crouch_speed, 3.0)
	assert_eq(tuning.crouch_height, 1.2)
	assert_eq(tuning.jump_height, 1.2)
	assert_eq(tuning.ground_acceleration, 60.0)
	assert_eq(tuning.air_acceleration, 15.0)
	assert_eq(tuning.gravity, 22.0)
	assert_eq(tuning.coyote_time, 0.1)
	assert_eq(tuning.step_height, 0.35)


func test_jump_velocity_reaches_jump_height() -> void:
	var tuning: PlayerTuning = PlayerTuning.new()
	var v: float = tuning.jump_velocity()
	var apex: float = v * v / (2.0 * tuning.gravity)
	assert_true(absf(apex - tuning.jump_height) < 0.0001, "apex %f" % apex)
