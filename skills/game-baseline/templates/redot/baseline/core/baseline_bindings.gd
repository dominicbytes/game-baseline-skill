class_name BaselineBindings
extends RefCounted
## Converts gameplay bindings between InputMap events and plain dictionaries:
## {"type": "key", "physical_keycode": int} or {"type": "mouse", "button_index": int}.
## Actions starting with "ui_" are menu navigation and are never remapped.

## Physical keys the player may not bind (Esc opens the pause menu).
const RESERVED_KEYS: Array[int] = [KEY_ESCAPE]
## InputEvent device id that matches every keyboard and mouse.
const ALL_DEVICES := -1


## Gameplay actions in project order.
static func gameplay_actions() -> Array[String]:
	var actions: Array[String] = []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			actions.append(String(action))
	return actions


## Converts a key or mouse event to a plain dictionary, or {} for events the
## remap system cannot represent (keycode-only keys, keys with modifiers, gamepad).
static func to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_NONE or key.shift_pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
			return {}
		return {"type": "key", "physical_keycode": int(key.physical_keycode)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button_index": int(event.button_index)}
	return {}


## Converts a plain dictionary back to an event, or null when it is not valid.
static func from_dict(binding: Variant) -> InputEvent:
	if not binding is Dictionary:
		return null
	match binding.get("type"):
		"key":
			var code: Variant = binding.get("physical_keycode")
			if not (code is int or code is float) or int(code) <= 0:
				return null
			var key := InputEventKey.new()
			key.physical_keycode = int(code)
			key.device = ALL_DEVICES
			return key
		"mouse":
			var index: Variant = binding.get("button_index")
			if not (index is int or index is float) or int(index) < 1 or int(index) > 32:
				return null
			var button := InputEventMouseButton.new()
			button.button_index = int(index)
			button.device = ALL_DEVICES
			return button
	return null


## True for bindings the player may not assign (Esc opens the pause menu).
static func is_reserved(binding: Dictionary) -> bool:
	return binding.get("type") == "key" and int(binding.get("physical_keycode", 0)) in RESERVED_KEYS


## Current key and mouse bindings of every gameplay action.
static func snapshot() -> Dictionary:
	var bindings := {}
	for action in gameplay_actions():
		var events: Array = []
		for event in InputMap.action_get_events(action):
			var binding := to_dict(event)
			if not binding.is_empty() and not is_reserved(binding):
				events.append(binding)
		bindings[action] = events
	return bindings


## Returns a clean copy of stored bindings, or null if value is not a Dictionary.
## Unknown actions are dropped, missing actions get their defaults, and invalid
## or reserved entries are removed.
static func sanitize(value: Variant, defaults: Dictionary) -> Variant:
	if not value is Dictionary:
		return null
	var clean := {}
	for action: String in defaults:
		var stored: Variant = value.get(action, defaults[action])
		if not stored is Array:
			stored = defaults[action]
		var events: Array = []
		for binding: Variant in stored:
			var event := from_dict(binding)
			if event == null:
				continue
			var normalized := to_dict(event)
			if not is_reserved(normalized) and not normalized in events:
				events.append(normalized)
		clean[action] = events
	return clean


## Replaces the remappable key and mouse events of each action. Events the
## remap system cannot represent (gamepad, Esc, keycode-only keys, modifier
## combos) are left alone.
static func apply(bindings: Dictionary) -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var binding := to_dict(event)
			if not binding.is_empty() and not is_reserved(binding):
				InputMap.action_erase_event(action, event)
		for binding: Dictionary in bindings[action]:
			var event := from_dict(binding)
			if event != null:
				InputMap.action_add_event(action, event)


## Returns the other action already using binding, or "".
static func find_conflict(bindings: Dictionary, action: String, binding: Dictionary) -> String:
	for other: String in bindings:
		if other != action and binding in bindings[other]:
			return other
	return ""


## Returns a copy with binding set in slot of action. With swap, the action that
## held binding gets this slot's previous binding instead (or loses it). If
## binding already sits in another slot of the same action, it moves.
static func assign(bindings: Dictionary, action: String, slot: int, binding: Dictionary, swap: bool) -> Dictionary:
	var result: Dictionary = bindings.duplicate(true)
	if slot < 0:
		push_error("BaselineBindings: negative slot %d for %s" % [slot, action])
		return result
	var events: Array = result.get(action, [])
	var previous: Dictionary = events[slot] if slot < events.size() else {}
	if swap:
		var other := find_conflict(result, action, binding)
		if other != "":
			var other_events: Array = result[other]
			var index := other_events.find(binding)
			if previous.is_empty():
				other_events.remove_at(index)
			else:
				other_events[index] = previous
	var placed := slot
	if slot < events.size():
		events[slot] = binding
	else:
		events.append(binding)
		placed = events.size() - 1
	for i in range(events.size() - 1, -1, -1):
		if i != placed and events[i] == binding:
			events.remove_at(i)
	result[action] = events
	return result
