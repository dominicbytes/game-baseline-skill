extends BaselineTestCase

const FIXTURE := preload("res://tests/fixtures/fixture_game.tscn")
const Fixture := preload("res://tests/fixtures/fixture_game.gd")

var game: Node


func after_each() -> void:
	BaselineFlow.reset_for_tests()
	_free_game()


func _start_game() -> void:
	game = FIXTURE.instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game


func _free_game() -> void:
	get_tree().current_scene = get_tree().root.get_node("Runner")
	if is_instance_valid(game):
		game.free()


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await frames(2)


func test_esc_pauses_and_esc_resumes() -> void:
	_start_game()
	await frames(2)
	await _tap("ui_cancel")
	expect(get_tree().paused, "paused")
	expect(BaselineFlow.top_screen() is BaselinePauseMenu, "pause menu shown")
	await _tap("ui_cancel")
	expect(not get_tree().paused, "resumed")
	expect(not BaselineFlow.has_screens(), "menu closed")


func test_pause_stops_gameplay_but_not_music() -> void:
	BaselineFlow.play_music(Fixture.silent_loop(), 0.0)
	_start_game()
	await frames(5)
	BaselineFlow.pause()
	var elapsed: float = game.elapsed
	var bob: float = game.bob
	await frames(20)
	expect_eq(game.elapsed, elapsed, "timer frozen")
	expect_eq(game.bob, bob, "tween frozen")
	expect(game.loop_player.stream_paused, "gameplay loop paused")
	expect(BaselineFlow.music_player().playing, "music keeps playing")
	await get_tree().create_timer(0.4, true).timeout
	expect(absf(BaselineFlow.music_player().volume_db - BaselineMusic.DUCK_DB) < 0.5, "music ducked to -10 dB")
	BaselineFlow.resume()
	await get_tree().create_timer(0.4, true).timeout
	expect(absf(BaselineFlow.music_player().volume_db) < 0.5, "music back to 0 dB")
	expect(game.elapsed > elapsed, "timer runs again")
	expect(not game.loop_player.stream_paused, "loop resumed")


func test_focus_loss_pauses_only_in_gameplay() -> void:
	BaselineFlow.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	expect(not get_tree().paused, "no pause outside gameplay")
	_start_game()
	BaselineFlow.set_gameplay_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	expect_eq(BaselineFlow.requested_mouse_mode, Input.MOUSE_MODE_CAPTURED, "gameplay captured the mouse")
	BaselineFlow.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	expect(get_tree().paused, "paused on focus loss")
	expect_eq(BaselineFlow.requested_mouse_mode, Input.MOUSE_MODE_VISIBLE, "cursor released")
	BaselineFlow.resume()
	expect_eq(BaselineFlow.requested_mouse_mode, Input.MOUSE_MODE_CAPTURED, "gameplay mode restored on resume")


func test_focus_loss_during_transition_pauses_afterwards() -> void:
	BaselineFlow.change_scene_impl = func(_path: String) -> void: _start_game()
	BaselineFlow.change_scene("res://unused.tscn")
	await frames(2)
	BaselineFlow.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().create_timer(BaselineFlow.FADE_TIME * 2.0 + 0.3, true).timeout
	await frames(2)
	expect(get_tree().paused, "paused once the transition finished")


func test_quit_flushes_settings_and_stops_audio() -> void:
	_start_game()
	await frames(2)
	var quit_calls := [0]
	BaselineFlow.quit_impl = func() -> void: quit_calls[0] += 1
	BaselineSettings.set_value("audio.sfx", 0.33)
	await BaselineFlow.quit_game()
	expect_eq(quit_calls[0], 1, "quit called once")
	expect(FileAccess.file_exists(BaselineSettings.PATH), "settings flushed before quit")
	expect(game.loop_player.stream == null, "streams released")


func test_close_request_runs_clean_quit() -> void:
	var quit_calls := [0]
	BaselineFlow.quit_impl = func() -> void: quit_calls[0] += 1
	BaselineFlow.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await get_tree().create_timer(BaselineFlow.QUIT_DRAIN_TIME + 0.1, true).timeout
	expect_eq(quit_calls[0], 1, "close request goes through quit_game")


