extends Node
## Autoload BaselineFlow. Owns pause, focus-loss pause, scene changes, music,
## subtitles and the clean quit. Menu screens, Esc routing and focus restore
## live in its BaselineScreenStack child, and the scene-change fade in its
## BaselineTransition child.

## Emitted after the game pauses (true) or resumes (false).
signal paused_changed(is_paused: bool)

const GAMEPLAY_GROUP := &"baseline_gameplay"
const FADE_TIME := 0.25
## Seconds quit_game waits after stopping sounds. The audio thread releases
## stopped playbacks a few frames later; quitting sooner leaks them.
const QUIT_DRAIN_TIME := 0.25
## Canvas layer for subtitles, below the menu screens (BaselineScreenStack.LAYER).
const SUBTITLE_LAYER := 90

var config: BaselineConfig = preload("res://baseline/baseline_config.tres")
## Mouse mode gameplay wants while it runs, e.g. captured while aiming.
var gameplay_mouse_mode := Input.MOUSE_MODE_VISIBLE

var _screens: BaselineScreenStack
var _transition: BaselineTransition
var _music: BaselineMusic
var _subtitle: BaselineSubtitle
var _quitting := false
var _pause_after_transition := false
var _theme: Theme
var _quit_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_reset_impls()
	var subtitle_layer := CanvasLayer.new()
	subtitle_layer.layer = SUBTITLE_LAYER
	add_child(subtitle_layer)
	_subtitle = BaselineSubtitle.new()
	subtitle_layer.add_child(_subtitle)
	_screens = BaselineScreenStack.new()
	_screens.cancel_without_screen.connect(_on_cancel_without_screen)
	add_child(_screens)
	_transition = BaselineTransition.new()
	add_child(_transition)
	_music = BaselineMusic.new()
	add_child(_music)
	BaselineSave.cleanup()
	_setup_quit_after(OS.get_cmdline_user_args())


## The shared menu Theme, built on first use.
func get_theme() -> Theme:
	if _theme == null:
		_theme = BaselineTheme.build()
	return _theme


## True while the scene tree is paused.
func is_paused() -> bool:
	return get_tree().paused


## True while a gameplay scene is current and no scene transition is running.
func is_gameplay_active() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group(GAMEPLAY_GROUP) and not _transition.is_running()


## Pauses gameplay and opens the pause menu. Does nothing outside gameplay.
func pause(reason: String = "menu") -> void:
	if is_paused() or _quitting:
		return
	if not is_gameplay_active():
		if _transition.is_running() and reason == "focus lost":
			_pause_after_transition = true
		return
	get_tree().paused = true
	set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_music.duck(true)
	push_screen(BaselinePauseMenu.new())
	print("[baseline] paused (%s)" % reason)
	paused_changed.emit(true)


## Closes every menu screen and unpauses gameplay.
func resume() -> void:
	if not is_paused():
		return
	_screens.clear()
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
	_screens.push(screen)


## Closes the top screen. With screen given, only closes it if it is the top.
func pop_screen(screen: Control = null) -> void:
	_screens.pop(screen)


## Closes screen wherever it is in the stack.
func remove_screen(screen: Control) -> void:
	_screens.remove_screen(screen)


## The screen on top of the stack, or null.
func top_screen() -> Control:
	return _screens.top()


## True while any menu screen is open.
func has_screens() -> bool:
	return _screens.has_screens()


## Fades to black, unpauses, changes to the scene at path and fades back in.
func change_scene(path: String) -> void:
	_transition.play(FADE_TIME, _swap_scene.bind(path), _end_transition)


## Deletes the autosave and starts the game scene.
func new_game() -> void:
	BaselineSave.delete()
	change_scene(config.game_scene_path)


## Starts the game scene; the game loads its own save.
func continue_game() -> void:
	change_scene(config.game_scene_path)


## Closes menus and changes to the title scene. Gameplay stays paused during
## the fade out; the tree unpauses only when the scene changes.
func return_to_title() -> void:
	_screens.clear()
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


## Shows a subtitle line when the game has voice (C02) and subtitles are on.
func show_subtitle(text: String, seconds: float = 3.0) -> void:
	if config.enable_voice and BaselineSettings.get_value("subtitles.dialogue"):
		_subtitle.show_line(text, seconds)


## Saves settings, stops every sound and quits. Used by Quit buttons and the window close button.
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	print("[baseline] quitting")
	_transition.stop()
	BaselineSettings.flush()
	# Paused gameplay cannot start new sounds while the old ones drain.
	get_tree().paused = true
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for player: Node in get_tree().root.find_children("*", type, true, false):
			player.call("stop")
			player.set("stream", null)
	await get_tree().create_timer(QUIT_DRAIN_TIME, true, false, true).timeout
	quit_impl.call()


## Esc with no menu open pauses gameplay.
func _on_cancel_without_screen() -> void:
	if is_gameplay_active():
		get_viewport().set_input_as_handled()
		pause("esc")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if is_gameplay_active() or _transition.is_running():
				pause.call_deferred("focus lost")
			set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit_game()


## Runs at full black: unpauses, so the new scene starts running, then swaps.
func _swap_scene(path: String) -> void:
	get_tree().paused = false
	change_scene_impl.call(path)


func _end_transition() -> void:
	if _pause_after_transition:
		_pause_after_transition = false
		pause("focus lost")


## Starts a timer that calls quit_game() when args ask for a bounded run.
## Returns the timer, or null when args have no valid --baseline-quit-after.
func _setup_quit_after(args: PackedStringArray) -> Timer:
	var seconds := BaselineQuitAfter.parse(args)
	if seconds < 0.0:
		return null
	if _quit_timer != null:
		_quit_timer.queue_free()
	_quit_timer = BaselineQuitAfter.new(seconds)
	_quit_timer.timeout.connect(quit_game)
	add_child(_quit_timer)
	print("[baseline] quitting after %s s (%s)" % [seconds, BaselineQuitAfter.ARG.trim_suffix("=")])
	return _quit_timer


# --- Test support ---

## Test support: the last mouse mode requested here, since headless runs
## cannot read it back from Input.
var requested_mouse_mode := Input.MOUSE_MODE_VISIBLE
## Test support: quits the game. Tests replace it so quitting doesn't end the run.
var quit_impl: Callable
## Test support: changes the scene. Tests replace it to record the path.
var change_scene_impl: Callable


## Test support: the music player, for volume checks.
func music_player() -> AudioStreamPlayer:
	return _music


## Test support: the subtitle label.
func subtitle_label() -> Label:
	return _subtitle


## Test support: back to a clean state between tests.
func reset_for_tests() -> void:
	_screens.clear()
	get_tree().paused = false
	_transition.stop(true)
	_quitting = false
	_pause_after_transition = false
	gameplay_mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_music.stop_music()
	_subtitle.hide_now()
	if _quit_timer != null:
		_quit_timer.queue_free()
		_quit_timer = null
	_reset_impls()


func _reset_impls() -> void:
	quit_impl = get_tree().quit
	change_scene_impl = get_tree().change_scene_to_file
