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
	for text in ["Audio", "Display", "Controls", "Gameplay"]:
		expect(menu.find_button(text) != null, "%s tab" % text)
	expect(menu.find_button("Back") != null, "Back button")


func test_audio_slider_label_and_mute() -> void:
	await _open("audio")
	var tab: BaselineOptionsAudioTab = menu.current_tab()
	tab.slider_for("audio.music").value = 0.0
	expect_eq(tab.value_label_for("audio.music").text, "Muted", "muted label")
	expect_eq(BaselineSettings.get_value("audio.music"), 0.0, "setting follows slider")
	tab.slider_for("audio.music").value = 0.29
	expect_eq(tab.value_label_for("audio.music").text, "29%", "rounded percent")
	expect(tab.slider_for("audio.voice") != null, "voice slider with C02")


func test_window_size_only_in_windowed_mode() -> void:
	await _open("display")
	var tab: BaselineOptionsDisplayTab = menu.current_tab()
	BaselineSettings.set_value("display.window_mode", "fullscreen")
	await frames(1)
	expect(tab.size_picker().disabled, "size disabled in fullscreen")
	BaselineSettings.set_value("display.window_mode", "windowed")
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


func test_controls_follow_action_order() -> void:
	await _open("controls")
	var panel: BaselineControlsPanel = menu.current_tab()
	expect_eq(panel.action_rows().slice(0, 3), ["move_left", "move_right", "move_up"] as Array[String], "config order")


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
	await _open("gameplay")
	var tab: Control = menu.current_tab()
	expect(tab is BaselineOptionsGameplayTab, "gameplay tab open")
	BaselineSettings.set_value("subtitles.dialogue", false)
	BaselineSettings.set_value("input.look_sensitivity", 2.0)
	await frames(1)
	expect_eq(menu.find_button("Subtitles").button_pressed, false, "switch follows setting")
	menu.find_button("Reset gameplay").pressed.emit()
	await frames(1)
	expect_eq(BaselineSettings.get_value("subtitles.dialogue"), true, "subtitles reset")
	expect_eq(BaselineSettings.get_value("input.look_sensitivity"), 1.0, "sensitivity reset")
	expect_eq(menu.find_button("Subtitles").button_pressed, true, "switch refreshed")
