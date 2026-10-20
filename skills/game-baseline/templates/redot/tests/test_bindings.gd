extends BaselineTestCase

const W := {"type": "key", "physical_keycode": KEY_W}
const A := {"type": "key", "physical_keycode": KEY_A}
const UP := {"type": "key", "physical_keycode": KEY_UP}
const ESC := {"type": "key", "physical_keycode": KEY_ESCAPE}
const LMB := {"type": "mouse", "button_index": MOUSE_BUTTON_LEFT}


func test_dict_round_trip() -> void:
	expect_eq(BaselineBindings.to_dict(BaselineBindings.from_dict(W)), W, "key")
	expect_eq(BaselineBindings.to_dict(BaselineBindings.from_dict(LMB)), LMB, "mouse")
	expect(BaselineBindings.from_dict({"type": "pad"}) == null, "unknown type rejected")
	expect_eq(BaselineBindings.from_dict(W).device, -1, "matches every device")


func test_esc_is_reserved() -> void:
	expect(BaselineBindings.is_reserved(ESC), "Esc reserved")
	expect(not BaselineBindings.is_reserved(W), "W not reserved")


func test_sanitize_drops_reserved_and_unknown_and_fills_defaults() -> void:
	var defaults := {"move_up": [W], "jump": [UP]}
	var stored := {"move_up": [ESC, A, {"type": "bogus"}], "removed_action": [W]}
	var clean: Dictionary = BaselineBindings.sanitize(stored, defaults)
	expect_eq(clean, {"move_up": [A], "jump": [UP]}, "sanitized")
	expect(BaselineBindings.sanitize("nope", defaults) == null, "non-dictionary rejected")


func test_conflict_and_swap() -> void:
	var bindings := {"move_up": [W], "move_left": [A]}
	expect_eq(BaselineBindings.find_conflict(bindings, "move_up", A), "move_left", "conflict found")
	expect_eq(BaselineBindings.find_conflict(bindings, "move_up", UP), "", "no conflict")
	var swapped: Dictionary = BaselineBindings.assign(bindings, "move_up", 0, A, true)
	expect_eq(swapped, {"move_up": [A], "move_left": [W]}, "swapped")
	expect_eq(bindings, {"move_up": [W], "move_left": [A]}, "input not mutated")
	var added: Dictionary = BaselineBindings.assign(bindings, "move_up", 1, UP, false)
	expect_eq(added["move_up"], [W, UP], "second slot appended")


func test_apply_updates_input_map_and_labels() -> void:
	InputMap.add_action("test_jump")
	BaselineBindings.apply({"test_jump": [UP, LMB]})
	expect_eq(InputMap.action_get_events("test_jump").size(), 2, "two events")
	expect_eq(BaselineInputLabels.action_label("test_jump"), "Up Arrow / Left Mouse", "label")
	BaselineBindings.apply({"test_jump": []})
	expect_eq(BaselineInputLabels.action_label("test_jump"), "Unbound", "unbound label")
	InputMap.erase_action("test_jump")


func test_plain_labels() -> void:
	expect_eq(BaselineInputLabels.dict_label(W), "W", "letter")
	expect_eq(BaselineInputLabels.dict_label({"type": "key", "physical_keycode": KEY_SPACE}), "Space", "space")
	expect_eq(BaselineInputLabels.dict_label({"type": "key", "physical_keycode": KEY_LEFT}), "Left Arrow", "arrow is not just Left")
	expect_eq(BaselineInputLabels.dict_label({"type": "mouse", "button_index": MOUSE_BUTTON_RIGHT}), "Right Mouse", "mouse")
	expect_eq(BaselineInputLabels.dict_label(ESC), "Esc", "esc")


func test_apply_keeps_bindings_it_cannot_represent() -> void:
	InputMap.add_action("test_keep")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	var keycode_only := InputEventKey.new()
	keycode_only.keycode = KEY_F
	var undo := InputEventKey.new()
	undo.physical_keycode = KEY_Z
	undo.ctrl_pressed = true
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	for event: InputEvent in [esc, keycode_only, undo, w]:
		InputMap.action_add_event("test_keep", event)
	BaselineBindings.apply({"test_keep": [A]})
	var events := InputMap.action_get_events("test_keep")
	expect(_has_key_event(events, KEY_ESCAPE, KEY_NONE, false), "Esc kept")
	expect(_has_key_event(events, KEY_NONE, KEY_F, false), "keycode-only key kept")
	expect(_has_key_event(events, KEY_Z, KEY_NONE, true), "Ctrl+Z kept")
	expect(not _has_key_event(events, KEY_W, KEY_NONE, false), "W replaced")
	expect(_has_key_event(events, KEY_A, KEY_NONE, false), "A added")
	expect_eq(events.size(), 4, "event count")
	InputMap.erase_action("test_keep")


func test_apply_keeps_gamepad_events() -> void:
	InputMap.add_action("test_pad")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	InputMap.action_add_event("test_pad", pad)
	BaselineBindings.apply({"test_pad": [W]})
	var has_pad := false
	for event in InputMap.action_get_events("test_pad"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
			has_pad = true
	expect(has_pad, "gamepad button kept")
	expect_eq(InputMap.action_get_events("test_pad").size(), 2, "pad + W")
	InputMap.erase_action("test_pad")


func test_modifier_keys_are_not_representable() -> void:
	var undo := InputEventKey.new()
	undo.physical_keycode = KEY_Z
	undo.ctrl_pressed = true
	expect_eq(BaselineBindings.to_dict(undo), {}, "Ctrl+Z has no dict")
	expect(BaselineBindings.from_dict({"type": "mouse", "button_index": 33}) == null, "mouse index above 32 rejected")
	expect(BaselineBindings.from_dict({"type": "mouse", "button_index": 32}) != null, "mouse index 32 accepted")


func test_assign_moves_within_action() -> void:
	var bindings := {"move_up": [W, UP]}
	var moved: Dictionary = BaselineBindings.assign(bindings, "move_up", 1, W, false)
	expect_eq(moved["move_up"], [W], "moved, not duplicated")
	var moved_back: Dictionary = BaselineBindings.assign(bindings, "move_up", 0, UP, false)
	expect_eq(moved_back["move_up"], [UP], "slot 0 takes UP from slot 1")


func _has_key_event(events: Array[InputEvent], physical: Key, keycode: Key, ctrl: bool) -> bool:
	for event in events:
		if event is InputEventKey and event.physical_keycode == physical and event.keycode == keycode and event.ctrl_pressed == ctrl:
			return true
	return false
