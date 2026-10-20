class_name BaselineConfirm
extends BaselineScreen
## Yes/no question for actions that lose progress. Focus starts on Cancel.
## Usage: var ok: bool = await BaselineConfirm.ask("Quit to desktop?", "Quit").answered

## Emitted with true for the confirm button, false for Cancel or Esc.
signal answered(confirmed: bool)

var _message := ""
var _confirm_text := ""
var _cancel_text := ""
var _cancel: Button


## Pushes a new dialog onto BaselineFlow's screen stack and returns it.
static func ask(message: String, confirm_text: String, cancel_text: String = "Cancel") -> BaselineConfirm:
	var dialog := BaselineConfirm.new()
	dialog._message = message
	dialog._confirm_text = confirm_text
	dialog._cancel_text = cancel_text
	BaselineFlow.push_screen(dialog)
	return dialog


func _ready() -> void:
	var box := make_panel(560.0)
	var label := Label.new()
	label.text = _message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 500.0
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_cancel = make_button(_cancel_text, _answer.bind(false))
	row.add_child(_cancel)
	row.add_child(make_button(_confirm_text, _answer.bind(true)))


## Cancel, so a stray Enter never confirms.
func first_focus() -> Control:
	return _cancel


## Esc answers no.
func back() -> void:
	_answer(false)


func _answer(confirmed: bool) -> void:
	BaselineFlow.pop_screen(self)
	answered.emit(confirmed)
