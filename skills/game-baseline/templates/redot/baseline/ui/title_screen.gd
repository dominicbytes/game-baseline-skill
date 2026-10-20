extends Control
## Main menu: Continue (when a save exists), New Game, Options, Credits, Quit.
## A plain scene root, not a BaselineScreen, so it is never part of the screen stack.

var _first_button: Button


func _ready() -> void:
	theme = BaselineTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.05, 0.06, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 360.0
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var heading := Label.new()
	heading.text = BaselineFlow.config.game_title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 56)
	box.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24.0
	box.add_child(gap)

	if BaselineSave.has_save():
		_first_button = _add_button(box, "Continue", BaselineFlow.continue_game)
	var new_game := _add_button(box, "New Game", _on_new_game)
	if _first_button == null:
		_first_button = new_game
	# Options is connected when the options menu exists.
	_add_button(box, "Options", _on_options)
	_add_button(box, "Credits", _on_credits)
	_add_button(box, "Quit", BaselineFlow.quit_game)

	var version := Label.new()
	version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "")
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(version)

	BaselineFlow.play_title_music()
	BaselineFlow.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_first_button.grab_focus.call_deferred()


# Builds the Button itself: calling BaselineScreen.make_button from a script that
# also names BaselineConfirm leaks scripts at exit in this engine build.
func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _on_new_game() -> void:
	if BaselineSave.has_save():
		var dialog := BaselineConfirm.ask("Start a new game? Your saved progress will be overwritten.", "Start New Game")
		if not await dialog.answered:
			return
	BaselineFlow.new_game()


func _on_options() -> void:
	pass


func _on_credits() -> void:
	BaselineFlow.push_screen(BaselineCreditsScreen.new())
