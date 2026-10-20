extends BaselineTestCase


func test_defaults() -> void:
	expect_eq(BaselineSettings.get_value("audio.master"), 0.7, "master")
	expect_eq(BaselineSettings.get_value("audio.music"), 0.6, "music")
	expect_eq(BaselineSettings.get_value("audio.sfx"), 0.8, "sfx")
	expect_eq(BaselineSettings.get_value("audio.voice"), 1.0, "voice (C02 enabled in demo)")
	expect_eq(BaselineSettings.get_value("display.vsync"), true, "vsync on")
	expect_eq(BaselineSettings.get_value("display.max_fps"), 60, "60 cap")
	expect_eq(BaselineSettings.get_value("display.window_mode"), "windowed", "windowed")
	expect_eq(BaselineSettings.get_value("input.look_sensitivity"), 1.0, "sensitivity (C01)")
	expect_eq(BaselineSettings.get_value("subtitles.dialogue"), true, "subtitles on")


func test_volume_applies_to_bus_in_db_and_mutes_at_zero() -> void:
	BaselineSettings.set_value("audio.music", 0.5)
	var music := AudioServer.get_bus_index("Music")
	expect(is_equal_approx(AudioServer.get_bus_volume_db(music), linear_to_db(0.5)), "linear to dB")
	BaselineSettings.set_value("audio.music", 0.0)
	expect(AudioServer.is_bus_mute(music), "muted at 0")


func test_invalid_values_rejected() -> void:
	expect(not BaselineSettings.set_value("audio.master", "loud"), "string rejected")
	expect(not BaselineSettings.set_value("display.max_fps", 75), "75 not a choice")
	expect(not BaselineSettings.set_value("display.window_mode", "maximized"), "unknown mode")
	expect_eq(BaselineSettings.get_value("audio.master"), 0.7, "unchanged")
	expect(BaselineSettings.set_value("audio.master", 1.7), "out of range clamps")
	expect_eq(BaselineSettings.get_value("audio.master"), 1.0, "clamped")


func test_each_key_applies_only_itself() -> void:
	for key in ["audio.music", "display.vsync", "display.max_fps", "display.window_mode", "display.window_size"]:
		BaselineSettings.apply_counts.clear()
		var value: Variant = {"audio.music": 0.3, "display.vsync": false, "display.max_fps": 30, "display.window_mode": "fullscreen", "display.window_size": Vector2i(1280, 720)}[key]
		BaselineSettings.set_value(key, value)
		expect_eq(BaselineSettings.apply_counts.keys(), [key], "%s applied alone" % key)


func test_persistence_round_trip() -> void:
	BaselineSettings.set_value("audio.sfx", 0.25)
	BaselineSettings.set_value("display.max_fps", 144)
	BaselineSettings.flush()
	BaselineSettings.load_from_disk()
	expect_eq(BaselineSettings.get_value("audio.sfx"), 0.25, "sfx persisted")
	expect_eq(BaselineSettings.get_value("display.max_fps"), 144, "fps persisted")


func test_corrupt_values_fall_back_to_defaults() -> void:
	BaselineSettings.set_value("audio.master", 0.3)
	BaselineSettings.flush()
	var stored := {"audio.master": "very loud", "display.max_fps": 999, "audio.music": 0.2}
	BaselineFile.write_text(BaselineSettings.PATH, JSON.stringify(stored))
	BaselineSettings.load_from_disk()
	expect_eq(BaselineSettings.get_value("audio.master"), 0.7, "bad master -> default")
	expect_eq(BaselineSettings.get_value("display.max_fps"), 60, "bad fps -> default")
	expect_eq(BaselineSettings.get_value("audio.music"), 0.2, "good value kept")


func test_unparseable_file_does_not_crash() -> void:
	BaselineSettings.set_value("audio.master", 0.3)
	BaselineSettings.flush()
	var file := FileAccess.open(BaselineSettings.PATH, FileAccess.WRITE)
	file.store_string("{{{ not json")
	file.close()
	BaselineSettings.load_from_disk()
	expect_eq(BaselineSettings.get_value("audio.master"), 0.7, "defaults")


