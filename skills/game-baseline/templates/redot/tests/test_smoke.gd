extends BaselineTestCase


func test_config_loads() -> void:
	var config: BaselineConfig = load("res://baseline/baseline_config.tres")
	expect(config != null, "baseline_config.tres loads")
	expect_eq(config.game_title, "Baseline Demo", "game title")


func test_bus_layout_has_baseline_buses() -> void:
	for bus in ["Master", "Music", "SFX", "Voice"]:
		expect(AudioServer.get_bus_index(bus) >= 0, "bus %s exists" % bus)
	var master := AudioServer.get_bus_index("Master")
	expect(AudioServer.get_bus_effect_count(master) >= 1, "Master has a limiter")
