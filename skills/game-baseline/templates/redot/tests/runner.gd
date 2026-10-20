extends Node
## Headless test runner.
## Usage: <redot> --headless --audio-driver Dummy --path <template> res://tests/runner.tscn -- [--only=test_settings]

const TEST_TIMEOUT := 30.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var files: Array[String] = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			if only == "" or file.trim_suffix(".gd") == only:
				files.append(file)
	files.sort()
	var passed := 0
	var failed := 0
	for file in files:
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL %s: script does not load" % file)
			continue
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test_case: BaselineTestCase = script.new()
			test_case.name = method_name
			add_child(test_case)
			await test_case.before_each()
			var state := {"done": false}
			var run := func() -> void:
				await test_case.call(method_name)
				state["done"] = true
			run.call()
			var waited := 0.0
			while not state["done"] and waited < TEST_TIMEOUT:
				await get_tree().process_frame
				waited += get_process_delta_time()
			if not state["done"]:
				test_case.failures.append("timed out after %d s" % TEST_TIMEOUT)
			await test_case.after_each()
			if test_case.failures.is_empty():
				passed += 1
				print("PASS %s::%s" % [file, method_name])
			else:
				failed += 1
				for failure in test_case.failures:
					print("FAIL %s::%s: %s" % [file, method_name, failure])
			test_case.queue_free()
			await get_tree().process_frame
	BaselineTestCase.reset_world()
	# Let the audio thread release stopped sounds before quitting, as quit_game does.
	await get_tree().create_timer(BaselineFlow.QUIT_DRAIN_TIME, true, false, true).timeout
	if passed + failed == 0:
		failed = 1
		print("FAIL no tests ran (check --only)")
	print("RESULT passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
