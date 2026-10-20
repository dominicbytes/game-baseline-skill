class_name BaselineProjectChecks
extends RefCounted
## Static Audit checks on a Redot project's settings and files. Each result is
## {"id": "B01", "ok": bool, "manual": bool, "message": String}. A result with
## "manual" true could not be settled statically (the project does not use the
## template's autoloads, or its config still starts the demo): it is neither a
## pass nor a failure, and what it names must be checked by hand. Settings
## missing from project.godot count as the engine's defaults.
## Command line: res://baseline/tools/check_project.gd

## Autoloads the Redot template registers.
const TEMPLATE_AUTOLOADS: Array[String] = ["BaselineSettings", "BaselineFlow"]
## Buses every game needs for the volume sliders.
const REQUIRED_BUSES: Array[String] = ["Master", "Music", "SFX"]
## Effect classes that count as a limiter on the Master bus.
const LIMITERS: Array[String] = ["AudioEffectHardLimiter", "AudioEffectLimiter"]
const STRETCH_MODES: Array[String] = ["canvas_items", "viewport"]
const STRETCH_ASPECTS: Array[String] = ["expand", "keep"]
## display/window/size/initial_position_type for a centred window.
const CENTERED_POSITION := 1
const VSYNC_ENABLED := 1
const MAX_FPS := 60
const WINDOWS_PLATFORM := "Windows Desktop"
## The template's per-game config. Copied projects must edit it.
const CONFIG_PATH := "res://baseline/baseline_config.tres"
## A game_scene_path under this folder still starts the template's demo.
const DEMO_FOLDER := "res://demo/"
## Items the template's autoloads provide.
const AUTOLOAD_ITEMS := "B05/B11/B13/B15"
## Appended to every B10 failure: what the static check can and cannot see.
const B10_NOTE := " (every action not starting with ui_ counts as gameplay; actions created only in code are not seen by this static check)"


## Runs every check on the project in project_dir.
static func run(project_dir: String = "res://") -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var project := ConfigFile.new()
	if project.load(project_dir.path_join("project.godot")) != OK:
		results.append(_result("General", false, "", "project.godot does not load"))
		return results
	results.append_array(_check_frame_pacing(project))
	results.append_array(_check_audio(project, project_dir))
	results.append_array(_check_window(project))
	results.append_array(_check_export(project_dir))
	results.append_array(_check_actions(gameplay_actions(project)))
	results.append_array(_check_autoloads(project))
	results.append_array(_check_release(project))
	results.append_array(_check_main_scene(project, project_dir))
	results.append_array(_check_config(project, project_dir))
	return results


## Value of the setting name ("section/key") in project, or the engine default.
static func setting(project: ConfigFile, name: String) -> Variant:
	var slash := name.find("/")
	return project.get_value(name.left(slash), name.substr(slash + 1), ProjectSettings.property_get_revert(name))


## Gameplay actions in project, name -> Array of InputEvents. Actions starting
## with "ui_" are menu navigation and are left out.
static func gameplay_actions(project: ConfigFile) -> Dictionary:
	var actions := {}
	if not project.has_section("input"):
		return actions
	for action in project.get_section_keys("input"):
		if action.begins_with("ui_"):
			continue
		var value: Variant = project.get_value("input", action)
		var events: Variant = value.get("events", []) if value is Dictionary else []
		actions[action] = events if events is Array else []
	return actions


## True when events has a key event on Esc (physical or not).
static func binds_esc(events: Array) -> bool:
	for event: Variant in events:
		if event is InputEventKey and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			return true
	return false


## True when events has at least one key or mouse button event.
static func has_key_or_mouse(events: Array) -> bool:
	for event: Variant in events:
		if event is InputEventKey or event is InputEventMouseButton:
			return true
	return false


## True when every key event in events uses a physical keycode.
static func uses_physical_keys(events: Array) -> bool:
	for event: Variant in events:
		if event is InputEventKey and event.physical_keycode == KEY_NONE:
			return false
	return true


## B01: VSync and a frame cap.
static func _check_frame_pacing(project: ConfigFile) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var vsync: Variant = setting(project, "display/window/vsync/vsync_mode")
	results.append(_result("B01", _is_int(vsync, VSYNC_ENABLED), "VSync is on by default",
			"VSync is not on by default (set display/window/vsync/vsync_mode=1)"))
	var max_fps: Variant = setting(project, "application/run/max_fps")
	results.append(_result("B01", _is_int(max_fps, MAX_FPS), "Frame rate is capped at %d" % MAX_FPS,
			"Frame rate is not capped at %d (set application/run/max_fps=%d)" % [MAX_FPS, MAX_FPS]))
	return results


