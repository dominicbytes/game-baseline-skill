class_name BaselineControlsPanel
extends VBoxContainer
## Controls tab: two binding slots per gameplay action. Pressing a slot waits for
## the next key or mouse button; Esc cancels and can never be bound. A binding
## used by another action asks before swapping the two. Reset controls asks
## first, because custom bindings would be lost.

const BINDINGS_KEY := "game.input.bindings"
const SLOTS := 2
const EMPTY_SLOT := "—"
const CAPTURE_TEXT := "Press a key or mouse button (Esc cancels)"
const WHEEL_BUTTONS: Array[MouseButton] = [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]

var _actions: Array[String] = []
var _slot_buttons: Dictionary = {}
var _capture_action := ""
var _capture_slot := -1


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var available := BaselineBindings.gameplay_actions()
	for action: String in BaselineFlow.config.action_order:
		if action in available and not action in _actions:
			_actions.append(action)
	for action in available:
		if not action in _actions:
			_actions.append(action)
	for action in _actions:
		_add_row(action)
	var footer := Label.new()
	footer.text = "Esc is reserved for pause and menus. Menus always work with the arrow keys, Enter and Esc."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(footer)
	add_child(BaselineScreen.make_button("Reset controls", _on_reset))
	refresh()
	BaselineSettings.changed.connect(_on_setting_changed)


## Reloads every slot label from BaselineSettings.
func refresh() -> void:
	var bindings: Dictionary = BaselineSettings.get_value(BINDINGS_KEY)
	for action in _actions:
		var events: Array = bindings.get(action, [])
		for slot in SLOTS:
			var text := EMPTY_SLOT
			if slot < events.size():
				text = BaselineInputLabels.dict_label(events[slot])
			if action == _capture_action and slot == _capture_slot:
				text = CAPTURE_TEXT
			slot_button(action, slot).text = text


## The button for slot (0 or 1) of action, or null.
func slot_button(action: String, slot: int) -> Button:
	var buttons: Array = _slot_buttons.get(action, [])
	return buttons[slot] if slot >= 0 and slot < buttons.size() else null


## True while waiting for a key or mouse button.
func is_capturing() -> bool:
	return _capture_slot >= 0


## Gameplay actions in the order they are shown.
func action_rows() -> Array[String]:
	return _actions.duplicate()


func _add_row(action: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var label := Label.new()
	label.text = _action_name(action)
	label.custom_minimum_size.x = 300.0
	row.add_child(label)
	var buttons: Array[Button] = []
	for slot in SLOTS:
		var button := BaselineScreen.make_button(EMPTY_SLOT, _start_capture.bind(action, slot))
		button.custom_minimum_size.x = 230.0
		button.clip_text = true
		row.add_child(button)
		buttons.append(button)
	_slot_buttons[action] = buttons


func _action_name(action: String) -> String:
	return BaselineFlow.config.action_names.get(action, action.capitalize())


func _start_capture(action: String, slot: int) -> void:
	_capture_action = action
	_capture_slot = slot
	refresh()


func _stop_capture() -> void:
	_capture_action = ""
	_capture_slot = -1
	refresh()


func _input(event: InputEvent) -> void:
	if not is_capturing() or event.is_echo() or not event.is_pressed():
		return
	var binding := {}
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_stop_capture()
			return
		if key.physical_keycode == KEY_NONE:
			return
		binding = {"type": "key", "physical_keycode": int(key.physical_keycode)}
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		# Wheel steps and the second press of a double-click are not deliberate bindings.
		if button.double_click or button.button_index in WHEEL_BUTTONS:
			return
		binding = {"type": "mouse", "button_index": int(button.button_index)}
	else:
		return
	get_viewport().set_input_as_handled()
	_bind(binding)


func _bind(binding: Dictionary) -> void:
	var action := _capture_action
	var slot := _capture_slot
	_stop_capture()
	if BaselineBindings.is_reserved(binding):
		return
	var bindings: Dictionary = BaselineSettings.get_value(BINDINGS_KEY)
	var other := BaselineBindings.find_conflict(bindings, action, binding)
	if other != "":
		var question := "“%s” is already used by %s. Swap them?" % [BaselineInputLabels.dict_label(binding), _action_name(other)]
		if not await BaselineConfirm.ask(question, "Swap").answered:
			return
		bindings = BaselineSettings.get_value(BINDINGS_KEY)
	BaselineSettings.set_value(BINDINGS_KEY, BaselineBindings.assign(bindings, action, slot, binding, other != ""))


func _on_reset() -> void:
	if await BaselineConfirm.ask("Reset every control to its default key?", "Reset controls").answered:
		BaselineSettings.reset_category(BINDINGS_KEY)


func _on_setting_changed(key: String) -> void:
	if key == BINDINGS_KEY:
		refresh()
