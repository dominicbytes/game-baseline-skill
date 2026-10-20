extends Node
## Autoload BaselineFlow. Owns pause, the menu screen stack, Esc routing,
## focus-loss pause, scene changes, music, subtitles and the clean quit.

## Emitted after the game pauses (true) or resumes (false).
signal paused_changed(is_paused: bool)

const GAMEPLAY_GROUP := &"baseline_gameplay"
const FADE_TIME := 0.25
## Loaded when needed, not referenced by class: the menu calls BaselineFlow, and
## that script cycle keeps scripts alive at exit ("resources still in use").
const PAUSE_MENU_PATH := "res://baseline/ui/pause_menu.gd"

var config: BaselineConfig = preload("res://baseline/baseline_config.tres")
## Mouse mode gameplay wants while it runs, e.g. captured while aiming.
var gameplay_mouse_mode := Input.MOUSE_MODE_VISIBLE
## Last mouse mode requested here. Headless runs cannot read it back from Input.
var requested_mouse_mode := Input.MOUSE_MODE_VISIBLE
## Tests replace these so quitting and scene changes don't end the run.
var quit_impl: Callable
var change_scene_impl: Callable

var _screen_layer: CanvasLayer
var _overlay_layer: CanvasLayer
var _screens: Array[Control] = []
var _focus_before: Array = []
var _fade: ColorRect
var _transition: Tween
var _music: BaselineMusic
var _subtitle: BaselineSubtitle
var _quitting := false
var _pause_after_transition := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_reset_impls()
	_screen_layer = CanvasLayer.new()
	_screen_layer.layer = 100
	add_child(_screen_layer)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 110
	add_child(_overlay_layer)
	_subtitle = BaselineSubtitle.new()
	_overlay_layer.add_child(_subtitle)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_fade)
	_music = BaselineMusic.new()
	add_child(_music)
	BaselineFile.remove_stale_temp(BaselineSave.PATH)


## True while the scene tree is paused.
func is_paused() -> bool:
	return get_tree().paused


## True while a gameplay scene is current and no scene transition is running.
func is_gameplay_active() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group(GAMEPLAY_GROUP) and _transition == null


## Pauses gameplay and opens the pause menu. Does nothing outside gameplay.
func pause(reason: String = "menu") -> void:
	if is_paused() or _quitting:
		return
	if not is_gameplay_active():
		if _transition != null and reason == "focus lost":
			_pause_after_transition = true
		return
	get_tree().paused = true
	set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_music.duck(true)
	push_screen((load(PAUSE_MENU_PATH) as GDScript).new())
	print("[baseline] paused (%s)" % reason)
	paused_changed.emit(true)


## Closes every menu screen and unpauses gameplay.
func resume() -> void:
	if not is_paused():
		return
	while not _screens.is_empty():
		pop_screen()
	get_tree().paused = false
	set_mouse_mode(gameplay_mouse_mode)
	_music.duck(false)
	print("[baseline] resumed")
	paused_changed.emit(false)


## Sets the mouse mode now and remembers it in requested_mouse_mode.
func set_mouse_mode(mode: Input.MouseMode) -> void:
	requested_mouse_mode = mode
	Input.mouse_mode = mode


## Gameplay calls this to capture or release the mouse.
func set_gameplay_mouse_mode(mode: Input.MouseMode) -> void:
	gameplay_mouse_mode = mode
	if not is_paused():
		set_mouse_mode(mode)


## Shows screen on top of the stack and focuses it.
func push_screen(screen: Control) -> void:
	_focus_before.append(get_viewport().gui_get_focus_owner())
	_screens.append(screen)
	_screen_layer.add_child(screen)
	_focus_screen.call_deferred(screen)


