class_name BaselineMusic
extends AudioStreamPlayer
## Music player owned by BaselineFlow. Fades in from silence, keeps playing
## while the game is paused and ducks to DUCK_DB under the pause menu.

const SILENT_DB := -80.0
const DUCK_DB := -10.0
const DUCK_TIME := 0.2

var _ducked := false
var _tween: Tween


func _init() -> void:
	bus = &"Music"
	process_mode = Node.PROCESS_MODE_ALWAYS


## Plays new_stream unless it is already playing. fade_in 0 starts at full level.
func play_stream(new_stream: AudioStream, fade_in: float) -> void:
	if new_stream == null or (stream == new_stream and playing):
		return
	stream = new_stream
	volume_db = SILENT_DB if fade_in > 0.0 else _target_db()
	play()
	if fade_in > 0.0:
		_fade_to(_target_db(), fade_in)


## Lowers the music to DUCK_DB (on) or brings it back to full level (off).
func duck(on: bool) -> void:
	_ducked = on
	if playing:
		_fade_to(_target_db(), DUCK_TIME)


## Stops and releases the stream and resets the level.
func stop_music() -> void:
	if _tween != null:
		_tween.kill()
	stop()
	stream = null
	_ducked = false
	volume_db = 0.0


func _target_db() -> float:
	return DUCK_DB if _ducked else 0.0


func _fade_to(db: float, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", db, seconds)
