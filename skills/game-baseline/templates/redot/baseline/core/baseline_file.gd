class_name BaselineFile
extends RefCounted
## Crash-safe text files. Writes go to a temp file, the previous file is kept
## as .bak, then the temp file is renamed into place.

const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"


## Writes text atomically. Returns OK or the error that stopped the write.
static func write_text(path: String, text: String) -> Error:
	var temp_path := path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(_absolute(temp_path))
		return write_error
	if FileAccess.file_exists(path):
		var copy_error := DirAccess.copy_absolute(_absolute(path), _absolute(path + BACKUP_SUFFIX))
		if copy_error != OK:
			print("[baseline] could not back up %s (%s)" % [path, error_string(copy_error)])
	return DirAccess.rename_absolute(_absolute(temp_path), _absolute(path))


## Returns the main file's text, or the backup's when the main file is missing
## or fails is_valid. Returns "" when neither is usable. A corrupt file is
## expected and recoverable, so it is printed, not reported as a warning.
static func read_text(path: String, is_valid: Callable) -> String:
	for candidate: String in [path, path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		var text := FileAccess.get_file_as_string(candidate)
		if is_valid.call(text):
			return text
		print("[baseline] ignoring unreadable %s" % candidate)
	return ""


## Deletes a temp file left behind by a crash during a write.
static func remove_stale_temp(path: String) -> void:
	if FileAccess.file_exists(path + TEMP_SUFFIX):
		DirAccess.remove_absolute(_absolute(path + TEMP_SUFFIX))


## Deletes the file, its backup and any temp file.
static func delete_all(path: String) -> void:
	for candidate: String in [path, path + BACKUP_SUFFIX, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(_absolute(candidate))


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
