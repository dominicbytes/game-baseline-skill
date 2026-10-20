class_name BaselinePauseMenu
extends BaselineScreen
## Pause menu. Esc resumes.

var _resume: Button


func _ready() -> void:
	var box := make_panel()
	box.add_child(make_title("Paused"))
	_resume = make_button("Resume", BaselineFlow.resume)
	box.add_child(_resume)
	box.add_child(make_button("Return to Title", _on_return_to_title))
	box.add_child(make_button("Quit to Desktop", _on_quit))


## Resume.
func first_focus() -> Control:
	return _resume


## Esc resumes the game.
func back() -> void:
	BaselineFlow.resume()


func _on_return_to_title() -> void:
	var dialog := BaselineConfirm.ask("Return to the title screen? Progress since your last save will be lost.", "Return to Title")
	if await dialog.answered:
		BaselineFlow.return_to_title()


func _on_quit() -> void:
	var dialog := BaselineConfirm.ask("Quit to desktop? Progress since your last save will be lost.", "Quit")
	if await dialog.answered:
		BaselineFlow.quit_game()
