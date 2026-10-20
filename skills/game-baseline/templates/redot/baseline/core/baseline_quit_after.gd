class_name BaselineQuitAfter
extends Timer
## One-shot timer for bounded automated runs. The user argument
## `-- --baseline-quit-after=<seconds>` makes BaselineFlow quit through
## quit_game() after that many seconds, so sounds stop and drain first. Prefer
## it over the engine's --quit-after, which skips quit_game() and leaks any
## audio stream still playing at exit.

const ARG := "--baseline-quit-after="


func _init(seconds: float = 1.0) -> void:
	name = "QuitAfter"
	process_mode = Node.PROCESS_MODE_ALWAYS
	one_shot = true
	wait_time = seconds
	autostart = true


## Seconds from a --baseline-quit-after=<seconds> user argument, or -1 when it
## is absent or not a positive number.
static func parse(args: PackedStringArray) -> float:
	for arg in args:
		if arg.begins_with(ARG):
			var text := arg.trim_prefix(ARG)
			if text.is_valid_float() and text.to_float() > 0.0:
				return text.to_float()
	return -1.0
