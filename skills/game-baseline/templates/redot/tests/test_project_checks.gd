extends BaselineTestCase

## Scratch project for the failing cases, in the run's isolated user data.
const SCRATCH := "user://project_checks_scratch"
## The line check_project.gd prints for a config that still starts the demo.
const DEMO_MANUAL := "MANUAL General Game scene is the template's demo (res://demo/demo_game.tscn): set game_scene_path in res://baseline/baseline_config.tres to your game"


func after_each() -> void:
	_remove_tree(SCRATCH)


func _remove_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _failures(results: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for result in results:
		if not result["ok"] and not result["manual"]:
			lines.append("%s %s" % [result["id"], result["message"]])
	return lines


func _manuals(results: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for result in results:
		if result["manual"]:
			lines.append("%s %s" % [result["id"], result["message"]])
	return lines


func _key(physical: Key, logical: Key = KEY_NONE) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = logical
	return event


func _write(file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH.path_join(file).get_base_dir())
	var handle := FileAccess.open(SCRATCH.path_join(file), FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


## A scratch project for the config checks: a bus layout with buses (after
## Master), a game.tscn, and baseline_config.tres with config lines when given.
func _write_project(config: String, buses: Array[String]) -> void:
	_write("project.godot", "config_version=5\n")
	var layout := "[gd_resource type=\"AudioBusLayout\" format=3]\n\n[resource]\n"
	for i in buses.size():
		layout += "bus/%d/name = &\"%s\"\nbus/%d/send = &\"Master\"\n" % [i + 1, buses[i], i + 1]
	_write("default_bus_layout.tres", layout)
	_write("game.tscn", "[gd_scene format=3]\n\n[node name=\"Game\" type=\"Node\"]\n")
	if config != "":
		_write("baseline/baseline_config.tres", "[gd_resource type=\"Resource\" script_class=\"BaselineConfig\" format=3]\n\n"
				+ "[ext_resource type=\"Script\" path=\"res://baseline/baseline_config.gd\" id=\"1\"]\n\n"
				+ "[resource]\nscript = ExtResource(\"1\")\n" + config)


## Status lines of the config checks only.
func _config_lines(results: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for result in results:
		if result["id"] == "C02" or (result["id"] == "General" and "ame scene" in result["message"]):
			var status := "MANUAL" if result["manual"] else ("PASS" if result["ok"] else "FAIL")
			lines.append("%s %s %s" % [status, result["id"], result["message"]])
	return lines


func test_template_passes_every_check() -> void:
	var results := BaselineProjectChecks.run()
	expect_eq(_failures(results), [], "failing checks")
	# The template ships the demo's config, so its game scene is a manual line.
	expect_eq(_manuals(results), [DEMO_MANUAL.trim_prefix("MANUAL ")], "only the demo scene is manual")
	var ids := {}
	for result in results:
		ids[result["id"]] = true
	for id in ["B01", "B02", "B03", "B07", "B10", "B05/B11/B13/B15", "B17", "General", "C02"]:
		expect(ids.has(id), "%s is checked" % id)


func test_config_game_scene_must_load() -> void:
	_write_project("game_scene_path = \"res://missing.tscn\"\n", ["Music", "SFX"])
	expect_eq(_config_lines(BaselineProjectChecks.run(SCRATCH)),
			["FAIL General Game scene does not load (res://missing.tscn; set game_scene_path in res://baseline/baseline_config.tres)"], "missing scene fails")
	_write_project("game_scene_path = \"res://game.tscn\"\n", ["Music", "SFX"])
	expect_eq(_config_lines(BaselineProjectChecks.run(SCRATCH)), ["PASS General Game scene loads (res://game.tscn)"], "own scene passes")


func test_no_config_means_no_config_checks() -> void:
	_write_project("", ["Music", "SFX"])
	expect_eq(_config_lines(BaselineProjectChecks.run(SCRATCH)), [], "no config lines")


func test_demo_game_scene_is_manual_not_failure() -> void:
	_write("demo/demo_game.tscn", "[gd_scene format=3]\n\n[node name=\"Demo\" type=\"Node\"]\n")
	_write_project("game_scene_path = \"res://demo/demo_game.tscn\"\n", ["Music", "SFX"])
	var results := BaselineProjectChecks.run(SCRATCH)
	expect_eq(_config_lines(results), [DEMO_MANUAL], "demo scene is manual")
	expect(not _failures(results).any(func(line: String) -> bool: return "ame scene" in line), "demo scene is not a failure")


func test_voice_needs_voice_bus() -> void:
	var voice_on := "game_scene_path = \"res://game.tscn\"\nenable_voice = true\n"
	_write_project(voice_on, ["Music", "SFX"])
	expect("FAIL C02 enable_voice is on but the bus layout has no Voice bus (add one sending to Master, or turn enable_voice off in res://baseline/baseline_config.tres)"
			in _config_lines(BaselineProjectChecks.run(SCRATCH)), "voice without a Voice bus fails")
	_write_project(voice_on, ["Music", "SFX", "Voice"])
	expect("PASS C02 Bus layout has a Voice bus (enable_voice is on)" in _config_lines(BaselineProjectChecks.run(SCRATCH)), "Voice bus passes")
	_write_project("game_scene_path = \"res://game.tscn\"\nenable_voice = false\n", ["Music", "SFX"])
	expect(not _config_lines(BaselineProjectChecks.run(SCRATCH)).any(func(line: String) -> bool: return "C02" in line), "no voice, no Voice bus check")


func test_action_bound_to_esc_fails_b10() -> void:
	var results := BaselineProjectChecks._check_actions({
		"jump": [_key(KEY_SPACE)],
		"fake_menu": [_key(KEY_ESCAPE)],
	})
	expect_eq(_failures(results), ["B10 Gameplay actions bound to Esc, which opens the pause menu: fake_menu" + BaselineProjectChecks.B10_NOTE], "only the Esc check fails")


func test_unbound_and_logical_key_actions_fail_b10() -> void:
	var results := BaselineProjectChecks._check_actions({
		"fake_unbound": [],
		"fake_logical": [_key(KEY_NONE, KEY_E)],
	})
	expect_eq(_failures(results), [
		"B10 Gameplay actions without a key or mouse binding: fake_unbound" + BaselineProjectChecks.B10_NOTE,
		"B10 Key bindings without physical_keycode: fake_logical" + BaselineProjectChecks.B10_NOTE,
	], "binding and physical key checks fail")
	expect_eq(_failures(BaselineProjectChecks._check_actions({})), ["B10 No gameplay input actions in the InputMap" + BaselineProjectChecks.B10_NOTE], "no actions")


func test_b10_note_explains_the_static_check() -> void:
	expect("ui_" in BaselineProjectChecks.B10_NOTE, "names the ui_ prefix rule")
	expect("only in code" in BaselineProjectChecks.B10_NOTE, "says code-only actions are not seen")


func test_esc_helper() -> void:
	expect(BaselineProjectChecks.binds_esc([_key(KEY_ESCAPE)]), "physical Esc")
	expect(BaselineProjectChecks.binds_esc([_key(KEY_NONE, KEY_ESCAPE)]), "logical Esc")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	expect(not BaselineProjectChecks.binds_esc([_key(KEY_A), mouse]), "no Esc")


func test_bare_project_fails_with_fixes() -> void:
	_write("project.godot", "config_version=5\n\n[application]\n\nconfig/name=\"Bare\"\n")
	_write("export_presets.cfg", "[preset.0]\n\nname=\"Win\"\nplatform=\"Windows Desktop\"\n\n[preset.0.options]\n\nbinary_format/embed_pck=false\ndebug/export_console_wrapper=1\n")
	var results := BaselineProjectChecks.run(SCRATCH)
	var failures := _failures(results)
	for line in [
		"B01 Frame rate is not capped at 60 (set application/run/max_fps=60)",
		"B02 Bus layout res://default_bus_layout.tres does not load (set audio/buses/default_bus_layout)",
		"B07 Windows preset \"Win\" does not embed the PCK (set binary_format/embed_pck=true)",
		"B07 Windows preset \"Win\" exports a console wrapper (set debug/export_console_wrapper=0)",
		"B10 No gameplay input actions in the InputMap" + BaselineProjectChecks.B10_NOTE,
		"B17 No version number (set application/config/version)",
		"General Main scene is not set or missing (set application/run/main_scene)",
	]:
		expect(line in failures, "fails: %s" % line)
	expect(not failures.any(func(line: String) -> bool: return line.begins_with("B01 VSync")), "VSync defaults to on")
	expect(not failures.any(func(line: String) -> bool: return line.begins_with("B17 File logging")), "file logging defaults to on")
	expect_eq(_manuals(results), ["B05/B11/B13/B15 Not using the Redot template: verify these by hand (see verification.md)"], "template items are manual")
	expect(not failures.any(func(line: String) -> bool: return line.begins_with("B05/B11/B13/B15")), "manual result is not a failure")


func test_main_scene_paths() -> void:
	var title := "res://baseline/ui/title_screen.tscn"
	expect(BaselineProjectChecks.main_scene_exists(title), "res:// path that exists")
	expect(not BaselineProjectChecks.main_scene_exists("res://no_such_scene.tscn"), "res:// path that does not exist")
	expect(not BaselineProjectChecks.main_scene_exists(""), "empty path")
	# The template's scenes carry no UID, but every script has a .uid file.
	var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid("res://baseline/ui/title_screen.gd"))
	expect(uid.begins_with("uid://") and BaselineProjectChecks.main_scene_exists(uid), "uid:// path known to the project")
	expect(not BaselineProjectChecks.main_scene_exists("uid://b0000000000000"), "unknown uid:// path")
	expect(not BaselineProjectChecks.main_scene_exists("uid://not a uid"), "malformed uid:// path")
	expect(not BaselineProjectChecks.main_scene_exists(uid, SCRATCH), "uid:// path outside the running project")
