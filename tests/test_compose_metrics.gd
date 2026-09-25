@tool
extends McpTestSuite

func suite_name() -> String:
	return "compose_metrics"


func test_average_per_player_and_empty() -> void:
	var a: Dictionary = {}
	var b: Dictionary = {}
	assert_eq(ComposeMetrics.average(a), 0.0)
	ComposeMetrics.record(a, 0.5)
	ComposeMetrics.record(a, 1.5)
	ComposeMetrics.record(b, 3.0)
	assert_eq(ComposeMetrics.average(a), 1.0)
	assert_eq(ComposeMetrics.average(b), 3.0)
	assert_eq(a["compose_count"], 2)


func test_recast_and_invalid_samples_do_not_pollute_average() -> void:
	var stats: Dictionary = {}
	for value: float in [-1.0, INF, NAN, 999.0]:
		ComposeMetrics.record(stats, value)
	assert_true(stats.is_empty())
	ComposeMetrics.record(stats, 0.0)
	ComposeMetrics.record(stats, 1.0)
	assert_eq(ComposeMetrics.average(stats), 0.5)