func test_music_fades_in_from_silence() -> void:
	BaselineFlow.play_music(Fixture.silent_loop())
	expect(BaselineFlow.music_player().volume_db <= -60.0, "starts silent")
	await get_tree().create_timer(1.0, true).timeout
	var at_one_second: float = BaselineFlow.music_player().volume_db
	expect(at_one_second < -3.0 and at_one_second > -79.0, "rising but still below target at 1 s")


func test_subtitle_follows_setting() -> void:
	BaselineFlow.show_subtitle("Hello", 0.5)
	expect(BaselineFlow.subtitle_label().visible, "shown when on")
	BaselineSettings.set_value("subtitles.dialogue", false)
	BaselineFlow.show_subtitle("Hidden", 0.5)
	expect_eq(BaselineFlow.subtitle_label().text, "Hello", "not replaced when off")


func test_confirm_defaults_to_cancel_and_esc_cancels() -> void:
	var dialog := BaselineConfirm.ask("Quit?", "Quit")
	await frames(2)
	expect_eq(get_viewport().gui_get_focus_owner(), dialog.first_focus(), "focus on Cancel")
	expect_eq(dialog.first_focus().text, "Cancel", "cancel text")
	var answers: Array = []
	dialog.answered.connect(func(ok: bool) -> void: answers.append(ok))
	await _tap("ui_cancel")
	expect_eq(answers, [false], "Esc answers no")
	expect(not BaselineFlow.has_screens(), "dialog closed")


func test_pause_menu_return_to_title_needs_confirmation() -> void:
	_start_game()
	await frames(2)
	var changes: Array = []
	BaselineFlow.change_scene_impl = func(path: String) -> void: changes.append(path)
	BaselineFlow.pause()
	await frames(2)
	var menu := BaselineFlow.top_screen() as BaselinePauseMenu
	menu.find_button("Return to Title").pressed.emit()
	await frames(2)
	expect(BaselineFlow.top_screen() is BaselineConfirm, "confirmation shown")
	(BaselineFlow.top_screen() as BaselineConfirm).answered.emit(false)
	BaselineFlow.pop_screen()
	await frames(2)
	expect(changes.is_empty(), "cancel keeps playing")
	expect(get_tree().paused, "still paused")


func test_parse_quit_after() -> void:
	expect_eq(BaselineFlow._parse_quit_after(PackedStringArray()), -1.0, "absent")
	expect_eq(BaselineFlow._parse_quit_after(PackedStringArray(["--only=test_flow"])), -1.0, "other args only")
	expect_eq(BaselineFlow._parse_quit_after(PackedStringArray(["--baseline-quit-after=2"])), 2.0, "whole seconds")
	expect_eq(BaselineFlow._parse_quit_after(PackedStringArray(["--x", "--baseline-quit-after=0.5"])), 0.5, "fractions, among other args")
	expect_eq(BaselineFlow._parse_quit_after(PackedStringArray(["--baseline-quit-after=soon"])), -1.0, "not a number")
	expect_eq(BaselineFlow._parse_quit_after(PackedStringArray(["--baseline-quit-after=0"])), -1.0, "zero")


func test_quit_after_starts_timer_that_runs_clean_quit() -> void:
	expect(BaselineFlow._setup_quit_after(PackedStringArray()) == null, "no timer without the argument")
	var quit_calls := [0]
	BaselineFlow.quit_impl = func() -> void: quit_calls[0] += 1
	var timer: Timer = BaselineFlow._setup_quit_after(PackedStringArray(["--baseline-quit-after=0.1"]))
	expect(timer != null and timer.is_inside_tree(), "timer added")
	if timer == null:
		return
	expect_eq(timer.wait_time, 0.1, "timer length")
	expect_eq(timer.process_mode, Node.PROCESS_MODE_ALWAYS, "runs while paused")
	get_tree().paused = true
	await get_tree().create_timer(0.1 + BaselineFlow.QUIT_DRAIN_TIME + 0.2, true, false, true).timeout
	expect_eq(quit_calls[0], 1, "timer quits through quit_game")
