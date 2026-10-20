class_name BaselineOptionsGameplayTab
extends VBoxContainer
## Gameplay tab: look sensitivity and invert options for games with mouse-look
## (C01), the subtitles switch for games with voice (C02), and a reset button.
## Only registered keys are shown.

const SENSITIVITY_KEY := "input.look_sensitivity"
const TOGGLES := [
	["game.input.invert_x", "Invert horizontal look"],
	["input.invert_y", "Invert vertical look"],
	["subtitles.dialogue", "Subtitles"],
]

var _sensitivity: HSlider
var _sensitivity_label: Label
var _toggles: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	if BaselineSettings.has_key(SENSITIVITY_KEY):
		_add_sensitivity_row()
	for toggle: Array in TOGGLES:
		if BaselineSettings.has_key(toggle[0]):
			var check := CheckButton.new()
			check.text = toggle[1]
			check.toggled.connect(func(on: bool) -> void: BaselineSettings.set_value(toggle[0], on))
			add_child(check)
			_toggles[toggle[0]] = check
	add_child(BaselineScreen.make_button("Reset gameplay", _reset))
	refresh()
	BaselineSettings.changed.connect(_on_setting_changed)


## Reloads every control from BaselineSettings.
func refresh() -> void:
	if _sensitivity != null:
		var value: float = BaselineSettings.get_value(SENSITIVITY_KEY)
		_sensitivity.set_value_no_signal(value)
		_sensitivity_label.text = "%.2f×" % value
	for key: String in _toggles:
		(_toggles[key] as CheckButton).set_pressed_no_signal(BaselineSettings.get_value(key))


func _add_sensitivity_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var label := Label.new()
	label.text = "Look sensitivity"
	label.custom_minimum_size.x = 220.0
	row.add_child(label)
	_sensitivity = HSlider.new()
	_sensitivity.min_value = 0.25
	_sensitivity.max_value = 3.0
	_sensitivity.step = 0.05
	_sensitivity.custom_minimum_size.x = 320.0
	_sensitivity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sensitivity.focus_mode = Control.FOCUS_ALL
	_sensitivity.tooltip_text = "Look sensitivity"
	_sensitivity.value_changed.connect(func(value: float) -> void: BaselineSettings.set_value(SENSITIVITY_KEY, value))
	row.add_child(_sensitivity)
	_sensitivity_label = Label.new()
	_sensitivity_label.custom_minimum_size.x = 90.0
	row.add_child(_sensitivity_label)


func _reset() -> void:
	var keys: Array[String] = [SENSITIVITY_KEY]
	for toggle: Array in TOGGLES:
		keys.append(toggle[0])
	for key in keys:
		if BaselineSettings.has_key(key):
			BaselineSettings.set_value(key, BaselineSettings.get_default(key))


func _on_setting_changed(key: String) -> void:
	if key == SENSITIVITY_KEY or _toggles.has(key):
		refresh()
