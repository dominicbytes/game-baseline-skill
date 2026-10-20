extends BaselineTestCase

const TITLE := preload("res://baseline/ui/title_screen.tscn")
var title: Control


func _open_title() -> void:
	title = TITLE.instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await frames(2)


func after_each() -> void:
	BaselineFlow.reset_for_tests()
	get_tree().current_scene = get_tree().root.get_node("Runner")
	if is_instance_valid(title):
		title.free()
	BaselineSave.delete()


func _button(text: String) -> Button:
	for node in title.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func test_buttons_without_save() -> void:
	BaselineSave.delete()
	await _open_title()
	expect(_button("Continue") == null, "no Continue without a save")
	for text in ["New Game", "Options", "Credits", "Quit"]:
		expect(_button(text) != null, "%s present" % text)
	expect(get_viewport().gui_get_focus_owner() is Button, "a button has focus")


func test_continue_shown_with_save() -> void:
	BaselineSave.save({"x": 1.0})
	await _open_title()
	expect(_button("Continue") != null, "Continue shown")
	expect_eq(get_viewport().gui_get_focus_owner(), _button("Continue"), "Continue focused first")


func test_version_label() -> void:
	await _open_title()
	var expected := "Version %s" % ProjectSettings.get_setting("application/config/version")
	var found := false
	for node in title.find_children("*", "Label", true, false):
		if (node as Label).text == expected:
			found = true
	expect(found, "version label shows '%s'" % expected)


func test_new_game_over_save_confirms() -> void:
	BaselineSave.save({"x": 1.0})
	await _open_title()
	var changes: Array = []
	BaselineFlow.change_scene_impl = func(path: String) -> void: changes.append(path)
	_button("New Game").pressed.emit()
	await frames(2)
	expect(BaselineFlow.top_screen() is BaselineConfirm, "overwrite confirmation shown")
	BaselineFlow.top_screen().call("back")
	await frames(2)
	expect(changes.is_empty(), "cancel starts nothing")
	expect(BaselineSave.has_save(), "save kept")


func test_new_game_without_save_starts_directly() -> void:
	BaselineSave.delete()
	await _open_title()
	var changes: Array = []
	BaselineFlow.change_scene_impl = func(path: String) -> void: changes.append(path)
	_button("New Game").pressed.emit()
	await get_tree().create_timer(BaselineFlow.FADE_TIME + 0.1, true).timeout
	expect_eq(changes, [BaselineFlow.config.game_scene_path], "game scene requested")


func test_quit_on_title_has_no_confirmation() -> void:
	await _open_title()
	var quit_calls := [0]
	BaselineFlow.quit_impl = func() -> void: quit_calls[0] += 1
	_button("Quit").pressed.emit()
	await get_tree().create_timer(BaselineFlow.QUIT_DRAIN_TIME + 0.1, true).timeout
	expect_eq(quit_calls[0], 1, "quit without dialog")


func test_esc_on_title_does_nothing() -> void:
	await _open_title()
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "ui_cancel"
		event.pressed = pressed
		Input.parse_input_event(event)
	await frames(2)
	expect(not BaselineFlow.has_screens(), "no screen opened")
	expect(not get_tree().paused, "not paused")


func test_credits_include_engine_licence() -> void:
	await _open_title()
	_button("Credits").pressed.emit()
	await frames(2)
	var screen := BaselineFlow.top_screen()
	expect(screen is BaselineCreditsScreen, "credits open")
	var text := ""
	for node in screen.find_children("*", "Label", true, false):
		text += (node as Label).text
	expect(text.contains("Redot"), "mentions Redot")
	expect(text.contains("Permission is hereby granted"), "includes the MIT licence text")


func test_focus_returns_to_credits_after_back() -> void:
	await _open_title()
	var credits := _button("Credits")
	credits.grab_focus()
	await frames(1)
	credits.pressed.emit()
	await frames(2)
	expect(BaselineFlow.top_screen() is BaselineCreditsScreen, "credits open")
	(BaselineFlow.top_screen() as BaselineScreen).find_button("Back").pressed.emit()
	await frames(2)
	expect(not BaselineFlow.has_screens(), "credits closed")
	expect_eq(get_viewport().gui_get_focus_owner(), credits, "focus back on Credits")
