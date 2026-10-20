extends Node
## Autoload BaselineSettings. Owns user://settings.json. Every key has a default,
## a validator and an optional apply function; setting a key applies only that key.
## Key names match the game-accessibility skill's registry where they overlap.

## Emitted after set_value stores a new value for key.
signal changed(key: String)

const PATH := "user://settings.json"
const SAVE_DELAY := 0.5
const FPS_MATCH_DISPLAY := -1
const FPS_CHOICES: Array[int] = [30, 60, 120, 144, FPS_MATCH_DISPLAY, 0]
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "exclusive"]
const WINDOW_SIZE_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]
## Stored window size meaning "pick a size that fits this screen".
const AUTO_WINDOW_SIZE := Vector2i.ZERO
const MIN_WINDOW_SIZE := Vector2i(640, 360)

## Feature switches that decide which optional keys are registered.
var config: BaselineConfig = preload("res://baseline/baseline_config.tres")
## Test support: number of times each key was applied.
var apply_counts: Dictionary = {}

var _keys: Dictionary = {}
var _values: Dictionary = {}
var _stored: Dictionary = {}
var _builtin: Array[String] = []
var _default_bindings: Dictionary = {}
var _save_timer: Timer
var _dirty := false
var _ready_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)
	_default_bindings = BaselineBindings.snapshot()
	_read_file()
	_register_builtin_keys()
	apply_all()
	_ready_done = true


## Adds a setting. validate(value) returns the cleaned value or null when invalid.
## apply(value) pushes the value into the engine; it is optional.
func register_key(key: String, default_value: Variant, validate: Callable, apply: Callable = Callable()) -> void:
	if _keys.has(key):
		push_error("BaselineSettings: key registered twice: " + key)
		return
	_keys[key] = {"default": default_value, "validate": validate, "apply": apply}
	_values[key] = _stored_or_default(key)
	if _ready_done:
		_apply(key)


## True when key has been registered.
func has_key(key: String) -> bool:
	return _keys.has(key)


## Current value of key (a copy for Dictionary and Array values), or null for an unknown key.
func get_value(key: String) -> Variant:
	if not _keys.has(key):
		push_error("BaselineSettings: unknown key " + key)
		return null
	return _copy(_values[key])


## Default value of key (a copy for Dictionary and Array values), or null for an unknown key.
func get_default(key: String) -> Variant:
	if not _keys.has(key):
		push_error("BaselineSettings: unknown key " + key)
		return null
	return _copy(_keys[key]["default"])


## Validates, stores and applies one key. Returns false when the value is invalid.
func set_value(key: String, value: Variant) -> bool:
	if not _keys.has(key):
		push_error("BaselineSettings: unknown key " + key)
		return false
	var checked: Variant = _keys[key]["validate"].call(value)
	if checked == null:
		return false
	if typeof(checked) == typeof(_values[key]) and checked == _values[key]:
		return true
	_values[key] = checked
	_apply(key)
	changed.emit(key)
	_dirty = true
	_save_timer.start()
	return true


## Resets every key whose name starts with prefix, e.g. "audio." or "display.".
func reset_category(prefix: String) -> void:
	for key: String in _keys:
		if key.begins_with(prefix):
			set_value(key, _copy(_keys[key]["default"]))


## Writes pending changes now. Called on quit. Stored keys that are not
## registered (yet) are written back unchanged.
func flush() -> void:
	_save_timer.stop()
	if not _dirty:
		return
	var data: Dictionary = _stored.duplicate(true)
	for key: String in _values:
		var value: Variant = _values[key]
		data[key] = [value.x, value.y] if value is Vector2i else _copy(value)
	_stored = data.duplicate(true)
	var error := BaselineFile.write_text(PATH, JSON.stringify(data, "\t"))
	if error != OK:
		push_warning("BaselineSettings: could not save settings (%s)" % error_string(error))
		return
	_dirty = false


## Re-reads the file and re-validates every key without applying.
func load_from_disk() -> void:
	_read_file()
	for key: String in _keys:
		_values[key] = _stored_or_default(key)


## Pushes every key's current value into the engine.
func apply_all() -> void:
	for key: String in _keys:
		_apply(key)


## Test support: back to a clean state with no settings file and only the
## built-in keys registered.
func reset_for_tests() -> void:
	_save_timer.stop()
	_dirty = false
	BaselineFile.delete_all(PATH)
	_stored = {}
	for key: String in _keys.keys():
		if not key in _builtin:
			_keys.erase(key)
			_values.erase(key)
	for key: String in _keys:
		_values[key] = _copy(_keys[key]["default"])
	apply_all()
	apply_counts.clear()


## Largest preset that fits in 85% of screen, or a 16:9 size that fits when
## no preset does (never below MIN_WINDOW_SIZE).
static func default_window_size(screen: Vector2i) -> Vector2i:
	var limit := Vector2(screen) * 0.85
	var best := AUTO_WINDOW_SIZE
	for preset in WINDOW_SIZE_PRESETS:
		if preset.x <= limit.x and preset.y <= limit.y:
			best = preset
	if best != AUTO_WINDOW_SIZE:
		return best
	var height := limit.y
	var width := height * 16.0 / 9.0
	if width > limit.x:
		width = limit.x
		height = width * 9.0 / 16.0
	return Vector2i(int(width), int(height)).max(MIN_WINDOW_SIZE)


