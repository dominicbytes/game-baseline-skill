class_name BaselineTransition
extends CanvasLayer
## BaselineFlow's scene-change fade: to black and back, drawn above every other
## layer. Blocks the mouse while it runs, and runs while the tree is paused.

## Above the menu screens (BaselineScreenStack.LAYER) and the subtitles.
const LAYER := 110

var _fade: ColorRect
var _tween: Tween


func _init() -> void:
	layer = LAYER
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


## Fades to black over seconds, calls at_black, fades back in over seconds,
## then calls done. Replaces any fade already running.
func play(seconds: float, at_black: Callable, done: Callable) -> void:
	stop()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(_fade, "modulate:a", 1.0, seconds)
	_tween.tween_callback(at_black)
	_tween.tween_property(_fade, "modulate:a", 0.0, seconds)
	_tween.tween_callback(_finish.bind(done))


## True while a fade runs.
func is_running() -> bool:
	return _tween != null


## Stops a running fade where it is. With clear_screen, also removes the black.
func stop(clear_screen: bool = false) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if clear_screen:
		_fade.modulate.a = 0.0
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _finish(done: Callable) -> void:
	_tween = null
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	done.call()
