class_name BaselineOptionsAudioTab
extends VBoxContainer
## Audio tab: one volume slider per bus (Voice only for games with C02 voice),
## each with a plain value label, and a reset button.

const ROWS := [
	["audio.master", "Master"],
	["audio.music", "Music"],
	["audio.sfx", "Sound effects"],
	["audio.voice", "Voice"],
]

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	for row: Array in ROWS:
		if BaselineSettings.has_key(row[0]):
			_add_row(row[0], row[1])
	add_child(BaselineScreen.make_button("Reset audio", BaselineSettings.reset_category.bind("audio.")))
	refresh()
	BaselineSettings.changed.connect(_on_setting_changed)


## Reloads every slider and label from BaselineSettings.
func refresh() -> void:
	for key: String in _sliders:
		var value: float = BaselineSettings.get_value(key)
		(_sliders[key] as HSlider).set_value_no_signal(value)
		_show_value(key, value)


## The slider for key, e.g. "audio.music", or null when the key is not shown.
func slider_for(key: String) -> HSlider:
	return _sliders.get(key)


## The label showing key's value ("Muted" or a percentage), or null.
func value_label_for(key: String) -> Label:
	return _value_labels.get(key)


## "Muted" at zero, otherwise a whole percentage such as "70%".
static func volume_text(value: float) -> String:
	return "Muted" if value <= 0.0 else "%d%%" % roundi(value * 100.0)


func _add_row(key: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size.x = 220.0
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size.x = 320.0
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.tooltip_text = "%s volume" % text
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 90.0
	row.add_child(value_label)
	_sliders[key] = slider
	_value_labels[key] = value_label


func _show_value(key: String, value: float) -> void:
	(_value_labels[key] as Label).text = volume_text(value)


func _on_slider_changed(value: float, key: String) -> void:
	BaselineSettings.set_value(key, value)
	_show_value(key, value)


func _on_setting_changed(key: String) -> void:
	if _sliders.has(key):
		refresh()
