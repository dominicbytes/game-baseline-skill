extends Node2D
## Minimal gameplay scene for flow tests: a timer, a looping tween and a looping sound.

var elapsed := 0.0
var bob := 0.0
var loop_player: AudioStreamPlayer


func _ready() -> void:
	add_to_group(BaselineFlow.GAMEPLAY_GROUP)
	var tween := create_tween().set_loops()
	tween.tween_property(self, "bob", 1.0, 0.5)
	tween.tween_property(self, "bob", 0.0, 0.5)
	loop_player = AudioStreamPlayer.new()
	loop_player.bus = &"SFX"
	loop_player.stream = silent_loop()
	add_child(loop_player)
	loop_player.play()


func _process(delta: float) -> void:
	elapsed += delta


## One second of silence that loops forever.
static func silent_loop() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2)
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 22050
	return wav
