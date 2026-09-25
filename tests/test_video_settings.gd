@tool
extends McpTestSuite

func suite_name() -> String:
	return "video_settings"


func test_config_round_trip_all_options() -> void:
	for aa: int in 4:
		for quality: int in 3:
			var original: VideoSettings = VideoSettings.new()
			original.resolution = Vector2i(2560, 1440)
			original.render_scale = 0.75
			original.shadow_quality = quality
			original.antialiasing = aa
			var cfg: ConfigFile = ConfigFile.new()
			original.write_config(cfg)
			var loaded: ConfigFile = ConfigFile.new()
			assert_eq(loaded.parse(cfg.encode_to_text()), OK)
			var restored: VideoSettings = VideoSettings.new()
			restored.read_config(loaded)
			assert_eq(restored.resolution, original.resolution)
			assert_eq(restored.render_scale, original.render_scale)
			assert_eq(restored.shadow_quality, quality)
			assert_eq(restored.antialiasing, aa)


func test_old_config_defaults_and_bounds() -> void:
	var options: VideoSettings = VideoSettings.new()
	options.read_config(ConfigFile.new())
	assert_eq(options.render_scale, 1.0)
	assert_eq(options.antialiasing, 0)
	options.render_scale = 0.1
	options.antialiasing = 99
	options.shadow_quality = -2
	options.resolution = Vector2i.ZERO
	options.normalize()
	assert_eq(options.render_scale, 0.5)
	assert_eq(options.antialiasing, 3)
	assert_eq(options.shadow_quality, 0)
	assert_eq(options.resolution, Vector2i(1280, 720))
	options.render_scale = 2.0
	options.normalize()
	assert_eq(options.render_scale, 1.0)
