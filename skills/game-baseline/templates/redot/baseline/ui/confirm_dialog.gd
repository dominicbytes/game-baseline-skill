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
var _answered := false


## Pushes a new dialog onto BaselineFlow's screen stack and returns it.
static func ask(message: String, confirm_text: String, cancel_text: String = "Cancel") -> BaselineConfirm:
	# new(), not BaselineConfirm.new(): code that names its own class makes a
	# script cycle, and cycles can leak at exit.
	var dialog: BaselineConfirm = new()
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
	var confirm := make_button(_confirm_text, _answer.bind(true))
	for button: Button in [_cancel, confirm]:
		button.custom_minimum_size = Vector2(200.0, 48.0)
		row.add_child(button)


## Cancel, so a stray Enter never confirms.
func first_focus() -> Control:
	return _cancel


## Esc answers no.
func back() -> void:
	_answer(false)


## Answers once, then closes, even when another screen is above this one.
func _answer(confirmed: bool) -> void:
	if _answered:
		return
	_answered = true
	BaselineFlow.remove_screen(self)
	answered.emit(confirmed)
