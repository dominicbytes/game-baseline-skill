class_name BaselineOptionsMenu
extends BaselineScreen
## Options: a row of tabs (Audio, Display, Controls and, for games with mouse-look
## or voice, Gameplay), the selected tab's controls and a Back button.
## Settings apply and save as they change; there is no Apply button.

const TAB_NAMES := {
	"audio": "Audio",
	"display": "Display",
	"controls": "Controls",
	"gameplay": "Gameplay",
}

var _start_tab := "audio"
var _tab_buttons: Dictionary = {}
var _selected := ""
var _content: ScrollContainer
var _current: Control
var _back: Button


## A new options menu that opens on start_tab ("audio", "display", "controls"
## or "gameplay"). Push it with BaselineFlow.push_screen.
static func create(start_tab: String = "audio") -> BaselineOptionsMenu:
	# new(), not BaselineOptionsMenu.new(): code that names its own class makes a
	# script cycle, and cycles can leak at exit.
	var menu: BaselineOptionsMenu = new()
	menu._start_tab = start_tab
	return menu


func _ready() -> void:
	var box := make_panel(860.0)
	box.add_child(make_title("Options"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var group := ButtonGroup.new()
	for id: String in _tab_ids():
		var button := make_button(TAB_NAMES[id], _select_tab.bind(id))
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.x = 150.0
		row.add_child(button)
		_tab_buttons[id] = button
	_content = ScrollContainer.new()
	_content.custom_minimum_size = Vector2(812.0, 430.0)
	_content.follow_focus = true
	_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_content)
	_back = make_button("Back", back)
	box.add_child(_back)
	_select_tab(_start_tab if _tab_buttons.has(_start_tab) else "audio")


## The selected tab's root control.
func current_tab() -> Control:
	return _current


## The selected tab's button.
func first_focus() -> Control:
	return _tab_buttons.get(_selected)


func _tab_ids() -> Array[String]:
	var ids: Array[String] = ["audio", "display", "controls"]
	if BaselineFlow.config.enable_mouse_look or BaselineFlow.config.enable_voice:
		ids.append("gameplay")
	return ids


func _select_tab(id: String) -> void:
	(_tab_buttons[id] as Button).button_pressed = true
	if id == _selected:
		return
	_selected = id
	if _current != null:
		_content.remove_child(_current)
		_current.queue_free()
	match id:
		"display":
			_current = BaselineOptionsDisplayTab.new()
		"controls":
			_current = BaselineControlsPanel.new()
		"gameplay":
			_current = BaselineOptionsGameplayTab.new()
		_:
			_current = BaselineOptionsAudioTab.new()
	_current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_current)
