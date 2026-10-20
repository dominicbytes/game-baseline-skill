extends SceneTree
## Prints the baseline's static Audit checks, one PASS or FAIL line each, and
## exits with 1 when any check fails.
## Usage: <redot> --headless --path <game> -s res://baseline/tools/check_project.gd
## On a fresh checkout, import once first (<redot> --headless --path <game> --import):
## the checks still run without the class cache, but the template's autoloads
## then fail to parse after them and print errors.

# A -s script may run before the class cache exists, so load the checks by path.
const Checks := preload("res://baseline/tools/project_checks.gd")


func _init() -> void:
	var failed := false
	for result: Dictionary in Checks.run():
		print("%s %s %s" % ["PASS" if result["ok"] else "FAIL", result["id"], result["message"]])
		failed = failed or not result["ok"]
	quit(1 if failed else 0)
