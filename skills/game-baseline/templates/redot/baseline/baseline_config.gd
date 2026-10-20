class_name BaselineConfig
extends Resource
## Per-game settings for the baseline template. Edit baseline_config.tres.

## Shown on the title screen.
@export var game_title: String = "My Game"
## Scene started by New Game and Continue.
@export_file("*.tscn") var game_scene_path: String = ""
## Scene shown by Return to Title.
@export_file("*.tscn") var title_scene_path: String = "res://baseline/ui/title_screen.tscn"
## Music for the title screen; fades in from silence. Optional.
@export_file("*.wav", "*.ogg", "*.mp3") var title_music_path: String = ""
## C01: the game has mouse-look, aiming or a pointer-driven camera.
@export var enable_mouse_look: bool = false
## C02: the game has spoken dialogue or voice.
@export var enable_voice: bool = false
## Order of gameplay actions on the Controls tab. Actions missing from the
## InputMap are skipped; actions not listed follow in project order.
@export var action_order: PackedStringArray = []
## Friendly names for gameplay actions on the Controls tab, e.g. {"move_left": "Move left"}.
@export var action_names: Dictionary = {}
## Credits text shown above the engine licence notice.
@export_multiline var credits_text: String = ""
