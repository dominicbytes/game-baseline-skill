extends BaselineTestCase

const PATH := "user://test_file.txt"


func before_each() -> void:
	super()
	BaselineFile.delete_all(PATH)


func after_each() -> void:
	BaselineFile.delete_all(PATH)


func _always_valid(_text: String) -> bool:
	return true


func _is_good(text: String) -> bool:
	return text.begins_with("good")


func test_write_then_read() -> void:
	expect_eq(BaselineFile.write_text(PATH, "good 1"), OK, "write")
	expect_eq(BaselineFile.read_text(PATH, _always_valid), "good 1", "read")
	expect(not FileAccess.file_exists(PATH + ".tmp"), "temp file renamed away")


func test_second_write_keeps_backup() -> void:
	BaselineFile.write_text(PATH, "good 1")
	BaselineFile.write_text(PATH, "good 2")
	expect_eq(FileAccess.get_file_as_string(PATH), "good 2", "main")
	expect_eq(FileAccess.get_file_as_string(PATH + ".bak"), "good 1", "backup")


func test_corrupt_main_falls_back_to_backup() -> void:
	BaselineFile.write_text(PATH, "good 1")
	BaselineFile.write_text(PATH, "good 2")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	expect_eq(BaselineFile.read_text(PATH, _is_good), "good 1", "fallback")


func test_corrupt_main_keeps_good_backup_on_write() -> void:
	BaselineFile.write_text(PATH, "good 1", _is_good)
	BaselineFile.write_text(PATH, "good 2", _is_good)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	expect_eq(BaselineFile.write_text(PATH, "good 3", _is_good), OK, "write")
	expect_eq(FileAccess.get_file_as_string(PATH), "good 3", "main")
	expect_eq(FileAccess.get_file_as_string(PATH + ".bak"), "good 1", "good backup kept")
	BaselineFile.write_text(PATH, "good 4", _is_good)
	expect_eq(FileAccess.get_file_as_string(PATH + ".bak"), "good 3", "valid main backed up again")


func test_missing_and_corrupt_return_empty() -> void:
	expect_eq(BaselineFile.read_text(PATH, _is_good), "", "missing")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	expect_eq(BaselineFile.read_text(PATH, _is_good), "", "corrupt with no backup")


func test_stale_temp_is_removed() -> void:
	var file := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	file.store_string("half written")
	file.close()
	BaselineFile.remove_stale_temp(PATH)
	expect(not FileAccess.file_exists(PATH + ".tmp"), "stale temp removed")
