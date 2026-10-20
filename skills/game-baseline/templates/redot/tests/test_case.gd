class_name BaselineTestCase
extends Node
## Base class for headless tests. Methods named test_* are run by runner.gd.

var failures: Array[String] = []


## Runs before each test method. Resets saved files and autoload state.
func before_each() -> void:
	reset_world()


func after_each() -> void:
	pass


static func reset_world() -> void:
	if Engine.get_main_loop() == null:
		return
	var root := (Engine.get_main_loop() as SceneTree).root
	if root.has_node("BaselineFlow"):
		root.get_node("BaselineFlow").reset_for_tests()
	if root.has_node("BaselineSettings"):
		root.get_node("BaselineSettings").reset_for_tests()


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func expect_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