func test_reset_category() -> void:
	BaselineSettings.set_value("audio.master", 0.1)
	BaselineSettings.set_value("audio.music", 0.1)
	BaselineSettings.set_value("display.max_fps", 30)
	BaselineSettings.reset_category("audio.")
	expect_eq(BaselineSettings.get_value("audio.master"), 0.7, "master reset")
	expect_eq(BaselineSettings.get_value("audio.music"), 0.6, "music reset")
	expect_eq(BaselineSettings.get_value("display.max_fps"), 30, "display untouched")


func test_save_is_debounced_then_flushed() -> void:
	BaselineSettings.set_value("audio.sfx", 0.4)
	expect(not FileAccess.file_exists(BaselineSettings.PATH), "not written immediately")
	await get_tree().create_timer(BaselineSettings.SAVE_DELAY + 0.3).timeout
	expect(FileAccess.file_exists(BaselineSettings.PATH), "written after the delay")


func test_bindings_setting_updates_input_map() -> void:
	var bindings: Dictionary = BaselineSettings.get_value("game.input.bindings")
	var changed: Dictionary = BaselineBindings.assign(bindings, "move_up", 0, {"type": "key", "physical_keycode": KEY_I}, false)
	expect(BaselineSettings.set_value("game.input.bindings", changed), "set")
	expect(BaselineInputLabels.action_label("move_up").begins_with("I"), "label follows binding")
	BaselineSettings.reset_category("game.input.bindings")
	expect(BaselineInputLabels.action_label("move_up").begins_with("W"), "reset restores W")


func test_default_window_size() -> void:
	expect_eq(BaselineSettings.default_window_size(Vector2i(1920, 1080)), Vector2i(1600, 900), "1080p screen")
	expect_eq(BaselineSettings.default_window_size(Vector2i(2560, 1440)), Vector2i(1920, 1080), "1440p screen")
	var small: Vector2i = BaselineSettings.default_window_size(Vector2i(1366, 768))
	expect(small.x <= 1366 * 0.85 and small.y <= 768 * 0.85, "small-screen fallback fits")
	expect(absf(float(small.x) / small.y - 16.0 / 9.0) < 0.01, "fallback is 16:9")


func test_fps_match_display_falls_back_to_60() -> void:
	expect_eq(BaselineSettings.resolve_max_fps(BaselineSettings.FPS_MATCH_DISPLAY, -1.0), 60, "unknown refresh")
	expect_eq(BaselineSettings.resolve_max_fps(BaselineSettings.FPS_MATCH_DISPLAY, 143.9), 144, "rounded")
	expect_eq(BaselineSettings.resolve_max_fps(0, 144.0), 0, "unlimited")


func test_registered_game_key_uses_same_file() -> void:
	BaselineSettings.register_key("game.difficulty_hint", "on", func(v: Variant) -> Variant: return v if v in ["on", "off"] else null)
	expect(BaselineSettings.set_value("game.difficulty_hint", "off"), "set custom key")
	BaselineSettings.flush()
	BaselineSettings.load_from_disk()
	expect_eq(BaselineSettings.get_value("game.difficulty_hint"), "off", "custom key persisted")


func test_flush_keeps_keys_that_are_not_registered_yet() -> void:
	BaselineFile.write_text(BaselineSettings.PATH, JSON.stringify({"game.later_key": "kept"}))
	BaselineSettings.load_from_disk()
	BaselineSettings.set_value("audio.sfx", 0.3)
	BaselineSettings.flush()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BaselineSettings.PATH))
	expect(data is Dictionary, "file is a JSON object")
	if data is Dictionary:
		expect_eq(data.get("game.later_key"), "kept", "unregistered key kept")
		expect_eq(data.get("audio.sfx"), 0.3, "new value written")


func test_window_size_round_trip() -> void:
	expect(BaselineSettings.set_value("display.window_size", Vector2i(1366, 768)), "set")
	BaselineSettings.flush()
	BaselineSettings.load_from_disk()
	expect_eq(BaselineSettings.get_value("display.window_size"), Vector2i(1366, 768), "window size persisted")


func test_corrupt_main_file_falls_back_to_backup() -> void:
	BaselineFile.write_text(BaselineSettings.PATH, JSON.stringify({"audio.master": 0.4}))
	BaselineFile.write_text(BaselineSettings.PATH, "{{{ not json")
	expect(FileAccess.file_exists(BaselineSettings.PATH + BaselineFile.BACKUP_SUFFIX), "backup written")
	BaselineSettings.load_from_disk()
	expect_eq(BaselineSettings.get_value("audio.master"), 0.4, "value from backup")
