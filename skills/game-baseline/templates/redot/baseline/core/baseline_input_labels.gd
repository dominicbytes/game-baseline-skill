class_name BaselineInputLabels
extends RefCounted
## Plain-language labels for live bindings, in the player's keyboard layout.

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Left Mouse",
	MOUSE_BUTTON_RIGHT: "Right Mouse",
	MOUSE_BUTTON_MIDDLE: "Middle Mouse",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
	MOUSE_BUTTON_XBUTTON1: "Mouse Back",
	MOUSE_BUTTON_XBUTTON2: "Mouse Forward",
}
## Keys whose engine names are ambiguous or terse.
const KEY_NAMES := {
	KEY_LEFT: "Left Arrow",
	KEY_RIGHT: "Right Arrow",
	KEY_UP: "Up Arrow",
	KEY_DOWN: "Down Arrow",
	KEY_ESCAPE: "Esc",
	KEY_ENTER: "Enter",
	KEY_KP_ENTER: "Keypad Enter",
	KEY_SPACE: "Space",
}


## Label for one key or mouse event, or "" for other event types.
static func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: Key = event.keycode
		if event.physical_keycode != KEY_NONE:
			if KEY_NAMES.has(event.physical_keycode):
				return KEY_NAMES[event.physical_keycode]
			# The headless display server has no keyboard layout and reports an error.
			code = event.physical_keycode
			if DisplayServer.get_name() != "headless":
				var mapped := DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
				if mapped != KEY_NONE:
					code = mapped
		if KEY_NAMES.has(code):
			return KEY_NAMES[code]
		var text := OS.get_keycode_string(code)
		return text if text != "" else "Unknown key"
	if event is InputEventMouseButton:
		return MOUSE_NAMES.get(event.button_index, "Mouse %d" % event.button_index)
	return ""


## Label for a binding dictionary, or "" when it is not valid.
static func dict_label(binding: Dictionary) -> String:
	var event := BaselineBindings.from_dict(binding)
	return event_label(event) if event != null else ""


## "W / Up Arrow" for every key and mouse binding of action, or "Unbound".
static func action_label(action: String) -> String:
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			labels.append(event_label(event))
	return " / ".join(labels) if not labels.is_empty() else "Unbound"
