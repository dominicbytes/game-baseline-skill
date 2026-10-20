extends BaselineTestCase

const DEMO := preload("res://demo/demo_game.tscn")
var game: Node


func before_each() -> void:
	super()
	BaselineSave.delete()
	get_tree().root.size = Vector2i(1280, 720)
	game = DEMO.instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(2)
	game.set_physics_process(false)


func after_each() -> void:
	Input.action_release("move_right")
	await _action("aim", false)
	BaselineFlow.reset_for_tests()
	get_tree().current_scene = get_tree().root.get_node("Runner")
	game.free()
	BaselineSave.delete()


func _action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)


func test_loops_are_set() -> void:
	expect_eq((load("res://demo/assets/music_loop.wav") as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "music loops")
	expect_eq((load("res://demo/assets/hum_loop.wav") as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "hum loops")


func test_movement_is_frame_rate_independent() -> void:
	Input.action_press("move_right")
	var start: Vector2 = game.player_position()
	for i in 30:
		game.step(1.0 / 30.0)
	var at_30: Vector2 = game.player_position() - start
	game.set_player_position(start)
	for i in 144:
		game.step(1.0 / 144.0)
	var at_144: Vector2 = game.player_position() - start
	expect(at_30.x > 100.0, "moved right")
	expect(at_30.distance_to(at_144) < 0.5, "same distance at 30 and 144 fps")


func test_ui_click_does_not_trigger_gameplay() -> void:
	var button: Button = game.save_button()
	var center := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = center
		click.global_position = center
		get_viewport().push_input(click, true)
	await frames(2)
	expect_eq(game.ping_count, 0, "no ping from a UI click")
	expect(BaselineSave.has_save(), "save button worked")


func test_click_on_world_pings() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(400, 400)
	click.global_position = Vector2(400, 400)
	get_viewport().push_input(click, true)
	await frames(2)
	expect_eq(game.ping_count, 1, "world click pings")


func test_mouse_look_while_aiming_respects_invert_and_sensitivity() -> void:
	BaselineSettings.set_value("input.look_sensitivity", 2.0)
	BaselineSettings.set_value("game.input.invert_x", false)
	BaselineSettings.set_value("input.invert_y", true)
	await _action("aim", true)
	expect_eq(BaselineFlow.requested_mouse_mode, Input.MOUSE_MODE_CAPTURED, "aiming captures the mouse")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10, 10)
	game._unhandled_input(motion)
	expect_eq(game.look_offset, Vector2(20, -20), "sensitivity 2, Y inverted")
	await _action("aim", false)
	expect_eq(BaselineFlow.requested_mouse_mode, Input.MOUSE_MODE_VISIBLE, "release frees the mouse")


func test_continue_restores_saved_position() -> void:
	BaselineSave.save({"x": 300.0, "y": 200.0, "elapsed": 42.0})
	var second: Node = DEMO.instantiate()
	get_tree().root.add_child(second)
	expect_eq(second.player_position(), Vector2(300, 200), "position restored")
	expect_eq(second.elapsed, 42.0, "time restored")
	second.free()


func test_prompts_use_live_bindings() -> void:
	expect(game.prompt_text().contains("W / Up Arrow"), "move prompt")
	var bindings: Dictionary = BaselineSettings.get_value("game.input.bindings")
	BaselineSettings.set_value("game.input.bindings", BaselineBindings.assign(bindings, "interact", 0, {"type": "key", "physical_keycode": KEY_F}, false))
	await frames(1)
	expect(game.prompt_text().contains("Save: F"), "prompt follows remap")
