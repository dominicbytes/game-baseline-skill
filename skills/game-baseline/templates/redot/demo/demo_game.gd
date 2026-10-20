extends Node2D
## Baseline demo: walk around, ping with the mouse, hop, aim with mouse-look
## and save at the save point. Exercises the baseline's pause, music, subtitles,
## remappable prompts, autosave and mouse capture.

const PLAY_AREA := Rect2(0.0, 0.0, 1280.0, 720.0)
const SPEED := 320.0
const PLAYER_HALF := 16.0
const START_POSITION := Vector2(640.0, 360.0)
const SAVE_POINT := Vector2(1040.0, 520.0)
const SAVE_RADIUS := 80.0
const AUTOSAVE_SECONDS := 20.0
const SAVED_SHOW_SECONDS := 1.5
const LOOK_LIMIT := 200.0
const PING_SECONDS := 0.6
const HOP_HEIGHT := 24.0
const HOP_SECONDS := 0.12
const GRID_STEP := 64.0

## Seconds played, restored from the save.
var elapsed := 0.0
## Number of world clicks (primary presses) so far.
var ping_count := 0
## Mouse-look offset of the crosshair from the player while aiming.
var look_offset := Vector2.ZERO
## Looping ambient hum on the SFX bus.
var hum: AudioStreamPlayer
## 0..1, driven by a looping tween; bobs the save point star.
var bob := 0.0

var _player := START_POSITION
var _hop := 0.0
var _hop_tween: Tween
var _aiming := false
var _since_save := 0.0
var _pings: Array[Dictionary] = []
var _time_label: Label
var _prompt_label: Label
var _saved_label: Label
var _save_button: Button
var _saved_tween: Tween


