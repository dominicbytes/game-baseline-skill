class_name BaselineScreen
extends Control
## A full-window menu screen on BaselineFlow's screen layer. Screens stack, and
## Esc calls back() on the top one. Subclasses build their UI in _ready().


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = BaselineTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called for Esc. Default: close this screen.
func back() -> void:
	BaselineFlow.pop_screen(self)


## The control that gets focus when the screen opens or becomes top again.
func first_focus() -> Control:
	return null


## Returns the first Button in this screen whose text is text, or null.
func find_button(text: String) -> Button:
	for node in find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


## A dimmed backdrop with a centred panel; returns the panel's VBoxContainer.
func make_panel(min_width: float = 520.0) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


## A Button showing text that calls on_pressed.
static func make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	return button


## A large centred heading.
static func make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	return label
