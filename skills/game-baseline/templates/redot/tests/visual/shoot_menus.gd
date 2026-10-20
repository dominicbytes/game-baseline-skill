extends Node
## Screenshots every menu at four window sizes, for a person to review.
## Not a test: the runner only collects res://tests/test_*.gd.
## Needs a real window, so run it with the background-mode engine build and a
## scratch APPDATA (it writes a save and changes settings):
##   timeout 300 "$REDOT_BG_BIN" --mcp-background --audio-driver Dummy --path <template> res://tests/visual/shoot_menus.tscn -- --out=<scratch folder>
## Saves <width>x<height>_<screen>.png into the --out folder. A size the
## monitor cannot hold is skipped and printed as "BLOCKED <size>".

const OUT_ARG := "--out="
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1080)]
const TITLE_SCENE := "res://baseline/ui/title_screen.tscn"
const DEMO_SCENE := "res://demo/demo_game.tscn"
const OPTION_TABS: Array[String] = ["audio", "display", "controls", "gameplay"]
## Frames to wait after opening a screen, so deferred focus and layout settle.
const SETTLE_FRAMES := 4

var _out := ""
var _tag := ""
var _saved: Array[String] = []
var _blocked: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(OUT_ARG):
			_out = arg.trim_prefix(OUT_ARG)
	if _out == "" or DisplayServer.get_name() == "headless":
		push_error("shoot_menus: needs a window and -- %s<folder>" % OUT_ARG)
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	# A save, so the title shows Continue, and one muted bus, so "Muted" shows
	# beside the percentages.
	BaselineSave.save({"x": 420.0, "y": 300.0, "elapsed": 83.0})
	BaselineSettings.set_value("audio.sfx", 0.0)
	BaselineSettings.set_value("audio.music", 0.7)
	for size in SIZES:
		if not await _set_size(size):
			continue
		await _shoot_title_screens()
		await _shoot_demo_screens()
	print("shoot_menus: saved %d screenshots; blocked sizes: %s" % [_saved.size(), ", ".join(_blocked) if not _blocked.is_empty() else "none"])
	BaselineFlow.quit_game()


## Resizes the window and returns false (printing BLOCKED) when the size does not take.
func _set_size(size: Vector2i) -> bool:
	_tag = "%dx%d" % [size.x, size.y]
	get_window().size = size
	await _frames(2)
	var got := get_window().size
	if got != size:
		print("BLOCKED %s (window is %dx%d)" % [_tag, got.x, got.y])
		_blocked.append(_tag)
		return false
	return true


func _shoot_title_screens() -> void:
	var title: Node = (load(TITLE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _shoot("title")

	for tab in OPTION_TABS:
		var menu := BaselineOptionsMenu.create(tab)
		BaselineFlow.push_screen(menu)
		await _shoot("options_" + tab)
		if tab == "controls":
			var panel := menu.current_tab() as BaselineControlsPanel
			var slot := panel.slot_button(panel.action_rows()[0], 0)
			slot.grab_focus()
			slot.pressed.emit()
			await _shoot("controls_capture")
		# Closing the menu also ends the capture; nothing gets bound.
		BaselineFlow.pop_screen(menu)
		await _frames(2)

	var dialog := BaselineConfirm.ask("Start a new game? Your saved progress will be overwritten.", "Start New Game")
	await _shoot("confirm")
	dialog.back()
	await _frames(2)

	var credits := BaselineCreditsScreen.new()
	BaselineFlow.push_screen(credits)
	await _shoot("credits")
	BaselineFlow.pop_screen(credits)
	await _frames(2)

	get_tree().current_scene = self
	title.free()
	await _frames(1)


func _shoot_demo_screens() -> void:
	var demo: Node = (load(DEMO_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(demo)
	get_tree().current_scene = demo
	await _shoot("demo_subtitle")

	BaselineFlow.pause("menu")
	await _shoot("pause")
	BaselineFlow.resume()
	await _frames(2)

	get_tree().current_scene = self
	demo.free()
	BaselineFlow.subtitle_label().hide_now()
	await _frames(1)


## Waits for layout and focus to settle, then saves the next drawn frame.
func _shoot(screen: String) -> void:
	await _frames(SETTLE_FRAMES)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file := "%s_%s.png" % [_tag, screen]
	var err := image.save_png(_out.path_join(file))
	if err != OK:
		push_error("shoot_menus: could not save %s (error %d)" % [file, err])
		return
	_saved.append(file)
	print("saved %s (%dx%d)" % [file, image.get_width(), image.get_height()])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
