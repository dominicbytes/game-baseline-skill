class_name BaselineSave
extends RefCounted
## One autosave slot. The game decides what goes in it and when to call save().
## Data must be JSON-compatible (numbers load back as floats).

const PATH := "user://save.json"
const FORMAT_VERSION := 1


## Writes data to the slot. Returns OK or the error that stopped the write.
static func save(data: Dictionary) -> Error:
	return BaselineFile.write_text(PATH, JSON.stringify({"version": FORMAT_VERSION, "data": data}), _is_valid)


## Returns the saved data, or {} when there is no usable save.
static func load_data() -> Dictionary:
	var text := BaselineFile.read_text(PATH, _is_valid)
	if text == "":
		return {}
	return JSON.parse_string(text)["data"]


## True when a usable save (or backup) exists.
static func has_save() -> bool:
	return BaselineFile.read_text(PATH, _is_valid) != ""


## Deletes a temp file left behind by a crash during a save. BaselineFlow
## calls this at startup.
static func cleanup() -> void:
	BaselineFile.remove_stale_temp(PATH)


## Deletes the save, its backup and any temp file.
static func delete() -> void:
	BaselineFile.delete_all(PATH)


static func _is_valid(text: String) -> bool:
	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	var parsed: Variant = json.data
	return parsed is Dictionary and parsed.get("data") is Dictionary
