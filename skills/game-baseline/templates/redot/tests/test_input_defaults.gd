extends BaselineTestCase


func test_gameplay_actions_exist_with_physical_keys() -> void:
	var actions := BaselineBindings.gameplay_actions()
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "primary"]:
		expect(action in actions, "%s exists" % action)
	for action in actions:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				expect(event.physical_keycode != KEY_NONE, "%s uses physical keys" % action)
				expect(event.physical_keycode != KEY_ESCAPE, "%s not on Esc" % action)


func test_default_labels() -> void:
	expect_eq(BaselineInputLabels.action_label("move_up"), "W / Up Arrow", "move up")
	expect_eq(BaselineInputLabels.action_label("primary"), "Left Mouse", "primary")


func test_every_gameplay_action_has_a_friendly_name() -> void:
	for action in BaselineBindings.gameplay_actions():
		expect(BaselineFlow.config.action_names.has(action), "%s has a name in action_names" % action)
	expect_eq(BaselineFlow.config.action_names.get("aim"), "Aim (hold)", "aim says it is held")
