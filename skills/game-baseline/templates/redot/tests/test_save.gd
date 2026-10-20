extends BaselineTestCase


func before_each() -> void:
	super()
	BaselineSave.delete()


func after_each() -> void:
	BaselineSave.delete()


func test_no_save_at_start() -> void:
	expect(not BaselineSave.has_save(), "no save yet")
	expect_eq(BaselineSave.load_data(), {}, "empty data")


func test_round_trip() -> void:
	expect_eq(BaselineSave.save({"x": 12.5, "level": "a"}), OK, "save")
	expect(BaselineSave.has_save(), "has save")
	expect_eq(BaselineSave.load_data(), {"x": 12.5, "level": "a"}, "data")


func test_corrupt_save_uses_backup() -> void:
	BaselineSave.save({"n": 1.0})
	BaselineSave.save({"n": 2.0})
	var file := FileAccess.open(BaselineSave.PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	expect_eq(BaselineSave.load_data(), {"n": 1.0}, "backup data")


func test_corrupt_without_backup_is_no_save() -> void:
	var file := FileAccess.open(BaselineSave.PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	expect(not BaselineSave.has_save(), "corrupt counts as no save")


func test_save_over_corrupt_file_keeps_good_backup() -> void:
	BaselineSave.save({"n": 1.0})
	BaselineSave.save({"n": 2.0})
	var file := FileAccess.open(BaselineSave.PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	expect_eq(BaselineSave.save({"n": 3.0}), OK, "save over corrupt file")
	expect_eq(BaselineSave.load_data(), {"n": 3.0}, "new save")
	file = FileAccess.open(BaselineSave.PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	expect_eq(BaselineSave.load_data(), {"n": 1.0}, "backup is still the good save")
