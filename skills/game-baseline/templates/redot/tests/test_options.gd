extends BaselineTestCase

var menu: BaselineOptionsMenu


func _open(tab: String = "audio") -> void:
	menu = BaselineOptionsMenu.create(tab)
	BaselineFlow.push_screen(menu)
	await frames(3)


func after_each() -> void:
	BaselineFlow.reset_for_tests()
	await frames(1)


func _key(physical: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = physical
		event.pressed = pressed
		Input.parse_input_event(event)


func test_tabs_present() -> void:
	await _open()
	for text in ["Audio", "Display", "Controls"]:
		expect(menu.find_button(text) != null, "%s tab" % text)
	var config := BaselineFlow.config
	expect_eq(menu.find_button("Gameplay") != null, config.enable_mouse_look or config.enable_voice, "Gameplay tab only with mouse-look or voice")
	expect(menu.find_button("Back") != null, "Back button")


func test_audio_slider_label_and_mute() -> void:
	await _open("audio")
	var tab: BaselineOptionsAudioTab = menu.current_tab()
	tab.slider_for("audio.music").value = 0.0
	expect_eq(tab.value_label_for("audio.music").text, "Muted", "muted label")
	expect_eq(BaselineSettings.get_value("audio.music"), 0.0, "setting follows slider")
	tab.slider_for("audio.music").value = 0.29
	expect_eq(tab.value_label_for("audio.music").text, "29%", "rounded percent")
	expect_eq(tab.slider_for("audio.voice") != null, BaselineFlow.config.enable_voice, "voice slider only with C02 voice")


func test_window_size_only_in_windowed_mode() -> void:
	await _open("display")
	var tab: BaselineOptionsDisplayTab = menu.current_tab()
	BaselineSettings.set_value("game.display.window_mode", "fullscreen")
	await frames(1)
	expect(tab.size_picker().disabled, "size disabled in fullscreen")
	BaselineSettings.set_value("game.display.window_mode", "windowed")
	await frames(1)
	expect(not tab.size_picker().disabled, "size enabled in windowed")


func test_frame_cap_choices() -> void:
	await _open("display")
	var tab: BaselineOptionsDisplayTab = menu.current_tab()
	var labels: Array[String] = []
	for i in tab.fps_picker().item_count:
		labels.append(tab.fps_picker().get_item_text(i))
	expect_eq(labels, ["30", "60", "120", "144", "Match display", "Unlimited"] as Array[String], "cap choices")


func test_remap_with_conflict_swap() -> void:
	await _open("controls")
	var panel: BaselineControlsPanel = menu.current_tab()
	panel.slot_button("move_up", 0).pressed.emit()
	await frames(1)
	expect(panel.is_capturing(), "capturing")
	_key(KEY_A)
	await frames(3)
	var dialog := BaselineFlow.top_screen() as BaselineConfirm
	expect(dialog != null, "conflict confirmation shown")
	dialog.find_button("Swap").pressed.emit()
	await frames(3)
	var bindings: Dictionary = BaselineSettings.get_value("game.input.bindings")
	expect_eq(bindings["move_up"][0], {"type": "key", "physical_keycode": KEY_A}, "move_up now A")
	expect_eq(bindings["move_left"][0], {"type": "key", "physical_keycode": KEY_W}, "move_left got W")
	expect(BaselineInputLabels.action_label("move_up").begins_with("A"), "label updated")


func test_remap_conflict_cancel_keeps_bindings() -> void:
	await _open("controls")
	var panel: BaselineControlsPanel = menu.current_tab()
	var before: Dictionary = BaselineSettings.get_value("game.input.bindings")
	panel.slot_button("move_up", 0).pressed.emit()
	await frames(1)
	_key(KEY_A)
	await frames(3)
	(BaselineFlow.top_screen() as BaselineConfirm).find_button("Cancel").pressed.emit()
	await frames(3)
	expect_eq(BaselineSettings.get_value("game.input.bindings"), before, "unchanged")


func test_esc_cancels_capture_and_cannot_be_bound() -> void:
	await _open("controls")
	var panel: BaselineControlsPanel = menu.current_tab()
	var before: Dictionary = BaselineSettings.get_value("game.input.bindings")
	panel.slot_button("move_up", 0).pressed.emit()
	await frames(1)
	_key(KEY_ESCAPE)
	await frames(2)
	expect(not panel.is_capturing(), "capture cancelled")
	expect_eq(BaselineFlow.top_screen(), menu, "options still open (Esc did not close it)")
	expect_eq(BaselineSettings.get_value("game.input.bindings"), before, "unchanged")


func test_capture_ignores_wheel_and_double_click() -> void:
	await _open("controls")
	var panel: BaselineControlsPanel = menu.current_tab()
	var before: Dictionary = BaselineSettings.get_value("game.input.bindings")
	panel.slot_button("move_up", 0).pressed.emit()
	await frames(1)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Input.parse_input_event(wheel)
	var double := InputEventMouseButton.new()
	double.button_index = MOUSE_BUTTON_MIDDLE
	double.pressed = true
	double.double_click = true
	Input.parse_input_event(double)
	await frames(2)
	expect(panel.is_capturing(), "still waiting for a binding")
	expect_eq(BaselineSettings.get_value("game.input.bindings"), before, "unchanged")


func test_controls_follow_action_order() -> void:
	await _open("controls")
	var panel: BaselineControlsPanel = menu.current_tab()
	var available := BaselineBindings.gameplay_actions()
	var expected: Array[String] = []
	for action: String in BaselineFlow.config.action_order:
		if action in available and not action in expected:
			expected.append(action)
	expect_eq(panel.action_rows().slice(0, expected.size()), expected, "config order first")
	expect_eq(panel.action_rows().size(), available.size(), "every gameplay action listed once")


func test_options_from_pause_menu_and_back() -> void:
	var game: Node = preload("res://tests/fixtures/fixture_game.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(2)
	BaselineFlow.pause()
	await frames(2)
	(BaselineFlow.top_screen() as BaselineScreen).find_button("Options").pressed.emit()
	await frames(2)
	expect(BaselineFlow.top_screen() is BaselineOptionsMenu, "options over pause")
	BaselineFlow.top_screen().call("back")
	await frames(2)
	expect(BaselineFlow.top_screen() is BaselinePauseMenu, "back to pause")
	expect(get_tree().paused, "still paused")
	BaselineFlow.reset_for_tests()
	get_tree().current_scene = get_tree().root.get_node("Runner")
	game.free()


func test_gameplay_tab_follows_settings_and_resets() -> void:
	var voice := BaselineFlow.config.enable_voice
	var look := BaselineFlow.config.enable_mouse_look
	await _open("gameplay")
	var tab: Control = menu.current_tab()
	expect_eq(tab is BaselineOptionsGameplayTab, voice or look, "gameplay tab only with mouse-look or voice")
	if not tab is BaselineOptionsGameplayTab:
		return
	expect_eq(menu.find_button("Subtitles") != null, voice, "Subtitles switch only with voice")
	expect_eq(menu.find_button("Invert vertical look") != null, look, "invert only with mouse-look")
	if voice:
		BaselineSettings.set_value("subtitles.dialogue", false)
	if look:
		BaselineSettings.set_value("input.look_sensitivity", 2.0)
		BaselineSettings.set_value("input.invert_y", true)
	await frames(1)
	if voice:
		expect_eq(menu.find_button("Subtitles").button_pressed, false, "switch follows setting")
	menu.find_button("Reset gameplay").pressed.emit()
	await frames(1)
	if voice:
		expect_eq(BaselineSettings.get_value("subtitles.dialogue"), true, "subtitles reset")
		expect_eq(menu.find_button("Subtitles").button_pressed, true, "switch refreshed")
	if look:
		expect_eq(BaselineSettings.get_value("input.look_sensitivity"), 1.0, "sensitivity reset")
		expect_eq(BaselineSettings.get_value("input.invert_y"), false, "invert reset")


func test_reset_controls_asks_first() -> void:
	await _open("controls")
	var bindings: Dictionary = BaselineSettings.get_value("game.input.bindings")
	bindings["jump"] = [{"type": "key", "physical_keycode": KEY_J}]
	BaselineSettings.set_value("game.input.bindings", bindings)
	var custom: Dictionary = BaselineSettings.get_value("game.input.bindings")
	expect(custom != BaselineSettings.get_default("game.input.bindings"), "jump customised")
	menu.find_button("Reset controls").pressed.emit()
	await frames(2)
	var dialog := BaselineFlow.top_screen() as BaselineConfirm
	expect(dialog != null, "reset asks first")
	if dialog == null:
		return
	expect(dialog.find_button("Reset controls") != null, "confirm button names the action")
	dialog.find_button("Cancel").pressed.emit()
	await frames(2)
	expect_eq(BaselineSettings.get_value("game.input.bindings"), custom, "cancel keeps the custom binding")
	menu.find_button("Reset controls").pressed.emit()
	await frames(2)
	(BaselineFlow.top_screen() as BaselineConfirm).find_button("Reset controls").pressed.emit()
	await frames(2)
	expect_eq(BaselineSettings.get_value("game.input.bindings"), BaselineSettings.get_default("game.input.bindings"), "confirm restores defaults")
	expect_eq(BaselineFlow.top_screen(), menu, "back on the options menu")
