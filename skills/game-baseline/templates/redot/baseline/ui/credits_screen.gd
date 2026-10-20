class_name BaselineCreditsScreen
extends BaselineScreen
## Credits: the game's credits text, the engine credit and the engine licence.

var _back: Button


func _ready() -> void:
	var box := make_panel(760.0)
	box.add_child(make_title("Credits"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(712.0, 380.0)
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var label := Label.new()
	label.text = "%s\n\nMade with Redot Engine.\n\n%s" % [BaselineFlow.config.credits_text, Engine.get_license_text()]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label)
	_back = make_button("Back", back)
	box.add_child(_back)


## Back.
func first_focus() -> Control:
	return _back