func _ready() -> void:
	add_to_group(BaselineFlow.GAMEPLAY_GROUP)
	var data := BaselineSave.load_data()
	set_player_position(Vector2(_number(data.get("x"), START_POSITION.x), _number(data.get("y"), START_POSITION.y)))
	elapsed = maxf(_number(data.get("elapsed"), 0.0), 0.0)

	BaselineFlow.play_music(load("res://demo/assets/music_loop.wav"))
	hum = AudioStreamPlayer.new()
	hum.bus = &"SFX"
	hum.stream = load("res://demo/assets/hum_loop.wav")
	add_child(hum)
	hum.play()

	var bob_tween := create_tween().set_loops()
	bob_tween.tween_property(self, "bob", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(self, "bob", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

	if BaselineFlow.config.enable_voice:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"Voice"
		voice.stream = load("res://demo/assets/voice_line.wav")
		add_child(voice)
		voice.play()
		BaselineFlow.show_subtitle("Welcome to the baseline demo. Walk to the save point and press %s to save." % BaselineInputLabels.action_label("interact"))

	_build_hud()
	BaselineSettings.changed.connect(_on_setting_changed)
	BaselineFlow.paused_changed.connect(_on_paused_changed)


func _physics_process(delta: float) -> void:
	step(delta)


func _process(delta: float) -> void:
	for i in range(_pings.size() - 1, -1, -1):
		_pings[i]["age"] += delta
		if _pings[i]["age"] >= PING_SECONDS:
			_pings.remove_at(i)
	queue_redraw()


## Advances the game by delta seconds: movement, play time and autosave.
func step(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	set_player_position(_player + direction * SPEED * delta)
	elapsed += delta
	_since_save += delta
	if _since_save >= AUTOSAVE_SECONDS:
		save_game()
	_update_time_label()


## The player's position in the play area.
func player_position() -> Vector2:
	return _player


## Moves the player to p, kept inside the play area.
func set_player_position(p: Vector2) -> void:
	var low := PLAY_AREA.position + Vector2.ONE * PLAYER_HALF
	var high := PLAY_AREA.end - Vector2.ONE * PLAYER_HALF
	_player = p.clamp(low, high)


## The HUD "Save now" button.
func save_button() -> Button:
	return _save_button


## The control prompts shown on the HUD, one "Name: labels" line per action.
func prompt_text() -> String:
	return _prompt_label.text


## Writes the autosave and shows "Saved".
func save_game() -> void:
	_since_save = 0.0
	if BaselineSave.save({"x": _player.x, "y": _player.y, "elapsed": elapsed}) != OK:
		return
	_saved_label.show()
	if _saved_tween != null:
		_saved_tween.kill()
	_saved_tween = create_tween()
	_saved_tween.tween_interval(SAVED_SHOW_SECONDS)
	_saved_tween.tween_callback(_saved_label.hide)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _aiming:
			var sensitivity: float = BaselineSettings.get_value("input.look_sensitivity")
			var invert := Vector2(
					-1.0 if BaselineSettings.get_value("game.input.invert_x") else 1.0,
					-1.0 if BaselineSettings.get_value("input.invert_y") else 1.0)
			look_offset = (look_offset + event.relative * sensitivity * invert).limit_length(LOOK_LIMIT)
			get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if event.is_action_pressed("primary"):
		_ping(event)
	elif event.is_action_pressed("interact"):
		if _player.distance_to(SAVE_POINT) <= SAVE_RADIUS:
			save_game()
	elif event.is_action_pressed("jump"):
		_jump()
	elif event.is_action_pressed("aim"):
		_set_aiming(true)
	elif event.is_action_released("aim"):
		_set_aiming(false)
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(PLAY_AREA, Color(0.09, 0.11, 0.15))
	var line := Color(1.0, 1.0, 1.0, 0.06)
	for x in range(0, int(PLAY_AREA.size.x) + 1, int(GRID_STEP)):
		draw_line(Vector2(x, 0.0), Vector2(x, PLAY_AREA.size.y), line)
	for y in range(0, int(PLAY_AREA.size.y) + 1, int(GRID_STEP)):
		draw_line(Vector2(0.0, y), Vector2(PLAY_AREA.size.x, y), line)

	draw_circle(SAVE_POINT, SAVE_RADIUS, Color(0.3, 0.8, 0.5, 0.12))
	draw_arc(SAVE_POINT, SAVE_RADIUS, 0.0, TAU, 48, Color(0.3, 0.8, 0.5, 0.6), 2.0)
	_draw_star(SAVE_POINT + Vector2(0.0, -12.0 - bob * 10.0), 14.0, Color(1.0, 0.85, 0.3))

	for ping in _pings:
		var t: float = ping["age"] / PING_SECONDS
		draw_arc(ping["position"], 8.0 + t * 40.0, 0.0, TAU, 32, Color(0.5, 0.8, 1.0, 1.0 - t), 3.0)

	var body := Rect2(_player + Vector2(-PLAYER_HALF, -PLAYER_HALF + _hop), Vector2.ONE * PLAYER_HALF * 2.0)
	draw_rect(body, Color(0.35, 0.65, 1.0))
	draw_rect(body, Color.WHITE, false, 2.0)

	if _aiming:
		var aim := _player + look_offset
		var color := Color(1.0, 0.4, 0.4)
		draw_arc(aim, 12.0, 0.0, TAU, 24, color, 2.0)
		draw_line(aim + Vector2(-18.0, 0.0), aim + Vector2(18.0, 0.0), color, 2.0)
		draw_line(aim + Vector2(0.0, -18.0), aim + Vector2(0.0, 18.0), color, 2.0)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)


func _ping(event: InputEvent) -> void:
	ping_count += 1
	var at := get_global_mouse_position()
	if event is InputEventMouseButton:
		at = (make_input_local(event) as InputEventMouseButton).position
	_pings.append({"position": at, "age": 0.0})


func _jump() -> void:
	if _hop_tween != null and _hop_tween.is_running():
		return
	_hop_tween = create_tween()
	_hop_tween.tween_property(self, "_hop", -HOP_HEIGHT, HOP_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hop_tween.tween_property(self, "_hop", 0.0, HOP_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Aim is a hold action: the mouse is captured only while it is held (C01).
func _set_aiming(on: bool) -> void:
	if not BaselineFlow.config.enable_mouse_look or on == _aiming:
		return
	_aiming = on
	if on:
		look_offset = Vector2.ZERO
	BaselineFlow.set_gameplay_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.theme = BaselineFlow.get_theme()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)

	_time_label = _make_label()
	_time_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	hud.add_child(_time_label)

	_prompt_label = _make_label()
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(_prompt_label)

	var corner := VBoxContainer.new()
	corner.alignment = BoxContainer.ALIGNMENT_BEGIN
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(corner)
	_save_button = BaselineScreen.make_button("Save now", _on_save_pressed)
	corner.add_child(_save_button)
	_saved_label = _make_label()
	_saved_label.text = "Saved"
	_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saved_label.hide()
	corner.add_child(_saved_label)

	_update_time_label()
	_refresh_prompts()


func _make_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


func _update_time_label() -> void:
	var total := int(elapsed)
	_time_label.text = "Time %02d:%02d" % [floori(total / 60.0), total % 60]


func _refresh_prompts() -> void:
	var move: Array[String] = []
	for action: String in ["move_up", "move_left", "move_down", "move_right"]:
		move.append(BaselineInputLabels.action_label(action))
	var lines: Array[String] = [
		"Move: " + " / ".join(move),
		"Jump: " + BaselineInputLabels.action_label("jump"),
		"Save: " + BaselineInputLabels.action_label("interact"),
		"Ping: " + BaselineInputLabels.action_label("primary"),
	]
	if BaselineFlow.config.enable_mouse_look:
		lines.append("Aim: " + BaselineInputLabels.action_label("aim"))
	lines.append("Pause: Esc")
	_prompt_label.text = "\n".join(lines)


func _on_save_pressed() -> void:
	save_game()
	# A focused HUD button would take Space and Enter away from gameplay.
	_save_button.release_focus()


func _on_setting_changed(key: String) -> void:
	if key == "game.input.bindings":
		_refresh_prompts()


## An aim button released while paused never reaches _unhandled_input.
func _on_paused_changed(is_paused: bool) -> void:
	if not is_paused and _aiming and not Input.is_action_pressed("aim"):
		_set_aiming(false)


## A saved number, or fallback when value is missing or not a number.
static func _number(value: Variant, fallback: float) -> float:
	return float(value) if (value is float or value is int) else fallback
