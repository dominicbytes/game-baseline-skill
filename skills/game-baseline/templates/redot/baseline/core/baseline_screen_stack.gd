class_name BaselineScreenStack
extends Node
## BaselineFlow's menu screen stack. Shows screens on their own canvas layer,
## sends Esc to the top screen's back() and restores keyboard focus when
## screens close. A screen freed by any means leaves the stack together with
## the focus saved for it.

## Emitted when Esc is pressed while no screen is open.
signal cancel_without_screen

## Canvas layer the screens are drawn on.
const LAYER := 100

var _layer: CanvasLayer
var _screens: Array[Control] = []
## The focus owner from before each screen opened, parallel to _screens.
var _focus_before: Array = []


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)


## Shows screen on top of the stack and focuses it.
func push(screen: Control) -> void:
	_focus_before.append(get_viewport().gui_get_focus_owner())
	_screens.append(screen)
	screen.tree_exiting.connect(_on_screen_exiting.bind(screen))
	_layer.add_child(screen)
	_focus_screen.call_deferred(screen)


## Closes the top screen. With screen given, only closes it if it is the top.
func pop(screen: Control = null) -> void:
	if _screens.is_empty() or (screen != null and screen != _screens.back()):
		return
	remove_screen(_screens.back())


## Closes screen wherever it is in the stack. Does nothing if it is not there.
func remove_screen(screen: Control) -> void:
	if _take(screen):
		screen.queue_free()


## Closes every screen, then restores focus once, to the control that had it
## before the first screen opened.
func clear() -> void:
	if _screens.is_empty():
		return
	var previous: Variant = _focus_before[0]
	for screen in _screens:
		screen.queue_free()
	_screens.clear()
	_focus_before.clear()
	_restore_focus.call_deferred(previous)


## The screen on top of the stack, or null.
func top() -> Control:
	return _screens.back() if not _screens.is_empty() else null


## True while any screen is open.
func has_screens() -> bool:
	return not _screens.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _screens.is_empty():
		cancel_without_screen.emit()
		return
	get_viewport().set_input_as_handled()
	var screen: Control = _screens.back()
	if screen.has_method("back"):
		screen.call("back")


## Removes screen and its saved focus from the stack without freeing it.
## Returns false when screen is not in the stack.
func _take(screen: Control) -> bool:
	var index := _screens.find(screen)
	if index < 0:
		return false
	var previous: Variant = _focus_before[index]
	_screens.remove_at(index)
	_focus_before.remove_at(index)
	if index < _screens.size():
		# The screen above saved a focus owner inside the removed screen.
		var saved: Variant = _focus_before[index]
		if not is_instance_valid(saved) or screen.is_ancestor_of(saved):
			_focus_before[index] = previous
	else:
		_restore_focus.call_deferred(previous)
	return true


func _on_screen_exiting(screen: Control) -> void:
	_take(screen)


func _restore_focus(previous: Variant) -> void:
	if is_instance_valid(previous) and previous is Control and (previous as Control).is_visible_in_tree():
		(previous as Control).grab_focus()
	elif not _screens.is_empty():
		_focus_screen(_screens.back())


func _focus_screen(screen: Control) -> void:
	if not is_instance_valid(screen) or screen != top():
		return
	var target: Control = screen.call("first_focus") if screen.has_method("first_focus") else null
	if target == null:
		target = screen.find_next_valid_focus()
	if target != null:
		target.grab_focus()