## Presets that fit inside screen. An unknown (zero) screen gets every preset.
static func window_sizes_for_screen(screen: Vector2i) -> Array[Vector2i]:
	var sizes: Array[Vector2i] = []
	for preset in WINDOW_SIZE_PRESETS:
		if screen == Vector2i.ZERO or (preset.x <= screen.x and preset.y <= screen.y):
			sizes.append(preset)
	return sizes


## Engine.max_fps for a stored choice. Match display uses refresh_rate, or 60
## when the refresh rate is unknown. 0 means unlimited.
static func resolve_max_fps(choice: int, refresh_rate: float) -> int:
	if choice == FPS_MATCH_DISPLAY:
		return roundi(refresh_rate) if refresh_rate > 0.0 else 60
	return choice


func _register_builtin_keys() -> void:
	register_key("audio.master", 0.7, _validate_unit, _apply_bus.bind("Master"))
	register_key("audio.music", 0.6, _validate_unit, _apply_bus.bind("Music"))
	register_key("audio.sfx", 0.8, _validate_unit, _apply_bus.bind("SFX"))
	if config.enable_voice:
		register_key("audio.voice", 1.0, _validate_unit, _apply_bus.bind("Voice"))
		register_key("subtitles.dialogue", true, _validate_bool)
	register_key("display.window_mode", "windowed", _validate_window_mode, _apply_window_mode)
	register_key("display.window_size", AUTO_WINDOW_SIZE, _validate_window_size, _apply_window_size)
	register_key("display.vsync", true, _validate_bool, _apply_vsync)
	# The owner requires a 60 FPS cap by default; Match display is offered for high-refresh screens.
	register_key("display.max_fps", 60, _validate_fps, _apply_max_fps)
	register_key("game.input.bindings", _default_bindings.duplicate(true), _validate_bindings, BaselineBindings.apply)
	if config.enable_mouse_look:
		register_key("input.look_sensitivity", 1.0, _validate_sensitivity)
		register_key("game.input.invert_x", false, _validate_bool)
		register_key("input.invert_y", false, _validate_bool)
	_builtin.assign(_keys.keys())


func _read_file() -> void:
	BaselineFile.remove_stale_temp(PATH)
	_stored = {}
	var text := BaselineFile.read_text(PATH, _is_json_object)
	if text != "":
		_stored = JSON.parse_string(text)


func _stored_or_default(key: String) -> Variant:
	if _stored.has(key):
		var checked: Variant = _keys[key]["validate"].call(_copy(_stored[key]))
		if checked != null:
			return checked
	return _copy(_keys[key]["default"])


## Deep copy for Dictionary and Array values; anything else is returned as is.
static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _apply(key: String) -> void:
	apply_counts[key] = apply_counts.get(key, 0) + 1
	var apply: Callable = _keys[key]["apply"]
	if apply.is_valid():
		apply.call(_values[key])


## JSON.parse on an instance reports failure without printing engine errors.
static func _is_json_object(text: String) -> bool:
	var json := JSON.new()
	return json.parse(text) == OK and json.data is Dictionary


static func _validate_unit(value: Variant) -> Variant:
	return clampf(float(value), 0.0, 1.0) if (value is float or value is int) else null


static func _validate_bool(value: Variant) -> Variant:
	return value if value is bool else null


static func _validate_sensitivity(value: Variant) -> Variant:
	return clampf(float(value), 0.25, 3.0) if (value is float or value is int) else null


static func _validate_window_mode(value: Variant) -> Variant:
	return value if value is String and value in WINDOW_MODES else null


static func _validate_window_size(value: Variant) -> Variant:
	if value is Array and value.size() == 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int):
		value = Vector2i(int(value[0]), int(value[1]))
	if not value is Vector2i:
		return null
	if value == AUTO_WINDOW_SIZE or (value.x >= MIN_WINDOW_SIZE.x and value.y >= MIN_WINDOW_SIZE.y):
		return value
	return null


static func _validate_fps(value: Variant) -> Variant:
	return int(value) if (value is int or value is float) and int(value) in FPS_CHOICES else null


func _validate_bindings(value: Variant) -> Variant:
	return BaselineBindings.sanitize(value, _default_bindings)


static func _apply_bus(volume: float, bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.0)


static func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"


func _apply_window_mode(mode: String) -> void:
	if not _has_window():
		return
	var current := DisplayServer.window_get_mode()
	match mode:
		"fullscreen":
			if current != DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"exclusive":
			if current != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			# A maximized or minimized window already counts as windowed.
			if current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				_resize_window(_values.get("display.window_size", AUTO_WINDOW_SIZE))


func _apply_window_size(size: Vector2i) -> void:
	if not _has_window():
		return
	var current := DisplayServer.window_get_mode()
	if current == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif current != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	_resize_window(size)


func _resize_window(size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var target := size if size != AUTO_WINDOW_SIZE else default_window_size(usable.size)
	# A saved size may come from a bigger monitor.
	target = target.min(usable.size)
	if DisplayServer.window_get_size() == target:
		return
	DisplayServer.window_set_size(target)
	DisplayServer.window_set_position(usable.position + (usable.size - target) / 2)


func _apply_vsync(enabled: bool) -> void:
	if not _has_window():
		return
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != mode:
		DisplayServer.window_set_vsync_mode(mode)


static func _apply_max_fps(choice: int) -> void:
	Engine.max_fps = resolve_max_fps(choice, DisplayServer.screen_get_refresh_rate())