## Closes the top screen. With screen given, only closes it if it is the top.
func pop_screen(screen: Control = null) -> void:
	if _screens.is_empty() or (screen != null and screen != _screens.back()):
		return
	var top: Control = _screens.pop_back()
	var previous: Variant = _focus_before.pop_back()
	top.queue_free()
	if is_instance_valid(previous) and previous is Control and (previous as Control).is_visible_in_tree():
		(previous as Control).grab_focus.call_deferred()
	elif not _screens.is_empty():
		_focus_screen.call_deferred(_screens.back())


## The screen on top of the stack, or null.
func top_screen() -> Control:
	return _screens.back() if not _screens.is_empty() else null


## True while any menu screen is open.
func has_screens() -> bool:
	return not _screens.is_empty()


## Fades to black, changes to the scene at path and fades back in.
func change_scene(path: String) -> void:
	if _transition != null:
		_transition.kill()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition = create_tween()
	_transition.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	_transition.tween_callback(func() -> void: change_scene_impl.call(path))
	_transition.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	_transition.tween_callback(_end_transition)


## Deletes the autosave and starts the game scene.
func new_game() -> void:
	BaselineSave.delete()
	change_scene(config.game_scene_path)


## Starts the game scene; the game loads its own save.
func continue_game() -> void:
	change_scene(config.game_scene_path)


## Closes menus, unpauses and changes to the title scene.
func return_to_title() -> void:
	while not _screens.is_empty():
		pop_screen()
	get_tree().paused = false
	_music.duck(false)
	gameplay_mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	change_scene(config.title_scene_path)


## Plays stream as music, fading in over fade_in seconds (0 for no fade).
func play_music(stream: AudioStream, fade_in: float = 2.5) -> void:
	_music.play_stream(stream, fade_in)


## Plays the config's title music when it is set and exists.
func play_title_music() -> void:
	if config.title_music_path != "" and ResourceLoader.exists(config.title_music_path):
		play_music(load(config.title_music_path))


## Stops the music and releases its stream.
func stop_music() -> void:
	_music.stop_music()


## The music player, for tests and volume checks.
func music_player() -> AudioStreamPlayer:
	return _music


## Shows a subtitle line when the game has voice (C02) and subtitles are on.
func show_subtitle(text: String, seconds: float = 3.0) -> void:
	if config.enable_voice and BaselineSettings.get_value("subtitles.dialogue"):
		_subtitle.show_line(text, seconds)


## The subtitle label, for tests.
func subtitle_label() -> Label:
	return _subtitle


## Saves settings, stops every sound and quits. Used by Quit buttons and the window close button.
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	print("[baseline] quitting")
	if _transition != null:
		_transition.kill()
		_transition = null
	BaselineSettings.flush()
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for player: Node in get_tree().root.find_children("*", type, true, false):
			player.call("stop")
			player.set("stream", null)
	await get_tree().process_frame
	await get_tree().process_frame
	quit_impl.call()


## Back to a clean state. Tests only.
func reset_for_tests() -> void:
	while not _screens.is_empty():
		pop_screen()
	get_tree().paused = false
	if _transition != null:
		_transition.kill()
		_transition = null
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quitting = false
	_pause_after_transition = false
	gameplay_mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_music.stop_music()
	_subtitle.hide_now()
	_reset_impls()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if not _screens.is_empty():
		get_viewport().set_input_as_handled()
		var top := top_screen()
		if top.has_method("back"):
			top.call("back")
	elif is_gameplay_active():
		get_viewport().set_input_as_handled()
		pause("esc")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if is_gameplay_active() or _transition != null:
				pause.call_deferred("focus lost")
			set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit_game()


func _end_transition() -> void:
	_transition = null
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _pause_after_transition:
		_pause_after_transition = false
		pause("focus lost")


func _focus_screen(screen: Control) -> void:
	if not is_instance_valid(screen):
		return
	var target: Control = screen.call("first_focus") if screen.has_method("first_focus") else null
	if target == null:
		target = screen.find_next_valid_focus()
	if target != null:
		target.grab_focus()


func _reset_impls() -> void:
	quit_impl = get_tree().quit
	change_scene_impl = get_tree().change_scene_to_file
