@tool
class_name ComposeMetrics
extends RefCounted
## Recasts have no first slot key and use -1 (excluded from the mean).

static func record(stats: Dictionary, seconds: float) -> void:
	if not is_finite(seconds) or seconds < 0.0 or seconds > SpellComposer.SEQUENCE_TIMEOUT + SpellComposer.AIM_TIMEOUT + SpellComposer.CAST_LOCKOUT:
		return
	stats["compose_total"] = float(stats.get("compose_total", 0.0)) + seconds
	stats["compose_count"] = int(stats.get("compose_count", 0)) + 1


static func average(stats: Dictionary) -> float:
	var count: int = int(stats.get("compose_count", 0))
	return float(stats.get("compose_total", 0.0)) / count if count > 0 else 0.0