## B03: the window scales its content and opens centred.
static func _check_window(project: ConfigFile) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var mode := str(setting(project, "display/window/stretch/mode"))
	var aspect := str(setting(project, "display/window/stretch/aspect"))
	results.append(_result("B03", mode in STRETCH_MODES and aspect in STRETCH_ASPECTS,
			"Window content scales (stretch %s, aspect %s)" % [mode, aspect],
			"Window content does not scale (stretch %s, aspect %s; use canvas_items or viewport with expand or keep)" % [mode, aspect]))
	var position: Variant = setting(project, "display/window/size/initial_position_type")
	results.append(_result("B03", _is_int(position, CENTERED_POSITION), "Window opens centred on the screen",
			"Window does not open centred (set display/window/size/initial_position_type=1)"))
	return results


## B02: bus layout with the volume buses and a limiter on Master.
static func _check_audio(project: ConfigFile, project_dir: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var layout := _bus_layout(project, project_dir)
	if layout == null:
		var path := str(setting(project, "audio/buses/default_bus_layout"))
		results.append(_result("B02", false, "", "Bus layout %s does not load (set audio/buses/default_bus_layout)" % path))
		return results
	var buses := _bus_names(layout)
	var missing: Array[String] = []
	for bus in REQUIRED_BUSES:
		if not bus in buses:
			missing.append(bus)
	results.append(_result("B02", missing.is_empty(), "Bus layout has Master, Music and SFX buses",
			"Bus layout is missing buses: %s" % ", ".join(missing)))
	var master := buses.find("Master")
	results.append(_result("B02", master >= 0 and _has_limiter(layout, master), "Master bus has a limiter",
			"Master bus has no enabled limiter (add AudioEffectHardLimiter)"))
	return results


## B07: a Windows preset that embeds the PCK and exports no console wrapper.
static func _check_export(project_dir: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var presets := ConfigFile.new()
	if presets.load(project_dir.path_join("export_presets.cfg")) != OK:
		results.append(_result("B07", false, "", "No export_presets.cfg (add a Windows Desktop preset)"))
		return results
	for section in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		if presets.get_value(section, "platform", "") != WINDOWS_PLATFORM:
			continue
		var options := section + ".options"
		var name := str(presets.get_value(section, "name", section))
		var embed: Variant = presets.get_value(options, "binary_format/embed_pck", false)
		results.append(_result("B07", embed is bool and embed, "Windows preset \"%s\" embeds the PCK" % name,
				"Windows preset \"%s\" does not embed the PCK (set binary_format/embed_pck=true)" % name))
		var wrapper: Variant = presets.get_value(options, "debug/export_console_wrapper", 1)
		results.append(_result("B07", _is_int(wrapper, 0), "Windows preset \"%s\" exports no console wrapper" % name,
				"Windows preset \"%s\" exports a console wrapper (set debug/export_console_wrapper=0)" % name))
	if results.is_empty():
		results.append(_result("B07", false, "", "No Windows Desktop export preset in export_presets.cfg"))
	return results


## B10: gameplay bindings, actions maps name -> Array of InputEvents.
static func _check_actions(actions: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if actions.is_empty():
		results.append(_result("B10", false, "", "No gameplay input actions in the InputMap" + B10_NOTE))
		return results
	var unbound: Array[String] = []
	var logical: Array[String] = []
	var on_esc: Array[String] = []
	for action: String in actions:
		var events: Array = actions[action]
		if not has_key_or_mouse(events):
			unbound.append(action)
		if not uses_physical_keys(events):
			logical.append(action)
		if binds_esc(events):
			on_esc.append(action)
	results.append(_result("B10", unbound.is_empty(), "Every gameplay action has a key or mouse binding",
			"Gameplay actions without a key or mouse binding: %s%s" % [", ".join(unbound), B10_NOTE]))
	results.append(_result("B10", logical.is_empty(), "Key bindings use physical keys",
			"Key bindings without physical_keycode: %s%s" % [", ".join(logical), B10_NOTE]))
	results.append(_result("B10", on_esc.is_empty(), "No gameplay action is bound to Esc",
			"Gameplay actions bound to Esc, which opens the pause menu: %s%s" % [", ".join(on_esc), B10_NOTE]))
	return results


## B05, B11, B13 and B15: the template's autoloads, which provide those items.
## A project without either autoload gets a manual result instead of a failure.
static func _check_autoloads(project: ConfigFile) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var missing: Array[String] = []
	for autoload in TEMPLATE_AUTOLOADS:
		if not str(project.get_value("autoload", autoload, "")).begins_with("*"):
			missing.append(autoload)
	if missing.size() == TEMPLATE_AUTOLOADS.size():
		results.append(_manual(AUTOLOAD_ITEMS,
				"Not using the Redot template: verify these by hand (see verification.md)"))
	else:
		results.append(_result(AUTOLOAD_ITEMS, missing.is_empty(), "BaselineSettings and BaselineFlow autoloads are registered",
				"Autoloads not registered as singletons: %s" % ", ".join(missing)))
	return results


## B17: a version number and log files for bug reports.
static func _check_release(project: ConfigFile) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var version := str(setting(project, "application/config/version"))
	results.append(_result("B17", version.strip_edges() != "", "Version is set (%s)" % version,
			"No version number (set application/config/version)"))
	var logging: Variant = setting(project, "debug/file_logging/enable_file_logging.pc")
	results.append(_result("B17", logging is bool and logging, "File logging is on for desktop builds",
			"File logging is off (set debug/file_logging/enable_file_logging.pc=true)"))
	return results


static func _check_main_scene(project: ConfigFile, project_dir: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var scene := str(setting(project, "application/run/main_scene"))
	results.append(_result("General", main_scene_exists(scene, project_dir), "Main scene is set (%s)" % scene,
			"Main scene is not set or missing (set application/run/main_scene)"))
	return results


## General and C02: the template's config, when the project has it. The game
## scene must load, and a game scene still in the demo folder is a manual
## result. With enable_voice on, the bus layout needs a Voice bus.
static func _check_config(project: ConfigFile, project_dir: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var file := _project_path(project_dir, CONFIG_PATH)
	if not ResourceLoader.exists(file):
		return results
	# Ignore the cache: a copy loaded earlier may differ from the file on disk.
	var config: Resource = ResourceLoader.load(file, "", ResourceLoader.CACHE_MODE_IGNORE)
	if config == null:
		results.append(_result("General", false, "", "%s does not load" % CONFIG_PATH))
		return results
	var scene_value: Variant = config.get("game_scene_path")
	var scene: String = scene_value if scene_value is String else ""
	if not main_scene_exists(scene, project_dir):
		results.append(_result("General", false, "",
				"Game scene does not load (%s; set game_scene_path in %s)" % [scene, CONFIG_PATH]))
	elif scene.begins_with(DEMO_FOLDER):
		results.append(_manual("General",
				"Game scene is the template's demo (%s): set game_scene_path in %s to your game" % [scene, CONFIG_PATH]))
	else:
		results.append(_result("General", true, "Game scene loads (%s)" % scene, ""))
	var voice: Variant = config.get("enable_voice")
	if voice is bool and voice:
		var layout := _bus_layout(project, project_dir)
		var has_voice := layout != null and "Voice" in _bus_names(layout)
		results.append(_result("C02", has_voice, "Bus layout has a Voice bus (enable_voice is on)",
				"enable_voice is on but the bus layout has no Voice bus (add one sending to Master, or turn enable_voice off in %s)" % CONFIG_PATH))
	return results


## True when scene names a file in the project at project_dir. A uid:// path is
## resolved through the running project's UID cache, so it only counts there.
static func main_scene_exists(scene: String, project_dir: String = "res://") -> bool:
	if scene == "":
		return false
	if scene.begins_with("uid://"):
		if project_dir != "res://":
			return false
		var id := ResourceUID.text_to_id(scene)
		return id != ResourceUID.INVALID_ID and ResourceUID.has_id(id)
	return ResourceLoader.exists(_project_path(project_dir, scene))


## The project's bus layout, or null when it is not set or does not load.
static func _bus_layout(project: ConfigFile, project_dir: String) -> AudioBusLayout:
	var path := str(setting(project, "audio/buses/default_bus_layout"))
	var file := _project_path(project_dir, path)
	if path == "" or not ResourceLoader.exists(file):
		return null
	return ResourceLoader.load(file, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioBusLayout


## Bus names of layout in bus order. Bus 0 is always Master.
static func _bus_names(layout: AudioBusLayout) -> Array[String]:
	var names: Array[String] = []
	var index := 0
	while true:
		var bus_name: Variant = layout.get("bus/%d/name" % index)
		if bus_name == null:
			break
		names.append(str(bus_name))
		index += 1
	return names


static func _has_limiter(layout: AudioBusLayout, bus: int) -> bool:
	var index := 0
	while true:
		var effect: Variant = layout.get("bus/%d/effect/%d/effect" % [bus, index])
		if effect == null:
			return false
		var enabled: Variant = layout.get("bus/%d/effect/%d/enabled" % [bus, index])
		if effect is AudioEffect and effect.get_class() in LIMITERS and enabled is bool and enabled:
			return true
		index += 1
	return false


## path inside the project at project_dir.
static func _project_path(project_dir: String, path: String) -> String:
	if project_dir == "res://" or not path.begins_with("res://"):
		return path
	return project_dir.path_join(path.trim_prefix("res://"))


static func _is_int(value: Variant, expected: int) -> bool:
	return value is int and value == expected


static func _result(id: String, ok: bool, pass_message: String, fail_message: String) -> Dictionary:
	return {"id": id, "ok": ok, "manual": false, "message": pass_message if ok else fail_message}


## A check that cannot run statically: not a pass, not a failure.
static func _manual(id: String, message: String) -> Dictionary:
	return {"id": id, "ok": false, "manual": true, "message": message}
