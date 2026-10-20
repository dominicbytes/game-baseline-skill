extends BaselineTestCase

## Scratch project for the failing cases, in the run's isolated user data.
const SCRATCH := "user://project_checks_scratch"


func after_each() -> void:
	if not DirAccess.dir_exists_absolute(SCRATCH):
		return
	for file in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(file))
	DirAccess.remove_absolute(SCRATCH)


func _failures(results: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for result in results:
		if not result["ok"]:
			lines.append("%s %s" % [result["id"], result["message"]])
	return lines


func _key(physical: Key, logical: Key = KEY_NONE) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = logical
	return event


func _write(file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var handle := FileAccess.open(SCRATCH.path_join(file), FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


func test_template_passes_every_check() -> void:
	var results := BaselineProjectChecks.run()
	# The Windows preset (B07) arrives with export_presets.cfg.
	var failures := _failures(results).filter(func(line: String) -> bool: return not line.begins_with("B07 "))
	expect_eq(failures, [], "failing checks")
	var ids := {}
	for result in results:
		ids[result["id"]] = true
	for id in ["B01", "B02", "B03", "B07", "B10", "B11/B13/B15", "B17", "General"]:
		expect(ids.has(id), "%s is checked" % id)


func test_action_bound_to_esc_fails_b10() -> void:
	var results := BaselineProjectChecks._check_actions({
		"jump": [_key(KEY_SPACE)],
		"fake_menu": [_key(KEY_ESCAPE)],
	})
	expect_eq(_failures(results), ["B10 Gameplay actions bound to Esc, which opens the pause menu: fake_menu"], "only the Esc check fails")


func test_unbound_and_logical_key_actions_fail_b10() -> void:
	var results := BaselineProjectChecks._check_actions({
		"fake_unbound": [],
		"fake_logical": [_key(KEY_NONE, KEY_E)],
	})
	expect_eq(_failures(results), [
		"B10 Gameplay actions without a key or mouse binding: fake_unbound",
		"B10 Key bindings without physical_keycode: fake_logical",
	], "binding and physical key checks fail")
	expect_eq(_failures(BaselineProjectChecks._check_actions({})), ["B10 No gameplay input actions in the InputMap"], "no actions")


func test_esc_helper() -> void:
	expect(BaselineProjectChecks.binds_esc([_key(KEY_ESCAPE)]), "physical Esc")
	expect(BaselineProjectChecks.binds_esc([_key(KEY_NONE, KEY_ESCAPE)]), "logical Esc")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	expect(not BaselineProjectChecks.binds_esc([_key(KEY_A), mouse]), "no Esc")


func test_bare_project_fails_with_fixes() -> void:
	_write("project.godot", "config_version=5\n\n[application]\n\nconfig/name=\"Bare\"\n")
	_write("export_presets.cfg", "[preset.0]\n\nname=\"Win\"\nplatform=\"Windows Desktop\"\n\n[preset.0.options]\n\nbinary_format/embed_pck=false\ndebug/export_console_wrapper=1\n")
	var failures := _failures(BaselineProjectChecks.run(SCRATCH))
	for line in [
		"B01 Frame rate is not capped at 60 (set application/run/max_fps=60)",
		"B02 Bus layout res://default_bus_layout.tres does not load (set audio/buses/default_bus_layout)",
		"B07 Windows preset \"Win\" does not embed the PCK (set binary_format/embed_pck=true)",
		"B07 Windows preset \"Win\" exports a console wrapper (set debug/export_console_wrapper=0)",
		"B10 No gameplay input actions in the InputMap",
		"B11/B13/B15 Not using the Redot template: verify B05, B11, B13 and B15 by hand.",
		"B17 No version number (set application/config/version)",
		"General Main scene is not set or missing (set application/run/main_scene)",
	]:
		expect(line in failures, "fails: %s" % line)
	expect(not failures.any(func(line: String) -> bool: return line.begins_with("B01 VSync")), "VSync defaults to on")
	expect(not failures.any(func(line: String) -> bool: return line.begins_with("B17 File logging")), "file logging defaults to on")
