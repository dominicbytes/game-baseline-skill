class_name BaselineOptionsDisplayTab
extends VBoxContainer
## Display tab: window mode, window size (windowed mode only), VSync, frame
## rate limit and a reset button.

const MODE_NAMES: Array[String] = ["Windowed", "Fullscreen", "Exclusive fullscreen"]
const FPS_NAMES: Array[String] = ["30", "60", "120", "144", "Match display", "Unlimited"]

var _mode: OptionButton
var _size: OptionButton
var _vsync: CheckButton
var _fps: OptionButton


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_mode = _add_picker("Window mode", MODE_NAMES, _on_mode_selected)
	_size = _add_picker("Window size", [], _on_size_selected)
	_size.tooltip_text = "Fullscreen uses your desktop resolution."
	_fill_sizes()
	_vsync = CheckButton.new()
	_vsync.text = "VSync (reduces screen tearing)"
	_vsync.toggled.connect(func(on: bool) -> void: BaselineSettings.set_value("display.vsync", on))
	add_child(_vsync)
	_fps = _add_picker("Frame rate limit", FPS_NAMES, _on_fps_selected)
	var help := Label.new()
	help.text = "On 120 Hz or faster screens, choose Match display for the smoothest motion."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	add_child(BaselineScreen.make_button("Reset display", BaselineSettings.reset_category.bind("display.")))
	refresh()
	BaselineSettings.changed.connect(_on_setting_changed)


## Reloads every control from BaselineSettings.
func refresh() -> void:
	var mode: String = BaselineSettings.get_value("display.window_mode")
	_mode.select(maxi(BaselineSettings.WINDOW_MODES.find(mode), 0))
	var size: Vector2i = BaselineSettings.get_value("display.window_size")
	var index := _size_index(size)
	if index < 0:
		# A size saved on a bigger screen still shows what is stored.
		_add_size(size)
		index = _size.item_count - 1
	_size.select(index)
	_size.disabled = mode != "windowed"
	_vsync.set_pressed_no_signal(BaselineSettings.get_value("display.vsync"))
	_fps.select(maxi(BaselineSettings.FPS_CHOICES.find(BaselineSettings.get_value("display.max_fps")), 0))


## The window size picker. Disabled unless the window mode is windowed.
func size_picker() -> OptionButton:
	return _size


## The frame rate limit picker.
func fps_picker() -> OptionButton:
	return _fps


func _add_picker(text: String, items: Array[String], on_selected: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 260.0
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = 320.0
	for item in items:
		picker.add_item(item)
	picker.item_selected.connect(on_selected)
	row.add_child(picker)
	return picker


func _fill_sizes() -> void:
	_size.add_item("Automatic")
	_size.set_item_metadata(0, BaselineSettings.AUTO_WINDOW_SIZE)
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	for size in BaselineSettings.window_sizes_for_screen(screen):
		_add_size(size)


func _add_size(size: Vector2i) -> void:
	_size.add_item("%d × %d" % [size.x, size.y])
	_size.set_item_metadata(_size.item_count - 1, size)


func _size_index(size: Vector2i) -> int:
	for i in _size.item_count:
		if _size.get_item_metadata(i) == size:
			return i
	return -1


func _on_mode_selected(index: int) -> void:
	BaselineSettings.set_value("display.window_mode", BaselineSettings.WINDOW_MODES[index])


func _on_size_selected(index: int) -> void:
	BaselineSettings.set_value("display.window_size", _size.get_item_metadata(index))


func _on_fps_selected(index: int) -> void:
	BaselineSettings.set_value("display.max_fps", BaselineSettings.FPS_CHOICES[index])


func _on_setting_changed(key: String) -> void:
	if key.begins_with("display."):
		refresh()
