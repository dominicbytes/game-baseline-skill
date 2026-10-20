class_name BaselineSubtitle
extends Label
## One line of dialogue subtitles near the bottom of the screen. BaselineFlow
## draws it below the menu screens. Its timer stops while the game is paused,
## so a line is not missed behind the pause menu.

var _timer: Timer


func _init() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -140.0
	offset_bottom = -40.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 28)
	add_theme_constant_override("outline_size", 8)
	add_theme_color_override("font_outline_color", Color.BLACK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_timer.timeout.connect(hide_now)
	add_child(_timer)


## Shows line for seconds, replacing any line already shown.
func show_line(line: String, seconds: float) -> void:
	text = line
	show()
	_timer.start(seconds)


## Hides the line now.
func hide_now() -> void:
	_timer.stop()
	hide()
