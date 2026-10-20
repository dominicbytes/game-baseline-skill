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
