extends Control
## Main menu: Continue (when a save exists), New Game, Options, Credits, Quit.
## A plain scene root, not a BaselineScreen, so it is never part of the screen stack.

var _first_button: Button


func _ready() -> void:
	theme = BaselineFlow.get_theme()
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
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	center.add_child(outer)

	var heading := Label.new()
	heading.text = BaselineFlow.config.game_title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 56)
	# Wide enough for most titles on one line; longer titles still wrap.
	heading.custom_minimum_size.x = 1000.0
	outer.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24.0
	outer.add_child(gap)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 360.0
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 12)
	outer.add_child(box)

	if BaselineSave.has_save():
		_first_button = _add_button(box, "Continue", BaselineFlow.continue_game)
	var new_game := _add_button(box, "New Game", _on_new_game)
	if _first_button == null:
		_first_button = new_game
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


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := BaselineScreen.make_button(text, on_pressed)
	parent.add_child(button)
	return button


func _on_new_game() -> void:
	if BaselineSave.has_save():
		var dialog := BaselineConfirm.ask("Start a new game? Your saved progress will be overwritten.", "Start New Game")
		if not await dialog.answered:
			return
	BaselineFlow.new_game()


func _on_options() -> void:
	BaselineFlow.push_screen(BaselineOptionsMenu.create())


func _on_credits() -> void:
	BaselineFlow.push_screen(BaselineCreditsScreen.new())
